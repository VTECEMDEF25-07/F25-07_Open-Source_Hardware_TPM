// Filename: tb_keygen_test_source.sv
// Modules: tb_keygen_test_source
// Authors: Project contributors; see Git history.
// Date: 2026-10-13
// General Description: Checks keygen test source behavior and reports failures.
// AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

`timescale 1ns/1ps
module tb_keygen_test_source;
    reg clock_i = 0;
    always #10 clock_i = ~clock_i;
    reg reset_n_i = 0, start_valid_i = 0, word_ready_i = 0;
    reg [255:0] seed_i = 0;
    wire start_ready_o, word_valid_o, failed_o;
    wire [31:0] data_o;
    reg [31:0] expected_words [0:679];
    reg [255:0] seeds [0:21];
    integer seed_index, word_index, schedule_index, wait_count;
    keygen_test_source dut (
        .clock_i(clock_i), .reset_n_i(reset_n_i), .start_valid_i(start_valid_i),
        .start_ready_o(start_ready_o), .seed_i(seed_i), .word_valid_o(word_valid_o),
        .word_ready_i(word_ready_i), .data_o(data_o), .failed_o(failed_o)
    );
    task assert_clean;
        begin
            if ((dut.seed_reg | dut.digest_reg) !== 0 || dut.counter_reg !== 0 ||
                (dut.a_reg | dut.b_reg | dut.c_reg | dut.d_reg | dut.e_reg | dut.f_reg | dut.g_reg | dut.h_reg) !== 0)
                $fatal(1, "seed/digest/compression state survived reset");
            for (schedule_index=0; schedule_index<16; schedule_index=schedule_index+1)
                if (dut.schedule_reg[schedule_index] !== 0) $fatal(1, "schedule survived reset");
        end
    endtask
    task reset_source;
        begin
            @(negedge clock_i); reset_n_i = 0; start_valid_i = 0; word_ready_i = 0;
            #1;
            if (start_ready_o || word_valid_o || failed_o || data_o !== 0) $fatal(1, "reset interface");
            assert_clean();
            @(negedge clock_i); reset_n_i = 1;
            @(negedge clock_i);
            if (!start_ready_o) $fatal(1, "source not ready after reset");
        end
    endtask
    task launch(input [255:0] seed);
        begin
            @(negedge clock_i); seed_i = seed; start_valid_i = 1;
            @(negedge clock_i); seed_i = ~seed; start_valid_i = 0;
            if (start_ready_o) $fatal(1, "source accepted another stream");
        end
    endtask
    task take_word(input [31:0] expected, input integer stalls);
        reg [63:0] held_counter;
        begin
            wait_count = 0;
            while (!word_valid_o && wait_count < 100) begin @(negedge clock_i); wait_count = wait_count + 1; end
            if (!word_valid_o || failed_o || data_o !== expected)
                $fatal(1, "word mismatch seed=%0d word=%0d actual=%h expected=%h", seed_index, word_index, data_o, expected);
            held_counter = dut.counter_reg;
            repeat (stalls) begin
                @(negedge clock_i);
                if (!word_valid_o || data_o !== expected || dut.counter_reg !== held_counter)
                    $fatal(1, "word or counter changed under backpressure");
            end
            word_ready_i = 1;
            @(negedge clock_i); word_ready_i = 0;
            if (start_ready_o) $fatal(1, "stream rearmed without reset");
        end
    endtask
    initial begin
        $readmemh("source_words.mem", expected_words);
        $readmemh("source_seeds.mem", seeds);
        for (seed_index=0; seed_index<20; seed_index=seed_index+1) begin
            reset_source(); launch(seeds[seed_index]);
            for (word_index=0; word_index<32; word_index=word_index+1)
                take_word(expected_words[seed_index*32+word_index], (word_index*7+seed_index)%5);
        end
        // Frozen benchmark seeds have zero high bytes; challenge every captured seed byte too.
        for (seed_index=20; seed_index<22; seed_index=seed_index+1) begin
            reset_source(); launch(seeds[seed_index]);
            for (word_index=0; word_index<8; word_index=word_index+1)
                take_word(expected_words[664+(seed_index-20)*8+word_index], word_index%3);
        end
        // Reset and replay the same context with a different stall pattern.
        reset_source(); launch(seeds[0]);
        for (word_index=0; word_index<32; word_index=word_index+1) take_word(expected_words[word_index], 0);
        // Capture occurs once: a second start with another seed is ignored while streaming.
        reset_source(); launch(seeds[0]);
        @(negedge clock_i); seed_i = seeds[19]; start_valid_i = 1;
        repeat (5) @(negedge clock_i);
        start_valid_i = 0;
        take_word(expected_words[0], 3);
        // Reset in compression, then regenerate the original first word.
        reset_source(); launch(seeds[0]); repeat (9) @(negedge clock_i);
        reset_source(); launch(seeds[0]); take_word(expected_words[0], 0);
        // Reset while an output word is stalled.
        while (!word_valid_o) @(negedge clock_i);
        reset_source(); launch(seeds[0]); take_word(expected_words[0], 4);
        // Inject only counter position to reach otherwise impractical carry/overflow cases.
        reset_source(); launch(seeds[0]); dut.counter_reg = 64'h00000000ffffffff;
        for (word_index=0; word_index<16; word_index=word_index+1) take_word(expected_words[640+word_index], 2);
        if (dut.counter_reg !== 64'h0000000100000001) $fatal(1, "64-bit counter carry");
        reset_source(); launch(seeds[0]); dut.counter_reg = 64'hffffffffffffffff;
        for (word_index=0; word_index<8; word_index=word_index+1) take_word(expected_words[656+word_index], 1);
        repeat (3) @(negedge clock_i);
        if (!failed_o || word_valid_o || start_ready_o || data_o !== 0) $fatal(1, "overflow not latched");
        assert_clean();
        reset_source(); launch(seeds[0]); take_word(expected_words[0], 0);
        $display("PASS test source: 20 seeds x 4 blocks, full-width seeds, stall replay, capture, reset, counter carry and overflow");
        $finish;
    end
    initial begin #1000000; $fatal(1, "global timeout"); end
endmodule
