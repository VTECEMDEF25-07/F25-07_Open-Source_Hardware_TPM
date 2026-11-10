// DE25 RevD dedicated HPS-only LCD island. Pro26.1 generated subsystem.
// No fabric bridge/status bus or crypto/fan reset connection.
`timescale 1 ps / 1 ps
module hps_lcd_island (
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
    hps_lcd_subsys u_hps_lcd_subsys (
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
