// tpm_top.v
// modules:
//	tpm_top
//
// Authors:
//	Ian Sizemore (idsizemore@vt.edu)
//	Aaron Grossman (IP_TYPE parameter and inactive keygen placeholder)
// AI Disclosure: Codex assisted with the IP_TYPE/placeholder changes.
//
// Date: 11/6/25
//
// General Description:
//	This file describes the top module of the TPM.
//	This instantiates and connects the i/o module, the management module,
//	and the execution engine.
// 


// IP_TYPE is the sole implementation selector; DEVICE_FAMILY is fixed board metadata.
// IP_TYPE: 0 = Generic, 1 = Altera, 2 = reserved Xilinx (unsupported).
module	TPM_TOP #(parameter IP_TYPE = 0, parameter DEVICE_FAMILY = "Agilex 5",
    parameter ENABLE_ENCRYPTDECRYPT2 = 0)
(
	input		CLOCK_50,	// 50 MHz sysclock
	input		CLOCK_100,	// 100 MHz clock (used for sampling SPI_CLOCK)
	input		RESET_n,	// async reset
	
	input		SPI_CLOCK,	// SPI clock
	input		SPI_CS_n,	// SPI chip select
	input		SPI_RST_n,	// SPI async reset
	input		SPI_MOSI,	// SPI mosi
	output		SPI_MISO,	// SPI miso
	output		SPI_PIRQ_n,	// SPI interrupt request

    // Optional object service. Normal board builds leave this feature disabled.
    output wire aes_key_request_o,
    input wire aes_key_request_ready_i,
    output wire [31:0] aes_key_handle_o,
    input wire aes_key_reply_valid_i,
    output wire aes_key_reply_ready_o,
    input wire [255:0] aes_resolved_key_i,
    input wire [31:0] aes_key_reply_code_i
);

	// this module is simply instantiations and their connections

	wire		rst_n;
	assign	rst_n = SPI_RST_n & RESET_n;

	// Temporary hierarchy only: keygen is not connected to TPM commands, entropy,
	// protected storage or response handling. Keep admission/data inputs inactive;
	// outputs are deliberately unused. Synthesis may remove this entire instance.
	keygen_core #(.IP_TYPE(IP_TYPE), .DEVICE_FAMILY(DEVICE_FAMILY)) keygen_placeholder (
		.clock_i(CLOCK_50), .reset_n_i(rst_n), .peers_ready_i(1'b0),
		.request_valid_i(1'b0), .request_ready_o(),
		.request_profile_i(2'd0), .request_id_i(32'd0),
		.generation_valid_i(1'b0), .generation_ready_o(),
		.generation_data_i(32'd0), .generation_failed_i(1'b0),
		.result_valid_o(), .result_ready_i(1'b0), .result_data_o(),
		.result_component_o(), .result_index_o(),
		.result_component_last_o(), .result_last_o(), .result_id_o(),
		.ownership_valid_i(1'b0), .ownership_ready_o(), .ownership_accept_i(1'b0),
		.result_discard_o(), .status_valid_o(), .status_ready_i(1'b0),
		.status_code_o(), .status_id_o()
	);
	
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
	
    // Only Hash and EncryptDecrypt2 use the new packet handlers. Preserve
    // the inherited parser/management/engine routes for every other command.
    wire scoped_command_en = commandCode == 32'h0000017d ||
        commandCode == 32'h00000193;
    wire legacy_response_ready;
    wire [11:0] exec_cmd_addr, exec_rsp_addr, exec_rsp_length;
    wire [7:0] exec_cmd_byte, exec_rsp_byte, hash_data;
    wire [31:0] exec_rsp_code;
    wire hash_request, hash_grant, hash_valid, hash_end, hash_ready;
    wire [255:0] hash_digest;
    wire hash_digest_valid, hash_digest_ready;

    // Command policy and packet fields are handled here. The SHA subsystem
    // receives only the validated message stream and returns its digest.
    wire select_aes = ENABLE_ENCRYPTDECRYPT2 && commandCode == 32'h00000193;
    wire [11:0] hash_cmd_addr, hash_rsp_length, aes_cmd_addr, aes_rsp_length;
    wire [7:0] hash_rsp_byte, aes_rsp_byte;
    wire [31:0] hash_rsp_code, aes_rsp_code;
    wire hash_rsp_valid, aes_rsp_valid;

    assign exec_cmd_addr = select_aes ? aes_cmd_addr : hash_cmd_addr;
    assign exec_rsp_length = select_aes ? aes_rsp_length : hash_rsp_length;
    assign exec_rsp_byte = select_aes ? aes_rsp_byte : hash_rsp_byte;
    assign exec_rsp_code = select_aes ? aes_rsp_code : hash_rsp_code;
    assign responseReady = scoped_command_en ?
        (select_aes ? aes_rsp_valid : hash_rsp_valid) : legacy_response_ready;

    generate if (ENABLE_ENCRYPTDECRYPT2) begin : aes_command_enabled
        execution_engine_aes_packet aes_command (
            .clock_i(CLOCK_50), .reset_n_i(rst_n),
            .start_i(execStart && select_aes), .operational_i(op_state == 3'b011),
            .command_tag_i(commandTag), .command_size_i(commandSize),
            .command_addr_o(aes_cmd_addr), .command_byte_i(exec_cmd_byte),
            .response_valid_o(aes_rsp_valid), .response_code_o(aes_rsp_code),
            .response_length_o(aes_rsp_length), .response_addr_i(exec_rsp_addr),
            .response_byte_o(aes_rsp_byte), .key_request_o(aes_key_request_o),
            .key_request_ready_i(aes_key_request_ready_i), .key_handle_o(aes_key_handle_o),
            .key_reply_valid_i(aes_key_reply_valid_i), .key_reply_ready_o(aes_key_reply_ready_o),
            .resolved_key_i(aes_resolved_key_i), .key_reply_code_i(aes_key_reply_code_i)
        );
    end else begin : aes_command_disabled
        assign aes_cmd_addr = 0;
        assign aes_rsp_length = 0;
        assign aes_rsp_byte = 0;
        assign aes_rsp_code = 0;
        assign aes_rsp_valid = 0;
        assign aes_key_request_o = 0;
        assign aes_key_handle_o = 0;
        assign aes_key_reply_ready_o = 0;
    end endgenerate

    execution_engine_hash hash_command (
        .clock_i(CLOCK_50), .reset_n_i(rst_n),
        .start_i(execStart && scoped_command_en && !select_aes), .operational_i(op_state == 3'b011),
        .command_tag_i(commandTag), .command_code_i(commandCode), .command_size_i(commandSize),
        .command_addr_o(hash_cmd_addr), .command_byte_i(exec_cmd_byte),
        .response_valid_o(hash_rsp_valid), .response_code_o(hash_rsp_code),
        .response_length_o(hash_rsp_length), .response_addr_i(exec_rsp_addr),
        .response_byte_o(hash_rsp_byte), .hash_request_o(hash_request),
        .hash_grant_i(hash_grant), .hash_data_o(hash_data), .hash_valid_o(hash_valid),
        .hash_end_o(hash_end), .hash_ready_i(hash_ready), .hash_digest_i(hash_digest),
        .hash_digest_valid_i(hash_digest_valid), .hash_digest_ready_o(hash_digest_ready)
    );

    // Only the raw SHA requester is connected in this host integration.
    // HMAC, PCR extend, and RNG keep their own interfaces for later wiring.
    hash_subsystem shared_hash (
        .clk_i(CLOCK_50), .reset_n_i(rst_n),
        .raw_request_i(hash_request), .raw_grant_o(hash_grant),
        .raw_data_i(hash_data), .raw_valid_i(hash_valid), .raw_end_i(hash_end),
        .raw_ready_o(hash_ready), .raw_digest_o(hash_digest),
        .raw_digest_valid_o(hash_digest_valid), .raw_digest_ready_i(hash_digest_ready),
        .hmac_start_en_i(1'b0), .hmac_key_data_i(8'd0),
        .hmac_key_valid_i(1'b0), .hmac_key_end_i(1'b0),
        .hmac_message_data_i(8'd0), .hmac_message_valid_i(1'b0),
        .hmac_message_end_i(1'b0), .hmac_digest_ready_i(1'b0),
        .pcr_extend_start_en_i(1'b0), .pcr_extend_index_i(5'd0),
        .pcr_measurement_i(256'd0), .pcr_read_index_i(5'd0),
        .rng_hash_msg_data_i(8'd0), .rng_hash_msg_valid_i(1'b0),
        .rng_hash_msg_last_i(1'b0)
    );

	tpm_io #(.SCOPED_COMMANDS(1), .PRESERVE_LEGACY_COMMANDS(1),
        .ENABLE_ENCRYPTDECRYPT2(ENABLE_ENCRYPTDECRYPT2)) io
	(
		.clock50_i(CLOCK_50), .clock100_i(CLOCK_100),
		.reset_n_i(rst_n),
		.SPI_clk_i(SPI_CLOCK), .SPI_cs_n_i(SPI_CS_n),
		.SPI_mosi_i(SPI_MOSI), .SPI_miso_o(SPI_MISO),
		.SPI_pirq_n_o(SPI_PIRQ_n),
		
		.execStart_o(execStart), .responseReady_i(responseReady),
		.commandCode_o(commandCode), .responseCode_i(scoped_command_en ? exec_rsp_code : responseCode),
        .exec_cmd_addr_i(exec_cmd_addr), .exec_cmd_byte_o(exec_cmd_byte),
        .exec_rsp_length_i(exec_rsp_length), .exec_rsp_addr_o(exec_rsp_addr),
        .exec_rsp_byte_i(exec_rsp_byte),
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
		.keyStart_n_i(~(execStart && !scoped_command_en)), .tpm_cc_i(commandCode[15:0]),
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
	
    // Preserve inherited command behavior, including its authorization
    // placeholders. Hash/AES are isolated from these stubs; this routing
    // compatibility change does not implement real legacy authorization.
	execution_engine ee
	(
		.clock_i(CLOCK_50), .reset_n_i(rst_n), 
		.command_ready_i(execStart && !scoped_command_en), .command_tag_i(commandTag),
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
		
		.response_valid_o(legacy_response_ready), .response_code_o(ee_responseCode)
	);
	
//TODO: Needed?
	
	/*
	startup_procedures_check su_proc
	(
	);
*/
	
endmodule
