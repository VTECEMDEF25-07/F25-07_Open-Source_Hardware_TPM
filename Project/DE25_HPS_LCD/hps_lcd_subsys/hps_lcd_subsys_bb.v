module hps_lcd_subsys (
		input  wire  hps_io_hps_osc_clk, // hps_io.hps_osc_clk
		output wire  hps_io_spim0_clk,   //       .spim0_clk
		output wire  hps_io_spim0_mosi,  //       .spim0_mosi
		output wire  hps_io_spim0_ss0_n, //       .spim0_ss0_n
		output wire  hps_io_uart1_tx,    //       .uart1_tx
		input  wire  hps_io_uart1_rx,    //       .uart1_rx
		inout  wire  hps_io_gpio34,      //       .gpio34
		inout  wire  hps_io_gpio35,      //       .gpio35
		inout  wire  hps_io_gpio42       //       .gpio42
	);
endmodule

