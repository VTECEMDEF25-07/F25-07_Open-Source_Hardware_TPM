module hps_lcd_subsys_agilex_hps (
		output wire  h2f_reset_reset,    // h2f_reset.reset,       Active high reset from the HPS Reset Manager.
		input  wire  hps_io_hps_osc_clk, //    hps_io.hps_osc_clk, HPS input clock pin for EOSC reference clock.
		output wire  hps_io_spim0_clk,   //          .spim0_clk,   SPIM0 serial clock.
		output wire  hps_io_spim0_mosi,  //          .spim0_mosi,  SPIM0 master out, slave in.
		output wire  hps_io_spim0_ss0_n, //          .spim0_ss0_n, SPIM0 slave select 0. Necessary for basic functionality.
		output wire  hps_io_uart1_tx,    //          .uart1_tx,    UART1 transmit data.
		input  wire  hps_io_uart1_rx,    //          .uart1_rx,    UART1 receive data.
		inout  wire  hps_io_gpio34,      //          .gpio34,      GPIO1 IO10
		inout  wire  hps_io_gpio35,      //          .gpio35,      GPIO1 IO11
		inout  wire  hps_io_gpio42       //          .gpio42,      GPIO1 IO18
	);
endmodule

