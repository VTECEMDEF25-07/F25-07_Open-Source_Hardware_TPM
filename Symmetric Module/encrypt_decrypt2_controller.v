// Filename: encrypt_decrypt2_controller.v
// Author: Makeda Solomon; refactor assisted by Codex
// Date: October 13, 2026
// Description: Validate a decoded EncryptDecrypt2 job, then request shared AES-256/CFB. Upstream resolves key handle, authorization and effective mode. One chunk only.
`default_nettype none
module encrypt_decrypt2_controller (

    // Caller supplies decoded command inputs and an already resolved object key.
    input wire clock_i, reset_n_i, start_i,
    input wire [15:0] command_code_i,
    input wire key_valid_i, decrypt_i,
    input wire [2:0] mode_i,
    input wire [4:0] data_bytes_i,
    input wire [255:0] key_i,
    input wire [127:0] iv_i, data_in_i,

    // Prepared request sent to the shared CFB worker.
    output wire cfb_start_o,
    output reg [255:0] cfb_key_o,
    output reg [127:0] cfb_iv_o, cfb_data_o,
    output reg [4:0] cfb_bytes_o,
    output reg cfb_decrypt_o,

    // Response from the shared CFB worker.
    input wire cfb_done_i,
    input wire [11:0] cfb_rc_i,
    input wire [127:0] cfb_data_i, cfb_iv_i,

    // Response returned to symm_top.
    output wire wait_o,
    output reg done_o,
    output reg [11:0] tpm_rc_o,
    output reg [127:0] data_out_o, iv_out_o
);
    localparam IDLE = 0, ISSUE = 1, WAIT_CFB = 2, DONE = 3, RELEASE = 4;
    reg [2:0] state_r;
    // ISSUE pulses start for the shared worker. WAIT_CFB waits for its completion.
    // No KDFa here: key_i is the already resolved AES object key.
    assign wait_o = state_r != IDLE;
    assign cfb_start_o = reset_n_i && state_r == ISSUE;

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
        end
        else begin
            done_o <= 0;
            case (state_r)

                // Capture inputs. Only valid AES-256/CFB jobs proceed to the worker.
                IDLE: if (start_i) begin
                    data_out_o <= 0;
                    iv_out_o <= 0;
                    tpm_rc_o <= 0;
                    cfb_key_o <= key_i;
                    cfb_iv_o <= iv_i;
                    cfb_data_o <= data_in_i;
                    cfb_bytes_o <= data_bytes_i;
                    cfb_decrypt_o <= decrypt_i;
                    if (command_code_i != 16'h0193) begin
                        tpm_rc_o <= 12'h143; // TCG name: TPM_RC_COMMAND_CODE 
                        state_r <= DONE;
                    end
                    else if (!key_valid_i) begin
                        tpm_rc_o <= 12'h09c; // TCG name: TPM_RC_KEY
                        state_r <= DONE;
                    end
                    else if (mode_i != 1) begin
                        tpm_rc_o <= 12'h089; // TCG name: TPM_RC_MODE
                        state_r <= DONE;
                    end
                    else if (data_bytes_i > 16) begin
                        tpm_rc_o <= 12'h095; // TCG name: TPM_RC_SIZE
                        state_r <= DONE;
                    end
                    else state_r <= ISSUE;
                end

                // Pulse worker start for one cycle; no key derivation is needed here.
                ISSUE: state_r <= WAIT_CFB;

                // Wait for the worker before publishing the command result.
                WAIT_CFB: if (cfb_done_i) begin
                    data_out_o <= cfb_data_i;
                    iv_out_o <= cfb_iv_i;
                    tpm_rc_o <= cfb_rc_i;
                    state_r <= DONE;
                end

                // Publish done for one clock and erase this controller's key copy.
                DONE: begin
                    done_o <= 1;
                    cfb_key_o <= 0;
                    state_r <= RELEASE;
                end

                // Wait for start to fall before accepting another job.
                RELEASE: if (!start_i) state_r <= IDLE;
                default: begin
                    tpm_rc_o <= 12'h101; // TCG name: TPM_RC_FAILUR
                    state_r <= DONE;
                end
            endcase
        end
    end
endmodule
`default_nettype wire
