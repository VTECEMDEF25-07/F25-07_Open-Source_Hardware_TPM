module hps_lcd_subsys (
		input  wire        hps_io_hps_osc_clk,    //       hps_io.hps_osc_clk
		output wire        hps_io_spim0_clk,      //             .spim0_clk
		output wire        hps_io_spim0_mosi,     //             .spim0_mosi
		output wire        hps_io_spim0_ss0_n,    //             .spim0_ss0_n
		output wire        hps_io_uart1_tx,       //             .uart1_tx
		input  wire        hps_io_uart1_rx,       //             .uart1_rx
		inout  wire        hps_io_gpio34,         //             .gpio34
		inout  wire        hps_io_gpio35,         //             .gpio35
		inout  wire        hps_io_gpio42,         //             .gpio42
		input  wire        display_waitrequest,   //      display.waitrequest
		input  wire [31:0] display_readdata,      //             .readdata
		input  wire        display_readdatavalid, //             .readdatavalid
		output wire [0:0]  display_burstcount,    //             .burstcount
		output wire [31:0] display_writedata,     //             .writedata
		output wire [7:0]  display_address,       //             .address
		output wire        display_write,         //             .write
		output wire        display_read,          //             .read
		output wire [3:0]  display_byteenable,    //             .byteenable
		output wire        display_debugaccess,   //             .debugaccess
		input  wire        fabric_clock_clk,      // fabric_clock.clk
		input  wire        fabric_reset_reset_n   // fabric_reset.reset_n
	);
endmodule

