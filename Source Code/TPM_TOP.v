// tpm_top.v
// modules:
//	tpm_top
//
// Authors:
//	Ian Sizemore (idsizemore@vt.edu)
//	Aaron Grossman (IP_TYPE parameter and gated internal keygen lifecycle)
// AI Disclosure: Codex assisted with the IP_TYPE and internal lifecycle changes.
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
    parameter ENABLE_ENCRYPTDECRYPT2 = 0, parameter ENABLE_GETRANDOM = 0,
    parameter ENABLE_INTERNAL_KEYGEN = 0,
    parameter ENABLE_AES_SLOT_CONSUMER = 0, ENABLE_AES_KEY_FIXTURE = 0,
    parameter ENABLE_PCR_EXTEND = 0,
    parameter [23:0] PCR_EXTEND_EMPTY_AUTH_MASK = 24'd0,
    parameter [4:0] PCR_EXTEND_LOCALITY_MASK = 5'b00001)
(
	input		CLOCK_50,	// 50 MHz sysclock
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
    input wire [31:0] aes_key_reply_code_i,
    // Trusted internal fixture only; no host authorization semantics.
    input wire aes_slot_allow_i
);

	// this module is simply instantiations and their connections

	wire		rst_n;
	assign	rst_n = SPI_RST_n & RESET_n;

    // Keep implementation validation independent of disabled worker pruning.
    generate if(IP_TYPE != 0 && IP_TYPE != 1) begin : invalid_ip_type
`ifdef VERILATOR
        initial begin $display("TPM_INVALID_IP_TYPE: use Generic=0 or Altera=1"); $stop; end
`else
        TPM_INVALID_IP_TYPE__USE_GENERIC_OR_ALTERA invalid_selection ();
`endif
    end else if(IP_TYPE == 1 && DEVICE_FAMILY != "Cyclone V" && DEVICE_FAMILY != "Agilex 5") begin : invalid_family
`ifdef VERILATOR
        initial begin $display("TPM_INVALID_DEVICE_FAMILY"); $stop; end
`else
        TPM_INVALID_DEVICE_FAMILY__USE_CYCLONE_V_OR_AGILEX_5 invalid_selection ();
`endif
    end endgenerate


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
	
    // Hash, GetRandom, PCR reads/capability, and optional AES use scoped packet handlers.
    // Preserve inherited routing for the remaining commands.
    wire scoped_command_en = commandCode == 32'h0000017d ||
        commandCode == 32'h00000193 || commandCode == 32'h17e || commandCode == 32'h17a || commandCode == 32'h182 || commandCode == 32'h17b;
    wire engine_response_ready;
    wire [11:0] exec_cmd_addr, exec_rsp_addr, exec_rsp_length;
    wire [7:0] exec_cmd_byte, exec_rsp_byte, hash_data;
    wire [31:0] exec_rsp_code;
    wire hash_request, hash_grant, hash_valid, hash_end, hash_ready;
    wire [255:0] hash_digest;
    wire hash_digest_valid, hash_digest_ready;

    // Phase One owns Hash, GetRandom and PCR acceptance, dispatch and completion.
    // The optional AES packet path retains its existing enable policy.
    wire select_aes = ENABLE_ENCRYPTDECRYPT2 && commandCode == 32'h00000193;
    wire [11:0] engine_cmd_addr, aes_cmd_addr, aes_rsp_length;
    wire [7:0] engine_rsp_byte, aes_rsp_byte;
    wire [31:0] aes_rsp_code;
    wire aes_rsp_valid;
    wire [15:0] engine_rsp_length;
    wire aes_lookup, aes_lookup_ready, aes_lookup_reply, aes_lookup_reply_ready;
    wire aes_key_release, aes_response_consumed;
    wire [31:0] aes_lookup_handle, aes_lookup_code;
    wire [255:0] aes_lookup_key;
    wire use_slot = ENABLE_INTERNAL_KEYGEN && ENABLE_AES_SLOT_CONSUMER;
    wire slot_lookup_ready, slot_lookup_reply;
    wire [31:0] slot_lookup_code;
    wire [255:0] slot_lookup_key;
    assign aes_lookup_ready = use_slot ? slot_lookup_ready :
        ENABLE_AES_KEY_FIXTURE ? aes_key_request_ready_i : 1'b1;
    assign aes_lookup_reply = use_slot ? slot_lookup_reply :
        ENABLE_AES_KEY_FIXTURE ? aes_key_reply_valid_i : 1'b1;
    assign aes_lookup_code = use_slot ? slot_lookup_code :
        ENABLE_AES_KEY_FIXTURE ? aes_key_reply_code_i : 32'h18b;
    assign aes_lookup_key = use_slot ? slot_lookup_key :
        ENABLE_AES_KEY_FIXTURE ? aes_resolved_key_i : 256'd0;

    assign exec_cmd_addr = select_aes ? aes_cmd_addr : engine_cmd_addr;
    assign exec_rsp_length = select_aes ? aes_rsp_length : engine_rsp_length[11:0];
    assign exec_rsp_byte = select_aes ? aes_rsp_byte : engine_rsp_byte;
    assign exec_rsp_code = select_aes ? aes_rsp_code : ee_responseCode;
    assign responseReady = select_aes ? aes_rsp_valid : engine_response_ready;

    generate if (ENABLE_ENCRYPTDECRYPT2) begin : aes_command_enabled
        execution_engine_aes_packet aes_command (
            .clock_i(CLOCK_50), .reset_n_i(rst_n),
            .start_i(execStart && select_aes), .operational_i(op_state == 3'b011),
            .command_tag_i(commandTag), .command_size_i(commandSize),
            .command_addr_o(aes_cmd_addr), .command_byte_i(exec_cmd_byte),
            .response_valid_o(aes_rsp_valid), .response_code_o(aes_rsp_code),
            .response_length_o(aes_rsp_length), .response_addr_i(exec_rsp_addr),
            .response_byte_o(aes_rsp_byte), .key_request_o(aes_lookup),
            .key_request_ready_i(aes_lookup_ready), .key_handle_o(aes_lookup_handle),
            .key_reply_valid_i(aes_lookup_reply), .key_reply_ready_o(aes_lookup_reply_ready),
            .resolved_key_i(aes_lookup_key), .key_reply_code_i(aes_lookup_code),
            .response_consumed_i(aes_response_consumed), .busy_o(), .key_release_o(aes_key_release)
        );
        assign aes_key_request_o=ENABLE_AES_KEY_FIXTURE && !use_slot && aes_lookup;
        assign aes_key_handle_o=ENABLE_AES_KEY_FIXTURE && !use_slot ? aes_lookup_handle : 32'd0;
        assign aes_key_reply_ready_o=ENABLE_AES_KEY_FIXTURE && !use_slot && aes_lookup_reply_ready;
    end else begin : aes_command_disabled
        assign aes_cmd_addr = 0;
        assign aes_rsp_length = 0;
        assign aes_rsp_byte = 0;
        assign aes_rsp_code = 0;
        assign aes_rsp_valid = 0;
        assign aes_key_request_o = 0;
        assign aes_key_handle_o = 0;
        assign aes_key_reply_ready_o = 0;
        assign aes_lookup=0; assign aes_lookup_handle=0;
        assign aes_lookup_reply_ready=0; assign aes_key_release=0;
    end endgenerate

    // Host Hash uses raw SHA; PCR_Read uses the same subsystem PCR bank.
    // Host Extend and RNG share SHA with raw Hash; HMAC remains inactive.
    wire pcr_extend_start, pcr_busy, pcr_done, pcr_error;
    wire [4:0] pcr_extend_index;
    wire [255:0] pcr_measurement;
    wire [7:0] command_locality;
    wire [4:0] pcr_read_index;
    wire [255:0] pcr_read_data;
    wire pcr_read_valid;
    wire [31:0] pcr_update_counter;
    wire [7:0] rng_hash_data;
    wire rng_hash_valid, rng_hash_last, rng_hash_ready, rng_digest_valid;
    wire [255:0] rng_digest, random_data;
    wire random_valid, random_request, rng_timeout, rng_fault;
    phase_one_rng #(.ENABLE(ENABLE_GETRANDOM || ENABLE_INTERNAL_KEYGEN)) rng (
        .clk(CLOCK_50), .rst_n(rst_n), .request_i(random_request),
        .timeout_i(rng_timeout), .random_o(random_data), .valid_o(random_valid),
        .fault_o(rng_fault), .hash_data_o(rng_hash_data),
        .hash_valid_o(rng_hash_valid), .hash_last_o(rng_hash_last),
        .hash_ready_i(rng_hash_ready), .digest_i(rng_digest), .digest_valid_i(rng_digest_valid));

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
        .pcr_extend_start_en_i(pcr_extend_start), .pcr_extend_index_i(pcr_extend_index),
        .pcr_measurement_i(pcr_measurement), .pcr_busy_o(pcr_busy),
        .pcr_done_o(pcr_done), .pcr_error_o(pcr_error), .pcr_read_index_i(pcr_read_index),
        .pcr_read_data_o(pcr_read_data), .pcr_read_valid_o(pcr_read_valid),
        .pcr_update_counter_o(pcr_update_counter),
        .rng_hash_msg_data_i(rng_hash_data), .rng_hash_msg_valid_i(rng_hash_valid),
        .rng_hash_msg_last_i(rng_hash_last), .rng_hash_msg_ready_o(rng_hash_ready),
        .rng_hash_digest_o(rng_digest), .rng_hash_digest_valid_o(rng_digest_valid)
    );

	tpm_io #(.SCOPED_COMMANDS(1), .PRESERVE_LEGACY_COMMANDS(1),
        .ENABLE_ENCRYPTDECRYPT2(ENABLE_ENCRYPTDECRYPT2)) io
	(
		.command_locality_o(command_locality),
		.clock50_i(CLOCK_50),
		.reset_n_i(rst_n),
		.SPI_clk_i(SPI_CLOCK), .SPI_cs_n_i(SPI_CS_n),
		.SPI_mosi_i(SPI_MOSI), .SPI_miso_o(SPI_MISO),
		.SPI_pirq_n_o(SPI_PIRQ_n),
		
		.execStart_o(execStart), .responseReady_i(responseReady),
		.commandCode_o(commandCode), .responseCode_i(scoped_command_en ? exec_rsp_code : responseCode),
        .exec_cmd_addr_i(exec_cmd_addr), .exec_cmd_byte_o(exec_cmd_byte),
        .exec_rsp_length_i(exec_rsp_length), .exec_rsp_addr_o(exec_rsp_addr),
        .exec_rsp_byte_i(exec_rsp_byte), .exec_rsp_consumed_o(aes_response_consumed),
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
    // placeholders. Scoped commands are isolated from these stubs; this routing
    // compatibility change does not implement real legacy authorization.
	execution_engine #(.ENABLE_INTERNAL_KEYGEN(ENABLE_INTERNAL_KEYGEN),
        .ENABLE_AES_SLOT_CONSUMER(ENABLE_AES_SLOT_CONSUMER && ENABLE_ENCRYPTDECRYPT2),
        .IP_TYPE(IP_TYPE), .DEVICE_FAMILY(DEVICE_FAMILY), .ENABLE_HASH_COMMAND(1), .ENABLE_PCR_COMMANDS(1), .ENABLE_GETRANDOM(ENABLE_GETRANDOM),
        .ENABLE_PCR_EXTEND(ENABLE_PCR_EXTEND),
        .PCR_EXTEND_EMPTY_AUTH_MASK(PCR_EXTEND_EMPTY_AUTH_MASK),
        .PCR_EXTEND_LOCALITY_MASK(PCR_EXTEND_LOCALITY_MASK)) ee
	(
		// No host access to the fixture or private consumer.
        .keygen_request_i(1'b0), .keygen_profile_i(2'd0), .keygen_id_i(32'd0), .keygen_allow_i(1'b0),
        .keygen_completion_ready_i(1'b1), .keygen_release_i(1'b0), .keygen_private_address_i(8'd0),
        .keygen_result_enable_i(1'b1), .keygen_ownership_enable_i(1'b1), .keygen_terminal_enable_i(1'b1),
        .aes_slot_request_i(use_slot && aes_lookup), .aes_slot_handle_i(aes_lookup_handle),
        .aes_slot_allow_i(aes_slot_allow_i), .aes_slot_request_ready_o(slot_lookup_ready),
        .aes_slot_reply_o(slot_lookup_reply), .aes_slot_reply_ready_i(aes_lookup_reply_ready),
        .aes_slot_key_o(slot_lookup_key), .aes_slot_code_o(slot_lookup_code),
        .aes_slot_release_i(aes_key_release), .aes_slot_reserved_o(),
        .clock_i(CLOCK_50), .reset_n_i(rst_n),
		.command_ready_i(execStart && !select_aes), .command_tag_i(commandTag),
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
		
		.response_valid_o(engine_response_ready), .response_code_o(ee_responseCode),
        .response_length_o(engine_rsp_length),
        .command_addr_o(engine_cmd_addr), .command_byte_i(exec_cmd_byte),
        .response_addr_i(exec_rsp_addr), .response_byte_o(engine_rsp_byte),
        .hash_request_o(hash_request), .hash_grant_i(hash_grant), .hash_data_o(hash_data),
        .hash_valid_o(hash_valid), .hash_end_o(hash_end), .hash_ready_i(hash_ready),
        .hash_digest_i(hash_digest), .hash_digest_valid_i(hash_digest_valid),
        .hash_digest_ready_o(hash_digest_ready),
        .pcr_read_index_o(pcr_read_index), .pcr_read_data_i(pcr_read_data),
        .pcr_read_valid_i(pcr_read_valid), .pcr_update_counter_i(pcr_update_counter),
        .locality_i(command_locality), .pcr_extend_start_o(pcr_extend_start),
        .pcr_extend_index_o(pcr_extend_index), .pcr_measurement_o(pcr_measurement),
        .pcr_busy_i(pcr_busy), .pcr_done_i(pcr_done), .pcr_error_i(pcr_error),
        .random_i(random_data), .random_valid_i(random_valid && !rng_fault),
        .random_request_o(random_request), .rng_fault_i(rng_fault), .rng_timeout_o(rng_timeout)
	);
	
//TODO: Needed?
	
	/*
	startup_procedures_check su_proc
	(
	);
*/
	
endmodule
