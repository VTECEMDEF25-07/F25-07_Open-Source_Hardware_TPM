module	TPM_TOP
(
	input		CLOCK_50,
	input		CLOCK_100,
	input		RESET_n,
	
	input		SPI_CLOCK,
	input		SPI_CS_n,
	input		SPI_RST_n,
	input		SPI_MOSI,
	output		SPI_MISO,
	output		SPI_PIRQ_n
);
	wire		rst_n;
	assign	rst_n = SPI_RST_n & RESET_n;
	
	wire	[31:0]	commandCode;
	wire	[31:0]	responseCode;
	wire	[31:0]	commandSize;
	wire	[15:0]	commandTag, expectedTag;
	wire	[39:0]	commandParam;
	wire	[7:0]	locality;
	wire		execStart, responseReady;
	
	wire	[31:0]	handle0, handle1, handle2;
	wire	[31:0]	sessionHandle0, sessionHandle1, sessionHandle2;
	wire	[15:0]	sessionNonceSize0, sessionNonceSize1, sessionNonceSize2;
	wire	[7:0]	sessionAttributes0, sessionAttributes1, sessionAttributes2;
	wire	[15:0]	sessionHmacSize0, sessionHmacSize1, sessionHmacSize2;
	wire	[31:0]	authSize;
	wire		sessionValid0, sessionValid1, sessionValid2;
	
	wire	[2:0]	op_state, startup_type;
	wire		phEnable, phEnableNV;
	wire		shEnable, ehEnable;
	wire	[15:0]	shutdownSave;
	wire	[15:0]	testsRun, testsPassed, untested;
	wire	[15:0]	orderlyInput;
	wire		nv_phEnableNV, nv_shEnable, nv_ehEnable;
	wire	[31:0]	ee_responseCode, authHierarchy;
	wire		initialized;
	
	TPM_IO io
	(
		.clock50(CLOCK_50), .clock100(CLOCK_100),
		.reset_n(rst_n),
		.SPI_clk(SPI_CLOCK), .SPI_cs_n(SPI_CS_n),
		.SPI_mosi(SPI_MOSI), .SPI_miso(SPI_MISO),
		.SPI_pirq_n(SPI_PIRQ_n),
		
		.execStart(execStart), .responseReady(responseReady),
		.commandCode(commandCode), .responseCode(responseCode),
		.commandParam(commandParam), .commandTag(commandTag),
		.locality(locality), .commandSize(commandSize),
		
		.handle0(handle0), .handle1(handle1), .handle2(handle2),
		.sessionHandle0(sessionHandle0), .sessionHandle1(sessionHandle1), .sessionHandle2(sessionHandle2),
		.sessionNonceSize0(sessionNonceSize0), .sessionNonceSize1(sessionNonceSize1), .sessionNonceSize2(sessionNonceSize2),
		.sessionAttributes0(sessionAttributes0), .sessionAttributes1(sessionAttributes1), .sessionAttributes2(sessionAttributes2),
		.sessionHmacSize0(sessionHmacSize0), .sessionHmacSize1(sessionHmacSize1), .sessionHmacSize2(sessionHmacSize2),
		.authSize(authSize),
		.sessionValid0(sessionValid0), .sessionValid1(sessionValid1), .sessionValid2(sessionValid2)
	);
	
	management_module mm
	(
		.clock(CLOCK_50), .reset_n(rst_n),
		.keyStart_n(~execStart), .tpm_cc(commandCode),
		.cmd_param({commandParam[39:8], commandParam[0]}), .orderlyInput(orderlyInput),
		.initialized(1'b1), .authHierarchy(authHierarchy),
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
		.clock(CLOCK_50), .reset_n(rst_n), 
		.command_ready(execStart), .command_tag(commandTag), 
		.command_size(commandSize), .command_code(commandCode), 
		.command_length(commandSize[15:0]),
		.handle_0(handle0), .handle_1(handle1), .handle_2(handle2), 
		.session0_handle(sessionHandle0), .session1_handle(sessionHandle1), .session2_handle(sessionHandle2), 
		.session0_attributes(sessionAttributes0), .session1_attributes(sessionAttributes1), .session2_attributes(sessionAttributes2), 
		.session0_hmac_size(sessionHmacSize0), .session1_hmac_size(sessionHmacSize1), .session2_hmac_size(sessionHmacSize2), 
		
		.session0_valid(sessionValid0), .session1_valid(sessionValid1), .session2_valid(sessionValid2), 
		.authorization_size(authSize), .session_loaded(1'b1), 
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
		
		.response_valid(responseReady), .response_code(ee_responseCode)
	);
	
/*
	startup_procedures_check su_proc
	(
	);
*/
	
endmodule