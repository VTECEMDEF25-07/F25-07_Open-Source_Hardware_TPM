// Filename: symmetric_top.v
// Author: Makeda Solomon; refactor assisted by Codex
// Date: October 13, 2026
// Session parameters use external HMAC-SHA256. Primitive EncryptDecrypt2
// and session jobs share a byte-buffer interface and one AES-CFB worker.
`default_nettype none
module symm_top #(
    parameter MAX_SYM_DATA_BYTES = 1024,
    parameter RAM_ADDR_WIDTH = 12,
    parameter MAX_SECRET_BYTES = 128,
    parameter MAX_NONCE_BYTES = 64
)(
    input wire clock_i, reset_n_i, start_i, // Present a job while busy_o is low.

    // Command context from the execution engine.
    input wire [15:0] command_code_i, // Decoded TPM command for the primitive path.
    input wire key_valid_i, session_protect_i, session_valid_i,
    input wire session_decrypt_i, session_encrypt_i, session_use_xor_i,
    input wire [2:0] mode_i, // Cipher mode selected by the caller.

    // Session CFB/XOR inputs from the caller.
    // These are supplied values: this module does not create sessions or nonces.
    input wire [MAX_SECRET_BYTES*8-1:0] session_value_i,
    input wire [15:0] session_value_bytes_i,
    input wire [MAX_NONCE_BYTES*8-1:0] nonce_newer_i, nonce_older_i,
    input wire [15:0] nonce_newer_bytes_i, nonce_older_bytes_i,

    // External HMAC service used by KDFa for session protection.
    output wire hmac_start_o,
    output wire [7:0] hmac_key_data_o, hmac_message_data_o,
    output wire hmac_key_valid_o, hmac_key_end_o,
    input wire hmac_key_ready_i,
    output wire hmac_message_valid_o, hmac_message_end_o,
    input wire hmac_message_ready_i, hmac_busy_i,
    input wire [255:0] hmac_digest_i,
    input wire hmac_digest_valid_i,
    output wire hmac_digest_ready_o,

    // Input validity and cryptography context are supplied by the caller.
    input wire [255:0] key_i, // Resolved AES key for the primitive path.
    input wire [127:0] iv_i, // Starting IV for direct AES. XOR passes it through.
    input wire decrypt_i,

    // Byte addresses and length of the payload. Session jobs work in place.
    input wire [RAM_ADDR_WIDTH-1:0] input_base_i, output_base_i,
    input wire [31:0] data_length_i,

    // Outputs back to the execution engine. Result bytes remain in the buffer.
    output wire busy_o, done_o, error_o,
    output wire [11:0] tpm_rc_o,
    output wire [127:0] final_iv_o,
    output wire [31:0] completed_length_o,

    // Shared byte-buffer interface for the selected controller.
    output wire ram_req_valid_o,
    input wire ram_req_ready_i,
    output wire ram_req_write_o,
    output wire [RAM_ADDR_WIDTH-1:0] ram_req_addr_o,
    output wire [7:0] ram_req_data_o,
    input wire ram_rsp_valid_i,
    output wire ram_rsp_ready_o,
    input wire [7:0] ram_rsp_data_i,
    input wire ram_rsp_error_i
);
    // Wrapper states: accept a job, wait for its controller, then release.
    localparam IDLE=0, RUN=1, REJECT=2, RELEASE=3;
    reg [1:0] state_r;
    reg session_r, rejected_r;
    reg [31:0] session_length_r;
    reg session_completed_r;
    wire accept_w = reset_n_i && state_r == IDLE && start_i;
    wire invalid_session_w = data_length_i > MAX_SYM_DATA_BYTES ||
        data_length_i > 32'd65535 || input_base_i != output_base_i;
    // s_* signals belong to session protection; p_* belong to EncryptDecrypt2.
    wire p_busy, p_done, p_error, s_busy, s_done, cfb_busy;
    wire [11:0] p_rc, s_rc, cfb_rc_w;
    wire [127:0] p_final_iv, s_final_iv, cfb_result_w, cfb_final_iv_w;
    wire [31:0] p_length;
    wire p_cfb_start, s_cfb_start, p_decrypt, s_decrypt, cfb_done_w;
    wire [255:0] p_key, s_key;
    wire [127:0] p_iv, s_iv, p_data, s_data;
    wire [4:0] p_bytes, s_bytes;
    wire p_req_valid, s_req_valid, p_req_write, s_req_write, p_rsp_ready, s_rsp_ready;
    wire [RAM_ADDR_WIDTH-1:0] p_addr, s_addr;
    wire [7:0] p_write, s_write;

    // Return only the selected controller's result to the caller.
    assign busy_o = reset_n_i && state_r != IDLE;
    assign done_o = reset_n_i && (state_r == REJECT ||
        (state_r == RUN && (session_r ? s_done : p_done)));
    assign tpm_rc_o = rejected_r ? 12'h095 : (session_r ? s_rc : p_rc);
    assign error_o = rejected_r || (session_r ? s_rc != 0 : p_error);
    assign final_iv_o = rejected_r ? 128'd0 : (session_r ? s_final_iv : p_final_iv);
    assign completed_length_o = rejected_r ? 32'd0 : (session_r ?
        ((session_completed_r || (s_done && s_rc == 0)) ? session_length_r : 32'd0) : p_length);
    assign ram_req_valid_o = session_r ? s_req_valid : p_req_valid;
    assign ram_req_write_o = session_r ? s_req_write : p_req_write;
    assign ram_req_addr_o = session_r ? s_addr : p_addr;
    assign ram_req_data_o = session_r ? s_write : p_write;
    assign ram_rsp_ready_o = session_r ? s_rsp_ready : p_rsp_ready;
    wire cfb_start_w = session_r ? s_cfb_start : p_cfb_start;

    // Remember the selected path even if caller inputs change after acceptance.
    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            state_r <= IDLE;
            session_r <= 0;
            rejected_r <= 0;
            session_length_r <= 0;
            session_completed_r <= 0;
        end else case (state_r)
            IDLE: if (accept_w) begin
                session_r <= session_protect_i;
                rejected_r <= session_protect_i && invalid_session_w;
                session_length_r <= data_length_i;
                session_completed_r <= 0;
                state_r <= session_protect_i && invalid_session_w ? REJECT : RUN;
            end
            RUN: if (session_r ? s_done : p_done) begin
                session_completed_r <= session_r && s_rc == 0;
                state_r <= RELEASE;
            end
            REJECT: state_r <= RELEASE;
            RELEASE: if (!start_i && !p_busy && !s_busy && !cfb_busy) state_r <= IDLE;
            default: state_r <= IDLE;
        endcase
    end

    // Command path: use the AES object key and IV supplied by upstream logic.
    primitive_controller #(
        .MAX_SYM_DATA_BYTES(MAX_SYM_DATA_BYTES), .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH)
    ) CONTROLLER (
        .clock_i(clock_i), .reset_n_i(reset_n_i), .start_i(accept_w && !session_protect_i),
        .command_code_i(command_code_i), .key_valid_i(key_valid_i), .mode_i(mode_i),
        .key_i(key_i), .iv_i(iv_i), .decrypt_i(decrypt_i),
        .input_base_i(input_base_i), .output_base_i(output_base_i), .data_length_i(data_length_i),
        .busy_o(p_busy), .done_o(p_done), .error_o(p_error), .tpm_rc_o(p_rc),
        .final_iv_o(p_final_iv), .completed_length_o(p_length),
        .ram_req_valid_o(p_req_valid), .ram_req_ready_i(!session_r && ram_req_ready_i),
        .ram_req_write_o(p_req_write), .ram_req_addr_o(p_addr), .ram_req_data_o(p_write),
        .ram_rsp_valid_i(!session_r && ram_rsp_valid_i), .ram_rsp_ready_o(p_rsp_ready),
        .ram_rsp_data_i(ram_rsp_data_i), .ram_rsp_error_i(ram_rsp_error_i),
        .cfb_start_o(p_cfb_start), .cfb_key_o(p_key), .cfb_iv_o(p_iv),
        .cfb_data_o(p_data), .cfb_bytes_o(p_bytes), .cfb_decrypt_o(p_decrypt),
        .cfb_done_i(!session_r && cfb_done_w), .cfb_rc_i(cfb_rc_w),
        .cfb_data_i(cfb_result_w), .cfb_iv_i(cfb_final_iv_w)
    );
    // Session path: derive CFB key/IV or XOR mask using KDFa and HMAC.
    session_parameter_controller #(
        .MAX_DATA_BYTES(MAX_SYM_DATA_BYTES), .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
        .MAX_SECRET_BYTES(MAX_SECRET_BYTES), .MAX_NONCE_BYTES(MAX_NONCE_BYTES)
    ) SESSION_CONTROLLER (
        .clock_i(clock_i), .reset_n_i(reset_n_i),
        .start_i(accept_w && session_protect_i && !invalid_session_w),
        .session_valid_i(session_valid_i), .key_valid_i(key_valid_i),
        .session_decrypt_i(session_decrypt_i), .session_encrypt_i(session_encrypt_i),
        .session_use_xor_i(session_use_xor_i), .mode_i(mode_i),
        .data_bytes_i(data_length_i[15:0]), .session_value_i(session_value_i),
        .session_value_bytes_i(session_value_bytes_i),
        .nonce_newer_i(nonce_newer_i), .nonce_older_i(nonce_older_i),
        .nonce_newer_bytes_i(nonce_newer_bytes_i), .nonce_older_bytes_i(nonce_older_bytes_i),
        .iv_i(iv_i), .parameter_base_i(input_base_i),
        .wait_o(s_busy), .done_o(s_done), .tpm_rc_o(s_rc), .iv_out_o(s_final_iv),
        .ram_req_valid_o(s_req_valid), .ram_req_ready_i(session_r && ram_req_ready_i),
        .ram_req_write_o(s_req_write), .ram_req_addr_o(s_addr), .ram_req_data_o(s_write),
        .ram_rsp_valid_i(session_r && ram_rsp_valid_i), .ram_rsp_ready_o(s_rsp_ready),
        .ram_rsp_data_i(ram_rsp_data_i), .ram_rsp_error_i(ram_rsp_error_i),
        .cfb_start_o(s_cfb_start), .cfb_key_o(s_key), .cfb_iv_o(s_iv),
        .cfb_data_o(s_data), .cfb_bytes_o(s_bytes), .cfb_decrypt_o(s_decrypt),
        .cfb_wait_i(cfb_busy), .cfb_done_i(session_r && cfb_done_w),
        .cfb_rc_i(cfb_rc_w), .cfb_data_i(cfb_result_w), .cfb_iv_i(cfb_final_iv_w),
        .hmac_start_o(hmac_start_o), .hmac_busy_i(hmac_busy_i),
        .hmac_key_data_o(hmac_key_data_o), .hmac_key_valid_o(hmac_key_valid_o),
        .hmac_key_end_o(hmac_key_end_o), .hmac_key_ready_i(hmac_key_ready_i),
        .hmac_message_data_o(hmac_message_data_o), .hmac_message_valid_o(hmac_message_valid_o),
        .hmac_message_end_o(hmac_message_end_o), .hmac_message_ready_i(hmac_message_ready_i),
        .hmac_digest_i(hmac_digest_i), .hmac_digest_valid_i(hmac_digest_valid_i),
        .hmac_digest_ready_o(hmac_digest_ready_o)
    );

    // Shared CFB worker: the remembered path selects its key, IV and data.
    cfb_block WORKER (
        .clock_i(clock_i), .reset_n_i(reset_n_i), .start_i(cfb_start_w),
        .key_i(session_r ? s_key : p_key), .iv_i(session_r ? s_iv : p_iv),
        .data_in_i(session_r ? s_data : p_data),
        .data_bytes_i(session_r ? s_bytes : p_bytes), .decrypt_i(session_r ? s_decrypt : p_decrypt),
        .wait_o(cfb_busy), .done_o(cfb_done_w), .tpm_rc_o(cfb_rc_w),
        .data_out_o(cfb_result_w), .iv_out_o(cfb_final_iv_w)
    );
endmodule
`default_nettype wire
