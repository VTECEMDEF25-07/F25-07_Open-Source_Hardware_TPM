// One complete session parameter. AES-256/CFB128 or SHA-256 KDFa XOR.
// Derives once and chains CFB blocks over RAM-backed parameter bytes.
// The execution engine supplies validated session settings and ordered nonces.
`default_nettype none
module session_parameter_controller #(
    parameter integer MAX_DATA_BYTES=1024,
    parameter integer MAX_SECRET_BYTES=128,
    parameter integer MAX_NONCE_BYTES=64,
    parameter integer RAM_ADDR_WIDTH=12
) (
    input wire clock_i, reset_n_i, start_i,
    input wire session_valid_i, key_valid_i, session_decrypt_i, session_encrypt_i, session_use_xor_i,
    input wire [2:0] mode_i,
    input wire [15:0] data_bytes_i,
    input wire [MAX_SECRET_BYTES*8-1:0] session_value_i,
    input wire [15:0] session_value_bytes_i,
    input wire [MAX_NONCE_BYTES*8-1:0] nonce_newer_i, nonce_older_i,
    input wire [15:0] nonce_newer_bytes_i, nonce_older_bytes_i,
    input wire [127:0] iv_i,
    output wire cfb_start_o,
    output reg [255:0] cfb_key_o,
    output reg [127:0] cfb_iv_o, cfb_data_o,
    output reg [4:0] cfb_bytes_o,
    output reg cfb_decrypt_o,
    input wire cfb_wait_i, cfb_done_i,
    input wire [11:0] cfb_rc_i,
    input wire [127:0] cfb_data_i, cfb_iv_i,
    output wire wait_o,
    output reg done_o,
    output reg [11:0] tpm_rc_o,
    output reg [127:0] iv_out_o,

    // Connect by name to hash_subsystem's matching hmac_* ports.
    output wire hmac_start_o,
    output wire [7:0] hmac_key_data_o, hmac_message_data_o,
    output wire hmac_key_valid_o, hmac_key_end_o,
    input wire hmac_key_ready_i,
    output wire hmac_message_valid_o, hmac_message_end_o,
    input wire hmac_message_ready_i, hmac_busy_i,
    input wire [255:0] hmac_digest_i,
    input wire hmac_digest_valid_i,
    output wire hmac_digest_ready_o,

    // In RAM mode the caller reserves this range and discards it on failure.
    input wire [RAM_ADDR_WIDTH-1:0] parameter_base_i,
    output wire ram_req_valid_o, ram_req_write_o,
    input wire ram_req_ready_i,
    output wire [RAM_ADDR_WIDTH-1:0] ram_req_addr_o,
    output wire [7:0] ram_req_data_o,
    input wire ram_rsp_valid_i, ram_rsp_error_i,
    output wire ram_rsp_ready_o,
    input wire [7:0] ram_rsp_data_i
);
    localparam integer KDF_BYTES=(MAX_DATA_BYTES < 48) ? 48 : MAX_DATA_BYTES;
    localparam IDLE=0, DERIVE=1, WAIT_KDF=2, PREPARE=3, ISSUE=4, WAIT_CFB=5, DONE=6, RELEASE=7;
    localparam READ_REQ=8, READ_RSP=9, WRITE_REQ=10, WRITE_RSP=11;
    reg [3:0] state_r;
    reg [15:0] secret_bytes_r, newer_bytes_r, older_bytes_r, data_bytes_r, offset_r;
    reg [RAM_ADDR_WIDTH-1:0] parameter_base_r;
    reg [4:0] chunk_index_r;
    reg [127:0] chunk_result_r;
    reg [KDF_BYTES*8-1:0] xor_mask_r;
    wire [RAM_ADDR_WIDTH+16:0] parameter_end_w =
        {{17{1'b0}},parameter_base_i} + {{(RAM_ADDR_WIDTH+1){1'b0}},data_bytes_i};
    wire [RAM_ADDR_WIDTH+16:0] ram_limit_w =
        {{(RAM_ADDR_WIDTH+16){1'b0}},1'b1} << RAM_ADDR_WIDTH;
    wire [16:0] byte_offset_w = {1'b0,offset_r}+{12'd0,chunk_index_r};
    assign ram_req_valid_o = reset_n_i &&
        (state_r == READ_REQ || state_r == WRITE_REQ);
    assign ram_req_write_o = state_r == WRITE_REQ;
    assign ram_req_addr_o = parameter_base_r + byte_offset_w;
    assign ram_req_data_o = chunk_result_r[127-chunk_index_r*8 -: 8];
    assign ram_rsp_ready_o = reset_n_i &&
        (state_r == READ_RSP || state_r == WRITE_RSP);
    reg use_xor_r;
    reg [MAX_SECRET_BYTES*8-1:0] secret_r;
    reg [MAX_NONCE_BYTES*8-1:0] newer_r, older_r;
    wire kdfa_req_ready_w, kdfa_rsp_valid_w, kdfa_error_w;
    wire [255:0] kdfa_key_w;
    wire [127:0] kdfa_iv_w;
    wire [KDF_BYTES*8-1:0] derived_w;
    assign wait_o = reset_n_i && state_r != IDLE;
    assign cfb_start_o = reset_n_i && state_r == ISSUE;

    kdfa_control #(.MAX_SECRET_BYTES(MAX_SECRET_BYTES), .MAX_NONCE_BYTES(MAX_NONCE_BYTES),
                   .MAX_OUTPUT_BYTES(KDF_BYTES)) KDFA_CONTROLLER (
        .clk_i(clock_i), .reset_n_i(reset_n_i),
        .req_valid_i(state_r == DERIVE), .req_ready_o(kdfa_req_ready_w),
        .rsp_valid_o(kdfa_rsp_valid_w), .rsp_ready_i(state_r == WAIT_KDF), .error_o(kdfa_error_w),
        .session_value_i(secret_r), .session_value_bytes_i(secret_bytes_r),
        .context_u_i(newer_r), .context_u_bytes_i(newer_bytes_r),
        .context_v_i(older_r), .context_v_bytes_i(older_bytes_r),
        .label_i(use_xor_r ? 32'h584f5200 : 32'h43464200),
        .xor_bits_i({16'd0,data_bytes_r} << 3),
        .aes_key_o(kdfa_key_w), .aes_iv_o(kdfa_iv_w), .derived_o(derived_w),
        .hmac_start_o(hmac_start_o), .hmac_busy_i(hmac_busy_i),
        .hmac_key_data_o(hmac_key_data_o), .hmac_key_valid_o(hmac_key_valid_o),
        .hmac_key_end_o(hmac_key_end_o), .hmac_key_ready_i(hmac_key_ready_i),
        .hmac_message_data_o(hmac_message_data_o), .hmac_message_valid_o(hmac_message_valid_o),
        .hmac_message_end_o(hmac_message_end_o), .hmac_message_ready_i(hmac_message_ready_i),
        .hmac_digest_i(hmac_digest_i), .hmac_digest_valid_i(hmac_digest_valid_i),
        .hmac_digest_ready_o(hmac_digest_ready_o)
    );

    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            state_r <= IDLE;
            done_o <= 0;
            tpm_rc_o <= 0;
            iv_out_o <= 0;
            cfb_key_o <= 0;
            cfb_iv_o <= 0;
            cfb_data_o <= 0;
            cfb_bytes_o <= 0;
            cfb_decrypt_o <= 0;
            use_xor_r <= 0;
            secret_r <= 0;
            newer_r <= 0;
            older_r <= 0;
            secret_bytes_r <= 0;
            newer_bytes_r <= 0;
            older_bytes_r <= 0;
            data_bytes_r <= 0;
            offset_r <= 0;
            parameter_base_r <= 0;
            chunk_index_r <= 0;
            chunk_result_r <= 0;
            xor_mask_r <= 0;
        end else begin
            done_o <= 0;
            case (state_r)
                IDLE: if (start_i) begin
                    tpm_rc_o <= 0;
                    iv_out_o <= 0;
                    secret_r <= session_value_i;
                    secret_bytes_r <= session_value_bytes_i;
                    newer_r <= nonce_newer_i;
                    newer_bytes_r <= nonce_newer_bytes_i;
                    older_r <= nonce_older_i;
                    older_bytes_r <= nonce_older_bytes_i;
                    use_xor_r <= session_use_xor_i;
                    parameter_base_r <= parameter_base_i;
                    data_bytes_r <= data_bytes_i;
                    offset_r <= 0;
                    cfb_decrypt_o <= session_decrypt_i;
                    cfb_iv_o <= iv_i;
                    cfb_key_o <= 0;
                    if (!session_valid_i) begin
                        tpm_rc_o <= 12'h08b;
                        state_r <= DONE;
                    end else if (!(session_encrypt_i ^ session_decrypt_i)) begin
                        tpm_rc_o <= 12'h082;
                        state_r <= DONE;
                    end else if (data_bytes_i > MAX_DATA_BYTES || parameter_end_w > ram_limit_w ||
                                 session_value_bytes_i > MAX_SECRET_BYTES ||
                                 nonce_newer_bytes_i > MAX_NONCE_BYTES || nonce_older_bytes_i > MAX_NONCE_BYTES) begin
                        tpm_rc_o <= 12'h095;
                        state_r <= DONE;
                    end else if (!session_use_xor_i && mode_i != 1) begin
                        tpm_rc_o <= 12'h089;
                        state_r <= DONE;
                    end else if (!key_valid_i) begin
                        tpm_rc_o <= 12'h09c;
                        state_r <= DONE;
                    end else if (data_bytes_i == 0) begin
                        iv_out_o <= iv_i;
                        state_r <= DONE;
                    end else state_r <= DERIVE;
                end
                DERIVE: if (kdfa_req_ready_w) state_r <= WAIT_KDF;
                WAIT_KDF: if (kdfa_rsp_valid_w) begin
                    if (kdfa_error_w) begin
                        tpm_rc_o <= 12'h101;
                        state_r <= DONE;
                    end else begin
                        if (use_xor_r) xor_mask_r <= derived_w;
                        else begin
                            cfb_key_o <= kdfa_key_w;
                            cfb_iv_o <= kdfa_iv_w;
                        end
                        state_r <= PREPARE;
                    end
                end
                PREPARE: if (!cfb_wait_i) begin
                    cfb_data_o <= 128'd0;
                    chunk_index_r <= 0;
                    cfb_bytes_o <= data_bytes_r-offset_r > 16 ? 5'd16 : data_bytes_r-offset_r;
                    state_r <= READ_REQ;
                end
                READ_REQ: if (ram_req_ready_i) state_r <= READ_RSP;
                READ_RSP: if (ram_rsp_valid_i) begin
                    if (ram_rsp_error_i) begin
                        tpm_rc_o <= 12'h101;
                        state_r <= DONE;
                    end else begin
                        cfb_data_o[127-chunk_index_r*8 -: 8] <= ram_rsp_data_i;
                        if (use_xor_r)
                            chunk_result_r[127-chunk_index_r*8 -: 8] <=
                                ram_rsp_data_i ^ xor_mask_r[(KDF_BYTES-byte_offset_w)*8-1 -: 8];
                        if (chunk_index_r+1 == cfb_bytes_o) begin
                            chunk_index_r <= 0;
                            state_r <= use_xor_r ? WRITE_REQ : ISSUE;
                        end else begin
                            chunk_index_r <= chunk_index_r+1'b1;
                            state_r <= READ_REQ;
                        end
                    end
                end
                ISSUE: state_r <= WAIT_CFB;
                WAIT_CFB: if (cfb_done_i) begin
                    if (cfb_rc_i != 0) begin
                        tpm_rc_o <= cfb_rc_i;
                        iv_out_o <= 0;
                        state_r <= DONE;
                    end else begin
                        chunk_result_r <= cfb_data_i;
                        cfb_iv_o <= cfb_iv_i;
                        state_r <= WRITE_REQ;
                    end
                end
                WRITE_REQ: if (ram_req_ready_i) state_r <= WRITE_RSP;
                WRITE_RSP: if (ram_rsp_valid_i) begin
                    if (ram_rsp_error_i) begin
                        tpm_rc_o <= 12'h101;
                        state_r <= DONE;
                    end else if (chunk_index_r+1 != cfb_bytes_o) begin
                        chunk_index_r <= chunk_index_r+1'b1;
                        state_r <= WRITE_REQ;
                    end else if (offset_r+cfb_bytes_o == data_bytes_r) begin
                        iv_out_o <= cfb_iv_o;
                        state_r <= DONE;
                    end else begin
                        offset_r <= offset_r+cfb_bytes_o;
                        state_r <= PREPARE;
                    end
                end
                DONE: begin
                    done_o <= 1;
                    secret_r <= 0;
                    newer_r <= 0;
                    older_r <= 0;
                    chunk_result_r <= 0;
                    xor_mask_r <= 0;
                    cfb_key_o <= 0;
                    cfb_data_o <= 0;
                    cfb_iv_o <= 0;
                    state_r <= RELEASE;
                end
                RELEASE: if (!start_i) state_r <= IDLE;
                default: begin
                    tpm_rc_o <= 12'h101;
                    iv_out_o <= 0;
                    state_r <= DONE;
                end
            endcase
        end
    end
endmodule
`default_nettype wire
