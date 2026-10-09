`timescale 1ns/1ps

// Wide RSA modular-exponentiation testbench. The Python driver writes one row
// to vectors.txt: base, exponent, modulus, expected result (hexadecimal).
module tb_rsa_modexp_vectors;

    parameter WIDTH = 2048;

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

    reg [WIDTH-1:0] vector_base;
    reg [WIDTH-1:0] vector_exponent;
    reg [WIDTH-1:0] vector_n;
    reg [WIDTH-1:0] vector_expected;

    integer vector_file;
    integer scan_count;
    integer cycles;
    integer failures;

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

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        start = 1'b0;
        base = {WIDTH{1'b0}};
        exponent = {WIDTH{1'b0}};
        n = {WIDTH{1'b0}};
        vector_base = {WIDTH{1'b0}};
        vector_exponent = {WIDTH{1'b0}};
        vector_n = {WIDTH{1'b0}};
        vector_expected = {WIDTH{1'b0}};
        failures = 0;

        repeat (2) @(negedge clk);
        rst_n = 1'b1;

        vector_file = $fopen("vectors.txt", "r");
        if (vector_file == 0) begin
            $display("FAIL: could not open vectors.txt");
            $finish;
        end

        scan_count = $fscanf(vector_file, "%h %h %h %h\n",
                             vector_base, vector_exponent, vector_n, vector_expected);
        $fclose(vector_file);

        if (scan_count != 4) begin
            $display("FAIL: expected one vector row in vectors.txt");
            failures = failures + 1;
        end else begin
            @(negedge clk);
            base = vector_base;
            exponent = vector_exponent;
            n = vector_n;
            start = 1'b1;

            @(negedge clk);
            start = 1'b0;

            // 2*WIDTH precomputation cycles, followed by 2*WIDTH+2
            // Montgomery products, each taking approximately WIDTH+3 cycles.
            cycles = 0;
            while ((done !== 1'b1) && (cycles < 9000000)) begin
                @(negedge clk);
                cycles = cycles + 1;
            end

            if (done !== 1'b1) begin
                $display("FAIL: timed out after %0d cycles", cycles);
                failures = failures + 1;
            end else if (error !== 1'b0) begin
                $display("FAIL: rsa_modexp rejected the valid wide vector");
                failures = failures + 1;
            end else if (result !== vector_expected) begin
                $display("FAIL: 2048-bit result mismatch");
                failures = failures + 1;
            end else begin
                $display("PASS: 2048-bit base^exponent mod n matched Python");
                $display("Completion cycles observed: %0d", cycles);
            end
        end

        if (failures == 0)
            $display("ALL 2048-BIT RSA MODEXP TESTS PASSED");
        else
            $display("2048-BIT RSA MODEXP TEST FAILED (%0d failure(s))", failures);
        $finish;
    end

    initial begin
        #120000000;
        $display("FAIL: global testbench timeout");
        $finish;
    end

endmodule
