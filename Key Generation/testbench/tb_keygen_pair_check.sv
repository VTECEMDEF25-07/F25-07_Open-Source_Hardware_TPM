`timescale 1ns/1ps
module tb_keygen_pair_check;
    reg clock_i = 0;
    always #10 clock_i = ~clock_i;
    reg reset_n_i = 0, start_valid_i = 0, result_ready_i = 0;
    reg [1023:0] p_i = 0, q_i = 0;
    wire start_ready_o, result_valid_o;
    wire [2047:0] n_o;
    wire [3:0] status_o;
    reg [8195:0] vectors [0:7];
    reg [2047:0] expected_n, expected_lambda, expected_d;
    reg [3:0] expected_status;
    integer case_index, cycles;
    reg check_d = 0;
    keygen_pair_check dut (
        .clock_i(clock_i), .reset_n_i(reset_n_i), .start_valid_i(start_valid_i),
        .start_ready_o(start_ready_o), .p_i(p_i), .q_i(q_i),
        .result_valid_o(result_valid_o), .result_ready_i(result_ready_i),
        .n_o(n_o), .status_o(status_o)
    );
    reg [31:0] observed_ram [0:511];
    reg [2047:0] observed_d, observed_lambda;
    reg d_checked=0;
    reg [8:0] observed_address;
    reg observed_read;
    integer reset_phase;
    // Observe accepted RAM traffic for both real implementations. Each read is
    // checked against independently tracked writes, including all operand limbs.
    always @(posedge clock_i) begin
        observed_read=reset_n_i && dut.ram_read_en;
        observed_address=dut.ram_read_address;
        if(reset_n_i && dut.ram_write_en)observed_ram[dut.ram_write_address]=dut.ram_write_data;
        #1;
        if(observed_read && dut.ram_read_data!==observed_ram[observed_address])
            $fatal(1,"RAM backend read mismatch address=%0d",observed_address);
    end
    always @(posedge clock_i) begin
        if(!reset_n_i || (start_valid_i && start_ready_o))d_checked<=0;
        if(reset_n_i && check_d && dut.state_reg==39)begin
            for(integer j=0;j<64;j++)begin observed_d[j*32+:32]=observed_ram[320+j];observed_lambda[j*32+:32]=observed_ram[192+j];end
            if(observed_lambda!==expected_lambda)$fatal(1,"LCM mismatch case=%0d",case_index);
            if(observed_d!==expected_d)$fatal(1,"canonical private exponent mismatch case=%0d",case_index);
            d_checked<=1;
        end
        if(reset_n_i && !result_valid_o && n_o!==0)$fatal(1,"early public result");
    end
    task assert_clean;
        begin
            if((dut.a_reg|dut.b_reg|dut.result_reg|dut.carry_reg|dut.mult_left_reg|dut.mult_right_reg|dut.accumulator_reg)!==0 ||
               dut.lambda_residue_reg!==0 || dut.k_reg!==0 || dut.k_residue_reg!==0 ||
               dut.d_remainder_reg!==0 || dut.mult_product!==0 || dut.ram_read_data!==0 ||
               {dut.common_shift_reg,dut.division_count_reg,dut.carry_bit_reg,dut.low_a_reg,dut.low_b_reg,
                dut.parity_bad_reg,dut.scalar_reg,dut.d_high_reg,dut.comparison_reg,dut.return_reg,
                dut.multiply_return_reg,dut.operation_reg,dut.constant_reg,dut.destination_reg,dut.source_a_reg,
                dut.source_b_reg,dut.multiply_a_reg,dut.multiply_b_reg,dut.multiply_n_reg,dut.index_reg,
                dut.length_reg,dut.b_length_reg,dut.row_reg,dut.column_reg,dut.word_bit_reg}!==0)
                $fatal(1,"private register or RAM output latch survived cleanup");
            for(integer j=0;j<512;j++)if(observed_ram[j]!==0)$fatal(1,"private RAM not swept address=%0d",j);
        end
    endtask
    task launch(input integer index);
        begin
            @(negedge clock_i);
            if (!start_ready_o) $fatal(1, "not ready");
            {p_i, q_i, expected_n, expected_lambda, expected_d, expected_status} = vectors[index];
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
            @(negedge clock_i); reset_n_i = 1;
            wait(start_ready_o);@(negedge clock_i);
            assert_clean();
        end
    endtask
    initial begin
        $readmemh("pair_vectors.mem", vectors);
        repeat (3) @(negedge clock_i);
        reset_n_i = 1;
        wait(start_ready_o);
        for (case_index = 0; case_index < 8; case_index = case_index + 1) begin
            check_d = 1;
            launch(case_index);
            cycles = 0;
            while (!result_valid_o && cycles < 10000000) begin @(negedge clock_i); cycles = cycles + 1; end
            if (!result_valid_o) $fatal(1, "pair timeout case=%0d state=%0d", case_index, dut.state_reg);
            if (status_o !== expected_status || n_o !== expected_n)
                $fatal(1, "pair mismatch case=%0d status=%0d expected=%0d", case_index, status_o, expected_status);
            if(case_index<4 && !d_checked)$fatal(1,"canonical d check never reached");
            $display("PASS pair case=%0d cycles=%0d",case_index,cycles);
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
        for (case_index = 0; case_index < 12; case_index = case_index + 1) begin
            case(case_index)
                0:reset_phase=4;1:reset_phase=60;2:reset_phase=51;3:reset_phase=52;
                4:reset_phase=14;5:reset_phase=21;6:reset_phase=23;7:reset_phase=30;
                8:reset_phase=31;9:reset_phase=37;10:reset_phase=39;11:reset_phase=0;
            endcase
            launch(0);
            cycles = 0;
            while (dut.state_reg != reset_phase && cycles < 10000000) begin
                @(negedge clock_i); cycles = cycles + 1;
            end
            if (dut.state_reg != reset_phase) $fatal(1, "reset phase not reached=%0d", case_index);
            reset_check();
        end
        launch(0);
        cycles = 0;
        while (!result_valid_o && cycles < 10000000) begin @(negedge clock_i); cycles = cycles + 1; end
        if (!result_valid_o || status_o !== 0 || n_o !== expected_n) $fatal(1, "post-reset valid generation");
        reset_check(); // Reset a held result, without ownership acceptance.
        $display("PASS pair check: 8 vectors, canonical d, stalls, cleanup, 12 busy reset phases, held-result reset");
        $finish;
    end
    initial begin #2000000000; $fatal(1, "global timeout"); end
endmodule
