// Filename: symmetric_top.v
// Author: Makeda Solomon; refactor assisted by Codex
// Date: October 13, 2026
// Session parameters use external HMAC-SHA256 and configurable byte buffers.
// Primitive EncryptDecrypt2 jobs retain the existing single-block interface.
`default_nettype none
module symm_top #(
    parameter integer MAX_DATA_BYTES=1024,
    parameter integer MAX_SECRET_BYTES=128,
    parameter integer MAX_NONCE_BYTES=64
)
(
    input wire clock_i, // 50 MHz clock
    input wire reset_n_i,
    input wire start_i, // Caller requests a job; present inputs while wait_o is low.

    // Command context from execution engine
    input wire [15:0] command_code_i, // TPM command sent from the Execution Engine
    input wire session_protect_i, // Status signal that indicates whether to take the session - based path or the primitive path
    input wire session_decrypt_i, // Status signal to enable the module to decrypt incoming command parameters
    input wire session_encrypt_i, // Status signal to enable the module to encrypt incoming command parameters
    input wire session_use_xor_i, // Select XOR Obfuscation within session protection instead of block ciphers

    // Input validity and cryptography context
    input wire key_valid_i, // Caller confirms the primitive key OR session value is valid.
    input wire session_valid_i, // Status signal to indicate a valid session creation for session - based protection
    input wire [2:0] mode_i, // Cipher - block mode selected for the primitive path
    input wire decrypt_i, // Decrypt status signal 
    input wire [15:0] data_bytes_i, // Valid byte count
    input wire [255:0] key_i, // Supplied AES key for the primitive path.
    input wire [127:0] iv_i, // Primitive IV; also passed through unchanged on the XOR path.
    input wire [MAX_DATA_BYTES*8-1:0] data_in_i, // Valid bytes are left aligned.
    input wire [127:0] session_mask_i, // Legacy compatibility input; ignored. XOR mask is derived inside.

    // Session CFB/XOR inputs from the caller (eventually the execution engine).
    // These are supplied values: this module does not create sessions or nonces.
    input wire [MAX_SECRET_BYTES*8-1:0] session_value_i,
    input wire [15:0] session_value_bytes_i,
    input wire [MAX_NONCE_BYTES*8-1:0] nonce_newer_i, nonce_older_i,
    input wire [15:0] nonce_newer_bytes_i, nonce_older_bytes_i,

    output wire hmac_start_o,
    output wire [7:0] hmac_key_data_o, hmac_message_data_o,
    output wire hmac_key_valid_o, hmac_key_end_o,
    input wire hmac_key_ready_i,
    output wire hmac_message_valid_o, hmac_message_end_o,
    input wire hmac_message_ready_i, hmac_busy_i,
    input wire [255:0] hmac_digest_i,
    input wire hmac_digest_valid_i,
    output wire hmac_digest_ready_o,

    // Outputs back to execution engine
    output wire wait_o, // Signal indicating the AES cipher is still computing cipher
    output wire done_o, // Signal indicating the completion of the symmetric module execution
    output wire [11:0] tpm_rc_o, // Error handling output
    output wire [MAX_DATA_BYTES*8-1:0] data_out_o,
    output wire [127:0] iv_out_o, // Final initialization vector
    output wire primitive_path_o, // Last accepted job selected EncryptDecrypt2.
    output wire session_path_o // Last accepted job selected session protection.
);

    // session_mask_i retained for old callers; XOR masks are now derived internally.

    // Wrapper states: accept a job, wait for its controller, then release.
    localparam IDLE = 0, WAIT_JOB = 1, RELEASE = 2;
    reg [1:0] state_r;
    reg selected_session_r;
    wire accept_w = reset_n_i && state_r == IDLE && start_i;

    // s_* signals belong to session protection; p_* belong to EncryptDecrypt2. These are the two encryption/decryption paths
    wire s_start, p_start, s_wait, p_wait, s_done, p_done;
    wire [255:0] s_key, p_key;
    wire [127:0] s_iv, p_iv, s_data, p_data, p_result, s_iv_result, p_iv_result;
    localparam SESSION_ADDR_WIDTH = $clog2(MAX_DATA_BYTES);
    reg [MAX_DATA_BYTES*8-1:0] session_buffer_r;
    reg session_result_valid_r, session_rsp_valid_r;
    reg [7:0] session_rsp_data_r;
    wire session_req_valid, session_req_write, session_rsp_ready;
    wire [SESSION_ADDR_WIDTH-1:0] session_req_addr;
    wire [7:0] session_req_data;
    integer session_byte;
    wire [11:0] s_rc, p_rc, cfb_rc;
    wire [MAX_DATA_BYTES*8-1:0] s_result =
        (session_result_valid_r || (s_done && s_rc == 0)) ? session_buffer_r : {MAX_DATA_BYTES*8{1'b0}};
    wire [4:0] s_bytes, p_bytes;
    wire s_decrypt, p_decrypt;
    wire cfb_done, cfb_wait;
    wire [127:0] cfb_result, cfb_iv_result;

    // Return only the selected controller's result to the caller.
    assign wait_o = reset_n_i && state_r != IDLE;
    assign done_o = reset_n_i && state_r == WAIT_JOB && (selected_session_r ? s_done : p_done);
    assign tpm_rc_o = selected_session_r ? s_rc : p_rc;
    assign data_out_o = selected_session_r ? s_result : {p_result,{(MAX_DATA_BYTES*8-128){1'b0}}};
    assign iv_out_o = selected_session_r ? s_iv_result : p_iv_result;
    assign session_path_o = selected_session_r;
    assign primitive_path_o = !selected_session_r;

    // Remember the selected path even if caller inputs change after acceptance.

    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            state_r <= IDLE;
            selected_session_r <= 0;
        end
        else case (state_r)
            IDLE: if (accept_w) begin
                selected_session_r <= session_protect_i;
                state_r <= WAIT_JOB;
            end
            WAIT_JOB: if (selected_session_r ? s_done : p_done) state_r <= RELEASE;
            RELEASE: if (!start_i && !s_wait && !p_wait && !cfb_wait) state_r <= IDLE;
            default: state_r <= IDLE;
        endcase
    end

    // Bridge the current packed top-level contract to the session byte port.
    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            session_buffer_r <= 0;
            session_result_valid_r <= 0;
            session_rsp_valid_r <= 0;
            session_rsp_data_r <= 0;
        end else if (accept_w && session_protect_i) begin
            session_result_valid_r <= 0;
            for (session_byte=0; session_byte<MAX_DATA_BYTES; session_byte=session_byte+1)
                session_buffer_r[(MAX_DATA_BYTES-session_byte)*8-1 -: 8] <=
                    session_byte < data_bytes_i ? data_in_i[(MAX_DATA_BYTES-session_byte)*8-1 -: 8] : 8'd0;
        end else begin
            if (s_done) begin
                session_result_valid_r <= s_rc == 0;
                if (s_rc != 0) session_buffer_r <= 0;
            end
            if (session_rsp_ready) session_rsp_valid_r <= 0;
            if (session_req_valid && !session_rsp_valid_r) begin
                session_rsp_valid_r <= 1;
                if (session_req_write)
                    session_buffer_r[(MAX_DATA_BYTES-session_req_addr)*8-1 -: 8] <= session_req_data;
                else
                    session_rsp_data_r <= session_buffer_r[(MAX_DATA_BYTES-session_req_addr)*8-1 -: 8];
            end
        end
    end

    // Session path: derive CFB key/IV or XOR mask using KDFa and HMAC.
    session_parameter_controller #(.MAX_DATA_BYTES(MAX_DATA_BYTES),
        .MAX_SECRET_BYTES(MAX_SECRET_BYTES), .MAX_NONCE_BYTES(MAX_NONCE_BYTES),
        .RAM_ADDR_WIDTH(SESSION_ADDR_WIDTH)) SESSION_CONTROLLER (
        .clock_i(clock_i),
        .reset_n_i(reset_n_i),
        .start_i(accept_w && session_protect_i),
        .session_valid_i(session_valid_i),
        .key_valid_i(key_valid_i),
        .session_decrypt_i(session_decrypt_i),
        .session_encrypt_i(session_encrypt_i),
        .session_use_xor_i(session_use_xor_i),
        .mode_i(mode_i),
        .data_bytes_i(data_bytes_i),
        .session_value_i(session_value_i),
        .session_value_bytes_i(session_value_bytes_i),
        .nonce_newer_i(nonce_newer_i),
        .nonce_newer_bytes_i(nonce_newer_bytes_i),
        .nonce_older_i(nonce_older_i),
        .nonce_older_bytes_i(nonce_older_bytes_i),
        .iv_i(iv_i),
        .cfb_start_o(s_start),
        .cfb_key_o(s_key),
        .cfb_iv_o(s_iv),
        .cfb_data_o(s_data),
        .cfb_bytes_o(s_bytes),
        .cfb_decrypt_o(s_decrypt),
        .cfb_done_i(cfb_done),
        .cfb_wait_i(cfb_wait),
        .cfb_rc_i(cfb_rc),
        .cfb_data_i(cfb_result),
        .cfb_iv_i(cfb_iv_result),
        .wait_o(s_wait),
        .done_o(s_done),
        .tpm_rc_o(s_rc),
        .parameter_base_i({SESSION_ADDR_WIDTH{1'b0}}),
        .ram_req_valid_o(session_req_valid), .ram_req_ready_i(!session_rsp_valid_r),
        .ram_req_write_o(session_req_write), .ram_req_addr_o(session_req_addr),
        .ram_req_data_o(session_req_data), .ram_rsp_valid_i(session_rsp_valid_r),
        .ram_rsp_ready_o(session_rsp_ready), .ram_rsp_data_i(session_rsp_data_r),
        .ram_rsp_error_i(1'b0),
        .iv_out_o(s_iv_result),
        .hmac_start_o(hmac_start_o), .hmac_busy_i(hmac_busy_i),
        .hmac_key_data_o(hmac_key_data_o), .hmac_key_valid_o(hmac_key_valid_o),
        .hmac_key_end_o(hmac_key_end_o), .hmac_key_ready_i(hmac_key_ready_i),
        .hmac_message_data_o(hmac_message_data_o), .hmac_message_valid_o(hmac_message_valid_o),
        .hmac_message_end_o(hmac_message_end_o), .hmac_message_ready_i(hmac_message_ready_i),
        .hmac_digest_i(hmac_digest_i), .hmac_digest_valid_i(hmac_digest_valid_i),
        .hmac_digest_ready_o(hmac_digest_ready_o)
    );

    // Command path: use the AES object key and IV supplied by upstream logic.
    encrypt_decrypt2_controller ENCRYPT_DECRYPT_CONTROLLER (
        .clock_i(clock_i),
        .reset_n_i(reset_n_i),
        .start_i(accept_w && !session_protect_i),
        .command_code_i(command_code_i),
        .key_valid_i(key_valid_i),
        .decrypt_i(decrypt_i),
        .mode_i(mode_i),
        .data_bytes_i(data_bytes_i),
        .key_i(key_i),
        .iv_i(iv_i),
        .data_in_i(data_in_i[MAX_DATA_BYTES*8-1 -: 128]),
        .cfb_start_o(p_start),
        .cfb_key_o(p_key),
        .cfb_iv_o(p_iv),
        .cfb_data_o(p_data),
        .cfb_bytes_o(p_bytes),
        .cfb_decrypt_o(p_decrypt),
        .cfb_done_i(cfb_done),
        .cfb_rc_i(cfb_rc),
        .cfb_data_i(cfb_result),
        .cfb_iv_i(cfb_iv_result),
        .wait_o(p_wait),
        .done_o(p_done),
        .tpm_rc_o(p_rc),
        .data_out_o(p_result),
        .iv_out_o(p_iv_result)
    );

    // Shared CFB worker: the remembered path selects its key, IV and data.
    cfb_block CFB_BLOCK (
        .clock_i(clock_i),
        .reset_n_i(reset_n_i),
        .start_i(s_start || p_start),
        .key_i(selected_session_r ? s_key : p_key),
        .iv_i(selected_session_r ? s_iv : p_iv),
        .data_in_i(selected_session_r ? s_data : p_data),
        .data_bytes_i(selected_session_r ? s_bytes : p_bytes),
        .decrypt_i(selected_session_r ? s_decrypt : p_decrypt),
        .wait_o(cfb_wait),
        .done_o(cfb_done),
        .tpm_rc_o(cfb_rc),
        .data_out_o(cfb_result),
        .iv_out_o(cfb_iv_result)
    );
endmodule

`default_nettype wire
