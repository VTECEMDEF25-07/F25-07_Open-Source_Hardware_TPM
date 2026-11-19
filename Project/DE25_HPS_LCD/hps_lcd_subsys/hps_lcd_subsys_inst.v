	hps_lcd_subsys u0 (
		.hps_io_hps_osc_clk    (_connected_to_hps_io_hps_osc_clk_),    //   input,   width = 1,       hps_io.hps_osc_clk
		.hps_io_spim0_clk      (_connected_to_hps_io_spim0_clk_),      //  output,   width = 1,             .spim0_clk
		.hps_io_spim0_mosi     (_connected_to_hps_io_spim0_mosi_),     //  output,   width = 1,             .spim0_mosi
		.hps_io_spim0_ss0_n    (_connected_to_hps_io_spim0_ss0_n_),    //  output,   width = 1,             .spim0_ss0_n
		.hps_io_uart1_tx       (_connected_to_hps_io_uart1_tx_),       //  output,   width = 1,             .uart1_tx
		.hps_io_uart1_rx       (_connected_to_hps_io_uart1_rx_),       //   input,   width = 1,             .uart1_rx
		.hps_io_gpio34         (_connected_to_hps_io_gpio34_),         //   inout,   width = 1,             .gpio34
		.hps_io_gpio35         (_connected_to_hps_io_gpio35_),         //   inout,   width = 1,             .gpio35
		.hps_io_gpio42         (_connected_to_hps_io_gpio42_),         //   inout,   width = 1,             .gpio42
		.display_waitrequest   (_connected_to_display_waitrequest_),   //   input,   width = 1,      display.waitrequest
		.display_readdata      (_connected_to_display_readdata_),      //   input,  width = 32,             .readdata
		.display_readdatavalid (_connected_to_display_readdatavalid_), //   input,   width = 1,             .readdatavalid
		.display_burstcount    (_connected_to_display_burstcount_),    //  output,   width = 1,             .burstcount
		.display_writedata     (_connected_to_display_writedata_),     //  output,  width = 32,             .writedata
		.display_address       (_connected_to_display_address_),       //  output,   width = 8,             .address
		.display_write         (_connected_to_display_write_),         //  output,   width = 1,             .write
		.display_read          (_connected_to_display_read_),          //  output,   width = 1,             .read
		.display_byteenable    (_connected_to_display_byteenable_),    //  output,   width = 4,             .byteenable
		.display_debugaccess   (_connected_to_display_debugaccess_),   //  output,   width = 1,             .debugaccess
		.fabric_clock_clk      (_connected_to_fabric_clock_clk_),      //   input,   width = 1, fabric_clock.clk
		.fabric_reset_reset_n  (_connected_to_fabric_reset_reset_n_)   //   input,   width = 1, fabric_reset.reset_n
	);

