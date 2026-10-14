// Filename: kdfa_control.v
// Author: Makeda Solomon
// Date: 30 Semptember 2026
// Version: 5
// Description:  Fixed-size CFB practice controller: two messages produce 32-byte key + 16-byte IV.
// Assumptions: 32-byte secret, two 32-byte nonces, label "CFB\0", output 384 bits.
// Those fixed sizes remove the need for byte-count ports. This is not general KDFa.
// Nonce sizes are fixed by the ports; the caller must supply the correct/fresh values.
// With a FAKE HMAC attached, the outputs are practice values, not real derived keys.
// All transfers happen on a rising clock edge with valid AND ready high.
`default_nettype none

module kdfa_control (
    input wire clk_i, // Shared clock.
    input wire reset_n_i, // Active-low reset; also reset the HMAC module.

    // Control signals sent and recieved between the KDFa controller and HMAC-SHA256
    input wire req_valid_i, // Verifies valid incoming inputs
    input wire rsp_ready_i, // Acceptance status of final results
    output reg error_o, // HMAC_SHA256 reports if there are any errors within its calculation
    output wire req_ready_o, // KDFa controller sends a valid/invalid response to the HMAC-SHA256's digest
    output wire rsp_valid_o, // KDFa indicates the key/IV or error is available.

    // All the inputs used for the kdfa to build the messege the HMAC-SHA256 module uses: counter || "CFB" + 0x00 || context_u_i || context_v_i || length (384 bits)
    input wire [255:0] session_value_i, // Fixechd 32-byte secret sent separately to HMAC. I need to figure out where I actually get this value from. Execution engine?
    input wire [31:0] label_i, // Must be 32'h43464200: C, F, B, zero byte.
    input wire [255:0] context_u_i, // Fixed 32-byte newer nonce, first byte at MSB.
    input wire [255:0] context_v_i, // Fixed 32-byte older nonce, first byte at MSB.
    output reg [255:0] aes_key_o, // First digest, usable when rsp_valid_o && !error_o.
    output reg [127:0] aes_iv_o, // First 16 bytes of the second digest.

    // Control signals the HMAC-SHA256 should communicate with the kdfa controller
    input wire hmac_req_ready_i, // HMAC can accept the pair (session_value_i and fully built messege)
    input wire [255:0] hmac_digest_i, // One returned 32-byte result the symmetric module will be using to build its 256 bit AES key and IV
    input wire hmac_rsp_valid_i, // HMAC has a result ready.
    input wire hmac_error_i, // HMAC says the calculation failed.
    output wire hmac_req_valid_o, // A key/message pair is ready for HMAC.
    output reg [255:0] hmac_key_o, // Captured session value; unchanged for both requests.
    output reg [607:0] hmac_message_o, // 76 bytes: counter, label, two nonces, bit count.
    output wire hmac_rsp_ready_o // This controller can accept that result.


);
    // Four states: accept a request from the symmetric module, send a message, wait for its digest, return results.
    localparam IDLE=2'd0, SEND=2'd1, WAIT_DIGEST=2'd2, DONE=2'd3;
    reg [1:0] state_r; // Remembers which step we are performing.

    // Each valid stays high until its receiver accepts it. Ready is not "finished".
    assign req_ready_o = reset_n_i && (state_r == IDLE); // Symmetric module is ready in the IDLE state and inactive reset_n_i signal
    assign rsp_valid_o = reset_n_i && (state_r == DONE); // Symmetric module indicates its comepletion in the DONE state
    assign hmac_req_valid_o = reset_n_i && (state_r == SEND); // Once the message is complete on the symmetric module's side, then it is ready to be sent to the HMAC-SHA256 module
    assign hmac_rsp_ready_o = reset_n_i && (state_r == WAIT_DIGEST); //Waiting for the HMAC-SHA256 to be comeplete with its calculation

    always @(posedge clk_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            state_r <= IDLE; // Use non-blocking assignments I believe is the correct way? 
            hmac_key_o <= 0;
            hmac_message_o <= 0;
            aes_key_o <= 0;
            aes_iv_o <= 0;
            error_o <= 0;
        end else begin
            case (state_r)
                IDLE: if (req_valid_i && req_ready_o) begin
                    // Capture the job by building/storing the entire first message.
                    // Braces concatenate fields; no hashing is done in this block.
                    aes_key_o <= 0;
                    aes_iv_o <= 0;
                    error_o <= 0;
                    case (label_i)
                        32'h43464200: begin // The hexadecimal represents the "CFB" operation within the symmetric module. 
                        //Now this can be changed to "ATH" as I believe when the Hashing module needs to complete a seperate kdfa controller
                        // for the calculation of the session hash. This Verilog can be used as a template for that.
                            hmac_key_o <= session_value_i;
                            hmac_message_o <= {32'd1, label_i, context_u_i,
                                               context_v_i, 32'd384}; //Concatenation to build the message for the HMAC-SHA256 calcalculation
                            state_r <= SEND;
                        end
                        default: begin
                            error_o <= 1;
                            state_r <= DONE;
                        end
                    endcase
                end

                SEND: if (hmac_req_ready_i) begin
                    // Both request signals are high at this edge: HMAC accepted it.
                    state_r <= WAIT_DIGEST;
                end

                WAIT_DIGEST: if (hmac_rsp_valid_i) begin
                    if (hmac_error_i) begin
                        // Discard even a previously received first digest on failure.
                        aes_key_o <= 0;
                        aes_iv_o <= 0;
                        error_o <= 1;
                        state_r <= DONE;
                    end else if (hmac_message_o[607:576] == 32'd1) begin
                        // The counter is stored in the first 32 message bits.
                        // Save digest 1 as the AES key; send message 2 next.
                        aes_key_o <= hmac_digest_i;
                        hmac_message_o[607:576] <= 32'd2;
                        state_r <= SEND;
                    end else begin
                        // Counter can only be 2 here. Keep the first 128 digest bits.
                        // Total kept: 256 + 128 = 384 bits. No third message is sent.
                        aes_iv_o <= hmac_digest_i[255:128];
                        state_r <= DONE;
                    end
                end

                DONE: if (rsp_ready_i) begin
                    // Hold the result until accepted, then clear this job's values.
                    hmac_key_o <= 0;
                    hmac_message_o <= 0;
                    aes_key_o <= 0;
                    aes_iv_o <= 0;
                    error_o <= 0;
                    state_r <= IDLE;
                end

                default: begin
                    aes_key_o <= 0;
                    aes_iv_o <= 0;
                    error_o <= 1;
                    state_r <= DONE;
                end
            endcase
        end
    end
endmodule
`default_nettype wire
