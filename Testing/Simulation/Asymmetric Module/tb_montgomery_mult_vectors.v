`timescale 1ns/1ps

// Wide-vector testbench. The Python driver writes vectors.txt in the simulator
// working directory; each row contains a, b, n, and the expected result in hex.
module tb_montgomery_mult_vectors;

    parameter WIDTH = 2048;

    reg clk;
    reg rst_n;
    reg start;
    reg [WIDTH-1:0] a;
    reg [WIDTH-1:0] b;
    reg [WIDTH-1:0] n;

    wire [WIDTH-1:0] result;
    wire done;
    wire busy;

    reg [WIDTH-1:0] vector_a;
    reg [WIDTH-1:0] vector_b;
    reg [WIDTH-1:0] vector_n;
    reg [WIDTH-1:0] vector_expected;

    integer vector_file;
    integer scan_count;
    integer vector_count;
    integer cycles;
    integer failures;

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

    task run_vector;
        begin
            @(negedge clk);
            a = vector_a;
            b = vector_b;
            n = vector_n;
            start = 1'b1;

            @(negedge clk);
            start = 1'b0;

            cycles = 0;
            while ((done !== 1'b1) && (cycles < WIDTH + 4)) begin
                @(negedge clk);
                cycles = cycles + 1;
            end

            if (done !== 1'b1) begin
                $display("FAIL: vector %0d timed out", vector_count);
                failures = failures + 1;
            end else if (result !== vector_expected) begin
                $display("FAIL: vector %0d result mismatch", vector_count);
                failures = failures + 1;
            end else begin
                $display("PASS: 2048-bit vector %0d", vector_count);
            end

            @(negedge clk);
            if ((done !== 1'b0) || (busy !== 1'b0)) begin
                $display("FAIL: vector %0d completion handshake", vector_count);
                failures = failures + 1;
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        start = 1'b0;
        a = {WIDTH{1'b0}};
        b = {WIDTH{1'b0}};
        n = {WIDTH{1'b0}};
        vector_a = {WIDTH{1'b0}};
        vector_b = {WIDTH{1'b0}};
        vector_n = {WIDTH{1'b0}};
        vector_expected = {WIDTH{1'b0}};
        vector_count = 0;
        failures = 0;

        repeat (2) @(negedge clk);
        rst_n = 1'b1;

        vector_file = $fopen("vectors.txt", "r");
        if (vector_file == 0) begin
            $display("FAIL: could not open vectors.txt");
            $finish;
        end

        begin : READ_VECTORS
            while (!$feof(vector_file)) begin
                scan_count = $fscanf(vector_file, "%h %h %h %h\n",
                                     vector_a, vector_b, vector_n, vector_expected);
                if (scan_count == 4) begin
                    run_vector;
                    vector_count = vector_count + 1;
                end else if (!$feof(vector_file)) begin
                    $display("FAIL: malformed row in vectors.txt");
                    failures = failures + 1;
                    disable READ_VECTORS;
                end
            end
        end

        $fclose(vector_file);
        if (vector_count == 0) begin
            $display("FAIL: no vectors were read");
            failures = failures + 1;
        end

        if (failures == 0)
            $display("ALL 2048-BIT VECTORS PASSED (%0d cases)", vector_count);
        else
            $display("2048-BIT TEST FAILED (%0d failure(s), %0d cases)", failures, vector_count);
        $finish;
    end

    initial begin
        #100000000;
        $display("FAIL: global testbench timeout");
        $finish;
    end

endmodule
