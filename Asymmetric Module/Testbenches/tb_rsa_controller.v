`timescale 1ns/1ps

// Small-width self-checking testbench for the RSA request controller.
// The integer reference is intended for WIDTH <= 10; default WIDTH=8.
module tb_rsa_controller;

    parameter WIDTH = 8;

    reg clk;
    reg rst_n;
    reg start;
    reg use_private_key;
    reg [WIDTH-1:0] representative;
    reg [WIDTH-1:0] modulus;
    reg [WIDTH-1:0] public_exponent;
    reg [WIDTH-1:0] private_exponent;

    wire [WIDTH-1:0] result;
    wire done;
    wire busy;
    wire error;

    integer failures;
    integer test_count;
    integer random_seed;
    integer random_word;
    integer representative_value;
    integer public_exponent_value;
    integer private_exponent_value;
    integer modulus_value;
    integer test_index;

    rsa_controller #(
        .WIDTH(WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .use_private_key(use_private_key),
        .representative(representative),
        .modulus(modulus),
        .public_exponent(public_exponent),
        .private_exponent(private_exponent),
        .result(result),
        .done(done),
        .busy(busy),
        .error(error)
    );

    always #5 clk = ~clk;

    function [WIDTH-1:0] reference_pow;
        input [WIDTH-1:0] base_in;
        input [WIDTH-1:0] exponent_in;
        input [WIDTH-1:0] modulus_in;
        integer base_integer;
        integer exponent_integer;
        integer modulus_integer;
        integer result_integer;
        begin
            base_integer = {{(32-WIDTH){1'b0}}, base_in};
            exponent_integer = {{(32-WIDTH){1'b0}}, exponent_in};
            modulus_integer = {{(32-WIDTH){1'b0}}, modulus_in};

            result_integer = 1 % modulus_integer;
            base_integer = base_integer % modulus_integer;
            while (exponent_integer > 0) begin
                if (exponent_integer[0])
                    result_integer = (result_integer * base_integer) % modulus_integer;
                base_integer = (base_integer * base_integer) % modulus_integer;
                exponent_integer = exponent_integer >> 1;
            end

            reference_pow = result_integer[WIDTH-1:0];
        end
    endfunction

    task run_case;
        input private_key;
        input [WIDTH-1:0] representative_in;
        input [WIDTH-1:0] public_exponent_in;
        input [WIDTH-1:0] private_exponent_in;
        input [WIDTH-1:0] modulus_in;
        reg [WIDTH-1:0] selected_exponent;
        reg [WIDTH-1:0] expected;
        integer cycles;
        integer max_cycles;
        begin
            if (private_key)
                selected_exponent = private_exponent_in;
            else
                selected_exponent = public_exponent_in;
            expected = reference_pow(representative_in, selected_exponent, modulus_in);
            max_cycles = (2*WIDTH + 2) * (WIDTH + 6) + 2*WIDTH + 20;

            @(negedge clk);
            use_private_key = private_key;
            representative = representative_in;
            public_exponent = public_exponent_in;
            private_exponent = private_exponent_in;
            modulus = modulus_in;
            start = 1'b1;

            @(negedge clk);
            start = 1'b0;

            cycles = 0;
            while ((done !== 1'b1) && (cycles < max_cycles)) begin
                if (busy !== 1'b1) begin
                    $display("FAIL: controller busy dropped early (test %0d)", test_count);
                    failures = failures + 1;
                end
                @(negedge clk);
                cycles = cycles + 1;
            end

            if (done !== 1'b1) begin
                $display("FAIL: controller timeout (test %0d)", test_count);
                failures = failures + 1;
            end else if (error !== 1'b0) begin
                $display("FAIL: unexpected controller error (test %0d)", test_count);
                failures = failures + 1;
            end else if (result !== expected) begin
                $display("FAIL: test %0d private=%0d representative=%0d exponent=%0d n=%0d expected=%0d got=%0d",
                         test_count, private_key, representative_in, selected_exponent,
                         modulus_in, expected, result);
                failures = failures + 1;
            end else begin
                $display("PASS: test %0d private=%0d representative=%0d exponent=%0d n=%0d result=%0d",
                         test_count, private_key, representative_in, selected_exponent,
                         modulus_in, result);
            end

            test_count = test_count + 1;
            @(negedge clk);
            if ((done !== 1'b0) || (busy !== 1'b0) || (error !== 1'b0)) begin
                $display("FAIL: controller status did not return inactive");
                failures = failures + 1;
            end
        end
    endtask

    task run_invalid_case;
        input [WIDTH-1:0] representative_in;
        input [WIDTH-1:0] modulus_in;
        integer cycles;
        begin
            @(negedge clk);
            use_private_key = 1'b0;
            representative = representative_in;
            modulus = modulus_in;
            public_exponent = 8'd17;
            private_exponent = 8'd7;
            start = 1'b1;

            @(negedge clk);
            start = 1'b0;

            cycles = 0;
            while ((done !== 1'b1) && (cycles < 8)) begin
                @(negedge clk);
                cycles = cycles + 1;
            end

            if ((done !== 1'b1) || (error !== 1'b1) ||
                (busy !== 1'b0) || (result !== {WIDTH{1'b0}})) begin
                $display("FAIL: controller did not forward invalid-input status (test %0d)", test_count);
                failures = failures + 1;
            end else begin
                $display("PASS: invalid-input status forwarded (test %0d)", test_count);
            end
            test_count = test_count + 1;

            @(negedge clk);
            if ((done !== 1'b0) || (error !== 1'b0)) begin
                $display("FAIL: invalid-input status was not a one-cycle pulse");
                failures = failures + 1;
            end
        end
    endtask

    task run_busy_start_case;
        reg [WIDTH-1:0] expected;
        integer cycles;
        integer max_cycles;
        begin
            expected = reference_pow(8'd7, 8'd9, 8'd13);
            max_cycles = (2*WIDTH + 2) * (WIDTH + 6) + 2*WIDTH + 20;

            @(negedge clk);
            use_private_key = 1'b0;
            representative = 8'd7;
            public_exponent = 8'd9;
            private_exponent = 8'd4;
            modulus = 8'd13;
            start = 1'b1;

            @(negedge clk);
            start = 1'b1;
            use_private_key = 1'b1;
            representative = 8'd3;
            public_exponent = 8'd2;
            private_exponent = 8'd4;
            modulus = 8'd5;

            @(negedge clk);
            start = 1'b0;

            cycles = 0;
            while ((done !== 1'b1) && (cycles < max_cycles)) begin
                @(negedge clk);
                cycles = cycles + 1;
            end

            if ((done !== 1'b1) || (error !== 1'b0) || (result !== expected)) begin
                $display("FAIL: start while busy altered/restarted the accepted request");
                failures = failures + 1;
            end else begin
                $display("PASS: busy start ignored; selected exponent and operands stayed latched");
            end
            test_count = test_count + 1;

            @(negedge clk);
            if (done !== 1'b0) begin
                $display("FAIL: busy-start done pulse lasted more than one cycle");
                failures = failures + 1;
            end
        end
    endtask

    task run_reset_mid_operation_case;
        begin
            @(negedge clk);
            use_private_key = 1'b1;
            representative = 8'd7;
            public_exponent = 8'd17;
            private_exponent = 8'd9;
            modulus = 8'd13;
            start = 1'b1;

            @(negedge clk);
            start = 1'b0;
            repeat (2) @(negedge clk);
            rst_n = 1'b0;

            @(negedge clk);
            if ((busy !== 1'b0) || (done !== 1'b0) || (error !== 1'b0) ||
                (result !== {WIDTH{1'b0}})) begin
                $display("FAIL: reset did not clear controller status/result");
                failures = failures + 1;
            end else begin
                $display("PASS: reset aborts controller request and clears outputs");
            end
            test_count = test_count + 1;

            rst_n = 1'b1;
            @(negedge clk);
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        start = 1'b0;
        use_private_key = 1'b0;
        representative = {WIDTH{1'b0}};
        modulus = {WIDTH{1'b0}};
        public_exponent = {WIDTH{1'b0}};
        private_exponent = {WIDTH{1'b0}};
        failures = 0;
        test_count = 0;
        random_seed = 32'h10293847;

        repeat (2) @(negedge clk);
        rst_n = 1'b1;

        // Public and private exponent paths use different exponents.
        run_case(1'b0, 8'd7, 8'd9, 8'd4, 8'd13);
        run_case(1'b1, 8'd7, 8'd9, 8'd4, 8'd13);
        run_case(1'b0, 8'd42, 8'd17, 8'd7, 8'd55);
        run_case(1'b1, 8'd42, 8'd17, 8'd7, 8'd55);
        run_case(1'b1, 8'd0, 8'd17, 8'd0, 8'd13);
        run_busy_start_case;

        // Random valid representatives with independently selected exponents.
        for (test_index = 0; test_index < 12; test_index = test_index + 1) begin
            random_word = $random(random_seed);
            modulus_value = 3 + ((random_word & 32'h7fffffff) % 127);
            if ((modulus_value & 1) == 0)
                modulus_value = modulus_value + 1;

            random_word = $random(random_seed);
            representative_value = (random_word & 32'h7fffffff) % modulus_value;
            random_word = $random(random_seed);
            public_exponent_value = random_word & 32'h000000ff;
            random_word = $random(random_seed);
            private_exponent_value = random_word & 32'h000000ff;

            run_case(test_index[0], representative_value[WIDTH-1:0],
                     public_exponent_value[WIDTH-1:0], private_exponent_value[WIDTH-1:0],
                     modulus_value[WIDTH-1:0]);
        end

        run_invalid_case(8'd4, 8'd10);
        run_invalid_case(8'd1, 8'd1);
        run_invalid_case(8'd13, 8'd13);
        run_reset_mid_operation_case;
        run_case(1'b0, 8'd7, 8'd9, 8'd4, 8'd13);

        if (failures == 0)
            $display("ALL TESTS PASSED (%0d cases)", test_count);
        else
            $display("TESTS FAILED: %0d failure(s) across %0d cases", failures, test_count);
        $finish;
    end

    initial begin
        #10000000;
        $display("FAIL: global testbench timeout");
        $finish;
    end

endmodule
