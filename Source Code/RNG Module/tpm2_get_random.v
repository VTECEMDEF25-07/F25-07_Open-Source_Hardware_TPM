// ===========================================================================
// tpm2_get_random.v
//
// TPM2_GetRandom command (TCG TPM 2.0 Library Spec, Part 3, "GetRandom").
//
// Receives one TPM command frame as a byte stream, checks it, and sends back
// the TPM response frame as a byte stream. All multi-byte fields are
// big-endian, as the spec requires.
//
// Command frame (12 bytes):
//   offset  size  field
//   0       2     tag             TPM_ST_NO_SESSIONS  (0x8001)
//   2       4     commandSize     12                  (0x0000000C)
//   6       4     commandCode     TPM_CC_GetRandom    (0x0000017B)
//   10      2     bytesRequested  UINT16
//
// Success response (12 + n bytes):
//   0       2     tag             TPM_ST_NO_SESSIONS  (0x8001)
//   2       4     responseSize    12 + n
//   6       4     responseCode    TPM_RC_SUCCESS      (0x00000000)
//   10      2     randomBytes.size  n
//   12      n     randomBytes.buffer
//
// n = min(bytesRequested, MAX_DIGEST_BYTES). The spec says a request larger
// than the largest supported digest is not an error: the TPM just returns
// that many bytes. With SHA-256 only, that is 32 bytes = one 256-bit block.
//
// Error response (10 bytes): tag, responseSize = 10, responseCode.
// Checks, in the same order as the TCG reference implementation:
//   fewer than 10 bytes received       -> TPM_RC_INSUFFICIENT      (0x09A)
//   tag is not TPM_ST_NO_SESSIONS      -> TPM_RC_BAD_TAG           (0x01E)
//   commandSize != bytes received      -> TPM_RC_COMMAND_SIZE      (0x142)
//   commandCode != TPM_CC_GetRandom    -> TPM_RC_COMMAND_CODE      (0x143)
//   tpm_initialized is low             -> TPM_RC_INITIALIZE        (0x100)
//   bytesRequested missing (size < 12) -> TPM_RC_INSUFFICIENT,
//                                         parameter 1              (0x1DA)
//   extra bytes after bytesRequested   -> TPM_RC_SIZE              (0x095)
//   rng_fault high (failed health test)-> TPM_RC_FAILURE           (0x101)
//
// Not supported here: TPM_ST_SESSIONS. The spec allows an audit or
// parameter-encryption session on GetRandom; this module has no session
// logic, so it rejects that tag with TPM_RC_BAD_TAG.
//
// Freshness: every 256-bit block from the DRBG is used for at most one
// response. Bytes not requested are discarded, never handed to a later
// command, and the response buffer is cleared once the response is sent.
//
// Byte-stream handshake (same idea as AXI-Stream): a byte moves on a rising
// clock edge when both valid and ready are 1. cmd_last marks the final byte
// of the command, the way the TIS "tpmGo" bit tells a TPM to execute.
//
// Written by Jungyeon Won with the help of generative AI
// ===========================================================================
 
`timescale 1ns/1ps
 
module tpm2_get_random #(
    parameter integer MAX_DIGEST_BYTES = 32   // sizeof(TPMU_HA): SHA-256 only
) (
    input  wire         clk,
    input  wire         rst_n,
 
    // Command bytes in (from the host transport)
    input  wire  [7:0]  cmd_data,
    input  wire         cmd_valid,
    input  wire         cmd_last,        // high with the last command byte
    output wire         cmd_ready,       // 1 = ready to accept a command byte
 
    // Response bytes out (to the host transport)
    output reg   [7:0]  rsp_data,
    output wire         rsp_valid,
    output wire         rsp_last,        // high with the last response byte
    input  wire         rsp_ready,
 
    // From the DRBG (random_number_generation)
    input  wire [255:0] rng_data,
    input  wire         rng_valid,       // 1-cycle pulse per new block
 
    // Status
    input  wire         tpm_initialized, // tie 1 until TPM2_Startup exists
    input  wire         rng_fault        // tie 0 until health tests exist
);
 
    // -----------------------------------------------------------------------
    // TPM constants (TCG TPM 2.0 Part 2)
    // -----------------------------------------------------------------------
    localparam [15:0] TPM_ST_NO_SESSIONS  = 16'h8001;
    localparam [31:0] TPM_CC_GETRANDOM    = 32'h0000_017B;
 
    localparam [31:0] TPM_RC_SUCCESS      = 32'h0000_0000;
    localparam [31:0] TPM_RC_BAD_TAG      = 32'h0000_001E;
    localparam [31:0] TPM_RC_INITIALIZE   = 32'h0000_0100;
    localparam [31:0] TPM_RC_FAILURE      = 32'h0000_0101;
    localparam [31:0] TPM_RC_SIZE         = 32'h0000_0095;
    localparam [31:0] TPM_RC_INSUFFICIENT = 32'h0000_009A;
    localparam [31:0] TPM_RC_COMMAND_SIZE = 32'h0000_0142;
    localparam [31:0] TPM_RC_COMMAND_CODE = 32'h0000_0143;
    // Parameter errors add TPM_RC_P (0x040) + parameter number << 8.
    localparam [31:0] TPM_RC_INSUFFICIENT_P1 = TPM_RC_INSUFFICIENT + 32'h040 + 32'h100;
 
    localparam [15:0] HEADER_BYTES  = 16'd10;
    localparam [15:0] COMMAND_BYTES = 16'd12;
 
    // -----------------------------------------------------------------------
    // FSM states
    // -----------------------------------------------------------------------
    localparam [2:0] S_RECV     = 3'd0;  // collect command bytes
    localparam [2:0] S_CHECK    = 3'd1;  // parse header, pick response code
    localparam [2:0] S_WAIT_RNG = 3'd2;  // wait for an unused random block
    localparam [2:0] S_SEND     = 3'd3;  // stream the response out
 
    reg [2:0] state;
 
    // -----------------------------------------------------------------------
    // Received command. Only the first 12 bytes matter; any extra bytes are
    // counted (to report TPM_RC_SIZE / COMMAND_SIZE) but not stored.
    // -----------------------------------------------------------------------
    reg [7:0]  cmd_buf [0:11];
    reg [31:0] rx_count;                  // bytes received, saturates
 
    wire [15:0] rx_tag       = {cmd_buf[0], cmd_buf[1]};
    wire [31:0] rx_size      = {cmd_buf[2], cmd_buf[3], cmd_buf[4], cmd_buf[5]};
    wire [31:0] rx_code      = {cmd_buf[6], cmd_buf[7], cmd_buf[8], cmd_buf[9]};
    wire [15:0] rx_requested = {cmd_buf[10], cmd_buf[11]};
 
    // -----------------------------------------------------------------------
    // Holding register for one DRBG block. rng_fresh = 1 means the block
    // has never been used. A new block overwrites an unused one, so the
    // response always gets the newest output.
    // -----------------------------------------------------------------------
    reg [255:0] rng_hold;
    reg         rng_fresh;
 
    // -----------------------------------------------------------------------
    // Response being sent
    // -----------------------------------------------------------------------
    reg [31:0]  rsp_code;
    reg [5:0]   rsp_n;          // random bytes in this response (0..32)
    reg [255:0] rsp_random;     // bytes leave from the top: byte 0 = [255:248]
    reg [15:0]  rsp_len;        // total response bytes
    reg [15:0]  tx_index;       // index of the byte now on rsp_data
 
    wire [31:0] rsp_size = {16'b0, rsp_len};
 
    // Response code chosen from the received command (combinational).
    reg [31:0] check_rc;
    always @(*) begin
        if (rx_count < HEADER_BYTES)            check_rc = TPM_RC_INSUFFICIENT;
        else if (rx_tag != TPM_ST_NO_SESSIONS)  check_rc = TPM_RC_BAD_TAG;
        else if (rx_size != rx_count)           check_rc = TPM_RC_COMMAND_SIZE;
        else if (rx_code != TPM_CC_GETRANDOM)   check_rc = TPM_RC_COMMAND_CODE;
        else if (!tpm_initialized)              check_rc = TPM_RC_INITIALIZE;
        else if (rx_count < COMMAND_BYTES)      check_rc = TPM_RC_INSUFFICIENT_P1;
        else if (rx_count > COMMAND_BYTES)      check_rc = TPM_RC_SIZE;
        else                                    check_rc = TPM_RC_SUCCESS;
    end
 
    // n = min(bytesRequested, MAX_DIGEST_BYTES)
    localparam [5:0] MAX_N = MAX_DIGEST_BYTES;
    wire [5:0] clamped_n = (rx_requested > MAX_DIGEST_BYTES)
                         ? MAX_N : rx_requested[5:0];
 
    // -----------------------------------------------------------------------
    // Handshake outputs
    // -----------------------------------------------------------------------
    assign cmd_ready = (state == S_RECV);
    assign rsp_valid = (state == S_SEND);
    assign rsp_last  = (state == S_SEND) && (tx_index == rsp_len - 16'd1);
 
    wire cmd_fire = cmd_valid && cmd_ready;
    wire rsp_fire = rsp_valid && rsp_ready;
 
    // -----------------------------------------------------------------------
    // Response byte at tx_index (combinational).
    // -----------------------------------------------------------------------
    always @(*) begin
        case (tx_index)
            16'd0:   rsp_data = TPM_ST_NO_SESSIONS[15:8];
            16'd1:   rsp_data = TPM_ST_NO_SESSIONS[7:0];
            16'd2:   rsp_data = rsp_size[31:24];
            16'd3:   rsp_data = rsp_size[23:16];
            16'd4:   rsp_data = rsp_size[15:8];
            16'd5:   rsp_data = rsp_size[7:0];
            16'd6:   rsp_data = rsp_code[31:24];
            16'd7:   rsp_data = rsp_code[23:16];
            16'd8:   rsp_data = rsp_code[15:8];
            16'd9:   rsp_data = rsp_code[7:0];
            16'd10:  rsp_data = 8'h00;              // randomBytes.size, high
            16'd11:  rsp_data = {2'b00, rsp_n};     // randomBytes.size, low
            default: rsp_data = rsp_random[255:248]; // random payload
        endcase
    end
 
    // -----------------------------------------------------------------------
    // Main sequential logic
    // -----------------------------------------------------------------------
    integer k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= S_RECV;
            rx_count   <= 32'd0;
            rng_hold   <= 256'b0;
            rng_fresh  <= 1'b0;
            rsp_code   <= 32'd0;
            rsp_n      <= 6'd0;
            rsp_random <= 256'b0;
            rsp_len    <= 16'd0;
            tx_index   <= 16'd0;
            for (k = 0; k < 12; k = k + 1) cmd_buf[k] <= 8'h00;
        end else begin
            // Capture each new DRBG block. Done first so the S_WAIT_RNG
            // branch below can clear rng_fresh in the same cycle it uses it.
            if (rng_valid) begin
                rng_hold  <= rng_data;
                rng_fresh <= 1'b1;
            end
 
            case (state)
                // -----------------------------------------------------------
                S_RECV: begin
                    if (cmd_fire) begin
                        if (rx_count < 32'd12)
                            cmd_buf[rx_count[3:0]] <= cmd_data;
                        if (rx_count != 32'hFFFF_FFFF)
                            rx_count <= rx_count + 32'd1;
                        if (cmd_last)
                            state <= S_CHECK;
                    end
                end
 
                // -----------------------------------------------------------
                // rx_count now holds the full frame length.
                S_CHECK: begin
                    rsp_code <= check_rc;
                    tx_index <= 16'd0;
                    if (check_rc == TPM_RC_SUCCESS) begin
                        rsp_n   <= clamped_n;
                        rsp_len <= 16'd12 + {10'b0, clamped_n};
                        state   <= S_WAIT_RNG;
                    end else begin
                        rsp_n   <= 6'd0;
                        rsp_len <= HEADER_BYTES;
                        state   <= S_SEND;
                    end
                end
 
                // -----------------------------------------------------------
                S_WAIT_RNG: begin
                    if (rng_fault) begin
                        rsp_code <= TPM_RC_FAILURE;
                        rsp_n    <= 6'd0;
                        rsp_len  <= HEADER_BYTES;
                        state    <= S_SEND;
                    end else if (rng_fresh) begin
                        rsp_random <= rng_hold;
                        rng_hold   <= 256'b0;    // used once, then erased
                        rng_fresh  <= 1'b0;
                        state      <= S_SEND;
                    end
                end
 
                // -----------------------------------------------------------
                S_SEND: begin
                    if (rsp_fire) begin
                        if (rsp_last) begin
                            // Done: erase everything from this command.
                            rsp_random <= 256'b0;
                            rx_count   <= 32'd0;
                            tx_index   <= 16'd0;
                            for (k = 0; k < 12; k = k + 1) cmd_buf[k] <= 8'h00;
                            state      <= S_RECV;
                        end else begin
                            tx_index <= tx_index + 16'd1;
                            // Once into the payload, shift the next random
                            // byte up to the top.
                            if (tx_index >= 16'd12)
                                rsp_random <= {rsp_random[247:0], 8'h00};
                        end
                    end
                end
 
                default: state <= S_RECV;
            endcase
        end
    end
 
endmodule