// Filename: hmac_sha256_placeholder.v
// Practice only: return the first 32 message bytes as a pretend digest.
// This does NOT calculate HMAC or SHA-256.
`default_nettype none

module hmac_sha256_placeholder (
    input wire clk_i,                 // Same clock as kdfa_control.
    input wire reset_n_i,             // Reset together with kdfa_control.
    input wire req_valid_i,           // Sender has a key/message ready.
    output wire req_ready_o,          // Placeholder can accept it.
    input wire [255:0] key_i,         // Real HMAC needs this; this fake ignores it.
    input wire [607:0] message_i,     // Fixed 76-byte message from kdfa_control.
    output reg [255:0] digest_o,      // FAKE 32-byte result; read only when valid.
    output reg rsp_valid_o,           // 1 means a fake result is waiting to be read.
    input wire rsp_ready_i,           // Sender is accepting our result.
    output wire error_o              // This simple placeholder never reports an error.
);
    // Accept a message only when no previous result is waiting.
    assign req_ready_o = reset_n_i && !rsp_valid_o;
    assign error_o = 1'b0;

    always @(posedge clk_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            // Reset: no result is waiting.
            rsp_valid_o <= 0;
            digest_o <= 0;
        end else if (req_valid_i && req_ready_o) begin
            // Take the first 256 bits. Counter 1 and 2 give different fake results.
            digest_o <= message_i[607:352];
            rsp_valid_o <= 1;
        end else if (rsp_valid_o && rsp_ready_i) begin
            // The controller received the result; make room for the next request.
            rsp_valid_o <= 0;
            digest_o <= 0;
        end
        // Otherwise keep the result unchanged until the controller accepts it.
    end
endmodule
`default_nettype wire
