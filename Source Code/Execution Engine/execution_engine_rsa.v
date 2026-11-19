// Internal RSA2048 operand adapter. No transport route or TPM command semantics.
// Allow/deny and operation selectors are internal test fixtures, not real auth.
// Codex assisted implementation; see RSA_PROTECTED_CONSUMER.md.
module execution_engine_rsa #(
    parameter ENABLE=0, IP_TYPE=0, parameter DEVICE_FAMILY="Agilex 5",
    parameter [63:0] WAIT_LIMIT=64'd100000000,
    parameter [63:0] TERMINAL_LIMIT=64'd1000000
)(
    input wire clock_i, reset_n_i,
    input wire request_valid_i, output wire request_ready_o,
    input wire [31:0] request_id_i, input wire request_allow_i,
    input wire [1:0] operation_i,
    input wire operand_valid_i, output wire operand_ready_o,
    input wire [31:0] operand_data_i, input wire operand_last_i,
    output wire result_valid_o, input wire result_ready_i,
    output wire [31:0] result_data_o, output wire result_last_o,
    output wire completion_valid_o, input wire completion_ready_i,
    output wire [3:0] completion_code_o, output wire [31:0] completion_id_o,
    output wire acquire_valid_o, input wire acquire_ready_i,
    output wire acquire_allow_o, output wire [1:0] acquire_type_o,
    output wire [7:0] acquire_words_o,
    input wire acquire_reply_valid_i, output wire acquire_reply_ready_o,
    input wire [3:0] acquire_code_i,
    output wire consumer_release_o, input wire reserved_i,
    input wire slot_valid_i, input wire [1:0] slot_type_i,
    input wire [7:0] slot_words_i,
    output wire [7:0] private_address_o, input wire [31:0] private_data_i
);
    generate if(ENABLE)begin : enabled
    localparam [4:0] IDLE=0, ACQUIRE=1, ACQUIRE_REPLY=2, LOAD_KEY=3,
        LOAD_OPERAND=4, CHECK=5, PAIR_START=6, PAIR_WAIT=7, CORE_START=8,
        CORE_WAIT=9, CLEAN=10, CLEAN_WAIT=11, OUTPUT=12, COMPLETE=13,
        RELEASE=14, SAVE_RESULT=15, WIPE_RESULT=16, REFRESH_RESULT=17;
    localparam [3:0] OK=0, BAD_SLOT=1, BAD_FORMAT=4, TIMEOUT=7, DENIED=9,
        BAD_OPERATION=10, ARITHMETIC=11, BAD_OPERAND=12;
    reg [4:0] state_reg;
    reg [3:0] status_reg;
    reg [31:0] id_reg;
    reg private_reg, allow_reg, owned_reg, d_captured_reg, pending_reg;
    reg [7:0] index_reg;
    reg [63:0] elapsed_reg, terminal_elapsed_reg;
    reg modulus_high, modulus_odd, operand_less, operand_greater, pair_mismatch;
    reg [1023:0] p_reg, q_reg;
    reg [31:0] public_exponent_reg;
    // Registered local resets clear retained child state and invalidate late
    // done pulses. Pair RAM performs its normal full sweep after reset removal.
    reg child_clear_reg;
    wire child_reset_n = reset_n_i && !child_clear_reg;
    wire pair_ready, pair_valid, pair_d_valid;
    wire [2047:0] pair_n, pair_d;
    wire [3:0] pair_status;
    wire core_done, core_error;
    wire core_ready;
    wire [31:0] core_word, modulus_word;
    wire operand_accept = operand_valid_i && operand_ready_o;
    wire load_n = state_reg==LOAD_KEY && index_reg<64 && slot_consistent;
    wire load_d = state_reg==PAIR_WAIT && pair_d_valid && !d_captured_reg && slot_consistent;
    wire [5:0] input_limb = 6'd63 - index_reg[5:0];
    wire [5:0] inspect_limb = state_reg==LOAD_OPERAND ?
        input_limb - {5'd0,operand_accept && index_reg!=63} :
        state_reg==PAIR_WAIT ? (pair_valid ? index_reg[5:0]+1'b1 : 6'd0) :
        state_reg==SAVE_RESULT ? input_limb-1'b1 : 6'd63;
    wire slot_consistent = reserved_i && slot_valid_i &&
        slot_type_i==2 && slot_words_i==129;
    wire lease_phase = (state_reg>=LOAD_KEY && state_reg<=COMPLETE) || state_reg==SAVE_RESULT;
    wire expired = elapsed_reg>=WAIT_LIMIT-1;
    assign request_ready_o=reset_n_i && ENABLE && state_reg==IDLE && pair_ready && core_ready;
    assign acquire_valid_o=reset_n_i && state_reg==ACQUIRE;
    assign acquire_allow_o=allow_reg;
    assign acquire_type_o=2;
    assign acquire_words_o=129;
    assign acquire_reply_ready_o=reset_n_i && state_reg==ACQUIRE_REPLY;
    assign consumer_release_o=reset_n_i && state_reg==RELEASE && owned_reg;
    assign private_address_o=reset_n_i && state_reg==LOAD_KEY && slot_consistent ? index_reg : 8'd0;
    assign operand_ready_o=reset_n_i && state_reg==LOAD_OPERAND && slot_consistent && !expired;
    assign result_valid_o=reset_n_i && state_reg==OUTPUT && slot_consistent && !expired;
    // Copy the held arithmetic result before clearing the child. Registered
    // lookahead presents one word per clock and keeps it stable on stalls.
    wire accept_result = result_valid_o && result_ready_i;
    wire result_write = state_reg==SAVE_RESULT || state_reg==WIPE_RESULT || accept_result;
    wire [31:0] result_word = state_reg==SAVE_RESULT ? core_word : 32'd0;
    wire [5:0] result_read_address = state_reg==OUTPUT ?
        index_reg[5:0] + {5'd0,accept_result} : 6'd0;
    wire [31:0] result_q;
    keygen_ram32 #(.ADDRESS_WIDTH(6),.IP_TYPE(IP_TYPE),.DEVICE_FAMILY(DEVICE_FAMILY)) result_store (
        .clock_i(clock_i),.reset_n_i(reset_n_i),.clock_en_i(1'b1),
        .write_en_i(result_write),.write_address_i(index_reg[5:0]),.write_data_i(result_word),
        .read_en_i(1'b1),.read_address_i(result_read_address),.read_data_o(result_q),.read_valid_o());
    assign result_data_o=result_valid_o ? result_q : 32'd0;
    assign result_last_o=result_valid_o && index_reg==63;
    assign completion_valid_o=reset_n_i && state_reg==COMPLETE &&
        (!owned_reg || status_reg!=OK || slot_consistent) && terminal_elapsed_reg<TERMINAL_LIMIT;
    assign completion_code_o=completion_valid_o?status_reg:4'd0;
    assign completion_id_o=completion_valid_o?id_reg:32'd0;

    keygen_pair_check #(.IP_TYPE(IP_TYPE),.DEVICE_FAMILY(DEVICE_FAMILY),
        .PROTECTED_D_HANDOFF(1)) protected_derivation (
        .clock_i(clock_i),.reset_n_i(child_reset_n),
        .start_valid_i(state_reg==PAIR_START),.start_ready_o(pair_ready),
        .p_i(p_reg),.q_i(q_reg),.result_valid_o(pair_valid),
        .result_ready_i(state_reg==PAIR_WAIT && ((index_reg==63 && d_captured_reg) || pair_status!=0)),.n_o(pair_n),.status_o(pair_status),
        .private_d_valid_o(pair_d_valid),.private_d_ready_i(load_d && index_reg==63),
        .private_d_o(pair_d));
    rsa_montgomery_words #(.IP_TYPE(IP_TYPE),.DEVICE_FAMILY(DEVICE_FAMILY)) arithmetic (
        .clock_i(clock_i),.reset_n_i(child_reset_n),.start_i(state_reg==CORE_START),
        .load_n_i(load_n),.load_base_i(operand_accept),.load_exp_i(load_d || (load_n && !private_reg)),
        .load_address_i(load_d ? index_reg[5:0] : input_limb),.inspect_address_i(inspect_limb),
        .n_word_i(private_data_i),.base_word_i(operand_data_i),
        .exp_word_i(load_d ? pair_d[index_reg[5:0]*32 +:32] : input_limb==0 ? 32'd65537 : 32'd0),
        .n_word_o(modulus_word),.result_word_o(core_word),.ready_o(core_ready),
        .done_o(core_done),.error_o(core_error));

    task fail;
        input [3:0] code;
        begin status_reg<=code;index_reg<=0;child_clear_reg<=1;state_reg<=WIPE_RESULT;end
    endtask
    always @(posedge clock_i or negedge reset_n_i) begin
        if(!reset_n_i)begin
            state_reg<=WIPE_RESULT;status_reg<=0;id_reg<=0;private_reg<=0;allow_reg<=0;
            owned_reg<=0;d_captured_reg<=0;pending_reg<=0;index_reg<=0;elapsed_reg<=0;terminal_elapsed_reg<=0;
            modulus_high<=0;modulus_odd<=0;operand_less<=0;operand_greater<=0;pair_mismatch<=0;
            p_reg<=0;q_reg<=0;public_exponent_reg<=0;child_clear_reg<=1;
        end else begin
            if(state_reg!=IDLE && state_reg!=COMPLETE && state_reg!=RELEASE && !expired)
                elapsed_reg<=elapsed_reg+1'b1;
            case(state_reg)
                IDLE: if(request_valid_i && request_ready_o)begin
                    id_reg<=request_id_i;private_reg<=operation_i[0];allow_reg<=request_allow_i;
                    pending_reg<=1;
                    elapsed_reg<=0;terminal_elapsed_reg<=0;status_reg<=OK;index_reg<=0;
                    if(!request_allow_i)begin status_reg<=DENIED;state_reg<=CLEAN;end
                    else if(operation_i>1)begin status_reg<=BAD_OPERATION;state_reg<=CLEAN;end
                    else state_reg<=ACQUIRE;
                end
                ACQUIRE: if(acquire_ready_i)state_reg<=ACQUIRE_REPLY;
                    else if(expired)fail(TIMEOUT);
                // A successful acquire reply is obligatory after an accepted
                // acquire. The engine slot replies in one cycle and holds it.
                // Never abandon an accepted acquire and leak a hidden lease.
                ACQUIRE_REPLY: if(acquire_reply_valid_i)begin
                    if(acquire_code_i!=0)fail(acquire_code_i);
                    else begin owned_reg<=1;index_reg<=0;state_reg<=LOAD_KEY;end
                end
                LOAD_KEY: begin
                    if(index_reg<64)begin
                        if(index_reg==0)modulus_high<=private_data_i[31];
                        if(index_reg==63)modulus_odd<=private_data_i[0];
                    end
                    else if(index_reg==64)public_exponent_reg<=private_data_i;
                    else if(index_reg<97)p_reg<={p_reg[991:0],private_data_i};
                    else q_reg<={q_reg[991:0],private_data_i};
                    if(index_reg==128 || (index_reg==64 && !private_reg))begin index_reg<=0;state_reg<=LOAD_OPERAND;end
                    else index_reg<=index_reg+1'b1;
                end
                LOAD_OPERAND: if(operand_valid_i && operand_ready_o)begin
                    if(operand_last_i!=(index_reg==63))fail(BAD_OPERAND);
                    else begin
                        if(!operand_less && !operand_greater)begin
                            operand_less<=operand_data_i<modulus_word;
                            operand_greater<=operand_data_i>modulus_word;
                        end
                        if(index_reg==63)begin index_reg<=0;state_reg<=CHECK;end
                        else index_reg<=index_reg+1'b1;
                    end
                end
                CHECK: if(!modulus_high || !modulus_odd || public_exponent_reg!=65537)
                    fail(BAD_FORMAT);
                    else if(!operand_less)fail(BAD_OPERAND);
                    else if(private_reg)state_reg<=PAIR_START;
                    else begin p_reg<=0;q_reg<=0;state_reg<=CORE_START;end
                PAIR_START: if(pair_ready)state_reg<=PAIR_WAIT;
                PAIR_WAIT: begin
                    if(pair_d_valid && !d_captured_reg)begin
                        index_reg<={2'd0,index_reg[5:0]+6'd1};
                        if(index_reg==63)begin d_captured_reg<=1;p_reg<=0;q_reg<=0;end
                    end
                    if(pair_valid)begin
                        if(pair_status!=0 || !d_captured_reg)fail(ARITHMETIC);
                        else begin
                            pair_mismatch<=pair_mismatch || pair_n[index_reg[5:0]*32 +:32]!=modulus_word;
                            index_reg<={2'd0,index_reg[5:0]+6'd1};
                            if(index_reg==63)begin
                                if(pair_mismatch || pair_n[2047:2016]!=modulus_word)fail(ARITHMETIC);
                                else state_reg<=CORE_START;
                            end
                        end
                    end
                end
                CORE_START: state_reg<=CORE_WAIT;
                CORE_WAIT: if(core_done)begin
                    if(core_error)fail(ARITHMETIC);
                    else begin index_reg<=0;state_reg<=SAVE_RESULT;end
                end
                SAVE_RESULT: begin
                    if(index_reg==63)begin index_reg<=0;state_reg<=CLEAN;end
                    else index_reg<=index_reg+1'b1;
                end
                WIPE_RESULT: begin
                    if(index_reg==63)begin index_reg<=0;state_reg<=REFRESH_RESULT;end
                    else index_reg<=index_reg+1'b1;
                end
                REFRESH_RESULT: state_reg<=CLEAN;
                CLEAN: begin
                    child_clear_reg<=1;modulus_high<=0;modulus_odd<=0;operand_less<=0;operand_greater<=0;pair_mismatch<=0;
                    p_reg<=0;q_reg<=0;public_exponent_reg<=0;
                    d_captured_reg<=0;index_reg<=0;state_reg<=CLEAN_WAIT;
                end
                CLEAN_WAIT: begin
                    child_clear_reg<=0;
                    if(pair_ready && core_ready)begin
                        if(owned_reg && status_reg==OK)state_reg<=OUTPUT;
                        else if(!pending_reg)state_reg<=IDLE;
                        else state_reg<=COMPLETE;
                        terminal_elapsed_reg<=0;
                    end
                end
                OUTPUT: if(result_valid_o && result_ready_i)begin
                    if(index_reg==63)begin index_reg<=0;state_reg<=COMPLETE;terminal_elapsed_reg<=0;end
                    else index_reg<=index_reg+1'b1;
                end
                COMPLETE: begin
                    terminal_elapsed_reg<=terminal_elapsed_reg+1'b1;
                    if((completion_valid_o && completion_ready_i) || terminal_elapsed_reg>=TERMINAL_LIMIT-1)
                        state_reg<=RELEASE;
                end
                RELEASE: begin
                    owned_reg<=0;pending_reg<=0;id_reg<=0;private_reg<=0;allow_reg<=0;
                    status_reg<=0;elapsed_reg<=0;terminal_elapsed_reg<=0;state_reg<=IDLE;
                end
                default: fail(ARITHMETIC);
            endcase
            // Once reserved, every transfer requires the same live slot. A
            // shared reset suppresses outputs immediately; no late publication.
            if(lease_phase && state_reg!=CLEAN && state_reg!=CLEAN_WAIT &&
                (state_reg!=COMPLETE || status_reg==OK))begin
                if(!slot_consistent)begin owned_reg<=reserved_i;fail(BAD_SLOT);end
                else if(expired && state_reg!=COMPLETE)fail(TIMEOUT);
            end
        end
    end
    end else begin : disabled
        assign request_ready_o=1'b0;
        assign operand_ready_o=1'b0;
        assign result_valid_o=1'b0;
        assign result_data_o=32'd0;
        assign result_last_o=1'b0;
        assign completion_valid_o=1'b0;
        assign completion_code_o=4'd0;
        assign completion_id_o=32'd0;
        assign acquire_valid_o=1'b0;
        assign acquire_allow_o=1'b0;
        assign acquire_type_o=2'd0;
        assign acquire_words_o=8'd0;
        assign acquire_reply_ready_o=1'b0;
        assign consumer_release_o=1'b0;
        assign private_address_o=8'd0;
    end endgenerate
endmodule
