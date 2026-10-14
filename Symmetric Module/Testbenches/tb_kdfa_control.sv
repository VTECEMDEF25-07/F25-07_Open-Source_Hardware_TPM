`timescale 1ns/1ps
// Practice control-flow tests only: the placeholder is NOT real HMAC/SHA-256.
// In Questa/ModelSim, run: do {path/to/Testbenches/run_kdfa_control.do}
// This testbench is the parent that instantiates and connects BOTH modules.
module tb_kdfa_control;
    localparam [255:0] SECRET = 256'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f;
    localparam [255:0] NEWER  = 256'h202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f;
    localparam [255:0] OLDER  = 256'h404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f;
    localparam [31:0] CFB = 32'h43464200;
    // Fake HMAC returns the first 32 message bytes: counter, CFB, first 24 nonce bytes.
    localparam [255:0] DIGEST_ONE = 256'h0000000143464200202122232425262728292a2b2c2d2e2f3031323334353637;
    localparam [255:0] DIGEST_TWO = 256'h0000000243464200202122232425262728292a2b2c2d2e2f3031323334353637;

    // Pretend to be the caller: supply a job, then acknowledge its final result.
    // A 10 ns clock period makes every transfer visible on a rising clock edge.
    reg clk_i=0; always #5 clk_i=~clk_i;
    reg reset_n_i=0, req_valid_i=0, rsp_ready_i=0;
    reg [255:0] session_value_i=0, context_u_i=0, context_v_i=0;
    reg [31:0] label_i=0;
    wire req_ready_o, rsp_valid_o, error_o;
    wire [255:0] aes_key_o;
    wire [127:0] aes_iv_o;
    // These wires carry messages/results between the two instantiated modules.
    wire hmac_req_ready_i, hmac_rsp_valid_i, hmac_error_i;
    wire [255:0] hmac_digest_i;
    wire hmac_req_valid_o, hmac_rsp_ready_o;
    wire [255:0] hmac_key_o;
    wire [607:0] hmac_message_o;
    // Simulation-only display helpers: current test and counter inside the message.
    integer test_case=0; // Matches the six numbered cases below and in the waveform.
    wire [31:0] message_counter = hmac_message_o[607:576];

    // Left of each pair = module port. Inside parentheses = testbench signal.
    kdfa_control dut (
        .clk_i(clk_i), .reset_n_i(reset_n_i),
        .req_valid_i(req_valid_i), .req_ready_o(req_ready_o),
        .rsp_valid_o(rsp_valid_o), .rsp_ready_i(rsp_ready_i),
        .error_o(error_o),
        .session_value_i(session_value_i), .label_i(label_i),
        .context_u_i(context_u_i), .context_v_i(context_v_i),
        .aes_key_o(aes_key_o), .aes_iv_o(aes_iv_o),
        .hmac_req_valid_o(hmac_req_valid_o), .hmac_req_ready_i(hmac_req_ready_i),
        .hmac_key_o(hmac_key_o), .hmac_message_o(hmac_message_o),
        .hmac_rsp_valid_i(hmac_rsp_valid_i), .hmac_rsp_ready_o(hmac_rsp_ready_o),
        .hmac_digest_i(hmac_digest_i), .hmac_error_i(hmac_error_i)
    );

    // Gate request acceptance to exercise backpressure. Inject one service error
    // at the KDFa boundary; the unmodified placeholder always reports success.
    reg accept_hmac=1, inject_second_error=0, forbid_hmac=0;
    wire fake_ready, fake_error;
    integer hmac_calls=0, case_count=0;
    reg successfully_completed=0;
    assign hmac_req_ready_i = fake_ready && accept_hmac;
    assign hmac_error_i = fake_error ||
        (inject_second_error && hmac_rsp_valid_i && hmac_calls==2);
    // This is the actual HMAC instance. With accept_hmac=1 and
    // inject_second_error=0, it connects directly to the controller's interface.
    hmac_sha256_placeholder fake_hmac (
        .clk_i(clk_i), .reset_n_i(reset_n_i),
        .req_valid_i(hmac_req_valid_o && accept_hmac), .req_ready_o(fake_ready),
        .key_i(hmac_key_o), .message_i(hmac_message_o),
        .rsp_valid_o(hmac_rsp_valid_i), .rsp_ready_i(hmac_rsp_ready_o),
        .digest_o(hmac_digest_i), .error_o(fake_error)
    );

    // Check every accepted message, including counter order and the 384-bit size.
    wire [31:0] expected_counter = hmac_calls+1;
    reg was_stalled=0;
    reg [255:0] held_key;
    reg [607:0] held_message;
    always @(posedge clk_i) begin
        if(!reset_n_i) begin
            hmac_calls<=0; was_stalled<=0;
        end else begin
            if(forbid_hmac && hmac_req_valid_o)
                $fatal(1,"Invalid label launched HMAC");
            if(was_stalled && (!hmac_req_valid_o || hmac_key_o!==held_key ||
                              hmac_message_o!==held_message))
                $fatal(1,"HMAC request changed while stalled");
            if(hmac_req_valid_o && hmac_req_ready_i) begin
                if(hmac_calls>=2 || hmac_key_o!==SECRET ||
                   hmac_message_o!=={expected_counter,CFB,NEWER,OLDER,32'd384})
                    $fatal(1,"Incorrect HMAC key, message, or counter");
                $display("%0t: HMAC accepted message %0d", $time, message_counter);
                hmac_calls<=hmac_calls+1;
            end
            if(hmac_rsp_valid_i && hmac_rsp_ready_o)
                $display("%0t: KDFa received digest %0d = %064h (error=%b)",
                         $time, message_counter, hmac_digest_i, hmac_error_i);
            was_stalled<=hmac_req_valid_o && !hmac_req_ready_i;
            held_key<=hmac_key_o; held_message<=hmac_message_o;
        end
    end

    task launch(input bit bad_label, input bit change_after_accept);
        begin
            @(negedge clk_i);
            if(!req_ready_o) $fatal(1,"Controller was not ready");
            hmac_calls=0;
            session_value_i=SECRET; label_i=bad_label ? 32'h42414400 : CFB;
            context_u_i=NEWER; context_v_i=OLDER; req_valid_i=1;
            // Inputs and valid remain stable across this accepting rising edge.
            @(posedge clk_i);
            if(!req_ready_o) $fatal(1,"Request handshake missing");
            @(negedge clk_i); req_valid_i=0;
            if(change_after_accept) begin
                session_value_i=~SECRET; label_i=0;
                context_u_i=~NEWER; context_v_i=~OLDER;
            end
        end
    endtask

    task wait_result;
        integer cycles;
        begin
            cycles=0;
            while(!rsp_valid_o && cycles<100) begin
                @(negedge clk_i); cycles=cycles+1;
            end
            if(!rsp_valid_o) $fatal(1,"Result timed out");
        end
    endtask

    task wait_hmac_request;
        integer cycles;
        begin
            cycles=0;
            while(!hmac_req_valid_o && cycles<20) begin
                @(negedge clk_i); cycles=cycles+1;
            end
            if(!hmac_req_valid_o) $fatal(1,"HMAC request timed out");
        end
    endtask

    task acknowledge;
        begin
            @(negedge clk_i); rsp_ready_i=1;
            @(negedge clk_i); rsp_ready_i=0;
            if(!req_ready_o || rsp_valid_o || error_o || aes_key_o!==0 || aes_iv_o!==0)
                $fatal(1,"Acknowledged result was not cleared");
        end
    endtask

    task check_success(input integer hold_cycles);
        integer n;
        begin
            wait_result();
            for(n=0;n<hold_cycles;n=n+1) begin
                if(!rsp_valid_o || req_ready_o || error_o || hmac_calls!=2 ||
                   aes_key_o!==DIGEST_ONE || aes_iv_o!==DIGEST_TWO[255:128])
                    $fatal(1,"Derived key/IV or held result is incorrect");
                @(negedge clk_i);
            end
            $display("AES key = %064h; IV = %032h", aes_key_o, aes_iv_o);
            acknowledge();
        end
    endtask

    task pass(input string name);
        begin
            case_count=case_count+1; $display("PASS %0d: %s",case_count,name);
        end
    endtask

    initial begin
        $timeformat(-9, 0, " ns", 8);
        // CASE 1: Start here in the waveform. Two messages, two digests, key + IV.
        test_case=1;
        repeat(3) @(negedge clk_i); reset_n_i=1;
        launch(0,0); check_success(5); // Leave final values visible for five clocks.
        pass("two correctly formatted messages produce the toy key and IV");

        // CASE 2: Make HMAC wait; change caller inputs after they were captured.
        test_case=2;
        accept_hmac=0; launch(0,1); wait_hmac_request();
        repeat(4) @(negedge clk_i);
        if(hmac_calls!=0 || rsp_valid_o) $fatal(1,"Stalled request advanced");
        accept_hmac=1; check_success(5);
        pass("captured inputs, request backpressure, and held response");

        // CASE 3: A wrong label must return an error without requesting HMAC.
        test_case=3;
        forbid_hmac=1; launch(1,0); wait_result();
        if(!error_o || hmac_calls!=0 || aes_key_o!==0 || aes_iv_o!==0)
            $fatal(1,"Invalid label was not rejected cleanly");
        acknowledge(); forbid_hmac=0;
        pass("invalid label performs no HMAC work");

        // CASE 4: Pretend the second HMAC result failed; discard the first digest.
        test_case=4;
        inject_second_error=1; launch(0,0); wait_result();
        if(!error_o || hmac_calls!=2 || aes_key_o!==0 || aes_iv_o!==0)
            $fatal(1,"Second HMAC failure did not clear all output material");
        acknowledge(); inject_second_error=0;
        pass("HMAC failure after the first digest clears key and IV");

        // CASE 5: Reset both modules while the controller is waiting to send.
        test_case=5;
        accept_hmac=0; launch(0,1); wait_hmac_request();
        // Both modules receive the same reset, so neither keeps the aborted job.
        reset_n_i=0; repeat(2) @(negedge clk_i);
        reset_n_i=1; accept_hmac=1;
        repeat(5) begin
            @(negedge clk_i);
            if(!req_ready_o || rsp_valid_o || hmac_req_valid_o || hmac_rsp_valid_i ||
               error_o || aes_key_o!==0 || aes_iv_o!==0)
                $fatal(1,"Stale work survived joint reset");
        end
        pass("joint reset aborts an in-flight request");

        // CASE 6: Another successful job proves the reset did not leave stale work.
        test_case=6;
        launch(0,1); check_success(5);
        pass("a fresh derivation succeeds after reset");
        successfully_completed=1;
        $display("ALL %0d KDFA PRACTICE CASES PASSED",case_count); $finish;
    end
    initial begin #100000; $fatal(1,"Global practice test timeout"); end
endmodule
