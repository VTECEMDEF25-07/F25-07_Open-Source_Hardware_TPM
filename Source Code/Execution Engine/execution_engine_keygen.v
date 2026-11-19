// Internal Phase Two lifecycle. This is not a TPM object/authorization service.
// One volatile private slot. Provisional ownership is not usable publication.
// Codex assisted implementation; see KEYGEN_LIFECYCLE.md.
module execution_engine_keygen #(
    parameter ENABLE=0, IP_TYPE=0, parameter DEVICE_FAMILY="Agilex 5",
    parameter [63:0] WAIT_LIMIT=64'd9000000000
)(
    input wire clock_i, reset_n_i,
    input wire request_valid_i, output wire request_ready_o,
    input wire [1:0] profile_i, input wire [31:0] id_i,
    input wire allow_i, output wire busy_o,
    output wire completion_valid_o, input wire completion_ready_i,
    output wire [3:0] completion_code_o, output wire [31:0] completion_id_o,
    input wire release_i, output wire slot_valid_o,
    output wire [1:0] slot_type_o, output wire [7:0] slot_words_o,
    input wire [7:0] private_address_i, output wire [31:0] private_data_o,
    input wire result_enable_i, ownership_enable_i, terminal_enable_i,
    output wire source_open_o, input wire source_grant_i,
    output wire source_close_o, input wire source_closed_i,
    input wire [31:0] source_word_i, input wire source_valid_i,
    output wire source_ready_o, input wire source_fault_i,
    output wire timeout_o
);
    localparam SCRUB=0, IDLE=1, OPEN=2, START=3, RUN=4,
        CLOSE=5, COMPLETE=6, LIVE=7;
    reg [3:0] state, outcome;
    reg [1:0] profile;
    reg [31:0] id;
    reg [63:0] elapsed;
    reg [7:0] count, scrub_index;
    reg owned, published, failed, return_completion;
    reg [31:0] slot [0:128];
    wire active = state==OPEN || state==START || state==RUN || state==CLOSE;
    wire expired = active && elapsed >= WAIT_LIMIT-1;
    wire bad = source_fault_i || failed || expired;
    wire generation_ready;
    wire core_ready, result_valid, result_last, component_last;
    wire [31:0] result_data, result_id, status_id;
    wire [2:0] component;
    wire [6:0] index;
    wire ownership_ready, discard, status_valid;
    wire [3:0] status;
    wire [7:0] expected_words = profile==0 ? 8'd4 : profile==1 ? 8'd8 : 8'd129;
    wire [2:0] expected_component = profile<2 ? 3'd1 : count<64 ? 3'd2 :
        count==64 ? 3'd3 : count<97 ? 3'd4 : 3'd5;
    wire [6:0] expected_index = profile<2 ? count[6:0] : count<64 ? count[6:0] :
        count==64 ? 7'd0 : count<97 ? count-8'd65 : count-8'd97;
    wire expected_component_last = profile<2 ? count==expected_words-1 :
        count==63 || count==64 || count==96 || count==128;
    wire consistent = count<expected_words && result_id==id &&
        component==expected_component && index==expected_index &&
        component_last==expected_component_last && result_last==(count==expected_words-1);
    wire take_result = state==RUN && result_enable_i && !bad && !discard;
    wire take_ownership = state==RUN && ownership_enable_i && !bad &&
        count==expected_words && !discard;
    wire take_status = state==RUN && (terminal_enable_i || bad);
    assign request_ready_o = reset_n_i && ENABLE && state==IDLE;
    assign busy_o = !request_ready_o;
    assign source_open_o = reset_n_i && state==OPEN && !bad;
    assign source_close_o = reset_n_i && state==CLOSE;
    assign source_ready_o = reset_n_i && state==RUN && !bad && generation_ready;
    assign timeout_o = reset_n_i && expired;
    assign completion_valid_o = reset_n_i && state==COMPLETE;
    assign completion_code_o = completion_valid_o ? outcome : 4'd0;
    assign completion_id_o = completion_valid_o ? id : 32'd0;
    assign slot_valid_o = reset_n_i && published && !release_i;
    assign slot_type_o = slot_valid_o ? profile : 2'd0;
    assign slot_words_o = slot_valid_o ? expected_words : 8'd0;
    assign private_data_o = slot_valid_o && private_address_i<expected_words ? slot[private_address_i] : 32'd0;
    keygen_core #(.IP_TYPE(IP_TYPE),.DEVICE_FAMILY(DEVICE_FAMILY)) core (
        .clock_i(clock_i),.reset_n_i(reset_n_i),.peers_ready_i(source_grant_i),
        .request_valid_i(state==START && !bad),.request_ready_o(core_ready),
        .request_profile_i(profile),.request_id_i(id),
        .generation_valid_i(state==RUN && source_valid_i && !bad),
        .generation_ready_o(generation_ready),.generation_data_i(source_word_i),
        .generation_failed_i(bad),.result_valid_o(result_valid),
        .result_ready_i(take_result),.result_data_o(result_data),
        .result_component_o(component),.result_index_o(index),
        .result_component_last_o(component_last),.result_last_o(result_last),.result_id_o(result_id),
        .ownership_valid_i(take_ownership),.ownership_ready_o(ownership_ready),
        .ownership_accept_i(1'b1),.result_discard_o(discard),
        .status_valid_o(status_valid),.status_ready_i(take_status),
        .status_code_o(status),.status_id_o(status_id));
    always @(posedge clock_i or negedge reset_n_i) begin
        if(!reset_n_i) begin
            state<=SCRUB; outcome<=0; profile<=0; id<=0; elapsed<=0;
            count<=0; scrub_index<=0; owned<=0; published<=0;
            failed<=0; return_completion<=0;
        end else begin
            if(active && !expired) elapsed<=elapsed+1'b1;
            if(active && bad) begin failed<=1; published<=0; if(outcome==0) outcome<=2; end
            case(state)
                SCRUB: begin
                    slot[scrub_index]<=0;
                    published<=0; owned<=0; count<=0;
                    if(scrub_index==128) begin
                        scrub_index<=0;
                        state<=return_completion ? COMPLETE : IDLE;
                    end else scrub_index<=scrub_index+1'b1;
                end
                IDLE: if(request_valid_i && request_ready_o) begin
                    id<=id_i; profile<=profile_i; elapsed<=0; failed<=0;
                    outcome<=0; count<=0; owned<=0; return_completion<=1;
                    if(!allow_i) begin outcome<=9; state<=COMPLETE; end
                    else if(profile_i==3) begin outcome<=1; state<=COMPLETE; end
                    else state<=OPEN;
                end
                OPEN: if(bad) state<=CLOSE;
                    else if(source_grant_i) state<=START;
                START: if(bad) state<=CLOSE;
                    else if(core_ready) state<=RUN;
                RUN: begin
                    if(result_valid && take_result) begin
                        if(!consistent) begin failed<=1; outcome<=4; end
                        else begin slot[count]<=result_data; count<=count+1'b1; end
                    end
                    if(ownership_ready && take_ownership) owned<=1;
                    if(discard) begin failed<=1; published<=0; end
                    if(status_valid && take_status) begin
                        if(status_id!=id || status!=0 || !owned || count!=expected_words || bad || discard) begin
                            failed<=1;
                            if(outcome==0) outcome<=bad ? 4'd2 : status!=0 ? status : 4'd4;
                        end
                        state<=CLOSE;
                    end
                end
                CLOSE: if(source_closed_i) begin
                    if(!bad && owned && outcome==0 && count==expected_words) begin
                        published<=1; state<=COMPLETE;
                    end else begin state<=SCRUB; scrub_index<=0; end
                end
                COMPLETE: begin
                    // Release also wins while completion is held. Failed/denied
                    // completion metadata stays held until explicitly accepted.
                    if(release_i && published) begin
                        published<=0; state<=SCRUB; scrub_index<=0;
                        return_completion<=!completion_ready_i;
                    end else if(completion_ready_i) begin
                        return_completion<=0; state<=published ? LIVE : IDLE;
                    end
                end
                LIVE: if(release_i) begin
                    published<=0; state<=SCRUB; scrub_index<=0; return_completion<=0;
                end
                default: begin published<=0; state<=SCRUB; scrub_index<=0; return_completion<=0; end
            endcase
        end
    end
endmodule
