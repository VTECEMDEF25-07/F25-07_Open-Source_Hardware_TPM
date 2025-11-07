module test0_top
(
	input		CLOCK_50,
	input		RESET_N,
	output	[9:0]	LEDR,
	
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
	
	TPM_TOP tpm
	(
		.CLOCK_50(CLOCK_50), .CLOCK_100(CLOCK_100),
		.RESET_n(RESET_N),
		.SPI_CLOCK(GPIO_1_2),
		.SPI_CS_n(GPIO_1_5),
		.SPI_RST_n(GPIO_1_6),
		.SPI_MOSI(GPIO_1_3),
		.SPI_MISO(GPIO_1_4),
		.SPI_PIRQ_n(pirq_out)
	);
	
endmodule