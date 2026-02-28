// tpm_io.v
// modules:
//	tpm_io
//
// Authors:
//	Ian Sizemore (idsizemore@vt.edu)
//
// Date: 11/6/25
//
// General Description:
//	Wrapper module to combine induvidual I/O submodules into a single module.
	
module	tpm_io
(
	input		clock50,	// 50 MHz	(sysclock, arbitrary)
	input		clock100,	// 100 MHz	(for SPI timing, should be >60 MHz)
	input		reset_n,
	
	// host system communication
	input		SPI_clk,	// SPI clock
	input		SPI_cs_n,	// SPI chip select, active low
	input		SPI_mosi,	// SPI mosi
	output		SPI_miso,	// SPI miso
	output		SPI_pirq_n,	// SPI Interrupt Request, active low
	
	// internal communication
	output		execStart,	// start execution
	output	[31:0]	commandCode,	// command code
	output	[15:0]	commandTag,	// command tag
	input		responseReady,	// response is ready
	input	[31:0]	responseCode,	// response code
	output	[39:0]	commandParam,	// command parameters for management module
	output	[7:0]	locality,	// active locality
	output	[31:0]	commandSize,	// command size
	
	// command session data
	output	[31:0]	handle0, handle1, handle2,
	output	[31:0]	sessionHandle0, sessionHandle1, sessionHandle2,
	output	[15:0]	sessionNonceSize0, sessionNonceSize1, sessionNonceSize2,
	output	[11:0]	sessionNonceAddr0, sessionNonceAddr1, sessionNonceAddr2,
	output	[7:0]	sessionAttributes0, sessionAttributes1, sessionAttributes2,
	output	[15:0]	sessionHmacSize0, sessionHmacSize1, sessionHmacSize2,
	output	[11:0]	sessionHmacAddr0, sessionHmacAddr1, sessionHmacAddr2,
	output	[31:0]	authSize,
	
	// session validity
	output		sessionValid0, sessionValid1, sessionValid2
);
	
	// this module is simply instantiations and connections
	
	wire	[7:0]	RX_byte, TX_byte;
	wire		RX_valid, TX_valid;
	wire		TX_request, TX_received;
	
	spi_slave spi_serialzier
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
	
	tpm_spi_ctrl transaction_handler
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
	
	tpm_reg_space fifo_register_space
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
	
	tpm_crb command_response_buffer
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