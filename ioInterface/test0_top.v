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
	output/*purple*/GPIO_1_7,	// PIRQ_n
	
	output		GPIO_0_2,	// scope_clock
	output		GPIO_0_3,	// scope_mosi
	output		GPIO_0_4,	// scope_miso
	output		GPIO_0_5	// scope_cs
	
//	output	[6:0]	HEX5,HEX4, HEX3,HEX2, HEX1,HEX0
);
	
	wire	reset_n;
	assign	reset_n = GPIO_1_6 & RESET_N;
	
	assign	GPIO_0_2 = GPIO_1_2;//	assign	LEDR[0] = GPIO_1_2;
	assign	GPIO_0_3 = GPIO_1_3;	assign	LEDR[1] = GPIO_1_3;
	assign	GPIO_0_4 = GPIO_1_4;	assign	LEDR[2] = GPIO_1_4;
	assign	GPIO_0_5 = GPIO_1_5;	assign	LEDR[3] = GPIO_1_5;
	assign	LEDR[8] = ~reset_n;	assign	LEDR[9] = GPIO_1_1;
	
	wire	SPI_clock, SPI_mosi, SPI_miso, SPI_cs;

	assign	SPI_cs = GPIO_1_5;
	assign	SPI_clock = GPIO_1_2;
	assign	SPI_mosi = GPIO_1_3;
	assign	GPIO_1_4 = SPI_miso;
	
	
	wire	[7:0]	RX_byte, TX_byte;
	wire		RX_valid, TX_valid;
	wire		next_byte, TX_ack;
	
	wire		CLOCK_100, SYSCLK;
	PLL_100	PLL0( .refclk(CLOCK_50), .rst(~RESET_N), .outclk_0(CLOCK_100) );
	
	assign	SYSCLK = CLOCK_50;
	
	SPI_SLAVE slave_header
	(
		.clock(SYSCLK), .reset_n(reset_n),
		
		.RX_data(RX_byte), .TX_data(TX_byte),
		.RX_valid(RX_valid), .TX_valid(TX_valid),
		.TX_request(next_byte), .TX_received(TX_ack),
		
		.SPI_clock(SPI_clock), .SPI_cs_n(SPI_cs),
		.SPI_miso(SPI_miso), .SPI_mosi(SPI_mosi)
	);
	
	wire	[15:0]	FRS_addr;
	wire		FRS_wren_n, FRS_rden_n;
	wire	[7:0]	FRS_wrByte, FRS_rdByte;
	wire	[15:0]	FRS_baseAddr;
	wire	[5:0]	CMD_size;
	wire		FRS_req;
	
	TPM_SPI_CTRL tpm_spi
	(
		SYSCLK, reset_n, SPI_cs,
		RX_byte, RX_valid,
		TX_byte, next_byte, TX_valid, TX_ack,
		FRS_addr, FRS_wren_n, FRS_rden_n, FRS_wrByte, FRS_rdByte,
		FRS_baseAddr, CMD_size, FRS_req
	);
	
	wire		t_req;
	wire		t_dir;
	wire	[15:0]	t_address;
	wire	[7:0]	t_writeByte;
	wire	[7:0]	t_readByte;
	wire		SPI_PIRQ_n;
	
	assign	t_req = FRS_req; // ~FRS_wren_n | ~FRS_rden_n;
	assign	t_dir = FRS_wren_n;
	assign	t_size = 6'd0;
	assign	t_address = FRS_addr;
	assign	t_baseAddr = t_address;
	
	TPM_REG_SPACE	frs
	(
		SYSCLK, reset_n,
		t_req, t_dir, CMD_size,
		t_address, FRS_baseAddr,
		FRS_wrByte, FRS_rdByte,
		1'b0, SPI_PIRQ_n, LEDR[7:5], LEDR[4]
	);

	assign	GPIO_1_7 = SPI_PIRQ_n;
	assign	LEDR[0] = SPI_PIRQ_n;
	
	
endmodule