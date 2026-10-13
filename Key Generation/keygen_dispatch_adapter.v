// AI-authored control plumbing; no cryptographic/key-storage implementation.
// Default backend is unavailable and returns COMMAND_CODE, never success.
module keygen_dispatch_adapter #(
    parameter EXTERNAL_BACKEND = 0
) (
    input wire clock_i,
    input wire reset_n_i,
    input wire start_i,
    input wire descriptor_valid_i,
    input wire session_validated_i,
    input wire [31:0] command_code_i,
    input wire [31:0] descriptor_id_i,
    input wire [1:0] descriptor_alg_i,
    input wire [11:0] descriptor_bits_i,
    input wire [1:0] descriptor_mode_i,
    input wire [31:0] descriptor_context_i,
    input wire [31:0] descriptor_destination_i,
    input wire [31:0] descriptor_exponent_i,
    input wire cancel_i,
    output wire busy_o,
    output wire terminal_valid_o,
    input wire terminal_ready_i,
    output reg [31:0] terminal_code_reg_o,
    output reg [31:0] terminal_object_reg_o,
    output wire req_valid_o,
    input wire req_ready_i,
    output reg [31:0] req_id_reg_o,
    output reg [1:0] req_alg_reg_o,
    output reg [11:0] req_bits_reg_o,
    output reg [1:0] req_mode_reg_o,
    output reg [31:0] req_context_reg_o,
    output reg [31:0] req_destination_reg_o,
    output reg [31:0] req_exponent_reg_o,
    output wire cancel_valid_o,
    input wire cancel_ready_i,
    output wire [31:0] cancel_id_o,
    input wire rsp_valid_i,
    output wire rsp_ready_o,
    input wire [31:0] rsp_id_i,
    input wire rsp_fail_i,
    input wire [31:0] rsp_code_i,
    input wire [31:0] rsp_object_i
);
    localparam IDLE = 3'd0, ISSUE = 3'd1, WAIT_RESULT = 3'd2, RESULT = 3'd3;
    localparam [31:0] RC_UNSUPPORTED = 32'h00000143, RC_FAILURE = 32'h00000101;
    reg [2:0] state_reg;
    reg armed_reg, cancel_sent_reg, cancel_pending_reg;
    wire supported = descriptor_valid_i && session_validated_i &&
        command_code_i == 32'h00000153 && descriptor_mode_i == 2'd0 &&
        ((descriptor_alg_i == 2'd1 && (descriptor_bits_i == 12'd128 || descriptor_bits_i == 12'd256) && descriptor_exponent_i == 0) ||
         (descriptor_alg_i == 2'd2 && descriptor_bits_i == 12'd2048 && descriptor_exponent_i == 32'd65537));

    assign busy_o = reset_n_i && state_reg != IDLE;
    assign terminal_valid_o = reset_n_i && state_reg == RESULT;
    // Cancel suppresses request acceptance on the same edge, including backpressure.
    assign req_valid_o = reset_n_i && state_reg == ISSUE && !cancel_i;
    assign cancel_valid_o = reset_n_i && state_reg == WAIT_RESULT && (cancel_i || cancel_pending_reg) && !cancel_sent_reg;
    assign cancel_id_o = req_id_reg_o;
    assign rsp_ready_o = reset_n_i && state_reg == WAIT_RESULT;

    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            state_reg <= IDLE;
            armed_reg <= 1'b0; // Require a sampled low start after reset; never replay held work.
            cancel_sent_reg <= 1'b0;
            cancel_pending_reg <= 1'b0;
            terminal_code_reg_o <= RC_UNSUPPORTED;
            terminal_object_reg_o <= 0;
            req_id_reg_o <= 0; req_alg_reg_o <= 0; req_bits_reg_o <= 0; req_mode_reg_o <= 0;
            req_context_reg_o <= 0; req_destination_reg_o <= 0; req_exponent_reg_o <= 0;
        end else begin
            if (!start_i) armed_reg <= 1'b1;
            case (state_reg)
                IDLE: if (start_i && armed_reg) begin
                    armed_reg <= 1'b0;
                    cancel_sent_reg <= 1'b0;
                    cancel_pending_reg <= 1'b0;
                    terminal_object_reg_o <= 0;
                    req_id_reg_o <= descriptor_id_i;
                    req_alg_reg_o <= descriptor_alg_i;
                    req_bits_reg_o <= descriptor_bits_i;
                    req_mode_reg_o <= descriptor_mode_i;
                    req_context_reg_o <= descriptor_context_i;
                    req_destination_reg_o <= descriptor_destination_i;
                    req_exponent_reg_o <= descriptor_exponent_i;
                    if (cancel_i) begin
                        terminal_code_reg_o <= RC_FAILURE;
                        state_reg <= RESULT;
                    end else if (EXTERNAL_BACKEND && supported) begin
                        state_reg <= ISSUE;
                    end else begin
                        terminal_code_reg_o <= RC_UNSUPPORTED;
                        state_reg <= RESULT;
                    end
                end
                ISSUE: begin
                    if (cancel_i) begin
                        terminal_code_reg_o <= RC_FAILURE;
                        state_reg <= RESULT;
                    end else if (req_valid_o && req_ready_i) begin
                        state_reg <= WAIT_RESULT;
                    end
                end
                WAIT_RESULT: begin
                    if (cancel_i) cancel_pending_reg <= 1'b1;
                    if (cancel_valid_o && cancel_ready_i) cancel_sent_reg <= 1'b1;
                    if (rsp_valid_i && rsp_ready_o) begin
                        // Failure/cancel dominates a simultaneous successful result.
                        // Unknown/unconnected terminal fields must never qualify as success.
                        if (rsp_id_i === req_id_reg_o && rsp_fail_i === 1'b0 && rsp_code_i === 32'd0 &&
                            !cancel_sent_reg && !(cancel_valid_o && cancel_ready_i)) begin
                            terminal_code_reg_o <= 0;
                            terminal_object_reg_o <= rsp_object_i;
                        end else begin
                            if (rsp_id_i == req_id_reg_o && rsp_code_i != 0) terminal_code_reg_o <= rsp_code_i;
                            else terminal_code_reg_o <= RC_FAILURE;
                            terminal_object_reg_o <= 0;
                        end
                        state_reg <= RESULT;
                    end
                end
                RESULT: if (terminal_valid_o && terminal_ready_i) begin
                    state_reg <= IDLE;
                    // Descriptor buses are no longer needed after terminal retirement.
                    req_id_reg_o <= 0; req_alg_reg_o <= 0; req_bits_reg_o <= 0; req_mode_reg_o <= 0;
                    req_context_reg_o <= 0; req_destination_reg_o <= 0; req_exponent_reg_o <= 0;
                end
                default: begin
                    state_reg <= RESULT;
                    terminal_code_reg_o <= RC_FAILURE;
                    terminal_object_reg_o <= 0;
                end
            endcase
        end
    end
endmodule
