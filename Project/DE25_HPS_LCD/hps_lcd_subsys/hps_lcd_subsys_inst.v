	hps_lcd_subsys u0 (
		.hps_io_hps_osc_clk (_connected_to_hps_io_hps_osc_clk_), //   input,  width = 1, hps_io.hps_osc_clk
		.hps_io_spim0_clk   (_connected_to_hps_io_spim0_clk_),   //  output,  width = 1,       .spim0_clk
		.hps_io_spim0_mosi  (_connected_to_hps_io_spim0_mosi_),  //  output,  width = 1,       .spim0_mosi
		.hps_io_spim0_ss0_n (_connected_to_hps_io_spim0_ss0_n_), //  output,  width = 1,       .spim0_ss0_n
		.hps_io_uart1_tx    (_connected_to_hps_io_uart1_tx_),    //  output,  width = 1,       .uart1_tx
		.hps_io_uart1_rx    (_connected_to_hps_io_uart1_rx_),    //   input,  width = 1,       .uart1_rx
		.hps_io_gpio34      (_connected_to_hps_io_gpio34_),      //   inout,  width = 1,       .gpio34
		.hps_io_gpio35      (_connected_to_hps_io_gpio35_),      //   inout,  width = 1,       .gpio35
		.hps_io_gpio42      (_connected_to_hps_io_gpio42_)       //   inout,  width = 1,       .gpio42
	);

