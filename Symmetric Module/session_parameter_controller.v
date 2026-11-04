// Filename: session_parameter_controller.v
// Author: Makeda Solomon; refactor assisted by Codex
// Date: October 13, 2026
// Description: One session parameter chunk: KDFa CFB key/IV OR KDFa XOR mask. Fixed 32-byte secret/nonces; fake HMAC is practice only. Upstream supplies validated session and ordered nonces.
`default_nettype none
module session_parameter_controller (

    // Caller presents one decoded session-protection job.
    input wire clock_i, reset_n_i, start_i,
    input wire session_valid_i, key_valid_i, session_decrypt_i, session_encrypt_i, session_use_xor_i,
    input wire [2:0] mode_i,
    input wire [4:0] data_bytes_i,
    input wire [255:0] session_value_i, nonce_newer_i, nonce_older_i,
    input wire [127:0] data_in_i, iv_i,

    // Prepared CFB request. XOR finishes locally and never starts this worker.
    output wire cfb_start_o,
    output reg [255:0] cfb_key_o,
    output reg [127:0] cfb_iv_o, cfb_data_o,
    output reg [4:0] cfb_bytes_o,
    output reg cfb_decrypt_o,

    // Completion/result returned by the shared CFB worker.
    input wire cfb_done_i,
    input wire [11:0] cfb_rc_i,
    input wire [127:0] cfb_data_i, cfb_iv_i,

    // Completion/result returned to symm_top.
    output wire wait_o,
    output reg done_o,
    output reg [11:0] tpm_rc_o,
    output reg [127:0] data_out_o, iv_out_o
);

    // States follow the job from capture through derivation to completion.
    localparam IDLE = 0, DERIVE = 1, WAIT_KDF = 2, ISSUE = 3, WAIT_CFB = 4, DONE = 5, RELEASE = 6;
    reg [2:0] state_r;
    reg use_xor_r;
    reg [255:0] secret_r, newer_r, older_r;
    reg [127:0] mask_r;
    // DERIVE holds the KDFa request until accepted. WAIT_KDF captures its result.
    // CFB then issues a job to the shared worker; XOR completes here without AES.
    wire kdfa_req_ready_w, kdfa_rsp_valid_w, kdfa_error_w;
    wire [255:0] kdfa_key_w;
    wire [127:0] kdfa_iv_w;
    wire hmac_req_valid_w, hmac_req_ready_w, hmac_rsp_valid_w, hmac_rsp_ready_w, hmac_error_w;
    wire [255:0] hmac_key_w, hmac_digest_w;
    wire [607:0] hmac_message_w;
    assign wait_o = state_r != IDLE;
    assign cfb_start_o = reset_n_i && state_r == ISSUE;

    // CFB requests 384 bits. XOR requests eight bits per valid data byte.
    kdfa_control KDFA_CONTROLLER (
        .clk_i(clock_i),
        .reset_n_i(reset_n_i),
        .req_valid_i(state_r == DERIVE),
        .req_ready_o(kdfa_req_ready_w),
        .rsp_valid_o(kdfa_rsp_valid_w),
        .rsp_ready_i(state_r == WAIT_KDF),
        .error_o(kdfa_error_w),
        .session_value_i(secret_r),
        .label_i(use_xor_r ? 32'h584f5200 : 32'h43464200),
        .xor_bits_i({27'd0, cfb_bytes_o} << 3),
        .context_u_i(newer_r),
        .context_v_i(older_r),
        .aes_key_o(kdfa_key_w),
        .aes_iv_o(kdfa_iv_w),
        .hmac_req_valid_o(hmac_req_valid_w),
        .hmac_req_ready_i(hmac_req_ready_w),
        .hmac_key_o(hmac_key_w),
        .hmac_message_o(hmac_message_w),
        .hmac_rsp_valid_i(hmac_rsp_valid_w),
        .hmac_rsp_ready_o(hmac_rsp_ready_w),
        .hmac_digest_i(hmac_digest_w),
        .hmac_error_i(hmac_error_w)
    );

    // Practice service only: replace this instance with real HMAC-SHA256.
    hmac_sha256_placeholder HMAC_PLACEHOLDER (
        .clk_i(clock_i),
        .reset_n_i(reset_n_i),
        .req_valid_i(hmac_req_valid_w),
        .req_ready_o(hmac_req_ready_w),
        .key_i(hmac_key_w),
        .message_i(hmac_message_w),
        .digest_o(hmac_digest_w),
        .rsp_valid_o(hmac_rsp_valid_w),
        .rsp_ready_i(hmac_rsp_ready_w),
        .error_o(hmac_error_w)
    );

    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            state_r <= IDLE;
            done_o <= 0;
            tpm_rc_o <= 0;
            data_out_o <= 0;
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
            mask_r <= 0;
        end
        else begin
            done_o <= 0;
            case (state_r)

                // Capture all job inputs, then reject invalid requests before derivation.
                IDLE: if (start_i) begin
                    tpm_rc_o <= 0;
                    data_out_o <= 0;
                    iv_out_o <= 0;
                    secret_r <= session_value_i;
                    newer_r <= nonce_newer_i;
                    older_r <= nonce_older_i;
                    use_xor_r <= session_use_xor_i;
                    cfb_data_o <= data_in_i;
                    cfb_bytes_o <= data_bytes_i;
                    cfb_decrypt_o <= session_decrypt_i;
                    cfb_iv_o <= iv_i;
                    cfb_key_o <= 0;
                    mask_r <= data_bytes_i == 0 ? 128'd0 : {128{1'b1}} << ((16 - data_bytes_i) * 8);
                    if (!session_valid_i) begin
                        tpm_rc_o <= 12'h08b;
                        state_r <= DONE;
                    end
                    else if (!(session_encrypt_i ^ session_decrypt_i)) begin
                        tpm_rc_o <= 12'h082;
                        state_r <= DONE;
                    end
                    else if (data_bytes_i > 16) begin
                        tpm_rc_o <= 12'h095;
                        state_r <= DONE;
                    end
                    else if (!session_use_xor_i && mode_i != 1) begin
                        tpm_rc_o <= 12'h089;
                        state_r <= DONE;
                    end
                    else if (!key_valid_i) begin
                        tpm_rc_o <= 12'h09c;
                        state_r <= DONE;
                    end
                    else if (session_use_xor_i && data_bytes_i == 0) begin
                        iv_out_o <= iv_i;
                        state_r <= DONE;
                    end
                    else state_r <= DERIVE;
                end

                // Hold the KDFa request until its ready signal acknowledges acceptance.
                DERIVE: if (kdfa_req_ready_w) state_r <= WAIT_KDF;

                // Capture derived material before KDFa clears it on acknowledgment.
                WAIT_KDF: if (kdfa_rsp_valid_w) begin
                    if (kdfa_error_w) begin
                        tpm_rc_o <= 12'h101;
                        state_r <= DONE;
                    end

                    // XOR uses leading digest bytes directly; it does not use AES or an IV.
                    else if (use_xor_r) begin
                        data_out_o <= (cfb_data_o ^ kdfa_key_w[255:128]) & mask_r;
                        iv_out_o <= cfb_iv_o;
                        state_r <= DONE;
                    end
                    else begin
                        cfb_key_o <= kdfa_key_w;
                        cfb_iv_o <= kdfa_iv_w;
                        state_r <= ISSUE;
                    end
                end

                // Pulse the shared CFB worker's start signal for one clock cycle.
                ISSUE: state_r <= WAIT_CFB;

                // Wait for CFB completion and forward its data, feedback and status.
                WAIT_CFB: if (cfb_done_i) begin
                    data_out_o <= cfb_data_i;
                    iv_out_o <= cfb_iv_i;
                    tpm_rc_o <= cfb_rc_i;
                    state_r <= DONE;
                end

                // Publish a one-cycle done pulse and clear the controller's secret copies.
                DONE: begin
                    done_o <= 1;
                    secret_r <= 0;
                    cfb_key_o <= 0;
                    state_r <= RELEASE;
                end

                // Do not accept the same request repeatedly if start stays high.
                RELEASE: if (!start_i) state_r <= IDLE;
                default: begin
                    tpm_rc_o <= 12'h101;
                    state_r <= DONE;
                end
            endcase
        end
    end
endmodule
`default_nettype wire
