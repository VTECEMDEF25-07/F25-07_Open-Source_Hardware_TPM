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
	
module	tpm_io #(parameter SCOPED_COMMANDS = 0,
    parameter ENABLE_ENCRYPTDECRYPT2 = 0,
    parameter ENABLE_DEMO_COMMANDS = 0,
    parameter CUSTOMER_DEMO_ENABLE = 0,
    parameter PRESERVE_LEGACY_COMMANDS = 0)
(
    // Pass packet reads and response payload reads between the CRB and the top.
    input wire [11:0] exec_cmd_addr_i,
    output wire [7:0] exec_cmd_byte_o,
    input wire [11:0] exec_rsp_length_i,
    output wire [11:0] exec_rsp_addr_o,
    input wire [7:0] exec_rsp_byte_i,
    input wire [31:0] snapshot_status_word_i,
    input wire [31:0] snapshot_operation_id_i,
    input wire [31:0] snapshot_sequence_i,
    input wire [511:0] metrics_snapshot_i,
    input wire demo_admit_i,
    output wire exec_response_consumed_o,
    output wire demo_transport_abort_o,
	input		clock50_i,	// 50 MHz	(sysclock, arbitrary)
	input		reset_n_i,
	
	// host system communication
	input		SPI_clk_i,	// SPI clock
	input		SPI_cs_n_i,	// SPI chip select, active low
	input		SPI_mosi_i,	// SPI mosi
	output		SPI_miso_o,	// SPI miso
	output		SPI_pirq_n_o,	// SPI Interrupt Request, active low
	
	// internal communication
	output		execStart_o,	// start execution
	output	[31:0]	commandCode_o,	// command code
	output	[15:0]	commandTag_o,	// command tag
	input		responseReady_i,	// response is ready
	input	[31:0]	responseCode_i,	// response code
	output	[39:0]	commandParam_o,	// command parameters for management module
	output	[7:0]	locality_o,	// active locality_o
	output	[31:0]	commandSize_o,	// command size
	
	// command session data
	output	[31:0]	handle0_o, handle1_o, handle2_o,
	output	[31:0]	sessionHandle0_o, sessionHandle1_o, sessionHandle2_o,
	output	[15:0]	sessionNonceSize0_o, sessionNonceSize1_o, sessionNonceSize2_o,
	output	[11:0]	sessionNonceAddr0_o, sessionNonceAddr1_o, sessionNonceAddr2_o,
	output	[7:0]	sessionAttributes0_o, sessionAttributes1_o, sessionAttributes2_o,
	output	[15:0]	sessionHmacSize0_o, sessionHmacSize1_o, sessionHmacSize2_o,
	output	[11:0]	sessionHmacAddr0_o, sessionHmacAddr1_o, sessionHmacAddr2_o,
	output	[31:0]	authSize_o,
	
	// session validity
	output		sessionValid0_o, sessionValid1_o, sessionValid2_o
);
	
	// this module is simply instantiations and connections
	
	wire	[7:0]	RX_byte, TX_byte;
	wire		RX_valid, TX_valid;
	wire		TX_request, TX_received;
	
    wire spi_transaction_cs_n;
    spi_slave spi_serializer (
        .clock_i(clock50_i), .reset_n_i(reset_n_i),
        .rx_valid_o(RX_valid), .rx_data_o(RX_byte),
        .tx_valid_i(TX_valid), .tx_data_i(TX_byte),
        .tx_request_o(TX_request), .tx_received_o(TX_received),
        .spi_clock_i(SPI_clk_i), .spi_cs_n_i(SPI_cs_n_i),
        .spi_mosi_i(SPI_mosi_i), .spi_miso_o(SPI_miso_o),
        .chip_select_n_o(spi_transaction_cs_n)
    );
	
	wire	[15:0]	t_addr, t_baseAddr;
	wire		t_wren_n, t_rden_n;
	wire	[7:0]	t_readByte, t_writeByte;
	wire	[5:0]	t_size;
	wire		t_req;
	wire		t_updateAddr;
	
	tpm_spi_ctrl transaction_handler
	(
		.clock_i(clock50_i), .reset_n_i(reset_n_i),
		.SPI_CS_n_i(spi_transaction_cs_n),
		.SPI_RX_byte_i(RX_byte), .SPI_RX_valid_i(RX_valid),
		.SPI_TX_byte_o(TX_byte), .SPI_TX_valid_o(TX_valid),
		.SPI_TX_prepare_i(TX_request), .SPI_TX_ack_i(TX_received),
		.FRS_addr_o(t_addr), .FRS_baseAddr_o(t_baseAddr),
		.FRS_wren_n_o(t_wren_n), .FRS_rden_n_o(t_rden_n),
		.FRS_wrByte_o(t_writeByte), .FRS_rdByte_i(t_readByte),
		.CMD_size_o(t_size), .FRS_req_o(t_req),
		.updateAddr_o(t_updateAddr)
	);
	
	wire	[31:0]	c_rspSize;
	wire		c_cmdSend, c_rspSend, c_cmdDone, c_rspDone;
	wire	[11:0]	c_cmdAddr, c_rspAddr;
	wire	[7:0]	c_cmdByte, c_rspByte;
	wire		c_execDone, c_execAck;
	
	wire crb_scrub_done;
    assign exec_response_consumed_o = c_rspDone;
    tpm_reg_space #(.ENABLE_DEMO_COMMANDS(ENABLE_DEMO_COMMANDS),.CUSTOMER_DEMO_ENABLE(CUSTOMER_DEMO_ENABLE)) fifo_register_space
	(
        .snapshot_status_word_i(snapshot_status_word_i),.snapshot_operation_id_i(snapshot_operation_id_i),
        .snapshot_sequence_i(snapshot_sequence_i),.metrics_snapshot_i(metrics_snapshot_i),
		.clock_i(clock50_i), .reset_n_i(reset_n_i),
        .demo_admit_i(demo_admit_i && crb_scrub_done),
        .demo_transport_abort_o(demo_transport_abort_o),
		.t_req_i(t_req), .t_dir_i(t_wren_n),
		.t_size_i(t_size), .updateAddr_i(t_updateAddr),
		.t_address_i(t_addr), .t_baseAddr_i(t_baseAddr),
		.t_writeByte_i(t_writeByte), .t_readByte_o(t_readByte),
		.SPI_PIRQ_n_o(SPI_pirq_n_o), .locality_out_o(locality_o),
		.c_cmdSize_o(commandSize_o), .c_rspSize_i(c_rspSize),
		.c_cmdSend_o(c_cmdSend), .c_rspSend_i(c_rspSend),
		.c_cmdDone_i(c_cmdDone), .c_rspDone_i(c_rspDone),
		.c_cmdInAddr_i(c_cmdAddr), .c_rspInAddr_i(c_rspAddr),
		.c_cmdByteOut_o(c_cmdByte), .c_rspByteIn_i(c_rspByte),
		.e_execDone_i(c_execDone),
		.c_execDone_i(c_execDone), .c_execAck_o(c_execAck)
	);
	
	tpm_crb #(.SCOPED_COMMANDS(SCOPED_COMMANDS),
        .PRESERVE_LEGACY_COMMANDS(PRESERVE_LEGACY_COMMANDS),
        .CUSTOMER_DEMO_ENABLE(CUSTOMER_DEMO_ENABLE),
        .ENABLE_ENCRYPTDECRYPT2(ENABLE_ENCRYPTDECRYPT2),
        .ENABLE_DEMO_COMMANDS(ENABLE_DEMO_COMMANDS)) command_response_buffer
	(
        .exec_cmd_addr_i(exec_cmd_addr_i), .exec_cmd_byte_o(exec_cmd_byte_o),
        .exec_rsp_length_i(exec_rsp_length_i), .exec_rsp_addr_o(exec_rsp_addr_o),
        .exec_rsp_byte_i(exec_rsp_byte_i), .scrub_done_o(crb_scrub_done),
		.clock_i(clock50_i), .reset_n_i(reset_n_i),
		.locality_i(locality_o), .cmdAbort_i(1'b0),
		.cmdSize_i(commandSize_o), .rspSize_o(c_rspSize),
		.cmdSend_i(c_cmdSend), .rspSend_o(c_rspSend),
		.cmdDone_o(c_cmdDone), .rspDone_o(c_rspDone),
		.cmdByteIn_i(c_cmdByte), .rspByteOut_o(c_rspByte),
		.execDone_o(c_execDone), .execStart_o(execStart_o),
		.cmdOutAddr_o(c_cmdAddr), .rspOutAddr_o(c_rspAddr),
		.execAck_i(c_execAck), .rspReady_i(responseReady_i),
		.commandCode_o(commandCode_o), .responseCode_i(responseCode_i),
		.commandParam_o(commandParam_o), .commandTag_o(commandTag_o),
		.handle0_o(handle0_o), .handle1_o(handle1_o), .handle2_o(handle2_o),
		.sessionHandle0_o(sessionHandle0_o), .sessionHandle1_o(sessionHandle1_o), .sessionHandle2_o(sessionHandle2_o),
		.sessionNonceSize0_o(sessionNonceSize0_o), .sessionNonceSize1_o(sessionNonceSize1_o), .sessionNonceSize2_o(sessionNonceSize2_o),
		.sessionAttributes0_o(sessionAttributes0_o), .sessionAttributes1_o(sessionAttributes1_o), .sessionAttributes2_o(sessionAttributes2_o),
		.sessionHmacSize0_o(sessionHmacSize0_o), .sessionHmacSize1_o(sessionHmacSize1_o), .sessionHmacSize2_o(sessionHmacSize2_o),
		.sessionNonceAddr0_o(sessionNonceAddr0_o), .sessionNonceAddr1_o(sessionNonceAddr1_o), .sessionNonceAddr2_o(sessionNonceAddr2_o),
		.sessionHmacAddr0_o(sessionHmacAddr0_o), .sessionHmacAddr1_o(sessionHmacAddr1_o), .sessionHmacAddr2_o(sessionHmacAddr2_o),
		.authSize_o(authSize_o),
		.sessionValid0_o(sessionValid0_o), .sessionValid1_o(sessionValid1_o), .sessionValid2_o(sessionValid2_o)
	);
	
endmodule