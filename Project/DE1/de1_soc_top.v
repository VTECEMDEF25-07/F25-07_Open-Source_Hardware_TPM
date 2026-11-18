// test0_top.v
// modules:
//	test0_top
//
//
// Authors:
//	Ian Sizemore (idsizemore@vt.edu)
//	Aaron Grossman (keygen IP_TYPE selection)
// AI Disclosure: Codex assisted with the IP_TYPE selection change.
//
// Date: 11/6/25
//
// General Description:
//	Top level module for our physical fpga testing.
//	Other top level modules for different devices will likely look similar.
//	This module targets the Terasic DE1-SoC development board.


// Select the implementation here for this board. This default propagates through
// TPM_TOP to keygen and its RAM/multiplier wrappers.
// 0 = Generic, 1 = Altera, 2 = Xilinx (not implemented).
`define FPGA_IP_TYPE 1

module de1_soc_top #(parameter IP_TYPE = `FPGA_IP_TYPE)
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
	assign	LEDR[9:1] = 9'b0;
	
	
// Common SPI and TPM state run directly at the board 50 MHz clock.
	
	// One vendor setting feeds all TPM resources; Cyclone V selects M10K RAM.
	TPM_TOP #(.IP_TYPE(IP_TYPE), .DEVICE_FAMILY("Cyclone V")) tpm
	(
		.CLOCK_50(CLOCK_50),
		.RESET_n(RESET_N),
		.SPI_CLOCK(GPIO_1_2),
		.SPI_CS_n(GPIO_1_5),
		.SPI_RST_n(GPIO_1_6),
		.SPI_MOSI(GPIO_1_3),
		.SPI_MISO(GPIO_1_4),
		.SPI_PIRQ_n(pirq_out)
	);
	
endmodule

// Keep this board default local to this source file.
`undef FPGA_IP_TYPE
