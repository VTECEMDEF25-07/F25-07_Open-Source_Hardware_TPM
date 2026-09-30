// AI-authored control plumbing; no cryptographic/key-storage implementation.
// Default backend is unavailable and returns COMMAND_CODE, never success.
module keygen_dispatch_adapter #(
    parameter EXTERNAL_BACKEND = 0
) (
    input wire clock,
    input wire reset_n,
    input wire start,
    input wire descriptor_valid,
    input wire session_validated,
    input wire [31:0] command_code,
    input wire [31:0] descriptor_id,
    input wire [1:0] descriptor_alg,
    input wire [11:0] descriptor_bits,
    input wire [1:0] descriptor_mode,
    input wire [31:0] descriptor_context,
    input wire [31:0] descriptor_destination,
    input wire [31:0] descriptor_exponent,
    input wire cancel,
    output wire busy,
    output wire terminal_valid,
    input wire terminal_ready,
    output reg [31:0] terminal_code,
    output reg [31:0] terminal_object,
    output wire req_valid,
    input wire req_ready,
    output reg [31:0] req_id,
    output reg [1:0] req_alg,
    output reg [11:0] req_bits,
    output reg [1:0] req_mode,
    output reg [31:0] req_context,
    output reg [31:0] req_destination,
    output reg [31:0] req_exponent,
    output wire cancel_valid,
    input wire cancel_ready,
    output wire [31:0] cancel_id,
    input wire rsp_valid,
    output wire rsp_ready,
    input wire [31:0] rsp_id,
    input wire rsp_fail,
    input wire [31:0] rsp_code,
    input wire [31:0] rsp_object
);
    localparam IDLE = 3'd0, ISSUE = 3'd1, WAIT_RESULT = 3'd2, RESULT = 3'd3;
    localparam [31:0] RC_UNSUPPORTED = 32'h00000143, RC_FAILURE = 32'h00000101;
    reg [2:0] state;
    reg armed, cancel_sent, cancel_pending;
    wire supported = descriptor_valid && session_validated &&
        command_code == 32'h00000153 && descriptor_mode == 2'd0 &&
        ((descriptor_alg == 2'd1 && descriptor_bits == 12'd256 && descriptor_exponent == 0) ||
         (descriptor_alg == 2'd2 && descriptor_bits == 12'd2048 && descriptor_exponent == 32'd65537));

    assign busy = reset_n && state != IDLE;
    assign terminal_valid = reset_n && state == RESULT;
    // Cancel suppresses request acceptance on the same edge, including backpressure.
    assign req_valid = reset_n && state == ISSUE && !cancel;
    assign cancel_valid = reset_n && state == WAIT_RESULT && (cancel || cancel_pending) && !cancel_sent;
    assign cancel_id = req_id;
    assign rsp_ready = reset_n && state == WAIT_RESULT;

    always @(posedge clock or negedge reset_n) begin
        if (!reset_n) begin
            state <= IDLE;
            armed <= 1'b0; // Require a sampled low start after reset; never replay held work.
            cancel_sent <= 1'b0;
            cancel_pending <= 1'b0;
            terminal_code <= RC_UNSUPPORTED;
            terminal_object <= 0;
            req_id <= 0; req_alg <= 0; req_bits <= 0; req_mode <= 0;
            req_context <= 0; req_destination <= 0; req_exponent <= 0;
        end else begin
            if (!start) armed <= 1'b1;
            case (state)
                IDLE: if (start && armed) begin
                    armed <= 1'b0;
                    cancel_sent <= 1'b0;
                    cancel_pending <= 1'b0;
                    terminal_object <= 0;
                    req_id <= descriptor_id;
                    req_alg <= descriptor_alg;
                    req_bits <= descriptor_bits;
                    req_mode <= descriptor_mode;
                    req_context <= descriptor_context;
                    req_destination <= descriptor_destination;
                    req_exponent <= descriptor_exponent;
                    if (cancel) begin
                        terminal_code <= RC_FAILURE;
                        state <= RESULT;
                    end else if (EXTERNAL_BACKEND && supported) begin
                        state <= ISSUE;
                    end else begin
                        terminal_code <= RC_UNSUPPORTED;
                        state <= RESULT;
                    end
                end
                ISSUE: begin
                    if (cancel) begin
                        terminal_code <= RC_FAILURE;
                        state <= RESULT;
                    end else if (req_valid && req_ready) begin
                        state <= WAIT_RESULT;
                    end
                end
                WAIT_RESULT: begin
                    if (cancel) cancel_pending <= 1'b1;
                    if (cancel_valid && cancel_ready) cancel_sent <= 1'b1;
                    if (rsp_valid && rsp_ready) begin
                        // Failure/cancel dominates a simultaneous successful result.
                        // Unknown/unconnected terminal fields must never qualify as success.
                        if (rsp_id === req_id && rsp_fail === 1'b0 && rsp_code === 32'd0 &&
                            !cancel_sent && !(cancel_valid && cancel_ready)) begin
                            terminal_code <= 0;
                            terminal_object <= rsp_object;
                        end else begin
                            if (rsp_id == req_id && rsp_code != 0) terminal_code <= rsp_code;
                            else terminal_code <= RC_FAILURE;
                            terminal_object <= 0;
                        end
                        state <= RESULT;
                    end
                end
                RESULT: if (terminal_valid && terminal_ready) begin
                    state <= IDLE;
                    // Descriptor buses are no longer needed after terminal retirement.
                    req_id <= 0; req_alg <= 0; req_bits <= 0; req_mode <= 0;
                    req_context <= 0; req_destination <= 0; req_exponent <= 0;
                end
                default: begin
                    state <= RESULT;
                    terminal_code <= RC_FAILURE;
                    terminal_object <= 0;
                end
            endcase
        end
    end
endmodule
