// Filename: keygen_math.v
// Modules: keygen_math
// Authors: Aaron Grossman; Project contributors; see Git history.
// Date: 2026-10-13
// General Description: Executes shared limb arithmetic, Montgomery multiplication and exponentiation in private scratch memory.
// AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

// Private-scratch arithmetic service. Words are little-endian 32-bit limbs.
// Reset invalidates immediately, then sweeps all RAM and operand registers.

// IP_TYPE: 0 = Generic, 1 = Altera, 2 = reserved Xilinx (unsupported).
// COMPACT_STORAGE=1 uses serial synchronous operand banks; default=0 preserves legacy cycle behavior.
module keygen_math #(parameter MAX_LIMBS = 64, parameter COMPACT_STORAGE = 0, parameter IP_TYPE = 0, parameter DEVICE_FAMILY = "Agilex 5") (
    input clock_i, input reset_n_i,
    input cmd_valid_i, output cmd_ready_o,
    input [7:0] cmd_op_i,
    input [31:0] cmd_arg0_i, input [31:0] cmd_arg1_i,
    input [31:0] cmd_arg2_i, input [31:0] cmd_arg3_i,
    output rsp_valid_o, input rsp_ready_i, output [7:0] rsp_status_o,
    input mem_write_en_i, input mem_read_en_i,
    input [11:0] mem_address_i, input [31:0] mem_write_data_i,
    output mem_ready_o, output mem_read_valid_o,
    output [31:0] mem_read_data_o
);
    generate if (COMPACT_STORAGE) begin : compact
        keygen_math_compact #(.MAX_LIMBS(MAX_LIMBS), .IP_TYPE(IP_TYPE), .DEVICE_FAMILY(DEVICE_FAMILY)) implementation (
            .clock_i(clock_i),.reset_n_i(reset_n_i),.cmd_valid_i(cmd_valid_i),.cmd_ready_o(cmd_ready_o),
            .cmd_op_i(cmd_op_i),.cmd_arg0_i(cmd_arg0_i),.cmd_arg1_i(cmd_arg1_i),.cmd_arg2_i(cmd_arg2_i),.cmd_arg3_i(cmd_arg3_i),
            .rsp_valid_o(rsp_valid_o),.rsp_ready_i(rsp_ready_i),.rsp_status_o(rsp_status_o),
            .mem_write_en_i(mem_write_en_i),.mem_read_en_i(mem_read_en_i),.mem_address_i(mem_address_i),
            .mem_write_data_i(mem_write_data_i),.mem_ready_o(mem_ready_o),.mem_read_valid_o(mem_read_valid_o),.mem_read_data_o(mem_read_data_o)
        );
    end else begin : legacy
        keygen_math_legacy #(.MAX_LIMBS(MAX_LIMBS), .IP_TYPE(IP_TYPE), .DEVICE_FAMILY(DEVICE_FAMILY)) implementation (
            .clock_i(clock_i),.reset_n_i(reset_n_i),.cmd_valid_i(cmd_valid_i),.cmd_ready_o(cmd_ready_o),
            .cmd_op_i(cmd_op_i),.cmd_arg0_i(cmd_arg0_i),.cmd_arg1_i(cmd_arg1_i),.cmd_arg2_i(cmd_arg2_i),.cmd_arg3_i(cmd_arg3_i),
            .rsp_valid_o(rsp_valid_o),.rsp_ready_i(rsp_ready_i),.rsp_status_o(rsp_status_o),
            .mem_write_en_i(mem_write_en_i),.mem_read_en_i(mem_read_en_i),.mem_address_i(mem_address_i),
            .mem_write_data_i(mem_write_data_i),.mem_ready_o(mem_ready_o),.mem_read_valid_o(mem_read_valid_o),.mem_read_data_o(mem_read_data_o)
        );
    end endgenerate
endmodule

module keygen_math_legacy #(parameter MAX_LIMBS = 64, parameter IP_TYPE = 0, parameter DEVICE_FAMILY = "Agilex 5") (
    input clock_i, input reset_n_i,
    input cmd_valid_i, output cmd_ready_o,
    input [7:0] cmd_op_i,
    input [31:0] cmd_arg0_i, input [31:0] cmd_arg1_i,
    input [31:0] cmd_arg2_i, input [31:0] cmd_arg3_i,
    output rsp_valid_o, input rsp_ready_i, output [7:0] rsp_status_o,
    input mem_write_en_i, input mem_read_en_i,
    input [11:0] mem_address_i, input [31:0] mem_write_data_i,
    output mem_ready_o, output mem_read_valid_o,
    output [31:0] mem_read_data_o
);
    localparam COPY=8'h01, ZERO=8'h02, COMPARE=8'h03, ADD=8'h04,
               SUB=8'h05, SHIFT_RIGHT=8'h06, MUL=8'h10,
               MOD_SETUP=8'h11, MONT_MUL=8'h12, MODEXP=8'h13;
    localparam CLEAR=0, IDLE=1, RESPONSE=2, LOAD_A=3, WAIT_A=4,
               LOAD_B=5, WAIT_B=6, PREPARE=7, WRITE=8,
               SIMPLE=9, CMP=10, PRODUCT_INIT=11, PRODUCT_NEXT=12,
               MULT_START=13, MULT_WAIT=14, INVERSE_START=15,
               R2_INIT=16, R2_DOUBLE=17, R2_COMPARE=18, R2_SUB=19,
               R2_NEXT=20, MONT_INIT=21, MONT_AB=22, MONT_CARRY=23,
               MONT_FACTOR=24, MONT_N=25, MONT_SHIFT=26,
               MONT_COMPARE=27, MONT_SUB=28, MONT_COPY=29,
               EXP_BASE_DONE=30, EXP_ONE_DONE=31, EXP_SQUARE=32,
               EXP_SQUARE_DONE=33, EXP_BIT_DONE=34, CHECK_A=35, CHECK_B=36, MONT_DISPATCH=37, CLEAR_READ=38, CLEAR_WAIT=39;
    localparam MULT_SCHOOL=0, MULT_INVERSE_A=1, MULT_INVERSE_B=2,
               MULT_MONT_AB=3, MULT_MONT_FACTOR=4, MULT_MONT_N=5;
    reg [5:0] state_reg;
    reg [7:0] op_reg, status_reg;
    reg [11:0] clear_address_reg, destination_reg, source_a_reg, source_b_reg;
    reg [6:0] length_reg, modulus_length_reg, exponent_length_reg;
    reg [7:0] index_reg, outer_reg, compare_index_reg;
    reg [31:0] a_reg [0:MAX_LIMBS-1];
    reg [31:0] b_reg [0:MAX_LIMBS-1];
    reg [31:0] modulus_reg [0:MAX_LIMBS-1];
    reg [31:0] r2_reg [0:MAX_LIMBS-1];
    reg [31:0] exponent_reg [0:MAX_LIMBS-1];
    reg [31:0] base_reg [0:MAX_LIMBS-1];
    reg [31:0] temporary_reg [0:2*MAX_LIMBS+1];
    reg context_valid_reg;
    reg [31:0] inverse_reg, nprime_reg, factor_reg, carry_reg;
    reg borrow_reg;
    reg [2:0] inverse_step_reg, mult_mode_reg;
    reg [12:0] double_count_reg;
    reg [11:0] exponent_bit_reg;
    reg [5:0] return_state_reg;
    reg [31:0] mult_left_reg, mult_right_reg;
    wire mult_valid;
    wire [63:0] product;
    wire [63:0] accumulated_product = product + {32'b0,temporary_reg[index_reg]} + {32'b0,carry_reg};
    wire [63:0] school_product = product + {32'b0,temporary_reg[outer_reg+index_reg]} + {32'b0,carry_reg};
    wire [32:0] doubled_word = {a_reg[index_reg],1'b0} + {1'b0,carry_reg};
    wire [32:0] sum_word = {1'b0,a_reg[index_reg]} + {1'b0,b_reg[index_reg]} + {1'b0,carry_reg};
    wire [32:0] difference_word = {1'b0,a_reg[index_reg]} - {1'b0,b_reg[index_reg]} - {32'b0,borrow_reg};
    wire [32:0] reduction_word = {1'b0,a_reg[index_reg]} - {1'b0,modulus_reg[index_reg]} - {32'b0,borrow_reg};
    wire [32:0] mont_reduction_word = {1'b0,temporary_reg[index_reg]} - {1'b0,modulus_reg[index_reg]} - {32'b0,borrow_reg};
    wire [32:0] top_sum = {1'b0,temporary_reg[length_reg]} + {1'b0,carry_reg};
    reg ram_write_en, ram_read_en;
    reg [11:0] ram_write_address, ram_read_address;
    reg [31:0] ram_write_data;
    wire [31:0] ram_read_data;
    reg private_read_valid_reg;
    integer clear_index;

    assign cmd_ready_o = state_reg == IDLE;
    assign rsp_valid_o = state_reg == RESPONSE;
    assign rsp_status_o = status_reg;
    assign mem_ready_o = state_reg == IDLE && !cmd_valid_i;
    assign mem_read_valid_o = private_read_valid_reg;
    assign mem_read_data_o = ram_read_data;
    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) private_read_valid_reg <= 1'b0;
        else private_read_valid_reg <= mem_ready_o && mem_read_en_i;
    end
    keygen_mult32 #(.IP_TYPE(IP_TYPE)) multiply (
        .clock_i(clock_i), .reset_n_i(reset_n_i), .clock_en_i(1'b1),
        .valid_i(state_reg == MULT_START), .left_i(mult_left_reg),
        .right_i(mult_right_reg), .valid_o(mult_valid), .product_o(product)
    );
    keygen_ram32 #(.ADDRESS_WIDTH(12), .IP_TYPE(IP_TYPE), .DEVICE_FAMILY(DEVICE_FAMILY)) scratch (
        .clock_i(clock_i), .reset_n_i(reset_n_i), .clock_en_i(1'b1),
        .write_en_i(ram_write_en), .write_address_i(ram_write_address),
        .write_data_i(ram_write_data), .read_en_i(ram_read_en),
        .read_address_i(ram_read_address), .read_valid_o(), .read_data_o(ram_read_data)
    );
    always @* begin
        ram_write_en = 1'b0; ram_read_en = 1'b0;
        ram_write_address = 12'b0; ram_read_address = 12'b0;
        ram_write_data = 32'b0;
        if (state_reg == CLEAR) begin
            ram_write_en = 1'b1; ram_write_address = clear_address_reg;
        end else if (state_reg == CLEAR_READ) begin
            // Refresh the RAM output latch without a collision after all writes.
            ram_read_en = 1'b1; ram_read_address = 12'd4095;
        end else if (mem_ready_o) begin
            ram_write_en = mem_write_en_i; ram_read_en = mem_read_en_i;
            ram_write_address = mem_address_i; ram_read_address = mem_address_i;
            ram_write_data = mem_write_data_i;
        end else if (state_reg == LOAD_A) begin
            ram_read_en = 1'b1; ram_read_address = source_a_reg + index_reg;
        end else if (state_reg == LOAD_B) begin
            ram_read_en = 1'b1; ram_read_address = source_b_reg + index_reg;
        end else if (state_reg == WRITE) begin
            ram_write_en = 1'b1; ram_write_address = destination_reg + index_reg;
            if (op_reg == ZERO) ram_write_data = 32'b0;
            else if (op_reg == MUL) ram_write_data = temporary_reg[index_reg];
            else ram_write_data = a_reg[index_reg];
        end
    end
    // Only command metadata crosses the CPU interface. Arithmetic operands
    // enter through the private scratch port, never through response status.
    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            state_reg <= CLEAR; clear_address_reg <= 0;
            context_valid_reg <= 0; status_reg <= 0;
            op_reg <= 0; destination_reg <= 0; source_a_reg <= 0; source_b_reg <= 0;
            length_reg <= 0; modulus_length_reg <= 0; exponent_length_reg <= 0;
            index_reg <= 0; outer_reg <= 0; compare_index_reg <= 0;
            inverse_reg <= 0; nprime_reg <= 0; factor_reg <= 0; carry_reg <= 0;
            borrow_reg <= 0; inverse_step_reg <= 0; mult_mode_reg <= 0;
            double_count_reg <= 0; exponent_bit_reg <= 0; return_state_reg <= 0;
            mult_left_reg <= 0; mult_right_reg <= 0;
        end else begin
            case (state_reg)
                CLEAR: begin
                    if (clear_address_reg < MAX_LIMBS) begin
                        a_reg[clear_address_reg] <= 0; b_reg[clear_address_reg] <= 0;
                        modulus_reg[clear_address_reg] <= 0; r2_reg[clear_address_reg] <= 0;
                        exponent_reg[clear_address_reg] <= 0; base_reg[clear_address_reg] <= 0;
                    end
                    if (clear_address_reg < 2*MAX_LIMBS+2) temporary_reg[clear_address_reg] <= 0;
                    if (clear_address_reg == 4095) state_reg <= CLEAR_READ;
                    else clear_address_reg <= clear_address_reg + 1'b1;
                end
                CLEAR_READ: state_reg <= CLEAR_WAIT;
                CLEAR_WAIT: state_reg <= IDLE;
                IDLE: if (cmd_valid_i) begin
                    op_reg <= cmd_op_i; status_reg <= 0; index_reg <= 0;
                    destination_reg <= cmd_arg0_i[11:0]; source_a_reg <= cmd_arg1_i[11:0];
                    source_b_reg <= cmd_arg2_i[11:0];
                    length_reg <= cmd_arg3_i[6:0]; state_reg <= LOAD_A;
                    if (cmd_op_i == MOD_SETUP) begin
                        context_valid_reg <= 0;
                        source_a_reg <= cmd_arg0_i[11:0]; length_reg <= cmd_arg2_i[6:0];
                        modulus_length_reg <= cmd_arg2_i[6:0];
                        if (cmd_arg2_i == 0 || cmd_arg2_i > MAX_LIMBS || cmd_arg3_i != 0 ||
                            cmd_arg0_i > 4096-cmd_arg2_i ||
                            cmd_arg1_i > 4096-(cmd_arg2_i*4+2)) begin
                            status_reg <= 2; state_reg <= RESPONSE;
                        end else if (cmd_arg0_i < cmd_arg1_i+cmd_arg2_i*4+2 &&
                                     cmd_arg1_i < cmd_arg0_i+cmd_arg2_i) begin
                            status_reg <= 3; state_reg <= RESPONSE;
                        end
                    end else if (cmd_op_i == MONT_MUL || cmd_op_i == MODEXP) begin
                        length_reg <= modulus_length_reg;
                        exponent_length_reg <= cmd_arg3_i[6:0];
                        if (!context_valid_reg) begin status_reg <= 4; state_reg <= RESPONSE; end
                        else if (cmd_arg0_i > 4096-modulus_length_reg ||
                                 cmd_arg1_i > 4096-modulus_length_reg ||
                                 cmd_arg2_i > 4096-(cmd_op_i == MODEXP ? cmd_arg3_i : modulus_length_reg) ||
                                 (cmd_op_i == MODEXP && (cmd_arg3_i == 0 || cmd_arg3_i > MAX_LIMBS)) ||
                                 (cmd_op_i == MONT_MUL && cmd_arg3_i != 0)) begin
                            status_reg <= 2; state_reg <= RESPONSE;
                        end
                    end else if (cmd_op_i == COPY || cmd_op_i == ZERO || cmd_op_i == COMPARE ||
                                 cmd_op_i == ADD || cmd_op_i == SUB || cmd_op_i == SHIFT_RIGHT || cmd_op_i == MUL) begin
                        if (cmd_arg3_i == 0 || cmd_arg3_i > MAX_LIMBS ||
                            cmd_arg0_i > 4096-(cmd_op_i == MUL ? cmd_arg3_i*2 : cmd_arg3_i) ||
                            (cmd_op_i != ZERO && cmd_arg1_i > 4096-cmd_arg3_i) ||
                            ((cmd_op_i == COMPARE || cmd_op_i == ADD || cmd_op_i == SUB || cmd_op_i == MUL) &&
                             cmd_arg2_i > 4096-cmd_arg3_i)) begin status_reg <= 2; state_reg <= RESPONSE; end
                        else if (cmd_op_i == ZERO) state_reg <= WRITE;
                    end else begin status_reg <= 1; state_reg <= RESPONSE; end
                end
                RESPONSE: if (rsp_ready_i) state_reg <= IDLE;
                LOAD_A: state_reg <= WAIT_A;
                WAIT_A: begin
                    if (op_reg == MOD_SETUP) modulus_reg[index_reg] <= ram_read_data;
                    else a_reg[index_reg] <= ram_read_data;
                    if (index_reg == length_reg-1) begin
                        index_reg <= 0;
                        if (op_reg == COPY) state_reg <= WRITE;
                        else if (op_reg == MOD_SETUP || op_reg == SHIFT_RIGHT) state_reg <= PREPARE;
                        else state_reg <= LOAD_B;
                    end else begin index_reg <= index_reg+1'b1; state_reg <= LOAD_A; end
                end
                LOAD_B: state_reg <= WAIT_B;
                WAIT_B: begin
                    if (op_reg == MODEXP) exponent_reg[index_reg] <= ram_read_data;
                    else b_reg[index_reg] <= ram_read_data;
                    if (index_reg == (op_reg == MODEXP ? exponent_length_reg : length_reg)-1) begin
                        index_reg <= 0; state_reg <= PREPARE;
                    end else begin index_reg <= index_reg+1'b1; state_reg <= LOAD_B; end
                end
                PREPARE: begin
                    carry_reg <= 0; borrow_reg <= 0; index_reg <= 0;
                    if (op_reg == MOD_SETUP) begin
                        if (!modulus_reg[0][0] || modulus_reg[length_reg-1] == 0 ||
                            (length_reg == 1 && modulus_reg[0] <= 1)) begin status_reg <= 4; state_reg <= RESPONSE; end
                        else begin inverse_reg <= 1; inverse_step_reg <= 0; state_reg <= INVERSE_START; end
                    end else if (op_reg == COMPARE) begin compare_index_reg <= length_reg-1; state_reg <= CMP; end
                    else if (op_reg == MUL) begin index_reg <= 0; state_reg <= PRODUCT_INIT; end
                    else if (op_reg == MONT_MUL || op_reg == MODEXP) begin compare_index_reg <= length_reg-1; state_reg <= CHECK_A; end
                    else state_reg <= SIMPLE;
                end
                CHECK_A: begin
                    if (a_reg[compare_index_reg] > modulus_reg[compare_index_reg] ||
                        (a_reg[compare_index_reg] == modulus_reg[compare_index_reg] && compare_index_reg == 0)) begin
                        status_reg <= 4; state_reg <= RESPONSE;
                    end else if (a_reg[compare_index_reg] < modulus_reg[compare_index_reg]) begin
                        compare_index_reg <= length_reg-1;
                        state_reg <= op_reg == MONT_MUL ? CHECK_B : MONT_DISPATCH;
                    end else compare_index_reg <= compare_index_reg-1'b1;
                end
                CHECK_B: begin
                    if (b_reg[compare_index_reg] > modulus_reg[compare_index_reg] ||
                        (b_reg[compare_index_reg] == modulus_reg[compare_index_reg] && compare_index_reg == 0)) begin
                        status_reg <= 4; state_reg <= RESPONSE;
                    end else if (b_reg[compare_index_reg] < modulus_reg[compare_index_reg]) state_reg <= MONT_DISPATCH;
                    else compare_index_reg <= compare_index_reg-1'b1;
                end
                MONT_DISPATCH: begin
                    if (op_reg == MONT_MUL) return_state_reg <= WRITE;
                    else begin
                        for (clear_index=0; clear_index<MAX_LIMBS; clear_index=clear_index+1) b_reg[clear_index] <= r2_reg[clear_index];
                        return_state_reg <= EXP_BASE_DONE;
                    end
                    state_reg <= MONT_INIT;
                end
                WRITE: begin
                    if (index_reg == (op_reg == MUL ? length_reg*2 : length_reg)-1) begin
                        index_reg <= 0; state_reg <= RESPONSE;
                    end else index_reg <= index_reg+1'b1;
                end
                SIMPLE: begin
                    if (op_reg == ADD) begin a_reg[index_reg] <= sum_word[31:0]; carry_reg <= {31'b0,sum_word[32]}; end
                    else if (op_reg == SUB) begin a_reg[index_reg] <= difference_word[31:0]; borrow_reg <= difference_word[32]; end
                    else a_reg[index_reg] <= {index_reg == length_reg-1 ? 1'b0 : a_reg[index_reg+1][0], a_reg[index_reg][31:1]};
                    if (index_reg == length_reg-1) begin index_reg <= 0; state_reg <= WRITE; end
                    else index_reg <= index_reg+1'b1;
                end
                CMP: begin
                    if (a_reg[compare_index_reg] < b_reg[compare_index_reg]) begin status_reg <= 8'h10; state_reg <= RESPONSE; end
                    else if (a_reg[compare_index_reg] > b_reg[compare_index_reg]) begin status_reg <= 8'h12; state_reg <= RESPONSE; end
                    else if (compare_index_reg == 0) begin status_reg <= 8'h11; state_reg <= RESPONSE; end
                    else compare_index_reg <= compare_index_reg-1'b1;
                end
                PRODUCT_INIT: begin
                    temporary_reg[index_reg] <= 0;
                    if (index_reg == length_reg*2-1) begin index_reg <= 0; outer_reg <= 0; carry_reg <= 0; state_reg <= PRODUCT_NEXT; end
                    else index_reg <= index_reg+1'b1;
                end
                PRODUCT_NEXT: begin
                    mult_left_reg <= a_reg[outer_reg]; mult_right_reg <= b_reg[index_reg];
                    mult_mode_reg <= MULT_SCHOOL; state_reg <= MULT_START;
                end
                INVERSE_START: begin
                    mult_left_reg <= modulus_reg[0]; mult_right_reg <= inverse_reg;
                    mult_mode_reg <= MULT_INVERSE_A; state_reg <= MULT_START;
                end
                MULT_START: state_reg <= MULT_WAIT;
                MULT_WAIT: if (mult_valid) begin
                    case (mult_mode_reg)
                        MULT_SCHOOL: begin
                            temporary_reg[outer_reg+index_reg] <= school_product[31:0]; carry_reg <= school_product[63:32];
                            if (index_reg == length_reg-1) begin
                                temporary_reg[outer_reg+length_reg] <= school_product[63:32];
                                index_reg <= 0; carry_reg <= 0;
                                if (outer_reg == length_reg-1) state_reg <= WRITE;
                                else begin outer_reg <= outer_reg+1'b1; state_reg <= PRODUCT_NEXT; end
                            end else begin index_reg <= index_reg+1'b1; state_reg <= PRODUCT_NEXT; end
                        end
                        MULT_INVERSE_A: begin
                            mult_left_reg <= inverse_reg; mult_right_reg <= 32'd2-product[31:0];
                            mult_mode_reg <= MULT_INVERSE_B; state_reg <= MULT_START;
                        end
                        MULT_INVERSE_B: begin
                            inverse_reg <= product[31:0];
                            if (inverse_step_reg == 4) begin nprime_reg <= -product[31:0]; state_reg <= R2_INIT; end
                            else begin inverse_step_reg <= inverse_step_reg+1'b1; state_reg <= INVERSE_START; end
                        end
                        MULT_MONT_AB: begin
                            temporary_reg[index_reg] <= accumulated_product[31:0]; carry_reg <= accumulated_product[63:32];
                            if (index_reg == length_reg-1) state_reg <= MONT_CARRY;
                            else begin index_reg <= index_reg+1'b1; state_reg <= MONT_AB; end
                        end
                        MULT_MONT_FACTOR: begin factor_reg <= product[31:0]; index_reg <= 0; carry_reg <= 0; state_reg <= MONT_N; end
                        MULT_MONT_N: begin
                            if (index_reg != 0) temporary_reg[index_reg-1] <= accumulated_product[31:0];
                            carry_reg <= accumulated_product[63:32];
                            if (index_reg == length_reg-1) state_reg <= MONT_SHIFT;
                            else begin index_reg <= index_reg+1'b1; state_reg <= MONT_N; end
                        end
                        default: begin status_reg <= 5; state_reg <= RESPONSE; end
                    endcase
                end
                R2_INIT: begin
                    for (clear_index=0; clear_index<MAX_LIMBS; clear_index=clear_index+1) a_reg[clear_index] <= 0;
                    a_reg[0] <= 1; double_count_reg <= {modulus_length_reg,6'b0};
                    index_reg <= 0; carry_reg <= 0; state_reg <= R2_DOUBLE;
                end
                R2_DOUBLE: begin
                    a_reg[index_reg] <= doubled_word[31:0]; carry_reg <= {31'b0,doubled_word[32]};
                    if (index_reg == length_reg-1) begin compare_index_reg <= length_reg-1; state_reg <= R2_COMPARE; end
                    else index_reg <= index_reg+1'b1;
                end
                R2_COMPARE: begin
                    if (carry_reg != 0 || a_reg[compare_index_reg] > modulus_reg[compare_index_reg]) begin index_reg <= 0; borrow_reg <= 0; state_reg <= R2_SUB; end
                    else if (a_reg[compare_index_reg] < modulus_reg[compare_index_reg]) state_reg <= R2_NEXT;
                    else if (compare_index_reg == 0) begin index_reg <= 0; borrow_reg <= 0; state_reg <= R2_SUB; end
                    else compare_index_reg <= compare_index_reg-1'b1;
                end
                R2_SUB: begin
                    a_reg[index_reg] <= reduction_word[31:0]; borrow_reg <= reduction_word[32];
                    if (index_reg == length_reg-1) state_reg <= R2_NEXT;
                    else index_reg <= index_reg+1'b1;
                end
                R2_NEXT: begin
                    if (double_count_reg == 1) begin
                        for (clear_index=0; clear_index<MAX_LIMBS; clear_index=clear_index+1) r2_reg[clear_index] <= a_reg[clear_index];
                        context_valid_reg <= 1; state_reg <= RESPONSE;
                    end else begin double_count_reg <= double_count_reg-1'b1; index_reg <= 0; carry_reg <= 0; state_reg <= R2_DOUBLE; end
                end
                MONT_INIT: begin
                    for (clear_index=0; clear_index<MAX_LIMBS+2; clear_index=clear_index+1) temporary_reg[clear_index] <= 0;
                    index_reg <= 0; outer_reg <= 0; carry_reg <= 0; state_reg <= MONT_AB;
                end
                MONT_AB: begin
                    mult_left_reg <= a_reg[index_reg]; mult_right_reg <= b_reg[outer_reg];
                    mult_mode_reg <= MULT_MONT_AB; state_reg <= MULT_START;
                end
                MONT_CARRY: begin
                    temporary_reg[length_reg] <= top_sum[31:0]; temporary_reg[length_reg+1'b1] <= {31'b0,top_sum[32]};
                    state_reg <= MONT_FACTOR;
                end
                MONT_FACTOR: begin
                    mult_left_reg <= temporary_reg[0]; mult_right_reg <= nprime_reg;
                    mult_mode_reg <= MULT_MONT_FACTOR; state_reg <= MULT_START;
                end
                MONT_N: begin
                    mult_left_reg <= factor_reg; mult_right_reg <= modulus_reg[index_reg];
                    mult_mode_reg <= MULT_MONT_N; state_reg <= MULT_START;
                end
                MONT_SHIFT: begin
                    temporary_reg[length_reg-1'b1] <= top_sum[31:0];
                    temporary_reg[length_reg] <= temporary_reg[length_reg+1'b1] + {31'b0,top_sum[32]};
                    index_reg <= 0; carry_reg <= 0;
                    if (outer_reg == length_reg-1) begin compare_index_reg <= length_reg-1; state_reg <= MONT_COMPARE; end
                    else begin outer_reg <= outer_reg+1'b1; state_reg <= MONT_AB; end
                end
                MONT_COMPARE: begin
                    if (temporary_reg[length_reg] != 0 || temporary_reg[compare_index_reg] > modulus_reg[compare_index_reg]) begin index_reg <= 0; borrow_reg <= 0; state_reg <= MONT_SUB; end
                    else if (temporary_reg[compare_index_reg] < modulus_reg[compare_index_reg]) begin index_reg <= 0; state_reg <= MONT_COPY; end
                    else if (compare_index_reg == 0) begin index_reg <= 0; borrow_reg <= 0; state_reg <= MONT_SUB; end
                    else compare_index_reg <= compare_index_reg-1'b1;
                end
                MONT_SUB: begin
                    a_reg[index_reg] <= mont_reduction_word[31:0]; borrow_reg <= mont_reduction_word[32];
                    if (index_reg == length_reg-1) begin index_reg <= 0; state_reg <= return_state_reg; end
                    else index_reg <= index_reg+1'b1;
                end
                MONT_COPY: begin
                    a_reg[index_reg] <= temporary_reg[index_reg];
                    if (index_reg == length_reg-1) begin index_reg <= 0; state_reg <= return_state_reg; end
                    else index_reg <= index_reg+1'b1;
                end
                EXP_BASE_DONE: begin
                    for (clear_index=0; clear_index<MAX_LIMBS; clear_index=clear_index+1) begin
                        base_reg[clear_index] <= a_reg[clear_index]; a_reg[clear_index] <= 0; b_reg[clear_index] <= r2_reg[clear_index];
                    end
                    a_reg[0] <= 1; return_state_reg <= EXP_ONE_DONE; state_reg <= MONT_INIT;
                end
                EXP_ONE_DONE: begin exponent_bit_reg <= exponent_length_reg*32-1; state_reg <= EXP_SQUARE; end
                EXP_SQUARE: begin
                    for (clear_index=0; clear_index<MAX_LIMBS; clear_index=clear_index+1) b_reg[clear_index] <= a_reg[clear_index];
                    return_state_reg <= EXP_SQUARE_DONE; state_reg <= MONT_INIT;
                end
                EXP_SQUARE_DONE: begin
                    if (exponent_reg[exponent_bit_reg[10:5]][exponent_bit_reg[4:0]]) begin
                        for (clear_index=0; clear_index<MAX_LIMBS; clear_index=clear_index+1) b_reg[clear_index] <= base_reg[clear_index];
                        return_state_reg <= EXP_BIT_DONE; state_reg <= MONT_INIT;
                    end else state_reg <= EXP_BIT_DONE;
                end
                EXP_BIT_DONE: begin
                    if (exponent_bit_reg == 0) begin
                        for (clear_index=0; clear_index<MAX_LIMBS; clear_index=clear_index+1) b_reg[clear_index] <= 0;
                        b_reg[0] <= 1; return_state_reg <= WRITE; state_reg <= MONT_INIT;
                    end else begin exponent_bit_reg <= exponent_bit_reg-1'b1; state_reg <= EXP_SQUARE; end
                end
                default: begin status_reg <= 5; state_reg <= RESPONSE; end
            endcase
        end
    end
endmodule

module keygen_math_compact #(parameter MAX_LIMBS = 64, parameter IP_TYPE = 0, parameter DEVICE_FAMILY = "Agilex 5") (
    input clock_i, input reset_n_i,
    input cmd_valid_i, output cmd_ready_o,
    input [7:0] cmd_op_i,
    input [31:0] cmd_arg0_i, input [31:0] cmd_arg1_i,
    input [31:0] cmd_arg2_i, input [31:0] cmd_arg3_i,
    output rsp_valid_o, input rsp_ready_i, output [7:0] rsp_status_o,
    input mem_write_en_i, input mem_read_en_i,
    input [11:0] mem_address_i, input [31:0] mem_write_data_i,
    output mem_ready_o, output mem_read_valid_o,
    output [31:0] mem_read_data_o
);
    localparam COPY=8'h01, ZERO=8'h02, COMPARE=8'h03, ADD=8'h04,
               SUB=8'h05, SHIFT_RIGHT=8'h06, MUL=8'h10,
               MOD_SETUP=8'h11, MONT_MUL=8'h12, MODEXP=8'h13;
    localparam CLEAR=0, IDLE=1, RESPONSE=2, LOAD_A=3, WAIT_A=4,
               LOAD_B=5, WAIT_B=6, PREPARE=7, WRITE=8,
               SIMPLE=9, CMP=10, PRODUCT_INIT=11, PRODUCT_NEXT=12,
               MULT_START=13, MULT_WAIT=14, INVERSE_START=15,
               R2_INIT=16, R2_DOUBLE=17, R2_COMPARE=18, R2_SUB=19,
               R2_NEXT=20, MONT_INIT=21, MONT_AB=22, MONT_CARRY=23,
               MONT_FACTOR=24, MONT_N=25, MONT_SHIFT=26,
               MONT_COMPARE=27, MONT_SUB=28, MONT_COPY=29,
               EXP_BASE_DONE=30, EXP_ONE_DONE=31, EXP_SQUARE=32,
               EXP_SQUARE_DONE=33, EXP_BIT_DONE=34, CHECK_A=35, CHECK_B=36, MONT_DISPATCH=37, CLEAR_READ=38, CLEAR_WAIT=39, BANK_COPY=40, MONT_CARRY_HIGH=41, SCHOOL_CARRY=42, MONT_SHIFT_HIGH=43;
    localparam MULT_SCHOOL=0, MULT_INVERSE_A=1, MULT_INVERSE_B=2,
               MULT_MONT_AB=3, MULT_MONT_FACTOR=4, MULT_MONT_N=5;
    reg [5:0] state_reg;
    reg [7:0] op_reg, status_reg;
    reg [11:0] clear_address_reg, destination_reg, source_a_reg, source_b_reg;
    reg [6:0] length_reg, modulus_length_reg, exponent_length_reg;
    reg [7:0] index_reg, outer_reg, compare_index_reg;
    // Each bank has registered read ports and a single serialized write port.
    // Execute every second clock so addresses settle for one synchronous read.
    reg execute_reg;
    reg [2:0] copy_mode_reg;
    reg [5:0] copy_return_reg;
    reg top_carry_reg;
    reg [31:0] shift_high_reg;
    localparam COPY_R2_B=0, COPY_ZERO_A=1, COPY_A_R2=2, COPY_ZERO_T=3,
               COPY_BASE_INIT=4, COPY_A_B=5, COPY_BASE_B=6, COPY_ONE_B=7;


    wire [7:0] a_ra = (state_reg == CMP || state_reg == CHECK_A || state_reg == R2_COMPARE) ? compare_index_reg :
                        (state_reg == PRODUCT_NEXT ? outer_reg : index_reg);
    wire [7:0] b_ra = (state_reg == CMP || state_reg == CHECK_B) ? compare_index_reg :
                        (state_reg == MONT_AB ? outer_reg : index_reg);
    wire [7:0] n_ra = (state_reg == PREPARE || state_reg == INVERSE_START) ? 8'd0 :
                        ((state_reg == CHECK_A || state_reg == CHECK_B || state_reg == R2_COMPARE || state_reg == MONT_COMPARE) ? compare_index_reg : index_reg);
    wire [7:0] t_ra = (state_reg == MULT_WAIT && mult_mode_reg == MULT_SCHOOL) ? outer_reg + index_reg :
                        (state_reg == MONT_FACTOR ? 8'd0 :
                         (state_reg == MONT_COMPARE ? compare_index_reg :
                          (state_reg == MONT_SHIFT ? length_reg + 8'd1 : index_reg)));
    reg a_we;
    reg [7:0] a_wa;
    reg [31:0] a_wd;
    wire [31:0] a_data, a_next;
    keygen_math_bank #(.DEPTH(MAX_LIMBS)) bank_a (
        .clock_i(clock_i),.write_en_i(a_we && reset_n_i),.write_address_i(a_wa),.write_data_i(a_wd),
        .read_address_a_i(a_ra),.read_address_b_i(index_reg+8'd1),.read_data_a_o(a_data),.read_data_b_o(a_next));
    task write_a; input [7:0] address; input [31:0] value;
        begin a_we <= 1; a_wa <= address; a_wd <= value; end
    endtask
    reg b_we;
    reg [7:0] b_wa;
    reg [31:0] b_wd;
    wire [31:0] b_data, b_unused;
    keygen_math_bank #(.DEPTH(MAX_LIMBS)) bank_b (
        .clock_i(clock_i),.write_en_i(b_we && reset_n_i),.write_address_i(b_wa),.write_data_i(b_wd),
        .read_address_a_i(b_ra),.read_address_b_i(b_ra),.read_data_a_o(b_data),.read_data_b_o(b_unused));
    task write_b; input [7:0] address; input [31:0] value;
        begin b_we <= 1; b_wa <= address; b_wd <= value; end
    endtask
    reg n_we;
    reg [7:0] n_wa;
    reg [31:0] n_wd;
    wire [31:0] n_data, n_high;
    keygen_math_bank #(.DEPTH(MAX_LIMBS)) bank_n (
        .clock_i(clock_i),.write_en_i(n_we && reset_n_i),.write_address_i(n_wa),.write_data_i(n_wd),
        .read_address_a_i(n_ra),.read_address_b_i(length_reg-8'd1),.read_data_a_o(n_data),.read_data_b_o(n_high));
    task write_n; input [7:0] address; input [31:0] value;
        begin n_we <= 1; n_wa <= address; n_wd <= value; end
    endtask
    reg r2_we;
    reg [7:0] r2_wa;
    reg [31:0] r2_wd;
    wire [31:0] r2_data, r2_unused;
    keygen_math_bank #(.DEPTH(MAX_LIMBS)) bank_r2 (
        .clock_i(clock_i),.write_en_i(r2_we && reset_n_i),.write_address_i(r2_wa),.write_data_i(r2_wd),
        .read_address_a_i(index_reg),.read_address_b_i(index_reg),.read_data_a_o(r2_data),.read_data_b_o(r2_unused));
    task write_r2; input [7:0] address; input [31:0] value;
        begin r2_we <= 1; r2_wa <= address; r2_wd <= value; end
    endtask
    reg exp_we;
    reg [7:0] exp_wa;
    reg [31:0] exp_wd;
    wire [31:0] exp_data, exp_unused;
    keygen_math_bank #(.DEPTH(MAX_LIMBS)) bank_exp (
        .clock_i(clock_i),.write_en_i(exp_we && reset_n_i),.write_address_i(exp_wa),.write_data_i(exp_wd),
        .read_address_a_i({2'b0,exponent_bit_reg[10:5]}),.read_address_b_i({2'b0,exponent_bit_reg[10:5]}),.read_data_a_o(exp_data),.read_data_b_o(exp_unused));
    task write_exp; input [7:0] address; input [31:0] value;
        begin exp_we <= 1; exp_wa <= address; exp_wd <= value; end
    endtask
    reg base_we;
    reg [7:0] base_wa;
    reg [31:0] base_wd;
    wire [31:0] base_data, base_unused;
    keygen_math_bank #(.DEPTH(MAX_LIMBS)) bank_base (
        .clock_i(clock_i),.write_en_i(base_we && reset_n_i),.write_address_i(base_wa),.write_data_i(base_wd),
        .read_address_a_i(index_reg),.read_address_b_i(index_reg),.read_data_a_o(base_data),.read_data_b_o(base_unused));
    task write_base; input [7:0] address; input [31:0] value;
        begin base_we <= 1; base_wa <= address; base_wd <= value; end
    endtask
    reg t_we;
    reg [7:0] t_wa;
    reg [31:0] t_wd;
    wire [31:0] t_data, t_high;
    keygen_math_bank #(.DEPTH(2*MAX_LIMBS+2)) bank_t (
        .clock_i(clock_i),.write_en_i(t_we && reset_n_i),.write_address_i(t_wa),.write_data_i(t_wd),
        .read_address_a_i(t_ra),.read_address_b_i({1'b0,length_reg}),.read_data_a_o(t_data),.read_data_b_o(t_high));
    task write_t; input [7:0] address; input [31:0] value;
        begin t_we <= 1; t_wa <= address; t_wd <= value; end
    endtask

    reg context_valid_reg;
    reg [31:0] inverse_reg, nprime_reg, factor_reg, carry_reg;
    reg borrow_reg;
    reg [2:0] inverse_step_reg, mult_mode_reg;
    reg [12:0] double_count_reg;
    reg [11:0] exponent_bit_reg;
    reg [5:0] return_state_reg;
    reg [31:0] mult_left_reg, mult_right_reg;
    wire mult_valid;
    wire [63:0] product;
    wire [63:0] accumulated_product = product + {32'b0,t_data} + {32'b0,carry_reg};
    wire [63:0] school_product = product + {32'b0,t_data} + {32'b0,carry_reg};
    wire [32:0] doubled_word = {a_data,1'b0} + {1'b0,carry_reg};
    wire [32:0] sum_word = {1'b0,a_data} + {1'b0,b_data} + {1'b0,carry_reg};
    wire [32:0] difference_word = {1'b0,a_data} - {1'b0,b_data} - {32'b0,borrow_reg};
    wire [32:0] reduction_word = {1'b0,a_data} - {1'b0,n_data} - {32'b0,borrow_reg};
    wire [32:0] mont_reduction_word = {1'b0,t_data} - {1'b0,n_data} - {32'b0,borrow_reg};
    wire [32:0] top_sum = {1'b0,t_high} + {1'b0,carry_reg};
    reg ram_write_en, ram_read_en;
    reg [11:0] ram_write_address, ram_read_address;
    reg [31:0] ram_write_data;
    wire [31:0] ram_read_data;
    reg private_read_valid_reg;
    integer clear_index;

    assign cmd_ready_o = reset_n_i && execute_reg && state_reg == IDLE;
    assign rsp_valid_o = reset_n_i && state_reg == RESPONSE;
    assign rsp_status_o = status_reg;
    assign mem_ready_o = reset_n_i && execute_reg && state_reg == IDLE && !cmd_valid_i;
    assign mem_read_valid_o = private_read_valid_reg;
    assign mem_read_data_o = ram_read_data;
    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) private_read_valid_reg <= 1'b0;
        else private_read_valid_reg <= mem_ready_o && mem_read_en_i;
    end
    keygen_mult32 #(.IP_TYPE(IP_TYPE)) multiply (
        .clock_i(clock_i), .reset_n_i(reset_n_i), .clock_en_i(1'b1),
        .valid_i(execute_reg && state_reg == MULT_START), .left_i(mult_left_reg),
        .right_i(mult_right_reg), .valid_o(mult_valid), .product_o(product)
    );
    keygen_ram32 #(.ADDRESS_WIDTH(12), .IP_TYPE(IP_TYPE), .DEVICE_FAMILY(DEVICE_FAMILY)) scratch (
        .clock_i(clock_i), .reset_n_i(reset_n_i), .clock_en_i(1'b1),
        .write_en_i(ram_write_en), .write_address_i(ram_write_address),
        .write_data_i(ram_write_data), .read_en_i(ram_read_en),
        .read_address_i(ram_read_address), .read_valid_o(), .read_data_o(ram_read_data)
    );
    always @* begin
        ram_write_en = 1'b0; ram_read_en = 1'b0;
        ram_write_address = 12'b0; ram_read_address = 12'b0;
        ram_write_data = 32'b0;
        if (state_reg == CLEAR) begin
            ram_write_en = 1'b1; ram_write_address = clear_address_reg;
        end else if (state_reg == CLEAR_READ) begin
            // Refresh the RAM output latch without a collision after all writes.
            ram_read_en = 1'b1; ram_read_address = 12'd4095;
        end else if (mem_ready_o) begin
            ram_write_en = mem_write_en_i; ram_read_en = mem_read_en_i;
            ram_write_address = mem_address_i; ram_read_address = mem_address_i;
            ram_write_data = mem_write_data_i;
        end else if (state_reg == LOAD_A) begin
            ram_read_en = 1'b1; ram_read_address = source_a_reg + index_reg;
        end else if (state_reg == LOAD_B) begin
            ram_read_en = 1'b1; ram_read_address = source_b_reg + index_reg;
        end else if (state_reg == WRITE) begin
            ram_write_en = 1'b1; ram_write_address = destination_reg + index_reg;
            if (op_reg == ZERO) ram_write_data = 32'b0;
            else if (op_reg == MUL) ram_write_data = t_data;
            else ram_write_data = a_data;
        end
    end
    // Only command metadata crosses the CPU interface. Arithmetic operands
    // enter through the private scratch port, never through response status.
    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            state_reg <= CLEAR; clear_address_reg <= 0;
            execute_reg <= 0; copy_mode_reg <= 0; copy_return_reg <= 0; top_carry_reg <= 0; shift_high_reg <= 0;
            a_we <= 0; a_wa <= 0; a_wd <= 0;
            b_we <= 0; b_wa <= 0; b_wd <= 0;
            n_we <= 0; n_wa <= 0; n_wd <= 0;
            r2_we <= 0; r2_wa <= 0; r2_wd <= 0;
            exp_we <= 0; exp_wa <= 0; exp_wd <= 0;
            base_we <= 0; base_wa <= 0; base_wd <= 0;
            t_we <= 0; t_wa <= 0; t_wd <= 0;

            context_valid_reg <= 0; status_reg <= 0;
            op_reg <= 0; destination_reg <= 0; source_a_reg <= 0; source_b_reg <= 0;
            length_reg <= 0; modulus_length_reg <= 0; exponent_length_reg <= 0;
            index_reg <= 0; outer_reg <= 0; compare_index_reg <= 0;
            inverse_reg <= 0; nprime_reg <= 0; factor_reg <= 0; carry_reg <= 0;
            borrow_reg <= 0; inverse_step_reg <= 0; mult_mode_reg <= 0;
            double_count_reg <= 0; exponent_bit_reg <= 0; return_state_reg <= 0;
            mult_left_reg <= 0; mult_right_reg <= 0;
        end else begin
            execute_reg <= !execute_reg;
            a_we <= 0;
            b_we <= 0;
            n_we <= 0;
            r2_we <= 0;
            exp_we <= 0;
            base_we <= 0;
            t_we <= 0;
            if (state_reg == RESPONSE && rsp_ready_i) state_reg <= IDLE;
            if ((execute_reg || state_reg == CLEAR || state_reg == CLEAR_READ || state_reg == CLEAR_WAIT) && state_reg != RESPONSE) begin
            case (state_reg)
                CLEAR: begin
                    if (clear_address_reg < MAX_LIMBS) begin
                        write_a(clear_address_reg, 0); write_b(clear_address_reg, 0);
                        write_n(clear_address_reg, 0); write_r2(clear_address_reg, 0);
                        write_exp(clear_address_reg, 0); write_base(clear_address_reg, 0);
                    end
                    if (clear_address_reg < 2*MAX_LIMBS+2) write_t(clear_address_reg, 0);
                    if (clear_address_reg == 4095) state_reg <= CLEAR_READ;
                    else clear_address_reg <= clear_address_reg + 1'b1;
                end
                CLEAR_READ: state_reg <= CLEAR_WAIT;
                CLEAR_WAIT: state_reg <= IDLE;
                IDLE: if (cmd_valid_i) begin
                    op_reg <= cmd_op_i; status_reg <= 0; index_reg <= 0;
                    destination_reg <= cmd_arg0_i[11:0]; source_a_reg <= cmd_arg1_i[11:0];
                    source_b_reg <= cmd_arg2_i[11:0];
                    length_reg <= cmd_arg3_i[6:0]; state_reg <= LOAD_A;
                    if (cmd_op_i == MOD_SETUP) begin
                        context_valid_reg <= 0;
                        source_a_reg <= cmd_arg0_i[11:0]; length_reg <= cmd_arg2_i[6:0];
                        modulus_length_reg <= cmd_arg2_i[6:0];
                        if (cmd_arg2_i == 0 || cmd_arg2_i > MAX_LIMBS || cmd_arg3_i != 0 ||
                            cmd_arg0_i > 4096-cmd_arg2_i ||
                            cmd_arg1_i > 4096-(cmd_arg2_i*4+2)) begin
                            status_reg <= 2; state_reg <= RESPONSE;
                        end else if (cmd_arg0_i < cmd_arg1_i+cmd_arg2_i*4+2 &&
                                     cmd_arg1_i < cmd_arg0_i+cmd_arg2_i) begin
                            status_reg <= 3; state_reg <= RESPONSE;
                        end
                    end else if (cmd_op_i == MONT_MUL || cmd_op_i == MODEXP) begin
                        length_reg <= modulus_length_reg;
                        exponent_length_reg <= cmd_arg3_i[6:0];
                        if (!context_valid_reg) begin status_reg <= 4; state_reg <= RESPONSE; end
                        else if (cmd_arg0_i > 4096-modulus_length_reg ||
                                 cmd_arg1_i > 4096-modulus_length_reg ||
                                 cmd_arg2_i > 4096-(cmd_op_i == MODEXP ? cmd_arg3_i : modulus_length_reg) ||
                                 (cmd_op_i == MODEXP && (cmd_arg3_i == 0 || cmd_arg3_i > MAX_LIMBS)) ||
                                 (cmd_op_i == MONT_MUL && cmd_arg3_i != 0)) begin
                            status_reg <= 2; state_reg <= RESPONSE;
                        end
                    end else if (cmd_op_i == COPY || cmd_op_i == ZERO || cmd_op_i == COMPARE ||
                                 cmd_op_i == ADD || cmd_op_i == SUB || cmd_op_i == SHIFT_RIGHT || cmd_op_i == MUL) begin
                        if (cmd_arg3_i == 0 || cmd_arg3_i > MAX_LIMBS ||
                            cmd_arg0_i > 4096-(cmd_op_i == MUL ? cmd_arg3_i*2 : cmd_arg3_i) ||
                            (cmd_op_i != ZERO && cmd_arg1_i > 4096-cmd_arg3_i) ||
                            ((cmd_op_i == COMPARE || cmd_op_i == ADD || cmd_op_i == SUB || cmd_op_i == MUL) &&
                             cmd_arg2_i > 4096-cmd_arg3_i)) begin status_reg <= 2; state_reg <= RESPONSE; end
                        else if (cmd_op_i == ZERO) state_reg <= WRITE;
                    end else begin status_reg <= 1; state_reg <= RESPONSE; end
                end
                RESPONSE: if (rsp_ready_i) state_reg <= IDLE;
                LOAD_A: state_reg <= WAIT_A;
                WAIT_A: begin
                    if (op_reg == MOD_SETUP) write_n(index_reg, ram_read_data);
                    else write_a(index_reg, ram_read_data);
                    if (index_reg == length_reg-1) begin
                        index_reg <= 0;
                        if (op_reg == COPY) state_reg <= WRITE;
                        else if (op_reg == MOD_SETUP || op_reg == SHIFT_RIGHT) state_reg <= PREPARE;
                        else state_reg <= LOAD_B;
                    end else begin index_reg <= index_reg+1'b1; state_reg <= LOAD_A; end
                end
                LOAD_B: state_reg <= WAIT_B;
                WAIT_B: begin
                    if (op_reg == MODEXP) write_exp(index_reg, ram_read_data);
                    else write_b(index_reg, ram_read_data);
                    if (index_reg == (op_reg == MODEXP ? exponent_length_reg : length_reg)-1) begin
                        index_reg <= 0; state_reg <= PREPARE;
                    end else begin index_reg <= index_reg+1'b1; state_reg <= LOAD_B; end
                end
                PREPARE: begin
                    carry_reg <= 0; borrow_reg <= 0; index_reg <= 0;
                    if (op_reg == MOD_SETUP) begin
                        if (!n_data[0] || n_high == 0 ||
                            (length_reg == 1 && n_data <= 1)) begin status_reg <= 4; state_reg <= RESPONSE; end
                        else begin inverse_reg <= 1; inverse_step_reg <= 0; state_reg <= INVERSE_START; end
                    end else if (op_reg == COMPARE) begin compare_index_reg <= length_reg-1; state_reg <= CMP; end
                    else if (op_reg == MUL) begin index_reg <= 0; state_reg <= PRODUCT_INIT; end
                    else if (op_reg == MONT_MUL || op_reg == MODEXP) begin compare_index_reg <= length_reg-1; state_reg <= CHECK_A; end
                    else state_reg <= SIMPLE;
                end
                CHECK_A: begin
                    if (a_data > n_data ||
                        (a_data == n_data && compare_index_reg == 0)) begin
                        status_reg <= 4; state_reg <= RESPONSE;
                    end else if (a_data < n_data) begin
                        compare_index_reg <= length_reg-1;
                        state_reg <= op_reg == MONT_MUL ? CHECK_B : MONT_DISPATCH;
                    end else compare_index_reg <= compare_index_reg-1'b1;
                end
                CHECK_B: begin
                    if (b_data > n_data ||
                        (b_data == n_data && compare_index_reg == 0)) begin
                        status_reg <= 4; state_reg <= RESPONSE;
                    end else if (b_data < n_data) state_reg <= MONT_DISPATCH;
                    else compare_index_reg <= compare_index_reg-1'b1;
                end
                MONT_DISPATCH: begin
                    if (op_reg == MONT_MUL) return_state_reg <= WRITE;
                    else begin
                        return_state_reg <= EXP_BASE_DONE;
                        copy_mode_reg <= COPY_R2_B; copy_return_reg <= MONT_INIT;
                        index_reg <= 0;
                    end
                    state_reg <= (op_reg == MODEXP) ? BANK_COPY : MONT_INIT;
                end
                WRITE: begin
                    if (index_reg == (op_reg == MUL ? length_reg*2 : length_reg)-1) begin
                        index_reg <= 0; state_reg <= RESPONSE;
                    end else index_reg <= index_reg+1'b1;
                end
                SIMPLE: begin
                    if (op_reg == ADD) begin write_a(index_reg, sum_word[31:0]); carry_reg <= {31'b0,sum_word[32]}; end
                    else if (op_reg == SUB) begin write_a(index_reg, difference_word[31:0]); borrow_reg <= difference_word[32]; end
                    else write_a(index_reg, {index_reg == length_reg-1 ? 1'b0 : a_next[0], a_data[31:1]});
                    if (index_reg == length_reg-1) begin index_reg <= 0; state_reg <= WRITE; end
                    else index_reg <= index_reg+1'b1;
                end
                CMP: begin
                    if (a_data < b_data) begin status_reg <= 8'h10; state_reg <= RESPONSE; end
                    else if (a_data > b_data) begin status_reg <= 8'h12; state_reg <= RESPONSE; end
                    else if (compare_index_reg == 0) begin status_reg <= 8'h11; state_reg <= RESPONSE; end
                    else compare_index_reg <= compare_index_reg-1'b1;
                end
                PRODUCT_INIT: begin
                    write_t(index_reg, 0);
                    if (index_reg == length_reg*2-1) begin index_reg <= 0; outer_reg <= 0; carry_reg <= 0; state_reg <= PRODUCT_NEXT; end
                    else index_reg <= index_reg+1'b1;
                end
                PRODUCT_NEXT: begin
                    mult_left_reg <= a_data; mult_right_reg <= b_data;
                    mult_mode_reg <= MULT_SCHOOL; state_reg <= MULT_START;
                end
                INVERSE_START: begin
                    mult_left_reg <= n_data; mult_right_reg <= inverse_reg;
                    mult_mode_reg <= MULT_INVERSE_A; state_reg <= MULT_START;
                end
                MULT_START: state_reg <= MULT_WAIT;
                MULT_WAIT: if (mult_valid) begin
                    case (mult_mode_reg)
                        MULT_SCHOOL: begin
                            write_t(outer_reg+index_reg, school_product[31:0]); carry_reg <= school_product[63:32];
                            if (index_reg == length_reg-1) begin
                                state_reg <= SCHOOL_CARRY;
                            end else begin index_reg <= index_reg+1'b1; state_reg <= PRODUCT_NEXT; end
                        end
                        MULT_INVERSE_A: begin
                            mult_left_reg <= inverse_reg; mult_right_reg <= 32'd2-product[31:0];
                            mult_mode_reg <= MULT_INVERSE_B; state_reg <= MULT_START;
                        end
                        MULT_INVERSE_B: begin
                            inverse_reg <= product[31:0];
                            if (inverse_step_reg == 4) begin nprime_reg <= -product[31:0]; state_reg <= R2_INIT; end
                            else begin inverse_step_reg <= inverse_step_reg+1'b1; state_reg <= INVERSE_START; end
                        end
                        MULT_MONT_AB: begin
                            write_t(index_reg, accumulated_product[31:0]); carry_reg <= accumulated_product[63:32];
                            if (index_reg == length_reg-1) state_reg <= MONT_CARRY;
                            else begin index_reg <= index_reg+1'b1; state_reg <= MONT_AB; end
                        end
                        MULT_MONT_FACTOR: begin factor_reg <= product[31:0]; index_reg <= 0; carry_reg <= 0; state_reg <= MONT_N; end
                        MULT_MONT_N: begin
                            if (index_reg != 0) write_t(index_reg-1, accumulated_product[31:0]);
                            carry_reg <= accumulated_product[63:32];
                            if (index_reg == length_reg-1) state_reg <= MONT_SHIFT;
                            else begin index_reg <= index_reg+1'b1; state_reg <= MONT_N; end
                        end
                        default: begin status_reg <= 5; state_reg <= RESPONSE; end
                    endcase
                end
                SCHOOL_CARRY: begin
                    write_t(outer_reg+length_reg, carry_reg);
                    index_reg <= 0; carry_reg <= 0;
                    if (outer_reg == length_reg-1) state_reg <= WRITE;
                    else begin outer_reg <= outer_reg+1'b1; state_reg <= PRODUCT_NEXT; end
                end
                R2_INIT: begin
                    double_count_reg <= {modulus_length_reg,6'b0};
                    index_reg <= 0; carry_reg <= 0;
                    copy_mode_reg <= COPY_ZERO_A; copy_return_reg <= R2_DOUBLE; state_reg <= BANK_COPY;
                end
                R2_DOUBLE: begin
                    write_a(index_reg, doubled_word[31:0]); carry_reg <= {31'b0,doubled_word[32]};
                    if (index_reg == length_reg-1) begin compare_index_reg <= length_reg-1; state_reg <= R2_COMPARE; end
                    else index_reg <= index_reg+1'b1;
                end
                R2_COMPARE: begin
                    if (carry_reg != 0 || a_data > n_data) begin index_reg <= 0; borrow_reg <= 0; state_reg <= R2_SUB; end
                    else if (a_data < n_data) state_reg <= R2_NEXT;
                    else if (compare_index_reg == 0) begin index_reg <= 0; borrow_reg <= 0; state_reg <= R2_SUB; end
                    else compare_index_reg <= compare_index_reg-1'b1;
                end
                R2_SUB: begin
                    write_a(index_reg, reduction_word[31:0]); borrow_reg <= reduction_word[32];
                    if (index_reg == length_reg-1) state_reg <= R2_NEXT;
                    else index_reg <= index_reg+1'b1;
                end
                R2_NEXT: begin
                    if (double_count_reg == 1) begin
                        copy_mode_reg <= COPY_A_R2; copy_return_reg <= RESPONSE;
                        index_reg <= 0; context_valid_reg <= 1; state_reg <= BANK_COPY;
                    end else begin double_count_reg <= double_count_reg-1'b1; index_reg <= 0; carry_reg <= 0; state_reg <= R2_DOUBLE; end
                end
                MONT_INIT: begin
                    index_reg <= 0; outer_reg <= 0; carry_reg <= 0;
                    copy_mode_reg <= COPY_ZERO_T; copy_return_reg <= MONT_AB; state_reg <= BANK_COPY;
                end
                MONT_AB: begin
                    mult_left_reg <= a_data; mult_right_reg <= b_data;
                    mult_mode_reg <= MULT_MONT_AB; state_reg <= MULT_START;
                end
                MONT_CARRY: begin
                    write_t(length_reg, top_sum[31:0]); top_carry_reg <= top_sum[32];
                    state_reg <= MONT_CARRY_HIGH;
                end
                MONT_CARRY_HIGH: begin
                    write_t(length_reg+1'b1, {31'b0,top_carry_reg});
                    state_reg <= MONT_FACTOR;
                end
                MONT_FACTOR: begin
                    mult_left_reg <= t_data; mult_right_reg <= nprime_reg;
                    mult_mode_reg <= MULT_MONT_FACTOR; state_reg <= MULT_START;
                end
                MONT_N: begin
                    mult_left_reg <= factor_reg; mult_right_reg <= n_data;
                    mult_mode_reg <= MULT_MONT_N; state_reg <= MULT_START;
                end
                MONT_SHIFT: begin
                    write_t(length_reg-1'b1, top_sum[31:0]);
                    shift_high_reg <= t_data + {31'b0,top_sum[32]};
                    state_reg <= MONT_SHIFT_HIGH;
                end
                MONT_SHIFT_HIGH: begin
                    write_t(length_reg, shift_high_reg);
                    index_reg <= 0; carry_reg <= 0;
                    if (outer_reg == length_reg-1) begin compare_index_reg <= length_reg-1; state_reg <= MONT_COMPARE; end
                    else begin outer_reg <= outer_reg+1'b1; state_reg <= MONT_AB; end
                end
                MONT_COMPARE: begin
                    if (t_high != 0 || t_data > n_data) begin index_reg <= 0; borrow_reg <= 0; state_reg <= MONT_SUB; end
                    else if (t_data < n_data) begin index_reg <= 0; state_reg <= MONT_COPY; end
                    else if (compare_index_reg == 0) begin index_reg <= 0; borrow_reg <= 0; state_reg <= MONT_SUB; end
                    else compare_index_reg <= compare_index_reg-1'b1;
                end
                MONT_SUB: begin
                    write_a(index_reg, mont_reduction_word[31:0]); borrow_reg <= mont_reduction_word[32];
                    if (index_reg == length_reg-1) begin index_reg <= 0; state_reg <= return_state_reg; end
                    else index_reg <= index_reg+1'b1;
                end
                MONT_COPY: begin
                    write_a(index_reg, t_data);
                    if (index_reg == length_reg-1) begin index_reg <= 0; state_reg <= return_state_reg; end
                    else index_reg <= index_reg+1'b1;
                end
                EXP_BASE_DONE: begin
                    return_state_reg <= EXP_ONE_DONE; index_reg <= 0;
                    copy_mode_reg <= COPY_BASE_INIT; copy_return_reg <= MONT_INIT; state_reg <= BANK_COPY;
                end
                EXP_ONE_DONE: begin exponent_bit_reg <= exponent_length_reg*32-1; state_reg <= EXP_SQUARE; end
                EXP_SQUARE: begin
                    return_state_reg <= EXP_SQUARE_DONE; index_reg <= 0;
                    copy_mode_reg <= COPY_A_B; copy_return_reg <= MONT_INIT; state_reg <= BANK_COPY;
                end
                EXP_SQUARE_DONE: begin
                    if (exp_data[exponent_bit_reg[4:0]]) begin
                        return_state_reg <= EXP_BIT_DONE; index_reg <= 0;
                        copy_mode_reg <= COPY_BASE_B; copy_return_reg <= MONT_INIT; state_reg <= BANK_COPY;
                    end else state_reg <= EXP_BIT_DONE;
                end
                EXP_BIT_DONE: begin
                    if (exponent_bit_reg == 0) begin
                        return_state_reg <= WRITE; index_reg <= 0;
                        copy_mode_reg <= COPY_ONE_B; copy_return_reg <= MONT_INIT; state_reg <= BANK_COPY;
                    end else begin exponent_bit_reg <= exponent_bit_reg-1'b1; state_reg <= EXP_SQUARE; end
                end
                BANK_COPY: begin
                    case (copy_mode_reg)
                        COPY_R2_B: write_b(index_reg, r2_data);
                        COPY_ZERO_A: write_a(index_reg, (index_reg == 0) ? 32'd1 : 32'd0);
                        COPY_A_R2: write_r2(index_reg, a_data);
                        COPY_ZERO_T: write_t(index_reg, 0);
                        COPY_BASE_INIT: begin
                            write_base(index_reg, a_data);
                            write_a(index_reg, (index_reg == 0) ? 32'd1 : 32'd0);
                            write_b(index_reg, r2_data);
                        end
                        COPY_A_B: write_b(index_reg, a_data);
                        COPY_BASE_B: write_b(index_reg, base_data);
                        COPY_ONE_B: write_b(index_reg, (index_reg == 0) ? 32'd1 : 32'd0);
                    endcase
                    if (index_reg == ((copy_mode_reg == COPY_ZERO_T) ? MAX_LIMBS+1 : MAX_LIMBS-1)) begin
                        index_reg <= 0; state_reg <= copy_return_reg;
                    end else index_reg <= index_reg + 1'b1;
                end
                default: begin status_reg <= 5; state_reg <= RESPONSE; end
            endcase
            end
        end
    end
endmodule

// Synchronous operand storage. No asynchronous RAM reset: CLEAR sweeps every
// used word before exposing ready. Write forwarding defines same-edge collisions.
module keygen_math_bank #(parameter DEPTH=64) (
    input clock_i, input write_en_i, input [7:0] write_address_i,
    input [31:0] write_data_i, input [7:0] read_address_a_i, read_address_b_i,
    output reg [31:0] read_data_a_o, read_data_b_o
);
    // Replicated simple-dual-port banks avoid a three-port inferred memory.
    // Synthesis can merge identical read addresses for single-reader banks.
    (* ramstyle = "M20K" *) reg [31:0] memory_a [0:DEPTH-1];
    (* ramstyle = "M20K" *) reg [31:0] memory_b [0:DEPTH-1];
    always @(posedge clock_i) begin
        if (write_en_i) begin
            memory_a[write_address_i] <= write_data_i;
            memory_b[write_address_i] <= write_data_i;
        end
        if (write_en_i && write_address_i == read_address_a_i) read_data_a_o <= write_data_i;
        else read_data_a_o <= memory_a[read_address_a_i];
        if (write_en_i && write_address_i == read_address_b_i) read_data_b_o <= write_data_i;
        else read_data_b_o <= memory_b[read_address_b_i];
    end
endmodule
