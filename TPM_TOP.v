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
	input		clock_50_i,	// 50 MHz sysclock
	input		clock_100_i,	// 100 MHz clock (used for sampling SPI_CLOCK)
	input		reset_n_i,	// async reset
	
	input		spi_clock_i,	// SPI clock
	input		spi_cs_n_i,	// SPI chip select
	input		spi_rst_n_i,	// SPI async reset
	input		spi_mosi_i,	// SPI mosi
	output		spi_miso_o,	// SPI miso
	output		spi_pirq_n_o	// SPI interrupt request
);

	// this module is simply instantiations and their connections

	wire		rst_n;
	assign	rst_n = spi_rst_n_i & reset_n_i;
	
	wire	[31:0]	command_code;
	wire	[31:0]	response_code;
	wire	[31:0]	command_size;
	wire	[15:0]	command_tag, expected_tag;
	wire	[39:0]	command_param;
	wire	[7:0]	locality;
	wire		exec_start, response_ready;
	
	wire	[31:0]	handle0, handle1, handle2;
	wire	[31:0]	session_handle0, session_handle1, session_handle2;
	wire	[15:0]	session_nonce_size0, session_nonce_size1, session_nonce_size2;
	wire	[7:0]	session_attributes0, session_attributes1, session_attributes2;
	wire	[15:0]	session_hmac_size0, session_hmac_size1, session_hmac_size2;
	wire	[31:0]	auth_size;
	wire		session_valid0, session_valid1, session_valid2;
	
	wire	[2:0]	op_state, startup_type;
	wire		ph_en, ph_en_nv;
	wire		sh_en, eh_en;
	wire	[15:0]	shutdown_save;
	wire	[15:0]	tests_run, tests_passed, untested;
	wire	[15:0]	orderly_input;
	wire		nv_ph_en_nv, nv_sh_en, nv_eh_en;
	wire	[31:0]	ee_response_code, auth_hierarchy;
	wire		initialized;
	
	tpm_io io
	(
		.clock50(clock_50_i), .clock100(clock_100_i),
		.reset_n(rst_n),
		.SPI_clk(spi_clock_i), .SPI_cs_n(spi_cs_n_i),
		.SPI_mosi(spi_mosi_i), .SPI_miso(spi_miso_o),
		.SPI_pirq_n(spi_pirq_n_o),
		
		.execStart(exec_start), .responseReady(response_ready),
		.commandCode(command_code), .responseCode(response_code),
		.commandParam(command_param), .commandTag(command_tag),
		.locality(locality), .commandSize(command_size),
		
		.handle0(handle0), .handle1(handle1), .handle2(handle2),
		.sessionHandle0(session_handle0), .sessionHandle1(session_handle1), .sessionHandle2(session_handle2),
		.sessionNonceSize0(session_nonce_size0), .sessionNonceSize1(session_nonce_size1), .sessionNonceSize2(session_nonce_size2),
		.sessionAttributes0(session_attributes0), .sessionAttributes1(session_attributes1), .sessionAttributes2(session_attributes2),
		.sessionHmacSize0(session_hmac_size0), .sessionHmacSize1(session_hmac_size1), .sessionHmacSize2(session_hmac_size2),
		.authSize(auth_size),
		.sessionValid0(session_valid0), .sessionValid1(session_valid1), .sessionValid2(session_valid2)
	);
	
	management_module mm
	(
		.clock(clock_50_i), .reset_n(rst_n),
		.keyStart_n(~exec_start), .tpm_cc(command_code[15:0]),
		.cmd_param({command_param[39:8], command_param[0]}), .orderlyInput(orderly_input),
		.initialized(1'b1), .authHierarchy(command_param[39:8]),
		.executionEng_rc(ee_response_code), .locality(locality),
		.testsRun(tests_run), .testsPassed(tests_passed),
		.untested(untested), .nv_phEnableNV(nv_ph_en_nv),
		.nv_shEnable(nv_sh_en), .nv_ehEnable(nv_eh_en),
		.op_state(op_state), .startup_type(startup_type),
		.tpm_rc(response_code) , .phEnable(ph_en),
		.phEnableNV(ph_en_nv), .shEnable(sh_en),
		.ehEnable(eh_en), .shutdownSave(shutdown_save)
	);
	
	execution_engine ee
	(
		.clock_i(clock_50_i), .reset_n_i(rst_n), 
		.command_ready_i(exec_start), .command_tag_i(command_tag), 
		.command_size_i(command_size), .command_code_i(command_code), 
		.command_length_i(command_size[15:0]),
		.handle_0_i(handle0), .handle_1_i(handle1), .handle_2_i(handle2), 
		.session0_handle_i(session_handle0), .session1_handle_i(session_handle1), .session2_handle_i(session_handle2), 
		.session0_attributes_i(session_attributes0), .session1_attributes_i(session_attributes1), .session2_attributes_i(session_attributes2), 
		.session0_hmac_size_i(session_hmac_size0), .session1_hmac_size_i(session_hmac_size1), .session2_hmac_size_i(session_hmac_size2), 
		
		.session0_valid_i(session_valid0), .session1_valid_i(session_valid1), .session2_valid_i(session_valid2), 
		.authorization_size_i(auth_size), .session_loaded_i(1'b1), 
		.max_session_amount_i(16'd3), .auth_session_i(1'b1), .auth_necessary_i(1'b1), 
		.auth_handle_i(handle0), .pcr_select_i(), .auth_done_i(1'b1), .auth_response_code_i(12'h101),
		.auth_success_i(1'b0), .param_decrypt_success_i(1'b1), .param_decrypt_fail_i(1'b0),
		.param_unmarshall_success_i(1'b1), .param_unmarshall_fail_i(1'b0), 
		.execution_startup_done_i(1'b1), .execution_response_code_i(32'd0), 
		
		.nv_ph_en_nv_in_i(1'b1), .nv_sh_en_in_i(1'b1), 
		.nv_eh_en_in_i(1'b1), .tpm_nv_index_i(32'd0), 
		.nv_index_attributes_i(32'd0), .nv_object_present_i(1'b1), 
		.nv_index_present_i(1'b1), .entity_hierarchy_i(32'd0), 
		
		.mem_orderly_i(16'd0), .ram_available_i(1'b1), 
		.loaded_object_present_i(1'b1), .object_attributes_i(32'd0), 
		
		.st_tests_run_i(16'd0), .st_tests_passed_i(16'd0), 
		.st_untested_i(16'd0),
		
		.op_state_i(op_state), 
		.startup_type_i(startup_type), .ph_en_i(ph_en), 
		.ph_en_nv_i(ph_en_nv), .sh_en_i(sh_en), 
		.eh_en_i(eh_en), .shutdown_save_i(shutdown_save), 
		.command_done_i(1'b1), .tests_passed_o(tests_passed), 
		.untested_o(untested), .nv_ph_en_nv_o(nv_ph_en_nv), 
		.nv_sh_en_o(nv_sh_en), .nv_eh_en_o(nv_eh_en), 
		.orderly_input_o(orderly_input), .initialized_reg_o(initialized), 
		.tests_run_o(tests_run), .auth_hierarchy_o(auth_hierarchy), 
		
		// Creation boundary disabled until real validation, authorization and backend exist.
        .response_ready_i(1'b1), .command_cancel_i(1'b0),
        .keygen_descriptor_valid_i(1'b0), .keygen_session_validated_i(1'b0),
        .keygen_id_i(32'd0), .keygen_alg_i(2'd0), .keygen_bits_i(12'd0), .keygen_mode_i(2'd0),
        .keygen_context_i(32'd0), .keygen_destination_i(32'd0), .keygen_exponent_i(32'd0),
        .kg_req_ready_i(1'b0), .kg_cancel_ready_i(1'b0), .kg_rsp_valid_i(1'b0),
        .kg_rsp_id_i(32'd0), .kg_rsp_fail_i(1'b1), .kg_rsp_code_i(32'h00000143), .kg_rsp_object_i(32'd0),
        .command_accept_o(), .command_busy_o(), .keygen_busy_o(), .keygen_object_reg_o(),
        .kg_req_valid_o(), .kg_req_id_o(), .kg_req_alg_o(), .kg_req_bits_o(), .kg_req_mode_o(),
        .kg_req_context_o(), .kg_req_destination_o(), .kg_req_exponent_o(),
        .kg_cancel_valid_o(), .kg_cancel_id_o(), .kg_rsp_ready_o(),
        .response_valid_o(response_ready), .response_code_reg_o(ee_response_code)
	);
	
//TODO: Needed?
	
	/*
	startup_procedures_check su_proc
	(
	);
*/
	
endmodule
