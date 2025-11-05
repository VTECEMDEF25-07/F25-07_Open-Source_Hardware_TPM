module test0_top
(
	input		CLOCK_50,
	input		RESET_N,
	output	[9:0]	LEDR,
	
	input /* nc */	GPIO_1_0,	// unused	[CLK_p]
	input /* red */	GPIO_1_1,	// cable detect
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
	wire		updateAddr;
	
	TPM_SPI_CTRL tpm_spi
	(
		SYSCLK, reset_n, SPI_cs,
		RX_byte, RX_valid,
		TX_byte, next_byte, TX_valid, TX_ack,
		FRS_addr, FRS_wren_n, FRS_rden_n, FRS_wrByte, FRS_rdByte,
		FRS_baseAddr, CMD_size, FRS_req, updateAddr
	);
	
	
/*	wire	[2:0]	subAddr;
	wire		writeBit, readBit;
	wire		bitAccess;
	wire		source;
	
	assign source = 1'b0;
	assign subAddr = 3'b000;
	assign writeBit = 1'b0;
	assign bitAccess = 1'b0;
	
	TPM_IO_REGISTERS frs
	(
		CLOCK_50, RESET_N,
		FRS_wrByte, FRS_wren_n,
		FRS_rdByte, FRS_rden_n,
		FRS_addr,
		source, bitAccess,
		subAddr, writeBit, readBit
	);
*/
	
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
	
	wire	[31:0]	c_cmdSize, c_rspSize;
	wire		c_cmdSend, c_rspSend, c_cmdDone, c_rspDone;
	wire	[11:0]	c_cmdAddr, c_rspAddr;
	wire	[7:0]	c_cmdByte, c_rspByte;
	wire		c_execDone, c_rspReady;
	wire		c_execAck;
	
	wire	[7:0]	locality;
	
/*	TPM_REG_SPACE	frs
	(
		SYSCLK, reset_n,
		t_req, t_dir, CMD_size,
		t_address, FRS_baseAddr,
		FRS_wrByte, FRS_rdByte,
		1'b0, SPI_PIRQ_n, LEDR[7:5], LEDR[4],
		updateAddr
	);
*/	
	TPM_REG_SPACE	frs
	(
		.clock(SYSCLK), .reset_n(reset_n),
		.SPI_PIRQ_n(SPI_PIRQ_n),
		.t_req(t_req), .t_dir(t_dir), .t_size(CMD_size),
		.t_address(t_address), .t_baseAddr(FRS_baseAddr),
		.t_writeByte(FRS_wrByte), .t_readByte(FRS_rdByte),
		.e_execDone(c_execDone), // .e_execStart(),
		.debug(LEDR[7:5]), .dbg(LEDR[4]),
		.updateAddr(updateAddr),
		.c_cmdSize(c_cmdSize), .c_rspSize(c_rspSize),
		.c_cmdSend(c_cmdSend), .c_rspSend(c_rspSend),
		.c_cmdDone(c_cmdDone), .c_rspDone(c_rspDone),
		.c_cmdInAddr(c_cmdAddr), .c_rspInAddr(c_rspAddr),
		.c_cmdByteOut(c_cmdByte), .c_rspByteIn(c_rspByte),
		.c_execDone(c_execDone), .c_execAck(c_execAck),
		.locality_out(locality)
	);

	assign	GPIO_1_7 = SPI_PIRQ_n;
	assign	LEDR[0] = SPI_PIRQ_n;
	
	wire	[31:0]	commandCode;
	wire	[31:0]	responseCode;
	wire	[15:0]	commandTag, expectedTag;
	wire	[39:0]	commandParam;
	wire		execStart;
	
	wire	[31:0]	handle0, handle1, handle2;
	wire	[31:0]	sessionHandle0, sessionHandle1, sessionHandle2;
	wire	[15:0]	sessionNonceSize0, sessionNonceSize1, sessionNonceSize2;
	wire	[7:0]	sessionAttributes0, sessionAttributes1, sessionAttributes2;
	wire	[15:0]	sessionHmacSize0, sessionHmacSize1, sessionHmacSize2;
	wire	[31:0]	authSize;
	wire		sessionValid0, sessionValid1, sessionValid2;
	
	TPM_CRB	crb
	(
		.clock(SYSCLK), .reset_n(reset_n),
		.locality(locality), .cmdAbort(1'b0),
		.cmdSize(c_cmdSize), .rspSize(c_rspSize),
		.cmdSend(c_cmdSend), .rspSend(c_rspSend),
		.cmdDone(c_cmdDone), .rspDone(c_rspDone),
		.cmdOutAddr(c_cmdAddr), .rspOutAddr(c_rspAddr),
		.cmdByteIn(c_cmdByte), .rspByteOut(c_rspByte),
		.execDone(c_execDone), .execStart(execStart),
		.rspReady(c_rspReady), .execAck(c_execAck),
		
		.commandCode(commandCode), .responseCode(responseCode),
		.commandParam(commandParam), .commandTag(commandTag),
		.expectedTag(expectedTag),
		
		.handle0(handle0), .handle1(handle1), .handle2(handle2),
		.sessionHandle0(sessionHandle0), .sessionHandle1(sessionHandle1), .sessionHandle2(sessionHandle2),
		.sessionNonceSize0(sessionNonceSize0), .sessionNonceSize1(sessionNonceSize1), .sessionNonceSize2(sessionNonceSize2),
		.sessionAttributes0(sessionAttributes0), .sessionAttributes1(sessionAttributes1), .sessionAttributes2(sessionAttributes2),
		.sessionHmacSize0(sessionHmacSize0), .sessionHmacSize1(sessionHmacSize1), .sessionHmacSize2(sessionHmacSize2),
		.authSize(authSize),
		.sessionValid0(sessionValid0), .sessionValid1(sessionValid1), .sessionValid2(sessionValid2)
	);
	
	
	wire	[2:0]	op_state, startup_type;
	wire		phEnable, phEnableNV;
	wire		shEnable, ehEnable;
	wire	[15:0]	shutdownSave;
	wire	[15:0]	testsRun, testsPassed, untested;
	wire	[15:0]	orderlyInput;
	wire		nv_phEnableNV, nv_shEnable, nv_ehEnable;
	wire	[31:0]	ee_responseCode, authHierarchy;
	wire		initialized;
	
	
	management_module mm
	(
		.clock(SYSCLK), .reset_n(reset_n),
		.keyStart_n(~execStart), .tpm_cc(commandCode),
		.cmd_param({commandParam[39:8], commandParam[0]}), .orderlyInput(orderlyInput),
		.initialized(1'b1), .authHierarchy(handle0),
		.executionEng_rc(ee_responseCode), .locality(locality),
		.testsRun(testsRun), .testsPassed(testsPassed),
		.untested(untested), .nv_phEnableNV(nv_phEnableNV),
		.nv_shEnable(nv_shEnable), .nv_ehEnable(nv_ehEnable),
		.op_state(op_state), .startup_type(startup_type),
		.tpm_rc(responseCode) , .phEnable(phEnable),
		.phEnableNV(phEnableNV), .shEnable(shEnable),
		.ehEnable(ehEnable), .shutdownSave(shutdownSave)
	);
	
	execution_engine ee
	(
		.clock(SYSCLK), .reset_n(reset_n), 
		.command_ready(execStart), .command_tag(commandTag), 
		.command_size(c_cmdSize), .command_code(commandCode), 
		.command_length(c_cmdSize[15:0]), //  .physical_presence(1'b1), 
		.handle_0(handle0), .handle_1(handle1), .handle_2(handle2), 
		.session0_handle(sessionHandle0), .session1_handle(sessionHandle1), .session2_handle(sessionHandle2), 
		.session0_attributes(sessionAttributes0), .session1_attributes(sessionAttributes1), .session2_attributes(sessionAttributes2), 
		.session0_hmac_size(sessionHmacSize0), .session1_hmac_size(sessionHmacSize1), .session2_hmac_size(sessionHmacSize2), 
		
		.session0_valid(sessionValid0), .session1_valid(sessionValid1), .session2_valid(sessionValid2), 
		.authorization_size(authSize), /*.command_code_tag(expectedTag),*/ .session_loaded(1'b1), 
		.max_session_amount(16'd3), .auth_session(1'b1), .auth_necessary(1'b1), 
		.authHandle(handle0), .pcrSelect(), .auth_done(1'b1), 
		.auth_success(1'b1), .param_decrypt_success(1'b1), .param_decrypt_fail(1'b0), 
		.param_unmarshall_success(1'b1), .param_unmarshall_fail(1'b0), 
		.execution_startup_done(1'b1), .execution_response_code(32'd0), 
		
		.nv_phEnableNV_in(1'b1), .nv_shEnable_in(1'b1), 
		.nv_ehEnable_in(1'b1), .tpm_nv_index(32'd0), 
		.nv_index_attributes(32'd0), .nv_object_present(1'b1), 
		.nv_index_present(1'b1), .entity_hierarchy(32'd0), 
		
		.mem_orderly(16'd0), .ram_available(1'b1), 
		.loaded_object_present(1'b1), .object_attributes(32'd0), 
		
		.st_testsRun(16'd0), .st_testsPassed(16'd0), 
		.st_untested(16'd0),
		
		.op_state(op_state), 
		.startup_type(startup_type), .phEnable(phEnable), 
		.phEnableNV(phEnableNV), .shEnable(shEnable), 
		.ehEnable(ehEnable), .shutdownSave(shutdownSave), 
		.command_done(1'b1), .testsPassed(testsPassed), 
		.untested(untested), .nv_phEnableNV(nv_phEnableNV), 
		.nv_shEnable(nv_shEnable), .nv_ehEnable(nv_ehEnable), 
		.orderlyInput(orderlyInput), .initialized(initialized), 
		.testsRun(testsRun), .authHierarchy(authHierarchy), 
		
		.response_valid(c_rspReady), .response_code(ee_responseCode) // , 
	//	.response_length(), .current_state(), 
	//	.command_start()
	);
	
	
	startup_procedures_check su_proc
	(
		.clock(SYSCLK), .reset_n(reset_n), 
		.op_state(op_state), .startup_type(startup_type), 
		.phEnable(1'b1), .shEnable(1'b1), 
		.ehEnable(), .phEnableNV(1'b1), 
		.nv_shEnable(1'b1), .nv_ehEnable(1'b1), 
		.nv_phEnableNV(1'b1), .nv_index_startup_done(1'b1), 
		.clock_startup_done(1'b1), .pcr_startup_done(1'b1), 
		.act_startup_done(1'b1), .mem_startup_done(1'b1) //,
	//	.startup_done()
	);
	
endmodule