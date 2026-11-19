module hps_lcd_subsys_agilex_hps_0 (
		output wire        h2f_reset_reset,            //            h2f_reset.reset,       Active high reset from the HPS Reset Manager.
		input  wire        lwhps2fpga_axi_clock_clk,   // lwhps2fpga_axi_clock.clk,         clock from a single source in the FPGA.
		input  wire        lwhps2fpga_axi_reset_reset, // lwhps2fpga_axi_reset.reset,       Async reset to the Bridge logic. This signal is active-HIGH.
		output wire [3:0]  lwhps2fpga_awid,            //           lwhps2fpga.awid,        Identification tag for a write transaction.
		output wire [28:0] lwhps2fpga_awaddr,          //                     .awaddr,      The address of the first transfer in a write transaction.
		output wire [7:0]  lwhps2fpga_awlen,           //                     .awlen,       The exact number of data transfers in a write transaction.
		output wire [2:0]  lwhps2fpga_awsize,          //                     .awsize,      The number of bytes in each data transfer in a write transaction.
		output wire [1:0]  lwhps2fpga_awburst,         //                     .awburst,     Indicates how address changes between each transfer in a write transaction.
		output wire        lwhps2fpga_awlock,          //                     .awlock,      Provides information about the atomic characteristics of a write transaction.
		output wire [3:0]  lwhps2fpga_awcache,         //                     .awcache,     Indicates how a write transaction is required to progress through a system.
		output wire [2:0]  lwhps2fpga_awprot,          //                     .awprot,      Protection attributes of a write transaction: privilege, security level, and access type.
		output wire        lwhps2fpga_awvalid,         //                     .awvalid,     Indicates that the write address channel signals are valid.
		input  wire        lwhps2fpga_awready,         //                     .awready,     Indicates that a transfer on the write address channel can be accepted.
		output wire [31:0] lwhps2fpga_wdata,           //                     .wdata,       Write data.
		output wire [3:0]  lwhps2fpga_wstrb,           //                     .wstrb,       Write strobes, indicate which byte lanes hold valid data.
		output wire        lwhps2fpga_wlast,           //                     .wlast,       User-defined extension for the write data channel.
		output wire        lwhps2fpga_wvalid,          //                     .wvalid,      Indicates that the write data channel signals are valid.
		input  wire        lwhps2fpga_wready,          //                     .wready,      Indicates that a transfer on the write data channel can be accepted.
		input  wire [3:0]  lwhps2fpga_bid,             //                     .bid,         Transaction identifier for the write response.
		input  wire [1:0]  lwhps2fpga_bresp,           //                     .bresp,       Write response, indicates the status of a write transaction.
		input  wire        lwhps2fpga_bvalid,          //                     .bvalid,      Indicates that the write response channel signals are valid.
		output wire        lwhps2fpga_bready,          //                     .bready,      Indicates that a transfer on the write response channel can be accepted.
		output wire [3:0]  lwhps2fpga_arid,            //                     .arid,        Transaction identifier for the read transaction.
		output wire [28:0] lwhps2fpga_araddr,          //                     .araddr,      The address of the first transfer in a read transaction.
		output wire [7:0]  lwhps2fpga_arlen,           //                     .arlen,       The exact number of data transfers in a read transaction.
		output wire [2:0]  lwhps2fpga_arsize,          //                     .arsize,      The number of bytes in each data transfer in a read transaction.
		output wire [1:0]  lwhps2fpga_arburst,         //                     .arburst,     Indicates how address changes between each transfer in a read transaction.
		output wire        lwhps2fpga_arlock,          //                     .arlock,      Provides information about the atomic characteristics of a read transaction.
		output wire [3:0]  lwhps2fpga_arcache,         //                     .arcache,     Indicates how a read transaction is required to progress through a system.
		output wire [2:0]  lwhps2fpga_arprot,          //                     .arprot,      Protection attributes of a read transaction: privilege, security level, and access type.
		output wire        lwhps2fpga_arvalid,         //                     .arvalid,     Indicates that the read address channel signals are valid.
		input  wire        lwhps2fpga_arready,         //                     .arready,     Indicates that a transfer on the read address channel can be accepted.
		input  wire [3:0]  lwhps2fpga_rid,             //                     .rid,         Identification tag for read data and response.
		input  wire [31:0] lwhps2fpga_rdata,           //                     .rdata,       Read data.
		input  wire [1:0]  lwhps2fpga_rresp,           //                     .rresp,       Read response, indicates the status of a read transfer.
		input  wire        lwhps2fpga_rlast,           //                     .rlast,       Indicates whether this is the last data transfer in a read transaction.
		input  wire        lwhps2fpga_rvalid,          //                     .rvalid,      Indicates that the read data channel signals are valid.
		output wire        lwhps2fpga_rready,          //                     .rready,      Indicates that a transfer on the read data channel can be accepted.
		output wire        h2f_cold_reset_reset_n,     //       h2f_cold_reset.reset_n,     Asserted when the HPS undergoes a cold reset.
		input  wire        hps_io_hps_osc_clk,         //               hps_io.hps_osc_clk, HPS input clock pin for EOSC reference clock.
		output wire        hps_io_spim0_clk,           //                     .spim0_clk,   SPIM0 serial clock.
		output wire        hps_io_spim0_mosi,          //                     .spim0_mosi,  SPIM0 master out, slave in.
		output wire        hps_io_spim0_ss0_n,         //                     .spim0_ss0_n, SPIM0 slave select 0. Necessary for basic functionality.
		output wire        hps_io_uart1_tx,            //                     .uart1_tx,    UART1 transmit data.
		input  wire        hps_io_uart1_rx,            //                     .uart1_rx,    UART1 receive data.
		inout  wire        hps_io_gpio34,              //                     .gpio34,      GPIO1 IO10
		inout  wire        hps_io_gpio35,              //                     .gpio35,      GPIO1 IO11
		inout  wire        hps_io_gpio42               //                     .gpio42,      GPIO1 IO18
	);
endmodule

