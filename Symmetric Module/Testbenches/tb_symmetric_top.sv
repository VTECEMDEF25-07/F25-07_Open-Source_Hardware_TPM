`timescale 1ns/1ps
// Tests the complete practice path: top -> KDFa -> fake HMAC -> real AES.
// The derived key is FAKE. Passing these tests does not validate real KDFa/HMAC.
module tb_symmetric_top;
    localparam [255:0] SECRET = 256'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f;
    localparam [255:0] NEWER = 256'h202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f;
    localparam [255:0] OLDER = 256'h404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f;
    // Placeholder copies counter, label, and 24 nonce bytes into each digest.
    localparam [255:0] DERIVED_KEY = 256'h0000000143464200202122232425262728292a2b2c2d2e2f3031323334353637;
    localparam [127:0] DERIVED_IV = 128'h00000002434642002021222324252627;
    localparam [127:0] PLAIN = 128'h6bc1bee22e409f96e93d7e117393172a;
    // Independently calculated with Python cryptography AES-256/CFB.
    localparam [127:0] SESSION_CIPHER = 128'h2756bf642e465250ea7b780717962112;
    // NIST SP 800-38A AES-256/CFB128 first-block example (also checked in Python).
    localparam [255:0] PRIMITIVE_KEY = 256'h603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4;
    localparam [127:0] PRIMITIVE_IV = 128'h000102030405060708090a0b0c0d0e0f;
    localparam [127:0] PRIMITIVE_CIPHER = 128'hdc7e84bfda79164b7ecd8486985d3860;

    // These signals act as the execution engine's request and result interface.
    reg clock_i=0; always #5 clock_i=~clock_i;
    reg reset_n_i=0, start_i=0;
    reg [15:0] command_code_i=16'h0193;
    reg session_protect_i=0, session_decrypt_i=0, session_encrypt_i=0, session_use_xor_i=0;
    reg key_valid_i=1, session_valid_i=1, decrypt_i=0;
    reg [2:0] mode_i=1;
    reg [4:0] data_bytes_i=16;
    reg [255:0] key_i=0, session_value_i=0, nonce_newer_i=0, nonce_older_i=0;
    reg [127:0] iv_i=0, data_in_i=0, session_mask_i=0;
    wire wait_o, done_o, primitive_path_o, session_path_o;
    wire [11:0] tpm_rc_o;
    wire [127:0] data_out_o, iv_out_o;

    // KDFa, HMAC, and AES are instantiated INSIDE this top, not by the testbench.
    symm_top dut (
        .clock_i(clock_i), .reset_n_i(reset_n_i), .start_i(start_i),
        .command_code_i(command_code_i), .session_protect_i(session_protect_i),
        .session_decrypt_i(session_decrypt_i), .session_encrypt_i(session_encrypt_i),
        .session_use_xor_i(session_use_xor_i), .key_valid_i(key_valid_i),
        .session_valid_i(session_valid_i), .mode_i(mode_i), .decrypt_i(decrypt_i),
        .data_bytes_i(data_bytes_i), .key_i(key_i), .iv_i(iv_i),
        .data_in_i(data_in_i), .session_mask_i(session_mask_i),
        .session_value_i(session_value_i), .nonce_newer_i(nonce_newer_i),
        .nonce_older_i(nonce_older_i), .wait_o(wait_o), .done_o(done_o),
        .tpm_rc_o(tpm_rc_o), .data_out_o(data_out_o), .iv_out_o(iv_out_o),
        .primitive_path_o(primitive_path_o), .session_path_o(session_path_o)
    );

    // Waveform labels and counters make each operation easy to identify.
    integer test_case=0, case_count=0, hmac_calls=0, aes_calls=0;
    reg successfully_completed=0, expect_kdfa=0, expect_aes=0;
    reg [255:0] expected_aes_key;
    reg [127:0] expected_aes_iv;
    wire [31:0] message_counter = dut.hmac_message_w[607:576];
    wire [31:0] expected_counter = hmac_calls+1;

    // Check the actual wires between modules and the key/IV reaching AES.
    always @(posedge clock_i) begin
        if(!reset_n_i) begin
            hmac_calls<=0; aes_calls<=0;
        end else begin
            if(!expect_kdfa && dut.kdfa_req_valid_w)
                $fatal(1,"Unexpected KDFa request");
            if(dut.hmac_req_valid_w && dut.hmac_req_ready_w) begin
                if(!expect_kdfa || hmac_calls>=2 || dut.hmac_key_w!==SECRET ||
                   dut.hmac_message_w!=={expected_counter,32'h43464200,NEWER,OLDER,32'd384})
                    $fatal(1,"Wrong session secret, message, or counter");
                hmac_calls<=hmac_calls+1;
                $display("%0t: HMAC accepts message %0d",$time,message_counter);
            end
            if(dut.aes_init_r) begin
                if(!expect_aes || dut.aes_key_r!==expected_aes_key ||
                   dut.aes_feedback_r!==expected_aes_iv)
                    $fatal(1,"AES started unexpectedly or used the wrong key/IV");
                aes_calls<=aes_calls+1;
                $display("%0t: AES starts with key=%064h IV=%032h",
                         $time,dut.aes_key_r,dut.aes_feedback_r);
            end
        end
    end

    // Prepare a normal request; each case below changes only what it exercises.
    task prepare(input bit session, input bit decrypt, input integer bytes);
        begin
            @(negedge clock_i);
            if(wait_o || done_o) $fatal(1,"Top is not ready for another request");
            hmac_calls=0; aes_calls=0; start_i=0;
            session_protect_i=session; session_decrypt_i=decrypt;
            session_encrypt_i=!decrypt; session_use_xor_i=0;
            key_valid_i=1; session_valid_i=1; command_code_i=16'h0193;
            mode_i=1; decrypt_i=decrypt; data_bytes_i=bytes;
            session_value_i=SECRET; nonce_newer_i=NEWER; nonce_older_i=OLDER;
            key_i=PRIMITIVE_KEY; iv_i=PRIMITIVE_IV; data_in_i=PLAIN; session_mask_i=0;
            expect_kdfa=session; expect_aes=(bytes!=0);
            expected_aes_key=session ? DERIVED_KEY : PRIMITIVE_KEY;
            expected_aes_iv=session ? DERIVED_IV : PRIMITIVE_IV;
        end
    endtask

    task launch(input bit hold_start);
        begin
            start_i=1;
            @(negedge clock_i);
            if(!wait_o) $fatal(1,"Top did not accept start");
            if(!hold_start) start_i=0;
        end
    endtask

    // Wait for completion, check the result, then release a possibly held start.
    task check_result(input [11:0] rc, input [127:0] data, input [127:0] iv,
                      input integer expected_hmac_calls, input integer expected_aes_calls);
        integer cycles;
        begin
            cycles=0;
            while(!done_o && cycles<300) begin
                @(negedge clock_i); cycles=cycles+1;
            end
            if(!done_o || tpm_rc_o!==rc || data_out_o!==data || iv_out_o!==iv ||
               hmac_calls!=expected_hmac_calls || aes_calls!=expected_aes_calls)
                $fatal(1,"Case %0d: rc=%h data=%h IV=%h HMAC=%0d AES=%0d",
                       test_case,tpm_rc_o,data_out_o,iv_out_o,hmac_calls,aes_calls);
            if(start_i) repeat(4) begin
                @(negedge clock_i);
                if(done_o || !wait_o || hmac_calls!=expected_hmac_calls ||
                   aes_calls!=expected_aes_calls || data_out_o!==data)
                    $fatal(1,"Held start repeated or changed the completed operation");
            end
            start_i=0;
            repeat(2) @(negedge clock_i);
            if(wait_o || done_o) $fatal(1,"Top did not return to idle");
        end
    endtask

    task pass(input string description);
        begin
            case_count=case_count+1;
            $display("PASS %0d: %s",case_count,description);
        end
    endtask

    initial begin
        $timeformat(-9,0," ns",8);
        repeat(3) @(negedge clock_i); reset_n_i=1;

        // 1: All caller inputs may change once the request has been accepted.
        test_case=1; prepare(1,0,16); launch(0);
        session_value_i=0; nonce_newer_i=0; nonce_older_i=0;
        key_i=0; iv_i=0; data_in_i=0; data_bytes_i=0;
        session_protect_i=0; session_encrypt_i=0; mode_i=0;
        check_result(0,SESSION_CIPHER,SESSION_CIPHER,2,1);
        if(!session_path_o || primitive_path_o) $fatal(1,"Wrong selected path");
        pass("session encryption uses captured inputs and derived key/IV");

        // 2: Decryption also uses AES encryption internally for CFB.
        test_case=2; prepare(1,1,16); data_in_i=SESSION_CIPHER; launch(1);
        check_result(0,PLAIN,SESSION_CIPHER,2,1);
        pass("session decryption and held-start protection");

        test_case=3; prepare(1,0,5); launch(0);
        check_result(0,128'h2756bf642e0000000000000000000000,
                       128'h2756bf642e0000000000000000000000,2,1);
        pass("five-byte session parameter masks unused bytes");

        test_case=4; prepare(1,0,0); launch(0);
        check_result(0,0,DERIVED_IV,2,0);
        pass("empty parameter derives material without starting AES");

        test_case=5; prepare(0,0,16); launch(0);
        check_result(0,PRIMITIVE_CIPHER,PRIMITIVE_CIPHER,0,1);
        if(!primitive_path_o || session_path_o) $fatal(1,"Wrong primitive path");
        pass("primitive CFB known-answer encryption bypasses KDFa");

        test_case=6; prepare(1,0,16);
        session_use_xor_i=1; session_mask_i={128{1'b1}};
        expect_kdfa=0; expect_aes=0; launch(0);
        check_result(0,~PLAIN,PRIMITIVE_IV,0,0);
        pass("supplied XOR mask bypasses both KDFa and AES");

        test_case=7; prepare(1,0,16);
        session_valid_i=0; expect_kdfa=0; expect_aes=0; launch(0);
        check_result(12'h08b,0,0,0,0);
        pass("invalid session is rejected before KDFa or AES");

        // 8: Inject a service failure at the second response, not inside HMAC.
        test_case=8; prepare(1,0,16); expect_aes=0; launch(0);
        wait(dut.hmac_rsp_valid_w && message_counter==2);
        force dut.hmac_error_w=1'b1;
        @(posedge clock_i);
        @(negedge clock_i);
        release dut.hmac_error_w;
        check_result(12'h101,0,0,2,0);
        pass("HMAC error reaches the caller and prevents encryption");

        // 9: Reset the entire chain during derivation, then try a fresh job.
        test_case=9; prepare(1,0,16); launch(0);
        wait(dut.hmac_req_valid_w);
        @(negedge clock_i); reset_n_i=0; start_i=0;
        repeat(2) @(negedge clock_i); reset_n_i=1;
        repeat(3) @(negedge clock_i);
        if(wait_o || done_o || dut.hmac_rsp_valid_w || dut.kdfa_rsp_valid_w ||
           dut.aes_init_r || data_out_o!==0)
            $fatal(1,"Reset left stale work in the pipeline");
        prepare(1,0,16); launch(0); check_result(0,SESSION_CIPHER,SESSION_CIPHER,2,1);
        pass("reset aborts derivation and a fresh request succeeds");

        test_case=10; prepare(0,1,16); data_in_i=PRIMITIVE_CIPHER; launch(0);
        check_result(0,PLAIN,PRIMITIVE_CIPHER,0,1);
        pass("primitive CFB known-answer decryption bypasses KDFa");

        successfully_completed=1;
        $display("ALL %0d SYMMETRIC TOP CASES PASSED",case_count); $finish;
    end
    initial begin #100000; $fatal(1,"Global symmetric-top test timeout"); end
endmodule
