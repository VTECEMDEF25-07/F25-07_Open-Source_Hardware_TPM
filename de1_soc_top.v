// test0_top.v
// modules:
//	test0_top
//
// Authors:
//	Ian Sizemore (idsizemore@vt.edu)
//
// Date: 11/6/25
//
// General Description:
//	Top level module for our physical fpga testing.
//	Other top level modules for different devices will likely look similar.
//	This module targets the Terasic DE0-CV development board.

module de1_soc_top
(
	input		CLOCK_50,
	input		RESET_N,
	output	[9:0]	LEDR,
	
	// the colors indicate the wires used by the FTDI USB-SPI cable
	input /*orange*/GPIO_1_2,	// SPI_clock	[CLK_n]
	input /*yellow*/GPIO_1_3,	// SPI_mosi
	output/*green*/	GPIO_1_4,	// SPI_miso
	input /*brown*/	GPIO_1_5,	// SPI_cs
	input /*grey*/	GPIO_1_6,	// SPI_rst_n
	output/*purple*/GPIO_1_7	// SPI_PIRQ_n
);
	
	wire	pirq_out;
	assign	GPIO_1_7 = pirq_out;
	assign	LEDR[0] = pirq_out;
	
	
	wire	CLOCK_100;
	PLL_100 PLL0( .refclk(CLOCK_50), .rst(~RESET_N), .outclk_0(CLOCK_100) );
	
	tpm_top tpm
	(
		.clock_50_i(CLOCK_50), .clock_100_i(CLOCK_100),
		.reset_n_i(RESET_N),
		.spi_clock_i(GPIO_1_2),
		.spi_cs_n_i(GPIO_1_5),
		.spi_rst_n_i(GPIO_1_6),
		.spi_mosi_i(GPIO_1_3),
		.spi_miso_o(GPIO_1_4),
		.spi_pirq_n_o(pirq_out)
	);
	
endmodule