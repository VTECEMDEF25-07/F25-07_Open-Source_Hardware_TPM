// Filename: cfb_block.v
// Author: Makeda Solomon; refactor assisted by Codex
// Date: October 13, 2026
// Description: One AES-256 CFB chunk (0–16 bytes). Key and IV already prepared; no command/session lookup. Partial final feedback is zero-filled; do not continue after a partial chunk.
`default_nettype none
module cfb_block (
    input wire clock_i, reset_n_i, start_i, decrypt_i,
    input wire [4:0] data_bytes_i,
    input wire [255:0] key_i,
    input wire [127:0] iv_i, data_in_i,
    output reg wait_o, done_o,
    output reg [11:0] tpm_rc_o,
    output reg [127:0] data_out_o, iv_out_o
);
    localparam ST_IDLE = 0, ST_EXECUTE = 1, ST_KEY_BUSY = 2, ST_KEY_READY = 3,
    ST_BLOCK_BUSY = 4, ST_BLOCK_DONE = 5, ST_DONE = 6, ST_RELEASE = 7;
    reg [3:0] state_r;
    reg [127:0] byte_mask_w;
    reg aes_init_r;
    reg aes_next_r;
    reg [255:0] aes_key_r;
    reg [127:0] aes_feedback_r;
    wire aes_ready_w;
    wire aes_result_valid_w;
    // Clear the expanded key after the output has been captured.
    wire aes_reset_n_w = reset_n_i && state_r != ST_DONE && state_r != ST_RELEASE;
    wire [127:0] cipher_stream_block_w;

    reg [127:0] data_r;
    reg [127:0] data_mask_r;
    reg decrypt_r;
    wire [127:0] cfb_result_w;
    wire [127:0] cfb_feedback_w;

    // AES encrypts the IV/feedback to make a mask. XOR works in both directions.
    assign cfb_result_w = (data_r ^ cipher_stream_block_w) & data_mask_r;

    // Feedback is always ciphertext: output during encryption, input during decryption.
    assign cfb_feedback_w = (decrypt_r ? data_r : cfb_result_w) & data_mask_r;

    // Valid bytes occupy the most significant end of the data bus.

    always @( * ) begin
        if (data_bytes_i == 5'd0)
        byte_mask_w = 128'b0;
        else if (data_bytes_i >= 5'd16)
        byte_mask_w = 128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
        else
        byte_mask_w = 128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF <<
        ((5'd16 - data_bytes_i) * 8);
    end

    aes AES_IMPLEMENT (
        .clock_i (clock_i),
        .reset_n_i (aes_reset_n_w),

        .init_i (aes_init_r),
        .next_i (aes_next_r),
        // Initial implementation: AES-256
        .keylen_i (1'b1),
        .key_i (aes_key_r),
        .block_i (aes_feedback_r),
        .ready_o (aes_ready_w),
        .result_valid_o (aes_result_valid_w),
        .block_o (cipher_stream_block_w)
    );

    // Sequential control + execution datapath
    // Use <= in clocked logic for non-blocking updates for registers. All registers will update together at a time step

    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            state_r <= ST_IDLE;
            aes_init_r <= 1'b0;
            aes_next_r <= 1'b0;
            aes_key_r <= 256'b0;
            aes_feedback_r <= 128'b0;
            data_r <= 128'b0;
            data_mask_r <= 128'b0;
            decrypt_r <= 1'b0;
            wait_o <= 1'b0;
            done_o <= 1'b0;
            tpm_rc_o <= 12'h000;
            data_out_o <= 128'b0;
            iv_out_o <= 128'b0;
        end
        else begin
            done_o <= 1'b0;
            aes_init_r <= 1'b0;
            aes_next_r <= 1'b0;

            case (state_r)

                // Capture the prepared key, IV, data and direction when start is asserted.
                ST_IDLE: begin
                    wait_o <= 1'b0;
                    if (start_i) begin
                        wait_o <= 1'b1;
                        tpm_rc_o <= 12'h000; // TCG name: TPM_RC_SUCCESS
                        data_out_o <= 128'b0;
                        iv_out_o <= 128'b0;

                        if (data_bytes_i > 16) begin
                            tpm_rc_o <= 12'h095;
                            state_r <= ST_DONE;
                        end
                        else begin
                            data_r <= data_in_i;
                            data_mask_r <= byte_mask_w;
                            decrypt_r <= decrypt_i;
                            aes_key_r <= key_i;
                            aes_feedback_r <= iv_i;
                            state_r <= ST_EXECUTE;
                        end
                    end
                end

                ST_EXECUTE: begin
                    if (data_mask_r == 128'b0) begin
                        // Empty operation: return the supplied/derived IV without starting AES.
                        data_out_o <= 128'b0;
                        iv_out_o <= aes_feedback_r;
                        state_r <= ST_DONE;
                    end
                    else if (aes_ready_w) begin
                        aes_init_r <= 1'b1;
                        state_r <= ST_KEY_BUSY;
                    end
                    // Otherwise hold this state until the core can accept init.
                end

                ST_KEY_BUSY: begin
                    // Do not mistake the pre-init ready=1 for completion.
                    if (!aes_ready_w)
                    state_r <= ST_KEY_READY;
                end

                ST_KEY_READY: begin
                    if (aes_ready_w) begin
                        // Key expansion completed; start E_key(feedback_IV).
                        aes_next_r <= 1'b1;
                        state_r <= ST_BLOCK_BUSY;
                    end
                end

                ST_BLOCK_BUSY: begin
                    // Qualify this new launch before looking at result_valid.
                    if (!aes_ready_w)
                    state_r <= ST_BLOCK_DONE;
                end

                // Apply the AES-produced mask and save the ciphertext feedback.
                ST_BLOCK_DONE: begin
                    if (aes_ready_w && aes_result_valid_w) begin
                        data_out_o <= cfb_result_w;
                        iv_out_o <= cfb_feedback_w;
                        aes_feedback_r <= cfb_feedback_w;
                        state_r <= ST_DONE;
                    end
                end

                ST_DONE: begin
                    done_o <= 1'b1;
                    aes_key_r <= 0;
                    data_r <= 0;
                    aes_feedback_r <= 0;
                    state_r <= ST_RELEASE;
                    // wait_o remains high through the result pulse.
                end

                ST_RELEASE: begin
                    // A held legacy start must not retrigger the same job.
                    if (!start_i) begin
                        wait_o <= 1'b0;
                        state_r <= ST_IDLE;
                    end
                end

                default: begin
                    wait_o <= 1'b1;
                    tpm_rc_o <= 12'h101; // TCG name: TPM_RC_FAILURE
                    data_out_o <= 128'b0;
                    iv_out_o <= 128'b0;
                    state_r <= ST_DONE;
                end
            endcase
        end
    end
endmodule
`default_nettype wire
