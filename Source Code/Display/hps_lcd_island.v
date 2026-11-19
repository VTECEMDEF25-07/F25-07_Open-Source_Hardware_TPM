// DE25 RevD dedicated HPS-only LCD island. Pro26.1 generated subsystem.
// Read-only display window on the lightweight HPS-to-FPGA bridge.
`timescale 1 ps / 1 ps
module hps_lcd_island (
    input wire clock_i, reset_n_i,
    output wire [5:0] display_word_o,
    input wire [31:0] display_data_i,
    input  wire hps_osc_clk25_i,
    input  wire hps_uart1_rx_i,
    output wire hps_uart1_tx_o,
    output wire hps_spim0_clk_o,
    output wire hps_spim0_mosi_o,
    output wire hps_spim0_ss0_n_o,
    inout  wire hps_gpio34_io,
    inout  wire hps_gpio35_io,
    inout  wire hps_gpio42_io
);
    wire [7:0] address;
    wire read;
    reg valid;
    reg [31:0] data;
    assign display_word_o = address[7:2];
    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) begin valid <= 0; data <= 0; end
        else begin
            valid <= read;
            if (read) data <= display_data_i;
        end
    end

    hps_lcd_subsys u_hps_lcd_subsys (
        .fabric_clock_clk(clock_i), .fabric_reset_reset_n(reset_n_i),
        .display_read(read), .display_address(address), .display_waitrequest(1'b0),
        .display_readdatavalid(valid), .display_readdata(data),
        .hps_io_hps_osc_clk (hps_osc_clk25_i),
        .hps_io_uart1_rx    (hps_uart1_rx_i),
        .hps_io_uart1_tx    (hps_uart1_tx_o),
        .hps_io_spim0_clk   (hps_spim0_clk_o),
        .hps_io_spim0_mosi  (hps_spim0_mosi_o),
        .hps_io_spim0_ss0_n (hps_spim0_ss0_n_o),
        .hps_io_gpio34      (hps_gpio34_io),
        .hps_io_gpio35      (hps_gpio35_io),
        .hps_io_gpio42      (hps_gpio42_io)
    );
endmodule
