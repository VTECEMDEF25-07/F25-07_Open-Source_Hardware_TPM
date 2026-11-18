`timescale 1ns/1ps
module tb_lenovo_aes_key_service;
    localparam [255:0] EXPECTED_KEY = 256'h3127189a1a42bcdcf45b4810b24d1c7ddd6c73cd5ea0053d34d5ae80db93bb22;
    reg clk=0, reset_n=0, request=0, consume=0, passed=0;
    reg [31:0] handle=32'h80000000;
    wire request_ready, reply_valid, key_ready;
    wire [255:0] key;
    wire [31:0] code;
    always #5 clk=~clk;
    lenovo_aes_key_service dut (
        .clock_i(clk), .reset_n_i(reset_n),
        .key_request_i(request), .key_request_ready_o(request_ready),
        .key_handle_i(handle), .key_reply_valid_o(reply_valid),
        .key_reply_ready_i(consume), .resolved_key_o(key),
        .key_reply_code_o(code), .key_ready_o(key_ready)
    );

    task automatic lookup(input [31:0] requested_handle, expected_code);
        begin
            @(negedge clk);
            handle=requested_handle;
            request=1;
            while (!request_ready) @(negedge clk);
            @(negedge clk);
            request=0;
            handle=~requested_handle;
            if (!reply_valid || code !== expected_code ||
                key !== (expected_code == 0 ? EXPECTED_KEY : 256'd0))
                $fatal(1,"Incorrect deterministic key lookup");
            repeat (5) begin
                @(negedge clk);
                if (!reply_valid || request_ready || code !== expected_code ||
                    key !== (expected_code == 0 ? EXPECTED_KEY : 256'd0))
                    $fatal(1,"Key reply changed under backpressure");
            end
            consume=1;
            @(negedge clk);
            consume=0;
            if (reply_valid || key !== 256'd0) $fatal(1,"Consumed reply leaked key");
        end
    endtask

    initial begin
        #2; reset_n=1;
        #3; reset_n=0;
        // Release exactly on a rising edge to exercise source startup ordering.
        #10; reset_n=1;
        repeat (20) @(negedge clk);
        reset_n=0;
        @(negedge clk);
        if (key_ready || reply_valid || key !== 0) $fatal(1,"Reset did not clear key service");
        reset_n=1;
        lookup(32'h80000000,0);
        lookup(32'h80000001,32'h18b);
        @(negedge clk);
        handle=32'h80000000; request=1;
        @(negedge clk);
        request=0;
        if (!reply_valid) $fatal(1,"Missing reply before reset");
        reset_n=0;
        @(negedge clk);
        if (key_ready || reply_valid || key !== 0) $fatal(1,"Reset retained an unconsumed key reply");
        reset_n=1;
        lookup(32'h80000000,0);
        passed=1;
        $display("LENOVO_AES_KEY_SERVICE_RESET_PASS");
        $finish;
    end
    initial begin #100000; $fatal(1,"Deterministic key service timeout"); end
endmodule
