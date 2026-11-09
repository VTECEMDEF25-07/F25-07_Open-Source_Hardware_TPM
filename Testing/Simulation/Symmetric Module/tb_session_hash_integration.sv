`timescale 1ns/1ps
// Real AES RTL plus Python HMAC over the bytes accepted by the external port.
module tb_session_hash_integration;
    reg clock_i=0;
    always #5 clock_i=~clock_i;
    reg reset_n_i=0, start_i=0;
    reg [15:0] command_code_i=16'h0193, data_bytes_i=0;
    reg session_protect_i=1, session_decrypt_i=0, session_encrypt_i=1, session_use_xor_i=0;
    reg key_valid_i=1, session_valid_i=1, decrypt_i=0;
    reg [2:0] mode_i=1;
    reg [255:0] key_i=0;
    reg [127:0] iv_i=0, session_mask_i=0;
    reg [8191:0] data_in_i=0;
    reg [1023:0] session_value_i=0;
    reg [511:0] nonce_newer_i=0, nonce_older_i=0;
    reg [15:0] session_value_bytes_i=0, nonce_newer_bytes_i=0, nonce_older_bytes_i=0;
    wire wait_o, done_o, primitive_path_o, session_path_o;
    wire [11:0] tpm_rc_o;
    wire [8191:0] data_out_o;
    wire [127:0] iv_out_o;
    wire hmac_start_o, hmac_key_valid_o, hmac_key_end_o, hmac_key_ready_i;
    wire hmac_message_valid_o, hmac_message_end_o, hmac_message_ready_i, hmac_busy_i;
    wire [7:0] hmac_key_data_o, hmac_message_data_o;
    wire [255:0] hmac_digest_i;
    wire hmac_digest_valid_i, hmac_digest_ready_o;
    symm_top dut(.*);
    hmac_stream_test_service #(.USE_PYTHON(1)) hmac_service(.*);
    integer cases=0, hmac_calls=0, cfb_calls=0;
    reg [255:0] expected_key;
    reg [127:0] expected_first_iv;
    reg [8191:0] expected_data;
    reg [127:0] expected_iv;
    integer expected_hmac, expected_cfb;
    reg [11:0] expected_rc=0;
    reg hold_start=0, mutate_inputs=0, checking_vectors=1;
    always @(posedge clock_i) if (reset_n_i) begin
        if (hmac_start_o) hmac_calls=hmac_calls+1;
        if (dut.s_start && checking_vectors) begin
            if (dut.s_key !== expected_key) $fatal(1,"Wrong derived AES key");
            if (cfb_calls == 0 && dut.s_iv !== expected_first_iv) $fatal(1,"Wrong derived IV");
            cfb_calls=cfb_calls+1;
        end
    end
    task execute;
        integer cycles;
        begin
            hmac_calls=0;
            cfb_calls=0;
            @(negedge clock_i); start_i=1;
            @(negedge clock_i);
            if (!wait_o) $fatal(1,"Job not accepted");
            if (!hold_start) start_i=0;
            if (mutate_inputs) begin
                data_in_i=0;
                session_value_i=0;
                nonce_newer_i=0;
                nonce_older_i=0;
                data_bytes_i=0;
                session_value_bytes_i=0;
                nonce_newer_bytes_i=0;
                nonce_older_bytes_i=0;
            end
            cycles=0;
            while (!done_o && cycles<200000) begin @(negedge clock_i); cycles++; end
            if (!done_o || tpm_rc_o !== expected_rc || data_out_o !== expected_data ||
                iv_out_o !== expected_iv || hmac_calls != expected_hmac || cfb_calls != expected_cfb)
                $fatal(1,"Case %0d rc=%h HMAC=%0d/%0d CFB=%0d/%0d data=%h iv=%h",
                       cases+1,tpm_rc_o,hmac_calls,expected_hmac,cfb_calls,expected_cfb,data_out_o,iv_out_o);
            if (dut.SESSION_CONTROLLER.secret_r !== 0 || dut.SESSION_CONTROLLER.cfb_key_o !== 0 ||
                dut.SESSION_CONTROLLER.KDFA_CONTROLLER.hmac_key_r !== 0)
                $fatal(1,"Secret copies survived completion");
            repeat (5) begin
                @(negedge clock_i);
                if (done_o || data_out_o !== expected_data) $fatal(1,"Unstable result or repeated completion");
            end
            start_i=0;
            repeat (4) @(negedge clock_i);
            if (wait_o) $fatal(1,"Controller did not release job");
            cases++;
            $display("PASS external HMAC integration case %0d",cases);
        end
    endtask
    initial begin
        repeat (3) @(negedge clock_i); reset_n_i=1;
        `include "session_vectors.svh"
        `include "session_faults.svh"

        // Reset during each external-service phase and during AES execution.
        checking_vectors=0;
        for (integer phase=0; phase<4; phase++) begin
            @(negedge clock_i);
            session_valid_i=1; key_valid_i=1; mode_i=1;
            session_use_xor_i=0; session_encrypt_i=1; session_decrypt_i=0;
            session_value_bytes_i=32; nonce_newer_bytes_i=32; nonce_older_bytes_i=32;
            data_bytes_i=64; start_i=1;
            case (phase)
                0: wait(hmac_key_valid_o);
                1: wait(hmac_message_valid_o);
                2: wait(hmac_digest_valid_i);
                3: wait(dut.cfb_wait);
            endcase
            @(negedge clock_i); reset_n_i=0; start_i=0;
            repeat (3) @(negedge clock_i); reset_n_i=1;
            repeat (5) @(negedge clock_i);
            if (wait_o || done_o || hmac_busy_i || hmac_digest_valid_i || data_out_o !== 0)
                $fatal(1,"Stale work after shared reset phase %0d",phase);
        end
        // A fresh cryptographic operation after all reset boundaries.
        checking_vectors=1;
        `include "session_recovery.svh"
        $display("SESSION_HASH_INTEGRATION_PASS (%0d cryptographic/error cases, 4 reset phases)",cases);
        $finish;
    end
    initial begin #50000000; $fatal(1,"Integration timeout"); end
endmodule
