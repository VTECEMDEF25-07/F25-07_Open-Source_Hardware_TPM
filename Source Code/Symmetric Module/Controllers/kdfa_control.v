// Filename: kdfa_control.v
// Author: Makeda Solomon; refactor assisted by Codex
// Date: October 13, 2026
// Description: TPM KDFa with HMAC-SHA256. Byte buffers are left aligned, MSB first.
//              Lengths exclude unused bytes. Labels include their terminating zero.
`default_nettype none
module kdfa_control #(
    parameter integer MAX_SECRET_BYTES=128,
    parameter integer MAX_NONCE_BYTES=64,
    parameter integer MAX_OUTPUT_BYTES=1024
) (
    input wire clk_i, reset_n_i, req_valid_i, rsp_ready_i,
    output wire req_ready_o, rsp_valid_o,
    output reg error_o,
    input wire [MAX_SECRET_BYTES*8-1:0] session_value_i,
    input wire [15:0] session_value_bytes_i,
    input wire [MAX_NONCE_BYTES*8-1:0] context_u_i, context_v_i,
    input wire [15:0] context_u_bytes_i, context_v_bytes_i,
    input wire [31:0] label_i, xor_bits_i,
    output reg [255:0] aes_key_o,
    output reg [127:0] aes_iv_o,
    output reg [MAX_OUTPUT_BYTES*8-1:0] derived_o,
    output wire hmac_start_o,
    output wire [7:0] hmac_key_data_o, hmac_message_data_o,
    output wire hmac_key_valid_o, hmac_key_end_o,
    input wire hmac_key_ready_i,
    output wire hmac_message_valid_o, hmac_message_end_o,
    input wire hmac_message_ready_i, hmac_busy_i,
    input wire [255:0] hmac_digest_i,
    input wire hmac_digest_valid_i,
    output wire hmac_digest_ready_o
);
    localparam integer MESSAGE_BYTES=12+2*MAX_NONCE_BYTES;
    localparam IDLE=0, START_HMAC=1, SEND_KEY=2, SEND_MESSAGE=3, WAIT_DIGEST=4, DONE=5;
    reg [2:0] state_r;
    reg [MAX_SECRET_BYTES*8-1:0] hmac_key_r;
    reg [MESSAGE_BYTES*8-1:0] hmac_message_r;
    reg [15:0] hmac_key_bytes_r, hmac_message_bytes_r, byte_index_r;
    reg [31:0] counter_r, output_bytes_r, offset_r;
    reg use_xor_r;
    integer i;
    assign req_ready_o = reset_n_i && state_r == IDLE;
    assign rsp_valid_o = reset_n_i && state_r == DONE;
    // The caller reserves the HMAC port through digest consumption.
    // Reset KDFa and the HMAC service together to abort an in-flight request.
    assign hmac_start_o = reset_n_i && state_r == START_HMAC && !hmac_busy_i;
    assign hmac_key_valid_o = reset_n_i && state_r == SEND_KEY && hmac_key_bytes_r != 0;
    assign hmac_key_end_o = reset_n_i && state_r == SEND_KEY &&
                           (hmac_key_bytes_r == 0 || byte_index_r+1 == hmac_key_bytes_r);
    assign hmac_key_data_o = hmac_key_valid_o ?
        hmac_key_r[(MAX_SECRET_BYTES-byte_index_r)*8-1 -: 8] : 8'd0;
    assign hmac_message_valid_o = reset_n_i && state_r == SEND_MESSAGE;
    assign hmac_message_end_o = hmac_message_valid_o && byte_index_r+1 == hmac_message_bytes_r;
    assign hmac_message_data_o = hmac_message_valid_o ?
        hmac_message_r[(MESSAGE_BYTES-byte_index_r)*8-1 -: 8] : 8'd0;
    assign hmac_digest_ready_o = reset_n_i && state_r == WAIT_DIGEST;

    always @(posedge clk_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            state_r <= IDLE;
            error_o <= 0;
            hmac_key_r <= 0;
            hmac_key_bytes_r <= 0;
            hmac_message_r <= 0;
            hmac_message_bytes_r <= 0;
            aes_key_o <= 0;
            aes_iv_o <= 0;
            derived_o <= 0;
            counter_r <= 0;
            output_bytes_r <= 0;
            offset_r <= 0;
            byte_index_r <= 0;
            use_xor_r <= 0;
        end else case (state_r)
            IDLE: if (req_valid_i) begin
                error_o <= 0;
                aes_key_o <= 0;
                aes_iv_o <= 0;
                derived_o <= 0;
                hmac_key_r <= 0;
                hmac_message_r <= 0;
                counter_r <= 1;
                offset_r <= 0;
                use_xor_r <= label_i == 32'h584f5200;
                if (session_value_bytes_i > MAX_SECRET_BYTES ||
                    context_u_bytes_i > MAX_NONCE_BYTES || context_v_bytes_i > MAX_NONCE_BYTES ||
                    (label_i != 32'h43464200 && label_i != 32'h584f5200) ||
                    (label_i == 32'h584f5200 &&
                     (xor_bits_i == 0 || xor_bits_i > MAX_OUTPUT_BYTES*8 || xor_bits_i[2:0] != 0)) ||
                    (label_i == 32'h43464200 && MAX_OUTPUT_BYTES < 48)) begin
                    error_o <= 1;
                    state_r <= DONE;
                end else begin
                    hmac_key_r <= session_value_i;
                    hmac_key_bytes_r <= session_value_bytes_i;
                    hmac_message_bytes_r <= 12+context_u_bytes_i+context_v_bytes_i;
                    hmac_message_r[MESSAGE_BYTES*8-1 -: 64] <= {32'd1,label_i};
                    for (i=0; i<MAX_NONCE_BYTES; i=i+1) begin
                        if (i < context_u_bytes_i)
                            hmac_message_r[(MESSAGE_BYTES-8-i)*8-1 -: 8] <= context_u_i[(MAX_NONCE_BYTES-i)*8-1 -: 8];
                        if (i < context_v_bytes_i)
                            hmac_message_r[(MESSAGE_BYTES-8-context_u_bytes_i-i)*8-1 -: 8] <= context_v_i[(MAX_NONCE_BYTES-i)*8-1 -: 8];
                    end
                    hmac_message_r[(MESSAGE_BYTES-8-context_u_bytes_i-context_v_bytes_i)*8-1 -: 32]
                        <= label_i == 32'h584f5200 ? xor_bits_i : 32'd384;
                    output_bytes_r <= label_i == 32'h584f5200 ? xor_bits_i >> 3 : 32'd48;
                    state_r <= START_HMAC;
                end
            end
            START_HMAC: if (hmac_start_o) begin
                byte_index_r <= 0;
                state_r <= SEND_KEY;
            end
            SEND_KEY: if (hmac_key_ready_i) begin
                if (hmac_key_end_o) begin
                    byte_index_r <= 0;
                    state_r <= SEND_MESSAGE;
                end else byte_index_r <= byte_index_r+1'b1;
            end
            SEND_MESSAGE: if (hmac_message_ready_i) begin
                if (hmac_message_end_o) state_r <= WAIT_DIGEST;
                else byte_index_r <= byte_index_r+1'b1;
            end
            WAIT_DIGEST: if (hmac_digest_valid_i) begin
                for (i=0; i<32; i=i+1)
                    if (offset_r+i < output_bytes_r)
                        derived_o[(MAX_OUTPUT_BYTES-offset_r-i)*8-1 -: 8] <= hmac_digest_i[(32-i)*8-1 -: 8];
                if (counter_r == 1) aes_key_o <= hmac_digest_i;
                if (!use_xor_r && counter_r == 2) aes_iv_o <= hmac_digest_i[255:128];
                if (offset_r+32 >= output_bytes_r) state_r <= DONE;
                else begin
                    counter_r <= counter_r+1;
                    offset_r <= offset_r+32;
                    hmac_message_r[MESSAGE_BYTES*8-1 -: 32] <= counter_r+1;
                    state_r <= START_HMAC;
                end
            end
            DONE: if (rsp_ready_i) begin
                hmac_key_r <= 0;
                hmac_key_bytes_r <= 0;
                hmac_message_r <= 0;
                hmac_message_bytes_r <= 0;
                aes_key_o <= 0;
                aes_iv_o <= 0;
                derived_o <= 0;
                error_o <= 0;
                state_r <= IDLE;
            end
            default: begin
                error_o <= 1;
                derived_o <= 0;
                aes_key_o <= 0;
                aes_iv_o <= 0;
                state_r <= DONE;
            end
        endcase
    end
endmodule
`default_nettype wire
