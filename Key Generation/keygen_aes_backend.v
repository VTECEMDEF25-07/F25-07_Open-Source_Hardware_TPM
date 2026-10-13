// AI-authored AES backend controller. External RNG/store contracts are proposals.
// No entropy source, durable store, authorization or production-top enable.
module keygen_aes_backend (
    input wire clock_i, reset_n_i,
    input wire req_valid_i, output wire req_ready_o,
    input wire [31:0] req_id_i, req_context_i, req_destination_i, req_exponent_i,
    input wire [1:0] req_alg_i, req_mode_i,
    input wire [11:0] req_bits_i,
    input wire cancel_valid_i, output wire cancel_ready_o,
    input wire [31:0] cancel_id_i,
    output wire rsp_valid_o, input wire rsp_ready_i,
    output reg [31:0] rsp_id_reg_o, rsp_code_reg_o, rsp_object_reg_o,
    output reg rsp_fail_reg_o,
    output wire busy_o,
    output reg health_fault_reg_o,
    output reg [7:0] health_status_reg_o,
    input wire [31:0] rng_data_i,
    input wire rng_valid_i, rng_error_i, output wire rng_ready_o,
    input wire store_available_i, store_error_i,
    output wire store_begin_valid_o, input wire store_begin_ready_i,
    output wire [31:0] store_begin_id_o, store_begin_context_o, store_begin_destination_o,
    output wire [1:0] store_begin_alg_o,
    output wire [11:0] store_begin_key_bits_o,
    output wire store_data_valid_o, input wire store_data_ready_i,
    output wire [31:0] store_data_id_o, store_data_word_o,
    output wire [3:0] store_data_component_o,
    output wire [6:0] store_data_index_o,
    output wire [11:0] store_data_bits_o,
    output wire store_data_last_o,
    output wire store_finish_valid_o, input wire store_finish_ready_i,
    output wire [31:0] store_finish_id_o, output wire store_finish_abort_o,
    input wire store_rsp_valid_i, output wire store_rsp_ready_o,
    input wire [31:0] store_rsp_id_i, store_rsp_object_i,
    input wire [7:0] store_rsp_status_i
);
    localparam IDLE=0, BEGIN_STORE=1, LAUNCH=2, RUN=3,
        FINISH=4, WAIT_ACK=5, RESULT=6;
    localparam [31:0] RC_FAILURE=32'h101, RC_UNSUPPORTED=32'h143;
    reg [2:0] state_reg;
    reg armed_reg, aborted_reg, finish_was_abort_reg;
    reg [31:0] context_ref_reg, destination_ref_reg;
    reg [11:0] key_bits_reg;
    wire active = state_reg!=IDLE && state_reg!=RESULT;
    wire early_rsp = store_rsp_valid_i===1'b1 && state_reg!=WAIT_ACK;
    wire rng_fault = rng_error_i!==1'b0;
    // Availability gates admission/recovery; a busy store may lower it normally.
    // Active transaction failure must use store_error or the final status.
    wire store_fault = store_error_i!==1'b0;
    wire ack_bad = state_reg==WAIT_ACK && store_rsp_valid_i===1'b1 &&
        (store_rsp_id_i!==rsp_id_reg_o || store_rsp_status_i!==8'd0 ||
         (!finish_was_abort_reg && ((^store_rsp_object_i===1'bx) || store_rsp_object_i==0)) ||
         (finish_was_abort_reg && store_rsp_object_i!==32'd0));
    wire protocol_fault = early_rsp || ack_bad ||
        (active && cancel_valid_i!==1'b0 && cancel_valid_i!==1'b1);
    wire [7:0] faults = {5'd0,protocol_fault,store_fault,rng_fault};
    wire cancel_fire = cancel_valid_i===1'b1 && cancel_ready_o;
    wire cancel_bad = active && cancel_valid_i===1'b1 && cancel_id_i!==rsp_id_reg_o;
    wire abort_now = aborted_reg || cancel_fire || health_fault_reg_o ||
        rng_fault || store_fault || protocol_fault || cancel_bad;
    wire descriptor_ok = (^({req_id_i,req_context_i,req_destination_i,req_exponent_i,
        req_alg_i,req_mode_i,req_bits_i})!==1'bx) && req_alg_i==1 && req_mode_i==0 &&
        req_exponent_i==0 && (req_bits_i==128 || req_bits_i==256);
    wire worker_ready, worker_out_valid, worker_done_valid;
    wire [31:0] worker_id, worker_word, worker_done_id;
    wire [3:0] worker_component;
    wire [6:0] worker_index;
    wire [11:0] worker_bits;
    wire worker_last;
    wire [7:0] worker_status;
    wire worker_rng_ready;
    wire worker_out_ready = state_reg==RUN && !abort_now && store_data_ready_i===1'b1;
    wire worker_work_valid = reset_n_i && state_reg==LAUNCH && !abort_now;

    assign busy_o = reset_n_i && state_reg!=IDLE;
    assign req_ready_o = reset_n_i && state_reg==IDLE && armed_reg && !health_fault_reg_o &&
        faults==0 && store_available_i===1'b1 && cancel_valid_i===1'b0;
    // Before accepted finish, a matching cancel requests rollback. After finish
    // acceptance the storage decision is irreversible here; cancellation is too late.
    assign cancel_ready_o = reset_n_i && active && state_reg!=WAIT_ACK && cancel_id_i===rsp_id_reg_o;
    assign rsp_valid_o = reset_n_i && state_reg==RESULT;
    assign rng_ready_o = reset_n_i && state_reg==RUN && !abort_now && worker_rng_ready;
    assign store_begin_valid_o = reset_n_i && state_reg==BEGIN_STORE && !abort_now;
    assign store_begin_id_o = rsp_id_reg_o;
    assign store_begin_context_o = context_ref_reg;
    assign store_begin_destination_o = destination_ref_reg;
    assign store_begin_alg_o = 2'd1;
    assign store_begin_key_bits_o = key_bits_reg;
    assign store_data_valid_o = reset_n_i && state_reg==RUN && !abort_now && worker_out_valid;
    assign store_data_id_o = store_data_valid_o ? worker_id : 32'd0;
    assign store_data_word_o = store_data_valid_o ? worker_word : 32'd0;
    assign store_data_component_o = store_data_valid_o ? worker_component : 4'd0;
    assign store_data_index_o = store_data_valid_o ? worker_index : 7'd0;
    assign store_data_bits_o = store_data_valid_o ? worker_bits : 12'd0;
    assign store_data_last_o = store_data_valid_o && worker_last;
    assign store_finish_valid_o = reset_n_i && state_reg==FINISH;
    assign store_finish_id_o = rsp_id_reg_o;
    assign store_finish_abort_o = abort_now;
    // Drain unsolicited responses without treating them as finish acknowledgments.
    assign store_rsp_ready_o = reset_n_i && (state_reg==WAIT_ACK || early_rsp);

    aes_key_assembler worker (
        .clock_i(clock_i),.reset_n_i(reset_n_i),.work_valid_i(worker_work_valid),
        .work_ready_o(worker_ready),.work_id_i(rsp_id_reg_o),.work_key_bits_i(key_bits_reg),
        .work_public_exponent_i(32'd0),.work_cancel_i(state_reg==RUN && abort_now),.busy_o(),
        .rng_data_i(rng_data_i),.rng_valid_i(state_reg==RUN && !abort_now && rng_valid_i),
        .rng_error_i(rng_error_i),.rng_ready_o(worker_rng_ready),
        .out_valid_o(worker_out_valid),.out_ready_i(worker_out_ready),
        .out_id_o(worker_id),.out_word_o(worker_word),.out_component_o(worker_component),
        .out_index_o(worker_index),.out_bits_o(worker_bits),.out_last_o(worker_last),
        .done_valid_o(worker_done_valid),.done_ready_i(state_reg==RUN && worker_done_valid),
        .done_id_reg_o(worker_done_id),.done_status_reg_o(worker_status)
    );

    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            state_reg<=IDLE; armed_reg<=0; aborted_reg<=0; finish_was_abort_reg<=0;
            context_ref_reg<=0; destination_ref_reg<=0; key_bits_reg<=0;
            rsp_id_reg_o<=0; rsp_code_reg_o<=RC_UNSUPPORTED; rsp_object_reg_o<=0; rsp_fail_reg_o<=1;
            health_fault_reg_o<=0; health_status_reg_o<=0;
        end else begin
            if(req_valid_i===1'b0) armed_reg<=1;
            // Sticky independent health never rewrites an already published response.
            if(faults!=0 || cancel_bad) begin
                health_fault_reg_o<=1;
                health_status_reg_o<=health_status_reg_o | faults | (cancel_bad ? 8'd4 : 8'd0);
            end
            if(active && abort_now) aborted_reg<=1;
            case(state_reg)
                IDLE: if(req_valid_i===1'b1 && req_ready_o) begin
                    armed_reg<=0; aborted_reg<=0; finish_was_abort_reg<=0;
                    rsp_id_reg_o <= (^req_id_i===1'bx) ? 32'd0 : req_id_i;
                    rsp_fail_reg_o<=1; rsp_code_reg_o<=RC_FAILURE; rsp_object_reg_o<=0;
                    context_ref_reg<=req_context_i; destination_ref_reg<=req_destination_i; key_bits_reg<=req_bits_i;
                    if(!descriptor_ok) begin rsp_code_reg_o<=RC_UNSUPPORTED; state_reg<=RESULT; end
                    else state_reg<=BEGIN_STORE;
                end
                BEGIN_STORE: if(abort_now) state_reg<=RESULT;
                    else if(store_begin_valid_o && store_begin_ready_i===1'b1) state_reg<=LAUNCH;
                LAUNCH: if(abort_now) state_reg<=FINISH;
                    else if(worker_work_valid && worker_ready) state_reg<=RUN;
                RUN: if(worker_done_valid) begin
                    if(worker_done_id!==rsp_id_reg_o || worker_status!==8'd0) begin
                        aborted_reg<=1;
                        if(!abort_now) begin
                            health_fault_reg_o<=1;
                            health_status_reg_o<=health_status_reg_o | (worker_status===8'd2 ? 8'd1 : 8'd4);
                        end
                    end
                    state_reg<=FINISH;
                end
                FINISH: if(store_finish_valid_o && store_finish_ready_i===1'b1) begin
                    finish_was_abort_reg<=abort_now; state_reg<=WAIT_ACK;
                end
                WAIT_ACK: if(store_rsp_valid_i===1'b1 && store_rsp_ready_o) begin
                    if(!abort_now && !finish_was_abort_reg && !ack_bad) begin
                        rsp_fail_reg_o<=0; rsp_code_reg_o<=0; rsp_object_reg_o<=store_rsp_object_i;
                    end
                    // Even a failed acknowledgment gives no rollback proof. Health
                    // quarantines further work; recovery must reconcile durable state.
                    state_reg<=RESULT;
                end
                RESULT: if(rsp_ready_i===1'b1) begin
                    state_reg<=IDLE; rsp_id_reg_o<=0; rsp_object_reg_o<=0;
                    context_ref_reg<=0; destination_ref_reg<=0; key_bits_reg<=0;
                end
                default: begin state_reg<=RESULT; rsp_fail_reg_o<=1; rsp_code_reg_o<=RC_FAILURE;
                    rsp_object_reg_o<=0; health_fault_reg_o<=1; health_status_reg_o<=health_status_reg_o|8'd4; end
            endcase
        end
    end
endmodule
