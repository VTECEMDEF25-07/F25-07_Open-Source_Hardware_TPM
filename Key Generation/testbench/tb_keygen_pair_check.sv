`timescale 1ns/1ps
module tb_keygen_pair_check;
    reg clock_i = 0;
    always #10 clock_i = ~clock_i;
    reg reset_n_i = 0, start_valid_i = 0, result_ready_i = 0;
    reg [1023:0] p_i = 0, q_i = 0;
    wire start_ready_o, result_valid_o;
    wire [2047:0] n_o;
    wire [3:0] status_o;
    reg [6147:0] vectors [0:7];
    reg [2047:0] expected_n, expected_d;
    reg [3:0] expected_status;
    integer case_index, cycles;
    reg check_d = 0;
    keygen_pair_check dut (
        .clock_i(clock_i), .reset_n_i(reset_n_i), .start_valid_i(start_valid_i),
        .start_ready_o(start_ready_o), .p_i(p_i), .q_i(q_i),
        .result_valid_o(result_valid_o), .result_ready_i(result_ready_i),
        .n_o(n_o), .status_o(status_o)
    );
    always @(negedge clock_i) begin
        if (reset_n_i && check_d && dut.state_reg == 12 && dut.d_reg !== expected_d)
            $fatal(1, "canonical private exponent mismatch case=%0d", case_index);
        if (reset_n_i && !result_valid_o && n_o !== 0)
            $fatal(1, "public result visible before validated handoff");
    end
    task assert_clean;
        begin
            if ((dut.p_reg | dut.q_reg | dut.gcd_left_reg | dut.gcd_right_reg) !== 0 ||
                (dut.quotient_reg | dut.lambda_reg | dut.d_reg) !== 0 ||
                dut.remainder_reg !== 0 || dut.numerator_reg !== 0 || dut.lambda_shift_reg !== 0 ||
                dut.carry_reg !== 0 || dut.lambda_residue_reg !== 0 || dut.k_reg !== 0 ||
                dut.k_residue_reg !== 0 || dut.d_remainder_reg !== 0 || dut.mult_product !== 0)
                $fatal(1, "private intermediate survived cleanup");
        end
    endtask
    task launch(input integer index);
        begin
            @(negedge clock_i);
            if (!start_ready_o) $fatal(1, "not ready");
            {p_i, q_i, expected_n, expected_d, expected_status} = vectors[index];
            start_valid_i = 1;
            @(negedge clock_i);
            start_valid_i = 0;
            p_i = 0; q_i = 0; // Accepted inputs must have been captured.
        end
    endtask
    task consume;
        begin
            @(negedge clock_i); result_ready_i = 1;
            @(negedge clock_i); result_ready_i = 0;
            if (!start_ready_o || result_valid_o || n_o !== 0) $fatal(1, "result acknowledgment");
        end
    endtask
    task reset_check;
        begin
            @(negedge clock_i); reset_n_i = 0;
            #1;
            if (result_valid_o || start_ready_o || n_o !== 0) $fatal(1, "reset visibility");
            assert_clean();
            @(negedge clock_i); reset_n_i = 1;
            @(negedge clock_i);
            if (!start_ready_o) $fatal(1, "reset recovery");
        end
    endtask
    initial begin
        $readmemh("pair_vectors.mem", vectors);
        repeat (3) @(negedge clock_i);
        reset_n_i = 1;
        for (case_index = 0; case_index < 8; case_index = case_index + 1) begin
            check_d = 1;
            launch(case_index);
            cycles = 0;
            while (!result_valid_o && cycles < 100000) begin @(negedge clock_i); cycles = cycles + 1; end
            if (!result_valid_o) $fatal(1, "pair timeout case=%0d state=%0d", case_index, dut.state_reg);
            if (status_o !== expected_status || n_o !== expected_n)
                $fatal(1, "pair mismatch case=%0d status=%0d expected=%0d", case_index, status_o, expected_status);
            assert_clean();
            repeat (7) begin
                @(negedge clock_i);
                if (!result_valid_o || n_o !== expected_n || status_o !== expected_status || start_ready_o)
                    $fatal(1, "stalled output changed");
            end
            consume();
        end
        check_d = 0;
        // Abandon operation in each major arithmetic phase; next operation remains possible.
        for (case_index = 2; case_index <= 13; case_index = case_index + 1) begin
            launch(0);
            cycles = 0;
            while (dut.state_reg != case_index && cycles < 100000) begin
                @(negedge clock_i); cycles = cycles + 1;
            end
            if (dut.state_reg != case_index) $fatal(1, "reset phase not reached=%0d", case_index);
            reset_check();
        end
        launch(0);
        cycles = 0;
        while (!result_valid_o && cycles < 100000) begin @(negedge clock_i); cycles = cycles + 1; end
        if (!result_valid_o || status_o !== 0 || n_o !== expected_n) $fatal(1, "post-reset valid generation");
        reset_check(); // Reset a held result, without ownership acceptance.
        $display("PASS pair check: 8 vectors, canonical d, stalls, cleanup, 12 busy reset phases, held-result reset");
        $finish;
    end
    initial begin #40000000; $fatal(1, "global timeout"); end
endmodule
