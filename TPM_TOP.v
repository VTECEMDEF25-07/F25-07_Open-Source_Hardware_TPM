// tpm_top.v
// modules:
//	tpm_top
//
// Authors:
//	Ian Sizemore (idsizemore@vt.edu)
//
// Date: 11/6/25
//
// General Description:
//	This file describes the top module of the TPM.
//	This instantiates and connects the i/o module, the management module,
//	and the execution engine.
// 

module	tpm_top
(
	input		CLOCK_50,	// 50 MHz sysclock
	input		CLOCK_100,	// 100 MHz clock (used for sampling SPI_CLOCK)
	input		RESET_n,	// async reset
	
	input		SPI_CLOCK,	// SPI clock
	input		SPI_CS_n,	// SPI chip select
	input		SPI_RST_n,	// SPI async reset
	input		SPI_MOSI,	// SPI mosi
	output		SPI_MISO,	// SPI miso
	output		SPI_PIRQ_n	// SPI interrupt request
);

	// this module is simply instantiations and their connections

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
	
	tpm_io io
	(
		.clock50_i(CLOCK_50), .clock100_i(CLOCK_100),
		.reset_n_i(rst_n),
		.SPI_clk_i(SPI_CLOCK), .SPI_cs_n_i(SPI_CS_n),
		.SPI_mosi_i(SPI_MOSI), .SPI_miso_o(SPI_MISO),
		.SPI_pirq_n_o(SPI_PIRQ_n),
		
		.execStart_o(execStart), .responseReady_i(responseReady),
		.commandCode_o(commandCode), .responseCode_i(responseCode),
		.commandParam_o(commandParam), .commandTag_o(commandTag),
		.locality_o(locality), .commandSize_o(commandSize),
		
		.handle0_o(handle0), .handle1_o(handle1), .handle2_o(handle2),
		.sessionHandle0_o(sessionHandle0), .sessionHandle1_o(sessionHandle1), .sessionHandle2_o(sessionHandle2),
		.sessionNonceSize0_o(sessionNonceSize0), .sessionNonceSize1_o(sessionNonceSize1), .sessionNonceSize2_o(sessionNonceSize2),
		.sessionAttributes0_o(sessionAttributes0), .sessionAttributes1_o(sessionAttributes1), .sessionAttributes2_o(sessionAttributes2),
		.sessionHmacSize0_o(sessionHmacSize0), .sessionHmacSize1_o(sessionHmacSize1), .sessionHmacSize2_o(sessionHmacSize2),
		.authSize_o(authSize),
		.sessionValid0_o(sessionValid0), .sessionValid1_o(sessionValid1), .sessionValid2_o(sessionValid2)
	);
	
	management_module mm
	(
		.clock_i(CLOCK_50), .reset_n_i(rst_n),
		.keyStart_n_i(~execStart), .tpm_cc_i(commandCode[15:0]),
		.cmd_param_i({commandParam[39:8], commandParam[0]}), .orderlyInput_i(orderlyInput),
		.initialized_i(1'b1), .authHierarchy_i(commandParam[39:8]),
		.executionEng_rc_i(ee_responseCode), .locality_i(locality),
		.testsRun_i(testsRun), .testsPassed_i(testsPassed),
		.untested_i(untested), .nv_phEnableNV_i(nv_phEnableNV),
		.nv_shEnable_i(nv_shEnable), .nv_ehEnable_i(nv_ehEnable),
		.op_state_o(op_state), .startup_type_o(startup_type),
		.tpm_rc_o(responseCode) , .phEnable_o(phEnable),
		.phEnableNV_o(phEnableNV), .shEnable_o(shEnable),
		.ehEnable_o(ehEnable), .shutdownSave_o(shutdownSave)
	);
	
	execution_engine ee
	(
		.clock_i(CLOCK_50), .reset_n_i(rst_n), 
		.command_ready_i(execStart), .command_tag_i(commandTag), 
		.command_size_i(commandSize), .command_code_i(commandCode), 
		.command_length_i(commandSize[15:0]),
		.handle_0_i(handle0), .handle_1_i(handle1), .handle_2_i(handle2), 
		.session0_handle_i(sessionHandle0), .session1_handle_i(sessionHandle1), .session2_handle_i(sessionHandle2), 
		.session0_attributes_i(sessionAttributes0), .session1_attributes_i(sessionAttributes1), .session2_attributes_i(sessionAttributes2), 
		.session0_hmac_size_i(sessionHmacSize0), .session1_hmac_size_i(sessionHmacSize1), .session2_hmac_size_i(sessionHmacSize2), 
		
		.session0_valid_i(sessionValid0), .session1_valid_i(sessionValid1), .session2_valid_i(sessionValid2), 
		.authorization_size_i(authSize), .session_loaded_i(1'b1), 
		.max_session_amount_i(16'd3), .auth_session_i(1'b1), .auth_necessary_i(1'b1), 
		.authHandle_i(handle0), .pcrSelect_i(), .auth_done_i(1'b1), 
		.auth_success_i(1'b1), .param_decrypt_success_i(1'b1), .param_decrypt_fail_i(1'b0), 
		.param_unmarshall_success_i(1'b1), .param_unmarshall_fail_i(1'b0), 
		.execution_startup_done_i(1'b1), .execution_response_code_i(32'd0), 
		
		.nv_phEnableNV_in_i(1'b1), .nv_shEnable_in_i(1'b1), 
		.nv_ehEnable_in_i(1'b1), .tpm_nv_index_i(32'd0), 
		.nv_index_attributes_i(32'd0), .nv_object_present_i(1'b1), 
		.nv_index_present_i(1'b1), .entity_hierarchy_i(32'd0), 
		
		.mem_orderly_i(16'd0), .ram_available_i(1'b1), 
		.loaded_object_present_i(1'b1), .object_attributes_i(32'd0), 
		
		.st_testsRun_i(16'd0), .st_testsPassed_i(16'd0), 
		.st_untested_i(16'd0),
		
		.op_state_i(op_state), 
		.startup_type_i(startup_type), .phEnable_i(phEnable), 
		.phEnableNV_i(phEnableNV), .shEnable_i(shEnable), 
		.ehEnable_i(ehEnable), .shutdownSave_i(shutdownSave), 
		.command_done_i(1'b1), .testsPassed_o(testsPassed), 
		.untested_o(untested), .nv_phEnableNV_o(nv_phEnableNV), 
		.nv_shEnable_o(nv_shEnable), .nv_ehEnable_o(nv_ehEnable), 
		.orderlyInput_o(orderlyInput), .initialized_o(initialized), 
		.testsRun_o(testsRun), .authHierarchy_o(authHierarchy), 
		
		.response_valid_o(responseReady), .response_code_o(ee_responseCode)
	);
	
//TODO: Needed?
	
	/*
	startup_procedures_check su_proc
	(
	);
*/
	
endmodule