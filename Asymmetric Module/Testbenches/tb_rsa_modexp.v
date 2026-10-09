`timescale 1ns/1ps

// Small-width self-checking testbench for rsa_modexp.
// The integer reference model is intended for WIDTH <= 10; default WIDTH=8.
module tb_rsa_modexp;

    parameter WIDTH = 8;

    reg clk;
    reg rst_n;
    reg start;
    reg [WIDTH-1:0] base;
    reg [WIDTH-1:0] exponent;
    reg [WIDTH-1:0] n;

    wire [WIDTH-1:0] result;
    wire done;
    wire busy;
    wire error;

    integer failures;
    integer test_count;
    integer random_seed;
    integer random_word;
    integer base_value;
    integer exponent_value;
    integer n_value;
    integer test_index;

    rsa_modexp #(
        .WIDTH(WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .base(base),
        .exponent(exponent),
        .n(n),
        .result(result),
        .done(done),
        .busy(busy),
        .error(error)
    );

    always #5 clk = ~clk;

    // Independent repeated-square reference, equivalent to Python pow(base,e,n).
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
        input [WIDTH-1:0] base_in;
        input [WIDTH-1:0] exponent_in;
        input [WIDTH-1:0] modulus_in;
        reg [WIDTH-1:0] expected;
        integer cycles;
        integer max_cycles;
        begin
            expected = reference_pow(base_in, exponent_in, modulus_in);
            max_cycles = (2*WIDTH + 2) * (WIDTH + 5) + 2*WIDTH + 10;

            @(negedge clk);
            base = base_in;
            exponent = exponent_in;
            n = modulus_in;
            start = 1'b1;

            @(negedge clk);
            start = 1'b0;

            cycles = 0;
            while ((done !== 1'b1) && (cycles < max_cycles)) begin
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
            end else if (error !== 1'b0) begin
                $display("FAIL: unexpected error (test %0d)", test_count);
                failures = failures + 1;
            end else if (result !== expected) begin
                $display("FAIL: test %0d base=%0d exponent=%0d n=%0d expected=%0d got=%0d",
                         test_count, base_in, exponent_in, modulus_in, expected, result);
                failures = failures + 1;
            end else begin
                $display("PASS: test %0d base=%0d exponent=%0d n=%0d result=%0d",
                         test_count, base_in, exponent_in, modulus_in, result);
            end

            test_count = test_count + 1;
            @(negedge clk);
            if ((done !== 1'b0) || (busy !== 1'b0) || (error !== 1'b0)) begin
                $display("FAIL: completion/status signals did not return inactive");
                failures = failures + 1;
            end
        end
    endtask

    task run_invalid_case;
        input [WIDTH-1:0] base_in;
        input [WIDTH-1:0] exponent_in;
        input [WIDTH-1:0] modulus_in;
        begin
            @(negedge clk);
            base = base_in;
            exponent = exponent_in;
            n = modulus_in;
            start = 1'b1;

            @(negedge clk);
            start = 1'b0;

            if ((done !== 1'b1) || (error !== 1'b1) ||
                (busy !== 1'b0) || (result !== {WIDTH{1'b0}})) begin
                $display("FAIL: invalid input was not rejected (test %0d)", test_count);
                failures = failures + 1;
            end else begin
                $display("PASS: invalid input rejected (test %0d)", test_count);
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
            max_cycles = (2*WIDTH + 2) * (WIDTH + 5) + 2*WIDTH + 10;

            @(negedge clk);
            base = 8'd7;
            exponent = 8'd9;
            n = 8'd13;
            start = 1'b1;

            // Change live inputs and pulse start while the first request is busy.
            @(negedge clk);
            start = 1'b1;
            base = 8'd3;
            exponent = 8'd4;
            n = 8'd5;

            @(negedge clk);
            start = 1'b0;

            cycles = 0;
            while ((done !== 1'b1) && (cycles < max_cycles)) begin
                @(negedge clk);
                cycles = cycles + 1;
            end

            if ((done !== 1'b1) || (error !== 1'b0) || (result !== expected)) begin
                $display("FAIL: start while busy changed or restarted the active request");
                failures = failures + 1;
            end else begin
                $display("PASS: start while busy is ignored and inputs were latched");
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
            base = 8'd7;
            exponent = 8'd9;
            n = 8'd13;
            start = 1'b1;

            @(negedge clk);
            start = 1'b0;
            repeat (2) @(negedge clk);
            rst_n = 1'b0;

            @(negedge clk);
            if ((busy !== 1'b0) || (done !== 1'b0) || (error !== 1'b0) ||
                (result !== {WIDTH{1'b0}})) begin
                $display("FAIL: reset did not clear status/result mid-operation");
                failures = failures + 1;
            end else begin
                $display("PASS: reset aborts the active operation and clears outputs");
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
        base = {WIDTH{1'b0}};
        exponent = {WIDTH{1'b0}};
        n = {WIDTH{1'b0}};
        failures = 0;
        test_count = 0;
        random_seed = 32'h2468ACE1;

        repeat (2) @(negedge clk);
        rst_n = 1'b1;

        // Deterministic functional cases, including exponent zero and boundaries.
        run_case(8'd7,   8'd9,   8'd13);
        run_case(8'd7,   8'd0,   8'd13);
        run_case(8'd0,   8'd7,   8'd13);
        run_case(8'd12,  8'd2,   8'd13);
        run_case(8'd12,  8'd3,   8'd13);
        run_case(8'd2,   8'd255, 8'd3);
        run_busy_start_case;

        // Random valid operands and odd moduli.
        for (test_index = 0; test_index < 20; test_index = test_index + 1) begin
            random_word = $random(random_seed);
            n_value = 3 + ((random_word & 32'h7fffffff) % 127);
            if ((n_value & 1) == 0)
                n_value = n_value + 1;

            random_word = $random(random_seed);
            base_value = (random_word & 32'h7fffffff) % n_value;
            random_word = $random(random_seed);
            exponent_value = random_word & 32'h000000ff;

            run_case(base_value[WIDTH-1:0], exponent_value[WIDTH-1:0], n_value[WIDTH-1:0]);
        end

        // The module promises explicit error completion for these bad inputs.
        run_invalid_case(8'd1, 8'd3, 8'd1);
        run_invalid_case(8'd1, 8'd3, 8'd10);
        run_invalid_case(8'd13, 8'd3, 8'd13);

        run_reset_mid_operation_case;
        run_case(8'd7, 8'd9, 8'd13);

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
