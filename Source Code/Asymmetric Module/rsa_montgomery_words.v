// Protected RSA2048 arithmetic. Each bank has one registered read and one
// write port. All limbs are little endian; only the adapter owns these ports.
// The 2048 exponent bits each execute a square and a multiply. Both choices
// write the accumulator on the same schedule. No side-channel signoff implied.
module rsa_montgomery_words #(parameter IP_TYPE=0, parameter DEVICE_FAMILY="Agilex 5") (
    input wire clock_i, reset_n_i, start_i,
    input wire load_n_i, load_base_i, load_exp_i,
    input wire [5:0] load_address_i, inspect_address_i,
    input wire [31:0] n_word_i, base_word_i, exp_word_i,
    output wire [31:0] n_word_o, result_word_o,
    output wire ready_o, done_o, error_o
);
    localparam WIPE=0, REFRESH=1, IDLE=2, INV=3, INIT_READ=4, INIT_WRITE=5,
        DOUBLE_READ=6, DOUBLE_WRITE=7, REDUCE_READ=8, REDUCE_WRITE=9,
        MULT_CLEAR=10, OUTER_READ=11, OUTER_LATCH=12, AB=13, AB_TOP=14,
        FACTOR_READ=15, FACTOR_START=16, FACTOR_WAIT=17, MOD_ADD=18,
        SHIFT_TOP=19, CMP_READ=20, CMP_WORD=21, DONE=22, FAULT=23;
    localparam DOUBLE_BASE=0, SQUARE=1, TIMES_BASE=2, FROM_MONT=3;
    reg [4:0] state;
    reg [1:0] operation;
    reg [5:0] limb, outer;
    reg [6:0] issued;
    reg [10:0] bit_index, doubling;
    reg [4:0] inverse_bit;
    reg [31:0] n0, quotient, nprime, digit, factor, carry, top;
    reg high, borrow, subtract_n, double_carry;
    wire [31:0] n_q, base_q, acc_q, exp_q, temp_q;
    wire idle = state==IDLE;
    assign ready_o = reset_n_i && idle;
    assign done_o = reset_n_i && (state==DONE || state==FAULT);
    assign error_o = reset_n_i && state==FAULT;
    assign result_word_o = acc_q;
    assign n_word_o = n_q;

    // Streaming MAC. One RAM read feeds the two enabled product stages.
    // Delay the matching scratch word and index alongside the product.
    wire mac = state==AB || state==MOD_ADD;
    wire issue = mac && !issued[6];
    reg read_valid;
    reg [5:0] read_index, pipe_index1, pipe_index2;
    reg [31:0] pipe_temp1, pipe_temp2;
    wire [31:0] right_digit = state==MOD_ADD ? n_q :
        operation==SQUARE ? acc_q : operation==FROM_MONT ? {31'd0,read_index==0} : base_q;
    wire mul_valid;
    wire [63:0] product;
    keygen_mult32 #(.IP_TYPE(IP_TYPE)) multiplier (
        .clock_i(clock_i),.reset_n_i(reset_n_i),.clock_en_i(1'b1),
        .valid_i(read_valid || state==FACTOR_START),
        .left_i(state==FACTOR_START ? temp_q : state==MOD_ADD ? factor : digit),
        .right_i(state==FACTOR_START ? nprime : right_digit),
        .valid_o(mul_valid),.product_o(product));
    wire mac_write = mac && mul_valid;
    // The maximum is (B-1)^2 + 2*(B-1) = B^2-1, B=2^32.
    wire [63:0] sum = product + {32'd0,pipe_temp2} + {32'd0,carry};
    wire [32:0] top_sum = {1'b0,top} + {1'b0,carry};
    wire [32:0] inverse_sum = {1'b0,quotient} + (quotient[0] ? {1'b0,n0} : 33'd0);
    wire [31:0] doubled = {base_q[30:0],double_carry};
    wire [31:0] minuend = state==INIT_WRITE ? 32'd0 : state==DOUBLE_WRITE ? doubled : temp_q;
    wire [32:0] difference = {1'b0,minuend} - {1'b0,n_q} - {32'd0,borrow};
    wire [31:0] reduced = subtract_n ? difference[31:0] : temp_q;

    wire wipe = state==WIPE;
    wire [5:0] scan_address = mac ? issued[5:0] : limb;
    wire [5:0] n_addr = idle ? inspect_address_i : scan_address;
    wire [5:0] acc_addr = idle || state==DONE ? inspect_address_i :
        state==OUTER_READ || state==OUTER_LATCH ? outer : scan_address;
    wire [5:0] temp_addr = state==FACTOR_READ || state==FACTOR_START ? 6'd0 : scan_address;
    wire convert_write = state==REDUCE_WRITE && operation==DOUBLE_BASE;
    wire acc_write = state==REDUCE_WRITE && operation!=DOUBLE_BASE;
    wire use_square = operation==TIMES_BASE && !exp_q[bit_index[4:0]];
    wire [31:0] acc_data = wipe ? 32'd0 : state==INIT_WRITE ? difference[31:0] :
        use_square ? acc_q : reduced;
    wire temp_write = wipe || state==DOUBLE_WRITE || state==MULT_CLEAR ||
        (mac_write && (state==AB || pipe_index2!=0)) || state==SHIFT_TOP;
    wire [5:0] temp_wa = state==SHIFT_TOP ? 6'd63 : mac ?
        (state==MOD_ADD ? pipe_index2-1'b1 : pipe_index2) : limb;
    wire [31:0] temp_data = state==DOUBLE_WRITE ? doubled : state==SHIFT_TOP ?
        top_sum[31:0] : mac ? sum[31:0] : 32'd0;

    // Identical wrapper contracts on the portable and Altera implementations.
    keygen_ram32 #(.ADDRESS_WIDTH(6),.IP_TYPE(IP_TYPE),.DEVICE_FAMILY(DEVICE_FAMILY)) modulus (
        .clock_i(clock_i),.reset_n_i(reset_n_i),.clock_en_i(1'b1),.read_en_i(1'b1),
        .read_address_i(n_addr),.read_data_o(n_q),.read_valid_o(),
        .write_en_i(wipe || (idle && load_n_i)),.write_address_i(wipe ? limb : load_address_i),
        .write_data_i(idle && load_n_i ? n_word_i : 32'd0));
    keygen_ram32 #(.ADDRESS_WIDTH(6),.IP_TYPE(IP_TYPE),.DEVICE_FAMILY(DEVICE_FAMILY)) representative (
        .clock_i(clock_i),.reset_n_i(reset_n_i),.clock_en_i(1'b1),.read_en_i(1'b1),
        .read_address_i(scan_address),.read_data_o(base_q),.read_valid_o(),
        .write_en_i(wipe || (idle && load_base_i) || convert_write),
        .write_address_i(idle ? load_address_i : limb),
        .write_data_i(idle && load_base_i ? base_word_i : convert_write ? reduced : 32'd0));
    keygen_ram32 #(.ADDRESS_WIDTH(6),.IP_TYPE(IP_TYPE),.DEVICE_FAMILY(DEVICE_FAMILY)) exponent (
        .clock_i(clock_i),.reset_n_i(reset_n_i),.clock_en_i(1'b1),.read_en_i(1'b1),
        .read_address_i(bit_index[10:5]),.read_data_o(exp_q),.read_valid_o(),
        .write_en_i(wipe || (idle && load_exp_i)),.write_address_i(wipe ? limb : load_address_i),
        .write_data_i(idle && load_exp_i ? exp_word_i : 32'd0));
    keygen_ram32 #(.ADDRESS_WIDTH(6),.IP_TYPE(IP_TYPE),.DEVICE_FAMILY(DEVICE_FAMILY)) accumulator (
        .clock_i(clock_i),.reset_n_i(reset_n_i),.clock_en_i(1'b1),.read_en_i(1'b1),
        .read_address_i(acc_addr),.read_data_o(acc_q),.read_valid_o(),
        .write_en_i(wipe || state==INIT_WRITE || acc_write),.write_address_i(limb),.write_data_i((state==INIT_WRITE || acc_write) ? acc_data : 32'd0));
    keygen_ram32 #(.ADDRESS_WIDTH(6),.IP_TYPE(IP_TYPE),.DEVICE_FAMILY(DEVICE_FAMILY)) scratch (
        .clock_i(clock_i),.reset_n_i(reset_n_i),.clock_en_i(1'b1),.read_en_i(1'b1),
        .read_address_i(temp_addr),.read_data_o(temp_q),.read_valid_o(),
        .write_en_i(temp_write),.write_address_i(temp_wa),.write_data_i(temp_data));

    always @(posedge clock_i or negedge reset_n_i) begin
        if(!reset_n_i) begin
            state<=WIPE; operation<=DOUBLE_BASE; limb<=0; outer<=0; issued<=0;
            bit_index<=0; doubling<=0; inverse_bit<=0; n0<=0; quotient<=0;
            nprime<=0; digit<=0; factor<=0; carry<=0; top<=0; high<=0;
            borrow<=0; subtract_n<=0; double_carry<=0; read_valid<=0;
            read_index<=0; pipe_index1<=0; pipe_index2<=0; pipe_temp1<=0; pipe_temp2<=0;
        end else begin
            read_valid<=issue;
            read_index<=issue ? issued[5:0] : 6'd0;
            pipe_index1<=read_index; pipe_index2<=pipe_index1;
            pipe_temp1<=read_valid ? temp_q : 32'd0; pipe_temp2<=pipe_temp1;
            if(issue) issued<=issued+1'b1;
            case(state)
                WIPE: begin
                    limb<=limb+1'b1;
                    if(limb==63) state<=REFRESH;
                end
                REFRESH: state<=IDLE;
                IDLE: begin
                    if(load_n_i && load_address_i==0) n0<=n_word_i;
                    if(start_i) begin
                        quotient<=1; inverse_bit<=0; nprime<=0; state<=INV;
                    end
                end
                // Select k one bit at a time so that 1+n0*k is divisible by R_word.
                INV: begin
                    nprime[inverse_bit]<=quotient[0]; quotient<=inverse_sum[32:1];
                    inverse_bit<=inverse_bit+1'b1;
                    if(inverse_bit==31) begin limb<=0; borrow<=0; state<=INIT_READ; end
                end
                INIT_READ: state<=INIT_WRITE;
                // With the mandatory top bit set, R mod n = R-n.
                INIT_WRITE: begin
                    borrow<=difference[32]; limb<=limb+1'b1; state<=INIT_READ;
                    if(limb==63) begin
                        borrow<=0; double_carry<=0; doubling<=0;
                        operation<=DOUBLE_BASE; state<=DOUBLE_READ;
                    end
                end
                DOUBLE_READ: state<=DOUBLE_WRITE;
                DOUBLE_WRITE: begin
                    double_carry<=base_q[31]; borrow<=difference[32]; limb<=limb+1'b1;
                    state<=DOUBLE_READ;
                    if(limb==63) begin
                        subtract_n<=base_q[31] || !difference[32]; borrow<=0; state<=REDUCE_READ;
                    end
                end
                REDUCE_READ: state<=REDUCE_WRITE;
                REDUCE_WRITE: begin
                    borrow<=difference[32]; limb<=limb+1'b1; state<=REDUCE_READ;
                    if(limb==63) begin
                        borrow<=0; double_carry<=0;
                        case(operation)
                            DOUBLE_BASE: if(doubling!=2047) begin
                                doubling<=doubling+1'b1; state<=DOUBLE_READ;
                            end else begin
                                bit_index<=2047; operation<=SQUARE; state<=MULT_CLEAR;
                            end
                            SQUARE: begin operation<=TIMES_BASE; state<=MULT_CLEAR; end
                            TIMES_BASE: begin
                                operation<=bit_index==0 ? FROM_MONT : SQUARE;
                                bit_index<=bit_index-1'b1; state<=MULT_CLEAR;
                            end
                            FROM_MONT: state<=DONE;
                        endcase
                    end
                end
                MULT_CLEAR: begin
                    limb<=limb+1'b1;
                    if(limb==63) begin top<=0; outer<=0; state<=OUTER_READ; end
                end
                OUTER_READ: state<=OUTER_LATCH;
                OUTER_LATCH: begin digit<=acc_q; issued<=0; carry<=0; state<=AB; end
                AB, MOD_ADD: if(mac_write) begin
                    carry<=sum[63:32];
                    if(state==MOD_ADD && pipe_index2==0 && sum[31:0]!=0) state<=FAULT;
                    else if(pipe_index2==63) state<=state==AB ? AB_TOP : SHIFT_TOP;
                end
                AB_TOP: begin top<=top_sum[31:0]; high<=top_sum[32]; state<=FACTOR_READ; end
                FACTOR_READ: state<=FACTOR_START;
                FACTOR_START: state<=FACTOR_WAIT;
                FACTOR_WAIT: if(mul_valid) begin
                    factor<=product[31:0]; issued<=0; carry<=0; state<=MOD_ADD;
                end
                SHIFT_TOP: begin
                    top<={31'd0,high}+{31'd0,top_sum[32]}; outer<=outer+1'b1;
                    if(outer==63) begin limb<=0; borrow<=0; state<=CMP_READ; end
                    else state<=OUTER_READ;
                end
                CMP_READ: state<=CMP_WORD;
                CMP_WORD: begin
                    borrow<=difference[32]; limb<=limb+1'b1; state<=CMP_READ;
                    if(limb==63) begin
                        subtract_n<=top!=0 || !difference[32]; borrow<=0; state<=REDUCE_READ;
                    end
                end
                DONE, FAULT: state<=state; // Held until adapter takes the result and scrubs.
                default: state<=FAULT;
            endcase
        end
    end
endmodule
