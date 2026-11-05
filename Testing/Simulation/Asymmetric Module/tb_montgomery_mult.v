`timescale 1ns/1ps

// Self-checking small-width testbench for montgomery_mult.
// The integer reference model is intended for WIDTH <= 10; default WIDTH=8.
module tb_montgomery_mult;

    parameter WIDTH = 8;

    reg clk;
    reg rst_n;
    reg start;
    reg [WIDTH-1:0] a;
    reg [WIDTH-1:0] b;
    reg [WIDTH-1:0] n;

    wire [WIDTH-1:0] result;
    wire done;
    wire busy;

    integer failures;
    integer test_count;
    integer random_seed;
    integer random_word;
    integer n_value;
    integer a_value;
    integer b_value;
    integer test_index;

    montgomery_mult #(
        .WIDTH(WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .a(a),
        .b(b),
        .n(n),
        .result(result),
        .done(done),
        .busy(busy)
    );

    always #5 clk = ~clk;

    // Independent mathematical reference: a*b*(2^WIDTH)^-1 mod n.
    // For this testbench's default 8-bit width, intermediate integers fit
    // safely in a Verilog integer.
    function integer montgomery_reference;
        input [WIDTH-1:0] a_in;
        input [WIDTH-1:0] b_in;
        input [WIDTH-1:0] n_in;
        integer a_integer;
        integer b_integer;
        integer n_integer;
        integer r_value;
        integer candidate;
        integer inverse;
        begin
            a_integer = {{(32-WIDTH){1'b0}}, a_in};
            b_integer = {{(32-WIDTH){1'b0}}, b_in};
            n_integer = {{(32-WIDTH){1'b0}}, n_in};
            r_value = 1 << WIDTH;
            inverse = -1;

            for (candidate = 1; candidate < n_integer; candidate = candidate + 1) begin
                if (((r_value % n_integer) * candidate % n_integer) == 1)
                    inverse = candidate;
            end

            if (inverse < 0)
                montgomery_reference = -1;
            else
                montgomery_reference = (((a_integer * b_integer) % n_integer) * inverse) % n_integer;
        end
    endfunction

    task run_case;
        input [WIDTH-1:0] a_value_in;
        input [WIDTH-1:0] b_value_in;
        input [WIDTH-1:0] n_value_in;
        integer expected_value;
        integer cycles;
        begin
            expected_value = montgomery_reference(a_value_in, b_value_in, n_value_in);

            @(negedge clk);
            a = a_value_in;
            b = b_value_in;
            n = n_value_in;
            start = 1'b1;

            @(negedge clk);
            start = 1'b0;

            cycles = 0;
            while ((done !== 1'b1) && (cycles < WIDTH + 4)) begin
                if (busy !== 1'b1) begin
                    $display("FAIL: busy dropped before completion (test %0d)", test_count);
                    failures = failures + 1;
                end
                @(negedge clk);
                cycles = cycles + 1;
            end

            if (done !== 1'b1) begin
                $display("FAIL: timeout waiting for done (test %0d)", test_count);
                failures = failures + 1;
            end else if (expected_value < 0) begin
                $display("FAIL: reference inverse not found (test %0d)", test_count);
                failures = failures + 1;
            end else if (result !== expected_value[WIDTH-1:0]) begin
                $display("FAIL: test %0d a=%0d b=%0d n=%0d expected=%0d got=%0d",
                         test_count, a_value_in, b_value_in, n_value_in,
                         expected_value, result);
                failures = failures + 1;
            end else begin
                $display("PASS: test %0d a=%0d b=%0d n=%0d result=%0d",
                         test_count, a_value_in, b_value_in, n_value_in, result);
            end

            test_count = test_count + 1;
            @(negedge clk);
            if ((done !== 1'b0) || (busy !== 1'b0)) begin
                $display("FAIL: done was not a one-cycle pulse or busy stayed high");
                failures = failures + 1;
            end
        end
    endtask

    task run_busy_start_case;
        integer expected_value;
        integer cycles;
        begin
            expected_value = montgomery_reference(8'd7, 8'd9, 8'd13);

            @(negedge clk);
            a = 7;
            b = 9;
            n = 13;
            start = 1'b1;

            // Change the live inputs and pulse start while the first operation
            // is busy. The accepted operation must still use its latched inputs.
            @(negedge clk);
            start = 1'b1;
            a = 3;
            b = 4;
            n = 5;

            @(negedge clk);
            start = 1'b0;

            cycles = 0;
            while ((done !== 1'b1) && (cycles < WIDTH + 4)) begin
                @(negedge clk);
                cycles = cycles + 1;
            end

            if ((done !== 1'b1) || (result !== expected_value[WIDTH-1:0])) begin
                $display("FAIL: start while busy changed or restarted the active operation");
                failures = failures + 1;
            end else begin
                $display("PASS: start while busy is ignored; operands were latched");
            end
            test_count = test_count + 1;

            @(negedge clk);
            if (done !== 1'b0) begin
                $display("FAIL: busy-start case done pulse lasted more than one cycle");
                failures = failures + 1;
            end
        end
    endtask

    task run_reset_mid_operation_case;
        begin
            @(negedge clk);
            a = 7;
            b = 9;
            n = 13;
            start = 1'b1;

            @(negedge clk);
            start = 1'b0;
            repeat (2) @(negedge clk);
            rst_n = 1'b0;

            @(negedge clk);
            if ((busy !== 1'b0) || (done !== 1'b0) || (result !== {WIDTH{1'b0}})) begin
                $display("FAIL: reset did not clear control and result state mid-operation");
                failures = failures + 1;
            end else begin
                $display("PASS: reset aborts an in-flight operation and clears outputs");
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
        a = {WIDTH{1'b0}};
        b = {WIDTH{1'b0}};
        n = {WIDTH{1'b0}};
        failures = 0;
        test_count = 0;
        random_seed = 32'h13579BDF;

        repeat (2) @(negedge clk);
        rst_n = 1'b1;

        // Sanity, zero, smallest valid modulus, and near-boundary operands.
        run_case(8'd7,   8'd9,   8'd13);
        run_case(8'd0,   8'd12,  8'd13);
        run_case(8'd12,  8'd12,  8'd13);
        run_case(8'd2,   8'd2,   8'd3);
        run_case(8'd254, 8'd254, 8'd255);
        run_busy_start_case;

        // Deterministic randomized cases with valid Montgomery operands.
        for (test_index = 0; test_index < 40; test_index = test_index + 1) begin
            random_word = $random(random_seed);
            n_value = 3 + ((random_word & 32'h7fffffff) % 127);
            if ((n_value & 1) == 0)
                n_value = n_value + 1;

            random_word = $random(random_seed);
            a_value = (random_word & 32'h7fffffff) % n_value;
            random_word = $random(random_seed);
            b_value = (random_word & 32'h7fffffff) % n_value;

            run_case(a_value[WIDTH-1:0], b_value[WIDTH-1:0], n_value[WIDTH-1:0]);
        end

        run_reset_mid_operation_case;
        run_case(8'd7, 8'd9, 8'd13);

        if (failures == 0)
            $display("ALL TESTS PASSED (%0d cases)", test_count);
        else
            $display("TESTS FAILED: %0d failure(s) across %0d cases", failures, test_count);
        $finish;
    end

    initial begin
        #100000;
        $display("FAIL: global testbench timeout");
        $finish;
    end

endmodule
