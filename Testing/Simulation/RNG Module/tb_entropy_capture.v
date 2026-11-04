// ===========================================================================
// tb_entropy_capture.v
//
// Testbench for the SP 800-90B capture path (entropy_source + entropy_capture)
// with small sizes so it runs quickly:
//   - ping returns 'K'
//   - 'S' sends back exactly the consecutive samples the source produced
//   - 'R' does the right number of restarts, records the right number of
//     samples after each one (only after warm-up), and sends them in order
//
// Run (Icarus):
//   iverilog -g2005 -s tb_entropy_capture -o simcap tb_entropy_capture.v \
//       entropy_capture.v uart.v entropy_source.v ring_osc.v
//   vvp -n simcap
// In Quartus: same NativeLink setup as tb_tpm2_get_random, with this file
// and tb_entropy_capture as the test bench.
//
// Written by Jungyeon Won with the help of generative AI
// ===========================================================================
`timescale 1ns/1ps
 
module tb_entropy_capture;
 
    localparam integer CPB       = 8;    // clocks per UART bit (fast sim)
    localparam integer SEQ_BYTES = 64;
    localparam integer RESTARTS  = 5;
    localparam integer RS        = 16;   // samples per restart
    localparam integer OFF       = 20;
 
    reg clk = 1'b0;
    always #5 clk = ~clk;
    reg rst_n = 1'b0;
 
    reg  pc_tx = 1'b1;       // PC -> FPGA
    wire fpga_tx;            // FPGA -> PC
    wire src_en, raw, raw_v, busy;
 
    entropy_source u_src (
        .clk(clk), .rst_n(rst_n), .enable(src_en),
        .entropy_output(), .entropy_valid(),
        .raw_sample(raw), .raw_sample_valid(raw_v)
    );
 
    entropy_capture #(
        .CLKS_PER_BIT(CPB), .SEQ_BYTES(SEQ_BYTES), .RESTARTS(RESTARTS),
        .RESTART_SAMPLES(RS), .OFF_CYCLES(OFF), .ADDR_W(7)
    ) u_cap (
        .clk(clk), .rst_n(rst_n), .uart_rx(pc_tx), .uart_tx(fpga_tx),
        .source_enable(src_en), .raw_sample(raw), .raw_sample_valid(raw_v),
        .busy(busy)
    );
 
    integer errors = 0;
    reg [8*40:1] current_test = "reset";   // view with radix ASCII
 
    // ---- Record every sample the capture actually takes (reference) ----
    reg     ref_bits [0:4095];
    integer ref_count = 0;
    reg     recording = 1'b0;
    always @(posedge clk)
        if (recording && u_cap.state == 3'd1 && raw_v) begin
            ref_bits[ref_count] = raw;
            ref_count = ref_count + 1;
        end
 
    // ---- Count restarts and samples per restart ----
    integer restarts_seen = 0, samples_this_run = 0, bad_rows = 0;
    integer since_en = 0, early = 0;
    reg     src_en_d = 1'b1;
    always @(posedge clk) begin
        since_en = src_en ? since_en + 1 : 0;
        if (recording) begin
            if (src_en && !src_en_d) begin                // rings restarted
                restarts_seen    = restarts_seen + 1;
                samples_this_run = 0;
            end
            // No sample may be taken during the 8-cycle warm-up.
            if (u_cap.state == 3'd1 && raw_v && since_en <= 8) early = early + 1;
            if (u_cap.state == 3'd1 && raw_v)
                samples_this_run = samples_this_run + 1;
            if (!src_en && src_en_d && current_test == "restart") begin
                if (samples_this_run != RS && restarts_seen > 0) bad_rows = bad_rows + 1;
            end
        end
        src_en_d <= src_en;
    end
 
    // ---- UART receiver model (PC side) ----
    reg [7:0] rx_bytes [0:1023];
    integer   rx_count = 0;
    integer   b;
    reg [7:0] byte_in;
    always begin
        @(negedge fpga_tx);
        repeat (CPB / 2) @(posedge clk);                 // middle of start bit
        for (b = 0; b < 8; b = b + 1) begin
            repeat (CPB) @(posedge clk);
            byte_in[b] = fpga_tx;
        end
        repeat (CPB) @(posedge clk);                     // stop bit
        if (fpga_tx !== 1'b1) begin
            $display("  FAIL bad stop bit"); errors = errors + 1;
        end
        rx_bytes[rx_count] = byte_in;
        rx_count = rx_count + 1;
    end
 
    // ---- UART transmitter model (PC side) ----
    task send_byte;
        input [7:0] d;
        integer i;
        begin
            @(negedge clk); pc_tx = 1'b0;
            repeat (CPB) @(negedge clk);
            for (i = 0; i < 8; i = i + 1) begin
                pc_tx = d[i];
                repeat (CPB) @(negedge clk);
            end
            pc_tx = 1'b1;
            repeat (CPB) @(negedge clk);
        end
    endtask
 
    task wait_bytes;
        input integer n;
        integer guard;
        begin
            guard = 0;
            while (rx_count < n && guard < 200000) begin
                @(posedge clk); guard = guard + 1;
            end
            repeat (4 * CPB) @(posedge clk);             // let it settle
            while (busy) @(posedge clk);
        end
    endtask
 
    // Compare received bytes with the reference samples, MSB = earliest.
    task compare;
        input integer nbytes;
        integer i, k, mism;
        begin
            mism = 0;
            if (ref_count != nbytes * 8) begin
                $display("  FAIL captured %0d samples, expected %0d", ref_count, nbytes * 8);
                errors = errors + 1;
            end
            if (rx_count != nbytes) begin
                $display("  FAIL received %0d bytes, expected %0d", rx_count, nbytes);
                errors = errors + 1;
            end
            for (i = 0; i < nbytes; i = i + 1)
                for (k = 0; k < 8; k = k + 1)
                    if (rx_bytes[i][7-k] !== ref_bits[i*8 + k]) mism = mism + 1;
            if (mism != 0) begin
                $display("  FAIL %0d sample(s) differ from what the source produced", mism);
                errors = errors + 1;
            end else
                $display("  pass %0d bytes received match the %0d captured samples",
                         nbytes, nbytes * 8);
        end
    endtask
 
    initial begin
        repeat (5) @(negedge clk);
        rst_n = 1'b1;
        repeat (50) @(negedge clk);
 
        current_test = "ping";
        rx_count = 0;
        send_byte("P"); wait_bytes(1);
        if (rx_count == 1 && rx_bytes[0] == "K") $display("  pass ping -> 'K'");
        else begin $display("  FAIL ping"); errors = errors + 1; end
 
        current_test = "sequential";
        rx_count = 0; ref_count = 0; recording = 1;
        send_byte("S"); wait_bytes(SEQ_BYTES);
        recording = 0;
        compare(SEQ_BYTES);
 
        current_test = "restart";
        rx_count = 0; ref_count = 0; restarts_seen = 0; bad_rows = 0; recording = 1;
        send_byte("R"); wait_bytes(RESTARTS * RS / 8);
        recording = 0;
        compare(RESTARTS * RS / 8);
        if (restarts_seen == RESTARTS && bad_rows == 0 && early == 0)
            $display("  pass %0d restarts, %0d samples recorded after each, none during warm-up",
                     RESTARTS, RS);
        else begin
            $display("  FAIL restarts seen = %0d (want %0d), bad rows = %0d, warm-up samples = %0d",
                     restarts_seen, RESTARTS, bad_rows, early);
            errors = errors + 1;
        end
 
        current_test = "done";
        if (errors == 0) $display("\nALL TESTS PASSED");
        else             $display("\n%0d TEST(S) FAILED", errors);
        $stop;
    end
 
    initial begin
        #20_000_000;
        $display("GLOBAL TIMEOUT"); $stop;
    end
 
endmodule
 