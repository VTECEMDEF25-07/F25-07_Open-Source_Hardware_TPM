// Nonsecret reset/recovery record. Outside crypto reset, inside board reset.
// Codex-assisted implementation; DE25 demo contract v0.1.
module demo_recovery_supervisor #(
    parameter [63:0] DEADLINE_CYCLES=64'd9000000000
) (
    input wire clock_i, reset_n_i,
    input wire active_i, recovery_request_i, transport_abort_i,
    input wire job_accept_i, input wire [31:0] job_id_i,
    input wire commit_i, input wire [31:0] commit_handle_i,
    output wire crypto_reset_n_o, recovery_pending_o,
    output reg recovered_o,
    output reg [31:0] last_id_o, last_handle_o,
    output reg last_committed_o,
    output reg [3:0] last_reason_o
);
    reg [63:0] elapsed;
    reg [3:0] reset_count;
    reg [1:0] release_sync;
    wire deadline=active_i && elapsed>=DEADLINE_CYCLES-1;
    wire trigger=recovery_request_i || transport_abort_i || deadline;
    // Qualify core/store transfer acceptance BEFORE the edge asserting reset.
    assign recovery_pending_o=crypto_reset_n_o && trigger;
    assign crypto_reset_n_o=reset_n_i && reset_count==0 && release_sync[1];
    always @(posedge clock_i or negedge reset_n_i) begin
        if(!reset_n_i) begin
            reset_count<=4;release_sync<=0;elapsed<=0;
            recovered_o<=0;last_id_o<=0;last_handle_o<=0;
            last_committed_o<=0;last_reason_o<=0;
        end else begin
            if(reset_count!=0) begin
                reset_count<=reset_count-1'b1;release_sync<=0;elapsed<=0;
            end else if(!release_sync[1]) begin
                release_sync<={release_sync[0],1'b1};elapsed<=0;
            end else if(trigger) begin
                reset_count<=4;release_sync<=0;elapsed<=0;recovered_o<=1;
                last_reason_o<=transport_abort_i ? 4'd1 : deadline ? 4'd2 : 4'd3;
            end else if(active_i) elapsed<=elapsed+1'b1;
            else elapsed<=0;
            if(crypto_reset_n_o && job_accept_i) begin
                last_id_o<=job_id_i;last_handle_o<=0;last_committed_o<=0;
                if(!trigger) begin recovered_o<=0;last_reason_o<=0;end
            end
            // Ownership at this edge remains a historical fact even on recovery.
            if(crypto_reset_n_o && commit_i) begin
                last_handle_o<=commit_handle_i;last_committed_o<=1;
            end
        end
    end
endmodule
