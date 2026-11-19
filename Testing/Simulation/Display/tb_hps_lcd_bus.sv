`timescale 1ns/1ps
// Exercise the fabric side of the generated bridge with adjacent and idle reads.
// Compile with the generated hps_lcd_subsys_bb.v interface for the hard HPS.
module tb_hps_lcd_bus;
    reg clk = 0;
    reg reset_n = 0;
    reg request = 0;
    reg [7:0] address = 0;
    wire [5:0] word_index;
    wire [31:0] data = 32'haced0000 + word_index;
    always #5 clk = ~clk;

    hps_lcd_island dut (
        .clock_i(clk), .reset_n_i(reset_n),
        .display_word_o(word_index), .display_data_i(data),
        .hps_osc_clk25_i(1'b0), .hps_uart1_rx_i(1'b1)
    );
    task check_cycle(input bit rd, input bit rst_n, input byte addr);
        @(negedge clk);
        request = rd;
        address = addr;
        reset_n = rst_n;
        force dut.u_hps_lcd_subsys.display_read = request;
        force dut.u_hps_lcd_subsys.display_address = address;
        #1;
        if (word_index !== addr[7:2] || dut.u_hps_lcd_subsys.display_waitrequest !== 0)
            $fatal(1, "Avalon address or backpressure");
        @(posedge clk);
        #1;
        if (dut.u_hps_lcd_subsys.display_readdatavalid !== (rd && rst_n))
            $fatal(1, "Avalon response without matching accepted request");
        if (rd && rst_n && dut.u_hps_lcd_subsys.display_readdata !== (32'haced0000 + addr[7:2]))
            $fatal(1, "Avalon response did not capture addressed word");
    endtask
    initial begin
        check_cycle(0, 0, 0);
        for (int i = 0; i < 64; i++) check_cycle(1, 1, i*4);
        check_cycle(0, 1, 0);
        check_cycle(1, 1, 32);
        check_cycle(1, 0, 156);
        check_cycle(0, 1, 24);
        check_cycle(1, 1, 156);
        $display("DISPLAY_AVALON_PASS");
        $finish;
    end
endmodule
