module	TPM_IO
(
	input		clock50,
	input		clock100,
	input		reset_n,
	
	input		SPI_clk,
	input		SPI_cs_n,
	input		SPI_mosi,
	output		SPI_miso,
	output		SPI_pirq_n,
	
	output		execStart,
	output	[31:0]	commandCode,
	output	[15:0]	commandTag,
	input		responseReady,
	input	[31:0]	responseCode,
	output	[39:0]	commandParam,
	output	[7:0]	locality,
	output	[31:0]	commandSize,
	
	output	[31:0]	handle0, handle1, handle2,
	output	[31:0]	sessionHandle0, sessionHandle1, sessionHandle2,
	output	[15:0]	sessionNonceSize0, sessionNonceSize1, sessionNonceSize2,
	output	[11:0]	sessionNonceAddr0, sessionNonceAddr1, sessionNonceAddr2,
	output	[7:0]	sessionAttributes0, sessionAttributes1, sessionAttributes2,
	output	[15:0]	sessionHmacSize0, sessionHmacSize1, sessionHmacSize2,
	output	[11:0]	sessionHmacAddr0, sessionHmacAddr1, sessionHmacAddr2,
	output	[31:0]	authSize,
	
	output		sessionValid0, sessionValid1, sessionValid2
);
	wire	[7:0]	RX_byte, TX_byte;
	wire		RX_valid, TX_valid;
	wire		TX_request, TX_received;
	
	SPI_SLAVE spi_serialzier
	(
		.clock50(clock50), .clock100(clock100),
		.reset_n(reset_n),
		.RX_valid(RX_valid), .RX_data(RX_byte),
		.TX_valid(TX_valid), .TX_data(TX_byte),
		.TX_request(TX_request), .TX_received(TX_received),
		.SPI_clock(SPI_clk), .SPI_cs_n(SPI_cs_n),
		.SPI_miso(SPI_miso), .SPI_mosi(SPI_mosi)
	);
	
	wire	[15:0]	t_addr, t_baseAddr;
	wire		t_wren_n, t_rden_n;
	wire	[7:0]	t_readByte, t_writeByte;
	wire	[5:0]	t_size;
	wire		t_req;
	wire		t_updateAddr;
	
	TPM_SPI_CTRL transaction_handler
	(
		.clock(clock50), .reset_n(reset_n),
		.SPI_CS_n(SPI_cs_n),
		.SPI_RX_byte(RX_byte), .SPI_RX_valid(RX_valid),
		.SPI_TX_byte(TX_byte), .SPI_TX_valid(TX_valid),
		.SPI_TX_prepare(TX_request), .SPI_TX_ack(TX_received),
		.FRS_addr(t_addr), .FRS_baseAddr(t_baseAddr),
		.FRS_wren_n(t_wren_n), .FRS_rden_n(t_rden_n),
		.FRS_wrByte(t_writeByte), .FRS_rdByte(t_readByte),
		.CMD_size(t_size), .FRS_req(t_req),
		.updateAddr(t_updateAddr)
	);
	
	wire	[31:0]	c_rspSize;
	wire		c_cmdSend, c_rspSend, c_cmdDone, c_rspDone;
	wire	[11:0]	c_cmdAddr, c_rspAddr;
	wire	[7:0]	c_cmdByte, c_rspByte;
	wire		c_execDone, c_execAck;
	
	TPM_REG_SPACE fifo_register_space
	(
		.clock(clock50), .reset_n(reset_n),
		.t_req(t_req), .t_dir(t_wren_n),
		.t_size(t_size), .updateAddr(t_updateAddr),
		.t_address(t_addr), .t_baseAddr(t_baseAddr),
		.t_writeByte(t_writeByte), .t_readByte(t_readByte),
		.SPI_PIRQ_n(SPI_pirq_n), .locality_out(locality),
		.c_cmdSize(commandSize), .c_rspSize(c_rspSize),
		.c_cmdSend(c_cmdSend), .c_rspSend(c_rspSend),
		.c_cmdDone(c_cmdDone), .c_rspDone(c_rspDone),
		.c_cmdInAddr(c_cmdAddr), .c_rspInAddr(c_rspAddr),
		.c_cmdByteOut(c_cmdByte), .c_rspByteIn(c_rspByte),
		.e_execDone(c_execDone),
		.c_execDone(c_execDone), .c_execAck(c_execAck)
	);
	
	TPM_CRB command_response_buffer
	(
		.clock(clock50), .reset_n(reset_n),
		.locality(locality), .cmdAbort(1'b0),
		.cmdSize(commandSize), .rspSize(c_rspSize),
		.cmdSend(c_cmdSend), .rspSend(c_rspSend),
		.cmdDone(c_cmdDone), .rspDone(c_rspDone),
		.cmdByteIn(c_cmdByte), .rspByteOut(c_rspByte),
		.execDone(c_execDone), .execStart(execStart),
		.cmdOutAddr(c_cmdAddr), .rspOutAddr(c_rspAddr),
		.execAck(c_execAck), .rspReady(responseReady),
		.commandCode(commandCode), .responseCode(responseCode),
		.commandParam(commandParam), .commandTag(commandTag),
		.handle0(handle0), .handle1(handle1), .handle2(handle2),
		.sessionHandle0(sessionHandle0), .sessionHandle1(sessionHandle1), .sessionHandle2(sessionHandle2),
		.sessionNonceSize0(sessionNonceSize0), .sessionNonceSize1(sessionNonceSize1), .sessionNonceSize2(sessionNonceSize2),
		.sessionAttributes0(sessionAttributes0), .sessionAttributes1(sessionAttributes1), .sessionAttributes2(sessionAttributes2),
		.sessionHmacSize0(sessionHmacSize0), .sessionHmacSize1(sessionHmacSize1), .sessionHmacSize2(sessionHmacSize2),
		.sessionNonceAddr0(sessionNonceAddr0), .sessionNonceAddr1(sessionNonceAddr1), .sessionNonceAddr2(sessionNonceAddr2),
		.sessionHmacAddr0(sessionHmacAddr0), .sessionHmacAddr1(sessionHmacAddr1), .sessionHmacAddr2(sessionHmacAddr2),
		.authSize(authSize),
		.sessionValid0(sessionValid0), .sessionValid1(sessionValid1), .sessionValid2(sessionValid2)
	);
	
endmodule