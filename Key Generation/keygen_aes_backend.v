// AI-authored AES backend controller. External RNG/store contracts are proposals.
// No entropy source, durable store, authorization or production-top enable.
module keygen_aes_backend (
    input wire clock, reset_n,
    input wire req_valid, output wire req_ready,
    input wire [31:0] req_id, req_context, req_destination, req_exponent,
    input wire [1:0] req_alg, req_mode,
    input wire [11:0] req_bits,
    input wire cancel_valid, output wire cancel_ready,
    input wire [31:0] cancel_id,
    output wire rsp_valid, input wire rsp_ready,
    output reg [31:0] rsp_id, rsp_code, rsp_object,
    output reg rsp_fail,
    output wire busy,
    output reg health_fault,
    output reg [7:0] health_status,
    input wire [31:0] rng_data,
    input wire rng_valid, rng_error, output wire rng_ready,
    input wire store_available, store_error,
    output wire store_begin_valid, input wire store_begin_ready,
    output wire [31:0] store_begin_id, store_begin_context, store_begin_destination,
    output wire [1:0] store_begin_alg,
    output wire [11:0] store_begin_key_bits,
    output wire store_data_valid, input wire store_data_ready,
    output wire [31:0] store_data_id, store_data_word,
    output wire [3:0] store_data_component,
    output wire [6:0] store_data_index,
    output wire [11:0] store_data_bits,
    output wire store_data_last,
    output wire store_finish_valid, input wire store_finish_ready,
    output wire [31:0] store_finish_id, output wire store_finish_abort,
    input wire store_rsp_valid, output wire store_rsp_ready,
    input wire [31:0] store_rsp_id, store_rsp_object,
    input wire [7:0] store_rsp_status
);
    localparam IDLE=0, BEGIN_STORE=1, LAUNCH=2, RUN=3,
        FINISH=4, WAIT_ACK=5, RESULT=6;
    localparam [31:0] RC_FAILURE=32'h101, RC_UNSUPPORTED=32'h143;
    reg [2:0] state;
    reg armed, aborted, finish_was_abort;
    reg [31:0] context_ref, destination_ref;
    reg [11:0] key_bits;
    wire active = state!=IDLE && state!=RESULT;
    wire early_rsp = store_rsp_valid===1'b1 && state!=WAIT_ACK;
    wire rng_fault = rng_error!==1'b0;
    // Availability gates admission/recovery; a busy store may lower it normally.
    // Active transaction failure must use store_error or the final status.
    wire store_fault = store_error!==1'b0;
    wire ack_bad = state==WAIT_ACK && store_rsp_valid===1'b1 &&
        (store_rsp_id!==rsp_id || store_rsp_status!==8'd0 ||
         (!finish_was_abort && ((^store_rsp_object===1'bx) || store_rsp_object==0)) ||
         (finish_was_abort && store_rsp_object!==32'd0));
    wire protocol_fault = early_rsp || ack_bad ||
        (active && cancel_valid!==1'b0 && cancel_valid!==1'b1);
    wire [7:0] faults = {5'd0,protocol_fault,store_fault,rng_fault};
    wire cancel_fire = cancel_valid===1'b1 && cancel_ready;
    wire cancel_bad = active && cancel_valid===1'b1 && cancel_id!==rsp_id;
    wire abort_now = aborted || cancel_fire || health_fault ||
        rng_fault || store_fault || protocol_fault || cancel_bad;
    wire descriptor_ok = (^({req_id,req_context,req_destination,req_exponent,
        req_alg,req_mode,req_bits})!==1'bx) && req_alg==1 && req_mode==0 &&
        req_exponent==0 && (req_bits==128 || req_bits==256);
    wire worker_ready, worker_out_valid, worker_done_valid;
    wire [31:0] worker_id, worker_word, worker_done_id;
    wire [3:0] worker_component;
    wire [6:0] worker_index;
    wire [11:0] worker_bits;
    wire worker_last;
    wire [7:0] worker_status;
    wire worker_rng_ready;
    wire worker_out_ready = state==RUN && !abort_now && store_data_ready===1'b1;
    wire worker_work_valid = reset_n && state==LAUNCH && !abort_now;

    assign busy = reset_n && state!=IDLE;
    assign req_ready = reset_n && state==IDLE && armed && !health_fault &&
        faults==0 && store_available===1'b1 && cancel_valid===1'b0;
    // Before accepted finish, a matching cancel requests rollback. After finish
    // acceptance the storage decision is irreversible here; cancellation is too late.
    assign cancel_ready = reset_n && active && state!=WAIT_ACK && cancel_id===rsp_id;
    assign rsp_valid = reset_n && state==RESULT;
    assign rng_ready = reset_n && state==RUN && !abort_now && worker_rng_ready;
    assign store_begin_valid = reset_n && state==BEGIN_STORE && !abort_now;
    assign store_begin_id = rsp_id;
    assign store_begin_context = context_ref;
    assign store_begin_destination = destination_ref;
    assign store_begin_alg = 2'd1;
    assign store_begin_key_bits = key_bits;
    assign store_data_valid = reset_n && state==RUN && !abort_now && worker_out_valid;
    assign store_data_id = store_data_valid ? worker_id : 32'd0;
    assign store_data_word = store_data_valid ? worker_word : 32'd0;
    assign store_data_component = store_data_valid ? worker_component : 4'd0;
    assign store_data_index = store_data_valid ? worker_index : 7'd0;
    assign store_data_bits = store_data_valid ? worker_bits : 12'd0;
    assign store_data_last = store_data_valid && worker_last;
    assign store_finish_valid = reset_n && state==FINISH;
    assign store_finish_id = rsp_id;
    assign store_finish_abort = abort_now;
    // Drain unsolicited responses without treating them as finish acknowledgments.
    assign store_rsp_ready = reset_n && (state==WAIT_ACK || early_rsp);

    aes_key_assembler worker (
        .clock(clock),.reset_n(reset_n),.work_valid(worker_work_valid),
        .work_ready(worker_ready),.work_id(rsp_id),.work_key_bits(key_bits),
        .work_public_exponent(32'd0),.work_cancel(state==RUN && abort_now),.busy(),
        .rng_data(rng_data),.rng_valid(state==RUN && !abort_now && rng_valid),
        .rng_error(rng_error),.rng_ready(worker_rng_ready),
        .out_valid(worker_out_valid),.out_ready(worker_out_ready),
        .out_id(worker_id),.out_word(worker_word),.out_component(worker_component),
        .out_index(worker_index),.out_bits(worker_bits),.out_last(worker_last),
        .done_valid(worker_done_valid),.done_ready(state==RUN && worker_done_valid),
        .done_id(worker_done_id),.done_status(worker_status)
    );

    always @(posedge clock or negedge reset_n) begin
        if (!reset_n) begin
            state<=IDLE; armed<=0; aborted<=0; finish_was_abort<=0;
            context_ref<=0; destination_ref<=0; key_bits<=0;
            rsp_id<=0; rsp_code<=RC_UNSUPPORTED; rsp_object<=0; rsp_fail<=1;
            health_fault<=0; health_status<=0;
        end else begin
            if(req_valid===1'b0) armed<=1;
            // Sticky independent health never rewrites an already published response.
            if(faults!=0 || cancel_bad) begin
                health_fault<=1;
                health_status<=health_status | faults | (cancel_bad ? 8'd4 : 8'd0);
            end
            if(active && abort_now) aborted<=1;
            case(state)
                IDLE: if(req_valid===1'b1 && req_ready) begin
                    armed<=0; aborted<=0; finish_was_abort<=0;
                    rsp_id <= (^req_id===1'bx) ? 32'd0 : req_id;
                    rsp_fail<=1; rsp_code<=RC_FAILURE; rsp_object<=0;
                    context_ref<=req_context; destination_ref<=req_destination; key_bits<=req_bits;
                    if(!descriptor_ok) begin rsp_code<=RC_UNSUPPORTED; state<=RESULT; end
                    else state<=BEGIN_STORE;
                end
                BEGIN_STORE: if(abort_now) state<=RESULT;
                    else if(store_begin_valid && store_begin_ready===1'b1) state<=LAUNCH;
                LAUNCH: if(abort_now) state<=FINISH;
                    else if(worker_work_valid && worker_ready) state<=RUN;
                RUN: if(worker_done_valid) begin
                    if(worker_done_id!==rsp_id || worker_status!==8'd0) begin
                        aborted<=1;
                        if(!abort_now) begin
                            health_fault<=1;
                            health_status<=health_status | (worker_status===8'd2 ? 8'd1 : 8'd4);
                        end
                    end
                    state<=FINISH;
                end
                FINISH: if(store_finish_valid && store_finish_ready===1'b1) begin
                    finish_was_abort<=abort_now; state<=WAIT_ACK;
                end
                WAIT_ACK: if(store_rsp_valid===1'b1 && store_rsp_ready) begin
                    if(!abort_now && !finish_was_abort && !ack_bad) begin
                        rsp_fail<=0; rsp_code<=0; rsp_object<=store_rsp_object;
                    end
                    // Even a failed acknowledgment gives no rollback proof. Health
                    // quarantines further work; recovery must reconcile durable state.
                    state<=RESULT;
                end
                RESULT: if(rsp_ready===1'b1) begin
                    state<=IDLE; rsp_id<=0; rsp_object<=0;
                    context_ref<=0; destination_ref<=0; key_bits<=0;
                end
                default: begin state<=RESULT; rsp_fail<=1; rsp_code<=RC_FAILURE;
                    rsp_object<=0; health_fault<=1; health_status<=health_status|8'd4; end
            endcase
        end
    end
endmodule
