module execution_engine #(parameter KEYGEN_EXTERNAL_BACKEND = 0)(
		clock_i,
		reset_n_i,
		command_ready_i,
		command_tag_i,
		command_size_i,
		command_code_i,
		command_length_i,
		//command buffer inputs
		handle_0_i,
		handle_1_i,
		handle_2_i,
		session0_handle_i,
		session1_handle_i,
		session2_handle_i,
		session0_attributes_i,
		session1_attributes_i,
		session2_attributes_i,
		session0_hmac_size_i,
		session1_hmac_size_i,
		session2_hmac_size_i,
		session0_valid_i,
		session1_valid_i,
		session2_valid_i,
		authorization_size_i,
		session_loaded_i,
		max_session_amount_i,
		auth_session_i,
		auth_necessary_i,
		auth_handle_i,
		pcr_select_i,
		// Authorization submodule inputs
		auth_done_i,
		auth_success_i,
		auth_response_code_i,
		//inputs from param decrypt submodule
		param_decrypt_success_i,
		param_decrypt_fail_i,
		param_unmarshall_success_i,
		param_unmarshall_fail_i,
		//execution engine inputs
		execution_startup_done_i,
		execution_response_code_i,
		// NV memory submodule inputs
		nv_ph_en_nv_in_i,
		nv_sh_en_in_i,
		nv_eh_en_in_i,
		tpm_nv_index_i,
		nv_index_attributes_i,
		nv_object_present_i,
		nv_index_present_i,
		entity_hierarchy_i,
		// Memory submodule inputs
		mem_orderly_i,
		ram_available_i,
		loaded_object_present_i,
		object_attributes_i,
		// Self-test submodule inputs
		st_tests_run_i,
		st_tests_passed_i,
		st_untested_i,
		// Management module inputs 
		op_state_i,
		startup_type_i,
		ph_en_i,
		ph_en_nv_i,
		sh_en_i,
		eh_en_i,
		shutdown_save_i,
		command_done_i,
		//management outputs
		tests_passed_o,
		untested_o,
		nv_ph_en_nv_o,
		nv_sh_en_o,
		nv_eh_en_o,
		orderly_input_o,
		initialized_reg_o,
		tests_run_o,
		auth_hierarchy_o,
		// Response outputs
		response_valid_o,
		response_code_reg_o,
		response_length_o,
		current_state_reg_o,
		command_start_o,
		command_accept_o,
		command_busy_o,
		response_ready_i,
		command_cancel_i,
		keygen_descriptor_valid_i,
		keygen_session_validated_i,
		keygen_id_i,
		keygen_alg_i,
		keygen_bits_i,
		keygen_mode_i,
		keygen_context_i,
		keygen_destination_i,
		keygen_exponent_i,
		keygen_busy_o,
		keygen_object_reg_o,
		kg_req_valid_o,
		kg_req_ready_i,
		kg_req_id_o,
		kg_req_alg_o,
		kg_req_bits_o,
		kg_req_mode_o,
		kg_req_context_o,
		kg_req_destination_o,
		kg_req_exponent_o,
		kg_cancel_valid_o,
		kg_cancel_ready_i,
		kg_cancel_id_o,
		kg_rsp_valid_i,
		kg_rsp_ready_o,
		kg_rsp_id_i,
		kg_rsp_fail_i,
		kg_rsp_code_i,
		kg_rsp_object_i
	);


	// AI-authored bounded keygen interface. Disabled by default; see Key Generation/PLUMBING.md.
	output command_accept_o;
    output command_busy_o;
    input  response_ready_i;
	input  command_cancel_i;
	input  keygen_descriptor_valid_i;
	input  keygen_session_validated_i;
	input [31:0] keygen_id_i;
	input [1:0] keygen_alg_i;
	input [11:0] keygen_bits_i;
	input [1:0] keygen_mode_i;
	input [31:0] keygen_context_i;
	input [31:0] keygen_destination_i;
	input [31:0] keygen_exponent_i;
	output  keygen_busy_o;
	output reg [31:0] keygen_object_reg_o;
	output  kg_req_valid_o;
	input  kg_req_ready_i;
	output [31:0] kg_req_id_o;
	output [1:0] kg_req_alg_o;
	output [11:0] kg_req_bits_o;
	output [1:0] kg_req_mode_o;
	output [31:0] kg_req_context_o;
	output [31:0] kg_req_destination_o;
	output [31:0] kg_req_exponent_o;
	output  kg_cancel_valid_o;
	input  kg_cancel_ready_i;
	output [31:0] kg_cancel_id_o;
	input  kg_rsp_valid_i;
	output  kg_rsp_ready_o;
	input [31:0] kg_rsp_id_i;
	input  kg_rsp_fail_i;
	input [31:0] kg_rsp_code_i;
	input [31:0] kg_rsp_object_i;

	// Inputs
	input         clock_i;					// Input clock signal
	input         reset_n_i;				// Active-low input reset signal
	input         command_ready_i;	// Active-high input command valid signal perhaps we can create a combinational logic check for this in a separate module
	input  [15:0] command_tag_i;
	input	 [31:0] command_size_i;
	input  [31:0] command_code_i;
	input  [15:0] command_length_i;		// 16-bit input command length
	
	input [31:0] handle_0_i;
	input [31:0] handle_1_i;
	input [31:0] handle_2_i;	
	// Inputs from managemnt module - EXACT MATCH to management_module outputs
	input  [2:0]  op_state_i;				// 3-bit input operational state from management module
	input  [2:0]  startup_type_i;		// 3-bit input startup type from management module
	input         ph_en_i;				// 1-bit input platform hierarchy enable from management module
	input         ph_en_nv_i;			// 1-bit input platform hierarchy NV memory enable from management module
	input         sh_en_i;				// 1-bit input owner hierarchy enable from management module
	input         eh_en_i;				// 1-bit input endorsement hierarchy enable from management module
	input  [15:0] shutdown_save_i;		// 16-bit input shutdown type from management module
	//Inputs from command processing
	input 		  command_done_i;
	//inputs for session validation
	input [31:0] session0_handle_i;
	input [31:0] session1_handle_i;
	input [31:0] session2_handle_i;


	input [7:0] session0_attributes_i;
	input [7:0] session1_attributes_i;
	input [7:0] session2_attributes_i;


	input [15:0] session0_hmac_size_i;
	input [15:0] session1_hmac_size_i;
	input [15:0] session2_hmac_size_i;


	input session0_valid_i;
	input session1_valid_i;
	input session2_valid_i;
	input [31:0] authorization_size_i;
	input	session_loaded_i;
	input [15:0] max_session_amount_i;
	input auth_session_i;
	input auth_necessary_i;
	
	input [31:0] auth_handle_i;			// 32-bit input signal from command buffer indicating authorization control domain requested by command

	input [7:0] pcr_select_i;
	
	// Authorization inputs for authorization checks
	input auth_done_i;			// 1-bit input signal from authorization submodule indicating completion of authorization checks
	input auth_success_i;			// 1-bit input signal from authorization submodule indicating successful authorization
	input [11:0] auth_response_code_i;
	
	input param_decrypt_success_i;
	input param_decrypt_fail_i;
	input param_unmarshall_success_i;
	input param_unmarshall_fail_i;
	//startup error signal
	input execution_startup_done_i;
	//execution response code
	input [31:0] execution_response_code_i;
	
	// NV memory submodule inputs
	input nv_ph_en_nv_in_i;
	input nv_sh_en_in_i;
	input nv_eh_en_in_i;
	input [31:0] tpm_nv_index_i;
	input [31:0] nv_index_attributes_i;
	input nv_object_present_i;
	input nv_index_present_i;
	input [31:0] entity_hierarchy_i;
	
	// Memory submodule inputs
	input [15:0] mem_orderly_i;
	input ram_available_i;
	input loaded_object_present_i;
	input [31:0] object_attributes_i;
	
	// Self-test submodule inputs
	input [15:0] st_tests_run_i;
	input [15:0] st_tests_passed_i;
	input [15:0] st_untested_i;
	
	// Outputs
	output        response_valid_o;		// 1-bit output response valid signal
	output [31:0] response_code_reg_o;		// 32-bit output response code
	output [15:0] response_length_o;		// 16-bit output response length
	output [3:0]  current_state_reg_o;		// 4-bit output current pipeline stage
   output reg    command_start_o;
	   
	//////////////////////////////////////////////////////////////////////////////////////////////////////////
	output	 [15:0] orderly_input_o;		// 2-byte (16 bits) input from memory of state of last shutdown state
	output reg	     initialized_reg_o;			// 1-bit input intialized bit (from execution engine)
	output	 [15:0] tests_run_o;				// 2-byte (16 bits) input of amount of tests run by the self-test module, from the execution engine
	output	 [15:0] tests_passed_o;			// 2-byte (16 bits) input of amount of tests that have run and passed by the self-test module, from the execution engine
	output	 [15:0] untested_o;				// 2-byte (16 bits) input of amount of tests that still need to be run by the self-test module, from the execution engine
	output 		     nv_ph_en_nv_o;		// 1-bit input of state of phEnableNV switch, from Non-Volatile memory
	output	        nv_sh_en_o;			// 1-bit input of state of shEnable switch, from Non-Volatile memory
	output           nv_eh_en_o;			// 1-bit input of state of ehEnable switch, from Non-Volatile memory
	// Outputs to management module - EXACT MATCH to management_module inputs
	output	 [31:0] auth_hierarchy_o;		// 2-byte (16 bits) input verifying which hiearchy was authorized (from execution engine)
	
	// ============================================================================
	// PIPELINE STAGES - TCG TPM 2.0 Specification Part 3, Section 5: Command Processing
	// ============================================================================
	localparam STATE_IDLE          = 4'b0000,	// Wait for command
				  STATE_HEADER_VALID  = 4'b0001,	// Section 5.2: Command Header Validation
				  STATE_MODE_CHECK    = 4'b0010,	// Section 5.3: Mode Checks  
				  STATE_HANDLE_VALID  = 4'b0011,	// Section 5.4: Handle Area Validation
				  STATE_SESSION_VALID = 4'b0100,	// Section 5.5: Session Area Validation
				  STATE_AUTH_CHECK    = 4'b0101,	// Section 5.6: Authorization Checks
				  STATE_PARAM_DECRYPT = 4'b0110,	// Section 5.7: Parameter Decryption
				  STATE_PARAM_UNMARSH = 4'b0111,	// Section 5.8: Parameter Unmarshaling
				  STATE_EXECUTE       = 4'b1000,	// Section 5.9: Command Execution
				  STATE_POST_PROCESS  = 4'b1001;	// Section 5.10: Command Post-Processing
	
	// ============================================================================
	// OPERATIONAL STATES FROM MANAGEMENT MODULE
	// ============================================================================
	localparam POWER_OFF_STATE       = 3'b000,
				  INITIALIZATION_STATE = 3'b001, 
				  STARTUP_STATE        = 3'b010,
				  OPERATIONAL_STATE    = 3'b011,
				  SELF_TEST_STATE      = 3'b100,
				  FAILURE_MODE_STATE   = 3'b101,
				  SHUTDOWN_STATE       = 3'b110;
	
	// ============================================================================
	// RESPONSE CODES - TCG TPM 2.0 Specification Part 2, Section 6.6: Response Codes
	// ============================================================================
 localparam RC_VER1 = 12'h100,	// set for all format 0 response codes
				RC_FMT1 = 12'h080,	// This bit is SET in all format 1 response codes 
											// The codes in this group may have a value added to them to indicate the handle, session, or parameter to which they apply.
				RC_WARN = 12'h900;	// set for warning response codes
				
 localparam TPM_RC_SUCCESS       = 12'h000,
				TPM_RC_BAD_TAG       = 12'h01E,  // Bad command tag:contentReference[oaicite:22]{index=22}
				TPM_RC_COMMAND_SIZE  = 12'h042,  // Command size mismatch
				TPM_RC_COMMAND_CODE  = 12'h043,  // Unimplemented/unsupported command
				TPM_RC_FAILURE       = RC_VER1 + 12'h001,  // TPM in failure mode
				TPM_RC_INITIALIZE    = RC_VER1 + 12'h000,  // TPM not initialized
				TPM_RC_HANDLE        = RC_FMT1 + 12'h00B,  // Handle error (e.g., invalid handle or hierarchy disabled)
				TPM_RC_AUTH_MISSING  = RC_VER1 + 12'h024,  // Authorization required but not provided
				TPM_RC_AUTH_FAIL     = RC_FMT1 + 12'h00E,  // Authorization failure
				TPM_RC_PP            = RC_FMT1 + 12'h010,  // Physical presence required (e.g., for TPM2_Clear)
				TPM_RC_AUTHSIZE		= RC_VER1 + 12'h044,  // the value of authorizationSize is out of range or the number of octets in the Authorization Area is greater than required
				TPM_RC_AUTH_CONTEXT  = RC_VER1 + 12'h045,  // use of an authorization session with a context command or another command that cannot have an authorization session.
				// Additional response codes for handle-specific errors:
				TPM_RC_REFERENCE_H0  = RC_WARN + 12'h010,  // 1st handle references a transient object or session that is not loaded:contentReference[oaicite:23]{index=23}
				TPM_RC_REFERENCE_H1  = RC_WARN + 12'h011,  // 2nd handle not loaded
				TPM_RC_REFERENCE_H2  = RC_WARN + 12'h012,  // 3rd handle not loaded
				// (TPM_RC_REFERENCE_H3, H4... would continue if more handles)
				// Additional response codes for handle-specific errors:
				TPM_RC_REFERENCE_S0  = RC_WARN + 12'h018,  
				// (TPM_RC_REFERENCE_H3, H4... would continue if more handles)
				TPM_RC_NV_LOCKED     = RC_VER1 + 12'h048,  // NV index is locked (NOTE: spec combines RC_NV_LOCKED with parameter/handle index coding, but using a generic code here)
				TPM_RC_HIERARCHY     = RC_FMT1 + 12'h005,  // Hierarchy is disabled:contentReference[oaicite:24]{index=24}
				TPM_RC_VALUE         = RC_VER1 + 12'h024,  // Value is out of range or inconsistent (e.g., bad PCR index or handle type):contentReference[oaicite:25]{index=25}
				TPM_RC_ATTRIBUTES		= RC_FMT1 + 12'h002,  // inconsistent attributes
				TPM_RC_OBJECT_MEMORY = RC_WARN + 12'h002;  // out of memory for object contexts

	// ============================================================================
	// HANDLE TYPES
	// ============================================================================
	localparam TPM_HT_PCR 				= 8'h00,
				  TPM_HT_NV_INDEX       = 8'h01,
				  TPM_HT_HMAC_SESSION 	= 8'h02,
				  TPM_HT_LOADED_SESSION = 8'h02,
				  TPM_HT_POLICY_SESSION = 8'h03,
				  TPM_HT_SAVED_SESSION 	= 8'h03,
				  TPM_HT_PERMANENT 		= 8'h40,
				  TPM_HT_TRANSIENT 		= 8'h80,
				  TPM_HT_PERSISTENT 		= 8'h81,
				  TPM_HT_AC 				= 8'h90;
				  
	// ============================================================================
	// NON-VOLATILE HANDLE TYPES
	// ============================================================================
	localparam TPM_NT_ORDINARY = 4'h0,
				  TPM_NT_COUNTER  = 4'h1,
				  TPM_NT_BITS     = 4'h2,
				  TPM_NT_EXTEND	= 4'h4,
				  TPM_NT_PIN_FAIL = 4'h8,
				  TPM_NT_PIN_PASS = 4'h9;
	
	// ============================================================================
	// PERMANENT HANDLES
	// ============================================================================
	localparam TPM_RH_PLATFORM  = 32'h4000000C,	// Handle references the Platform Primary Seed (PPS), platformAuth, and platformPolicy
			   TPM_RH_OWNER    	 = 32'h40000001,	// Handle references the Storage Primary Seed (SPS), the ownerAuth, and the ownerPolicy
			   TPM_RH_ENDORSEMENT = 32'h4000000B,	// Handle references the Endorsement Primary Seed (EPS), endorsementAuth, and endorsementPolicy
			   TPM_RH_NULL		  	 = 32'h40000007,	// A handle associated with the null hierarchy, and Empty Auth authValue, and an Empty Policy authPolicy
				TPM_RS_PW			 = 32'h40000009;  // authorization value used to indicate a password authorization session
	
	// ============================================================================
	// COMMAND TAGS AND CODES
	// ============================================================================
	localparam TPM_ST_NO_SESSIONS = 16'h8001,	// Command has no sessions
				  TPM_ST_SESSIONS    = 16'h8002;	// Command has sessions
	
    localparam TPM_CC_NV_UNDEFINE_SPACE_SPECIAL = 16'h011F,
               TPM_CC_EVICT_CONTROL            = 16'h0120,
               TPM_CC_HIERARCHY_CONTROL        = 16'h0121,
               TPM_CC_NV_UNDEFINE_SPACE        = 16'h0122,
               TPM_CC_CHANGE_EPS               = 16'h0124,
               TPM_CC_CHANGE_PPS               = 16'h0125,
               TPM_CC_CLEAR                    = 16'h0126,  // TPM2_Clear
               TPM_CC_CLEAR_CONTROL            = 16'h0127,
               TPM_CC_CLOCK_SET                = 16'h0128,
               TPM_CC_HIERARCHY_CHANGE_AUTH    = 16'h0129,
               TPM_CC_NV_DEFINE_SPACE          = 16'h012A,
               TPM_CC_PCR_ALLOCATE             = 16'h012B,
               TPM_CC_PCR_SET_AUTH_POLICY      = 16'h012C,
               TPM_CC_PP_COMMANDS              = 16'h012D,
               TPM_CC_SET_PRIMARY_POLICY       = 16'h012E,
               // FieldUpgradeStart (0x0000012F) and FieldUpgradeData (0x00000141) are *not* supported in this implementation
               TPM_CC_CLOCK_RATE_ADJUST        = 16'h0130,
               TPM_CC_CREATE_PRIMARY           = 16'h0131,
               TPM_CC_NV_GLOBAL_WRITE_LOCK     = 16'h0132,
               TPM_CC_GET_COMMAND_AUDIT_DIGEST = 16'h0133,
               TPM_CC_NV_INCREMENT             = 16'h0134,
               TPM_CC_NV_SET_BITS              = 16'h0135,
               TPM_CC_NV_EXTEND                = 16'h0136,
               TPM_CC_NV_WRITE                 = 16'h0137,
               TPM_CC_NV_WRITE_LOCK            = 16'h0138,
               TPM_CC_DICTIONARY_ATTACK_LOCK_RESET = 16'h0139,
               TPM_CC_DICTIONARY_ATTACK_PARAMETERS = 16'h013A,
               TPM_CC_NV_CHANGE_AUTH           = 16'h013B,
               TPM_CC_PCR_EVENT                = 16'h013C,
               TPM_CC_PCR_RESET                = 16'h013D,
               TPM_CC_SEQUENCE_COMPLETE        = 16'h013E,
               TPM_CC_SET_ALGORITHM_SET        = 16'h013F,
               TPM_CC_SET_COMMAND_CODE_AUDIT_STATUS = 16'h0140,
               TPM_CC_INCREMENTAL_SELF_TEST    = 16'h0142,
               TPM_CC_SELF_TEST                = 16'h0143,
               TPM_CC_STARTUP                  = 16'h0144,  // TPM2_Startup
               TPM_CC_SHUTDOWN                 = 16'h0145,
               TPM_CC_STIR_RANDOM              = 16'h0146,
               TPM_CC_ACTIVATE_CREDENTIAL      = 16'h0147,
               TPM_CC_CERTIFY                  = 16'h0148,
               TPM_CC_POLICY_NV                = 16'h0149,
               TPM_CC_CERTIFY_CREATION         = 16'h014A,
               TPM_CC_DUPLICATE                = 16'h014B,
               TPM_CC_GET_TIME                 = 16'h014C,
               TPM_CC_GET_SESSION_AUDIT_DIGEST = 16'h014D,
               TPM_CC_NV_READ                  = 16'h014E,
               TPM_CC_NV_READ_LOCK             = 16'h014F,
               TPM_CC_OBJECT_CHANGE_AUTH       = 16'h0150,
               TPM_CC_POLICY_SECRET            = 16'h0151,
               TPM_CC_REWRAP                   = 16'h0152,
               TPM_CC_CREATE                   = 16'h0153,
               TPM_CC_ECDH_ZGEN                = 16'h0154,
               TPM_CC_HMAC                     = 16'h0155,
               TPM_CC_IMPORT                   = 16'h0156,
               TPM_CC_LOAD                     = 16'h0157,
               TPM_CC_QUOTE                    = 16'h0158,
               TPM_CC_RSA_DECRYPT              = 16'h0159,
               TPM_CC_HMAC_START               = 16'h015B,
               TPM_CC_SEQUENCE_UPDATE          = 16'h015C,
               TPM_CC_SIGN                     = 16'h015D,
               TPM_CC_UNSEAL                   = 16'h015E,
               TPM_CC_POLICY_SIGNED            = 16'h0160,
               TPM_CC_CONTEXT_LOAD             = 16'h0161,
               TPM_CC_CONTEXT_SAVE             = 16'h0162,
               TPM_CC_ECDH_KEY_GEN             = 16'h0163,
               TPM_CC_ENCRYPT_DECRYPT          = 16'h0164,
               TPM_CC_FLUSH_CONTEXT            = 16'h0165,
               TPM_CC_LOAD_EXTERNAL            = 16'h0167,
               TPM_CC_MAKE_CREDENTIAL          = 16'h0168,
               TPM_CC_NV_READ_PUBLIC           = 16'h0169,
               TPM_CC_POLICY_AUTHORIZE         = 16'h016A,
               TPM_CC_POLICY_AUTH_VALUE        = 16'h016B,
               TPM_CC_POLICY_COMMAND_CODE      = 16'h016C,
               TPM_CC_POLICY_COUNTER_TIMER     = 16'h016D,
               TPM_CC_POLICY_CP_HASH           = 16'h016E,
               TPM_CC_POLICY_LOCALITY          = 16'h016F,
               TPM_CC_POLICY_NAME_HASH         = 16'h0170,
               TPM_CC_POLICY_OR                = 16'h0171,
               TPM_CC_POLICY_TICKET            = 16'h0172,
               TPM_CC_READ_PUBLIC              = 16'h0173,
               TPM_CC_RSA_ENCRYPT              = 16'h0174,
               TPM_CC_START_AUTH_SESSION       = 16'h0176,
               TPM_CC_VERIFY_SIGNATURE         = 16'h0177,
               TPM_CC_ECC_PARAMETERS           = 16'h0178,
               TPM_CC_FIRMWARE_READ            = 16'h0179,
               TPM_CC_GET_CAPABILITY           = 16'h017A,
               TPM_CC_GET_RANDOM               = 16'h017B,
               TPM_CC_GET_TEST_RESULT          = 16'h017C,  // TPM2_GetTestResult
               TPM_CC_HASH                     = 16'h017D,
               TPM_CC_PCR_READ                 = 16'h017E,
               TPM_CC_POLICY_PCR               = 16'h017F,
               TPM_CC_POLICY_RESTART           = 16'h0180,
               TPM_CC_READ_CLOCK               = 16'h0181,
               TPM_CC_PCR_EXTEND               = 16'h0182,
               TPM_CC_PCR_SET_AUTH_VALUE       = 16'h0183,
               TPM_CC_NV_CERTIFY               = 16'h0184,
               TPM_CC_EVENT_SEQUENCE_COMPLETE  = 16'h0185,
               TPM_CC_HASH_SEQUENCE_START      = 16'h0186,
               TPM_CC_POLICY_PHYSICAL_PRESENCE = 16'h0187,
               TPM_CC_POLICY_DUPLICATION_SELECT= 16'h0188,
               TPM_CC_POLICY_GET_DIGEST        = 16'h0189,
               TPM_CC_TEST_PARMS               = 16'h018A,
               TPM_CC_COMMIT                   = 16'h018B,
               TPM_CC_POLICY_PASSWORD          = 16'h018C,
               TPM_CC_ZGEN_2_PHASE              = 16'h018D,
               TPM_CC_EC_EPHEMERAL             = 16'h018E,
               TPM_CC_POLICY_NV_WRITTEN        = 16'h018F,
               TPM_CC_POLICY_TEMPLATE          = 16'h0190,
               TPM_CC_CREATE_LOADED            = 16'h0191,
               TPM_CC_POLICY_AUTHORIZE_NV      = 16'h0192,
               TPM_CC_ENCRYPT_DECRYPT_2        = 16'h0193,
               TPM_CC_AC_GET_CAPABILITY        = 16'h0194,
               TPM_CC_AC_SEND                  = 16'h0195,
               TPM_CC_POLICY_AC_SEND_SELECT    = 16'h0196;
					
	// ============================================================================
	// IMPLENTATION-DEPENDENT CONSTANTS
	// ============================================================================
	localparam PCR_SELECT_MAX = 8'd255;			// Max PCRs based on implementation
	
	// ============================================================================
	// INTERNAL REGISTERS
	// ============================================================================

	reg command_armed_reg, execution_started_reg, startup_success_reg;
    assign command_accept_o = reset_n_i && current_state_reg_o == STATE_IDLE && command_ready_i && command_armed_reg;
    assign command_busy_o = reset_n_i && current_state_reg_o != STATE_IDLE;
	reg [15:0]  cmd_command_tag_reg;
	reg [31:0]  cmd_command_size_reg;
	reg [31:0]  cmd_command_code_reg;
	reg [15:0]  cmd_command_length_reg;
	reg [31:0]  cmd_handle_0_reg;
	reg [31:0]  cmd_handle_1_reg;
	reg [31:0]  cmd_handle_2_reg;
	reg [31:0]  cmd_session0_handle_reg;
	reg [31:0]  cmd_session1_handle_reg;
	reg [31:0]  cmd_session2_handle_reg;
	reg [7:0]  cmd_session0_attributes_reg;
	reg [7:0]  cmd_session1_attributes_reg;
	reg [7:0]  cmd_session2_attributes_reg;
	reg [15:0]  cmd_session0_hmac_size_reg;
	reg [15:0]  cmd_session1_hmac_size_reg;
	reg [15:0]  cmd_session2_hmac_size_reg;
	reg  cmd_session0_valid_reg;
	reg  cmd_session1_valid_reg;
	reg  cmd_session2_valid_reg;
	reg [31:0]  cmd_authorization_size_reg;
	reg  cmd_session_loaded_reg;
	reg [15:0]  cmd_max_session_amount_reg;
	reg  cmd_auth_session_reg;
	reg  cmd_auth_necessary_reg;
	reg [31:0]  cmd_auth_handle_reg;
	reg [7:0]  cmd_pcr_select_reg;
	reg  cmd_keygen_descriptor_valid_reg;
	reg  cmd_keygen_session_validated_reg;
	reg [31:0]  cmd_keygen_id_reg;
	reg [1:0]  cmd_keygen_alg_reg;
	reg [11:0]  cmd_keygen_bits_reg;
	reg [1:0]  cmd_keygen_mode_reg;
	reg [31:0]  cmd_keygen_context_reg;
	reg [31:0]  cmd_keygen_destination_reg;
	reg [31:0]  cmd_keygen_exponent_reg;
	wire is_creation = cmd_command_code_reg[15:0] == TPM_CC_CREATE || cmd_command_code_reg[15:0] == TPM_CC_CREATE_PRIMARY || cmd_command_code_reg[15:0] == TPM_CC_CREATE_LOADED;
    wire kg_terminal_valid;
    wire [31:0] kg_terminal_code, kg_terminal_object;
    keygen_dispatch_adapter #(.EXTERNAL_BACKEND(KEYGEN_EXTERNAL_BACKEND)) keygen_dispatch (
        .clock_i(clock_i), .reset_n_i(reset_n_i), .start_i(current_state_reg_o == STATE_EXECUTE && is_creation),
        .descriptor_valid_i(cmd_keygen_descriptor_valid_reg), .session_validated_i(cmd_keygen_session_validated_reg),
        .command_code_i(cmd_command_code_reg), .descriptor_id_i(cmd_keygen_id_reg), .descriptor_alg_i(cmd_keygen_alg_reg),
        .descriptor_bits_i(cmd_keygen_bits_reg), .descriptor_mode_i(cmd_keygen_mode_reg),
        .descriptor_context_i(cmd_keygen_context_reg), .descriptor_destination_i(cmd_keygen_destination_reg),
        .descriptor_exponent_i(cmd_keygen_exponent_reg), .cancel_i(command_cancel_i), .busy_o(keygen_busy_o),
        .terminal_valid_o(kg_terminal_valid), .terminal_ready_i(current_state_reg_o == STATE_EXECUTE && is_creation),
        .terminal_code_reg_o(kg_terminal_code), .terminal_object_reg_o(kg_terminal_object),
        .req_valid_o(kg_req_valid_o), .req_ready_i(kg_req_ready_i), .req_id_reg_o(kg_req_id_o), .req_alg_reg_o(kg_req_alg_o),
        .req_bits_reg_o(kg_req_bits_o), .req_mode_reg_o(kg_req_mode_o), .req_context_reg_o(kg_req_context_o),
        .req_destination_reg_o(kg_req_destination_o), .req_exponent_reg_o(kg_req_exponent_o),
        .cancel_valid_o(kg_cancel_valid_o), .cancel_ready_i(kg_cancel_ready_i), .cancel_id_o(kg_cancel_id_o),
        .rsp_valid_i(kg_rsp_valid_i), .rsp_ready_o(kg_rsp_ready_o), .rsp_id_i(kg_rsp_id_i),
        .rsp_fail_i(kg_rsp_fail_i), .rsp_code_i(kg_rsp_code_i), .rsp_object_i(kg_rsp_object_i)
    );
    // Descriptor/session approval must refer to this accepted command and context.
    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            command_armed_reg <= 1'b0; execution_started_reg <= 1'b0; startup_success_reg <= 1'b0;
            keygen_object_reg_o <= 0;
            cmd_command_tag_reg <= 0;
            cmd_command_size_reg <= 0;
            cmd_command_code_reg <= 0;
            cmd_command_length_reg <= 0;
            cmd_handle_0_reg <= 0;
            cmd_handle_1_reg <= 0;
            cmd_handle_2_reg <= 0;
            cmd_session0_handle_reg <= 0;
            cmd_session1_handle_reg <= 0;
            cmd_session2_handle_reg <= 0;
            cmd_session0_attributes_reg <= 0;
            cmd_session1_attributes_reg <= 0;
            cmd_session2_attributes_reg <= 0;
            cmd_session0_hmac_size_reg <= 0;
            cmd_session1_hmac_size_reg <= 0;
            cmd_session2_hmac_size_reg <= 0;
            cmd_session0_valid_reg <= 0;
            cmd_session1_valid_reg <= 0;
            cmd_session2_valid_reg <= 0;
            cmd_authorization_size_reg <= 0;
            cmd_session_loaded_reg <= 0;
            cmd_max_session_amount_reg <= 0;
            cmd_auth_session_reg <= 0;
            cmd_auth_necessary_reg <= 0;
            cmd_auth_handle_reg <= 0;
            cmd_pcr_select_reg <= 0;
            cmd_keygen_descriptor_valid_reg <= 0;
            cmd_keygen_session_validated_reg <= 0;
            cmd_keygen_id_reg <= 0;
            cmd_keygen_alg_reg <= 0;
            cmd_keygen_bits_reg <= 0;
            cmd_keygen_mode_reg <= 0;
            cmd_keygen_context_reg <= 0;
            cmd_keygen_destination_reg <= 0;
            cmd_keygen_exponent_reg <= 0;
        end else begin
            if (!command_ready_i) command_armed_reg <= 1'b1;
            if (current_state_reg_o == STATE_IDLE && command_ready_i && command_armed_reg) begin
                command_armed_reg <= 1'b0; execution_started_reg <= 1'b0; startup_success_reg <= 1'b0;
                keygen_object_reg_o <= 0;
                cmd_command_tag_reg <= command_tag_i;
                cmd_command_size_reg <= command_size_i;
                cmd_command_code_reg <= command_code_i;
                cmd_command_length_reg <= command_length_i;
                cmd_handle_0_reg <= handle_0_i;
                cmd_handle_1_reg <= handle_1_i;
                cmd_handle_2_reg <= handle_2_i;
                cmd_session0_handle_reg <= session0_handle_i;
                cmd_session1_handle_reg <= session1_handle_i;
                cmd_session2_handle_reg <= session2_handle_i;
                cmd_session0_attributes_reg <= session0_attributes_i;
                cmd_session1_attributes_reg <= session1_attributes_i;
                cmd_session2_attributes_reg <= session2_attributes_i;
                cmd_session0_hmac_size_reg <= session0_hmac_size_i;
                cmd_session1_hmac_size_reg <= session1_hmac_size_i;
                cmd_session2_hmac_size_reg <= session2_hmac_size_i;
                cmd_session0_valid_reg <= session0_valid_i;
                cmd_session1_valid_reg <= session1_valid_i;
                cmd_session2_valid_reg <= session2_valid_i;
                cmd_authorization_size_reg <= authorization_size_i;
                cmd_session_loaded_reg <= session_loaded_i;
                cmd_max_session_amount_reg <= max_session_amount_i;
                cmd_auth_session_reg <= auth_session_i;
                cmd_auth_necessary_reg <= auth_necessary_i;
                cmd_auth_handle_reg <= auth_handle_i;
                cmd_pcr_select_reg <= pcr_select_i;
                cmd_keygen_descriptor_valid_reg <= keygen_descriptor_valid_i;
                cmd_keygen_session_validated_reg <= keygen_session_validated_i;
                cmd_keygen_id_reg <= keygen_id_i;
                cmd_keygen_alg_reg <= keygen_alg_i;
                cmd_keygen_bits_reg <= keygen_bits_i;
                cmd_keygen_mode_reg <= keygen_mode_i;
                cmd_keygen_context_reg <= keygen_context_i;
                cmd_keygen_destination_reg <= keygen_destination_i;
                cmd_keygen_exponent_reg <= keygen_exponent_i;
            end
            if (current_state_reg_o == STATE_EXECUTE && !is_creation) begin
                execution_started_reg <= 1'b1;
                if (command_done_i && execution_response_code_i == 0 && execution_startup_done_i)
                    startup_success_reg <= 1'b1;
            end
            if (current_state_reg_o == STATE_EXECUTE && is_creation && kg_terminal_valid)
                keygen_object_reg_o <= kg_terminal_object;
        end
    end

	reg [3:0]  state;
	reg 		  session_present;
	reg 		  response_valid_o;
	reg [31:0] s_response_code;
	reg [15:0] response_length_o;
	reg [3:0]  current_state_reg_o;
	reg [2:0]  handle_index_reg;
	reg [2:0]  handle_count_reg;
	wire [31:0] current_handle;
	wire [7:0]  handle_type;
	wire [23:0] handle_index_bits;
	reg 		  handle_error_reg;
	reg [15:0] command_code_tag;
	reg [1:0]  session_index_reg;     // Index of the session currently being processed 
	reg        session_error_reg;     // Flag to detect session validation failure
	wire [7:0]  session_handle_type;
	wire [31:0] current_session_handle;
	wire [7:0]  current_session_attributes;
	wire [15:0] current_session_hmac_size;
	wire        current_session_valid;
	reg [31:0] auth_hierarchy_o;
	reg		  audit_reg;
	reg		  decrypt_reg;
	reg		  encrypt_reg;
	reg		  audit_reset_reg;
	reg		  audit_exclusive_reg;
	reg		  continue_session_reg;
	reg [1:0]  audit_count_reg;
	reg [1:0]  decrypt_count_reg;
	reg [1:0]  encrypt_count_reg;
	
	reg [31:0] response_code_reg_o;
	reg [2:0]  s_handle_index;
	reg [2:0]  s_handle_count;
	reg [31:0] s_current_handle;
	reg [7:0]  s_handle_type;
	reg [23:0] s_handle_index_bits;
	reg 		  s_handle_error;
	reg [1:0]  s_session_index;     // Index of the session currently being processed (0–2)
	reg        s_session_error;     // Flag to detect session validation failure
	reg [7:0]  s_session_handle_type;
	reg [31:0] s_current_session_handle;
	reg [7:0]  s_current_session_attributes;
	reg [15:0] s_current_session_hmac_size;
	reg        s_current_session_valid;
	reg		  s_audit;
	reg		  s_decrypt;
	reg		  s_encrypt;
	reg		  s_audit_reset;
	reg		  s_audit_exclusive;
	reg		  s_continue_session;
	reg [1:0]  s_audit_count;
	reg [1:0]  s_decrypt_count;
	reg [1:0]  s_encrypt_count;
	reg auth_check_error_reg;
	
	reg s_execution_startup_done;
	reg header_valid_error_reg, s_header_valid_error;
	reg mode_check_error_reg, s_mode_check_error;
	reg s_auth_check_error;
	reg param_decrypt_error_reg, s_param_decrypt_error;
	reg param_unmarshall_error_reg, s_param_unmarshall_error;
	reg s_initialized;
	
	wire [15:0] command_index;
	wire nv;
	wire extensive;
	wire flushed;
	wire [2:0] c_handles;
	wire r_handle;
	wire v;

	wire x509sign;
	wire sign;
	wire object_encrypt;
	wire object_decrypt;
	wire restricted;
	wire encrypted_duplication;
	wire no_da;
	wire admin_with_policy;
	wire user_with_auth;
	wire sensitive_data_origin;
	wire fixed_parent;
	wire st_clear;
	wire fixed_tpm;
	
	wire [7:0] nv_tag;
	wire [23:0] nv_index;
	
	wire nv_write;
	wire nv_read;
	
	wire tpma_nv_read_st_clear;
	wire tpma_nv_platform_create;
	wire tpma_nv_written;
	wire tpma_nv_read_locked;
	wire tpma_nv_clear_st_clear;
	wire tpma_nv_orderly;
	wire tpma_nv_no_da;
	wire tpma_nv_policy_read;
	wire tpma_nv_auth_read;
	wire tpma_nv_owner_read;
	wire tpma_nv_pp_read;
	wire tpma_nv_global_lock;
	wire tpma_nv_write_st_clear;
	wire tpma_nv_write_define;
	wire tpma_nv_write_all;
	wire tpma_nv_write_locked;
	wire tpma_nv_policy_delete;
	wire [3:0] tpm_nt;
	wire tpma_nv_policy_write;
	wire tpma_nv_auth_write;
	wire tpma_nv_owner_write;
	wire tpma_nv_pp_write;
	
	wire command_valid;

	assign current_handle =
		(handle_index_reg == 3'b000) ? cmd_handle_0_reg :
                (handle_index_reg == 3'b001) ? cmd_handle_1_reg :
                                           cmd_handle_2_reg;

	assign handle_type       = current_handle[31:24];
	assign handle_index_bits = current_handle[23:0];
	assign current_session_handle =
    (session_index_reg == 2'd0) ? cmd_session0_handle_reg :
    (session_index_reg == 2'd1) ? cmd_session1_handle_reg :
                              cmd_session2_handle_reg;

	assign current_session_attributes =
    (session_index_reg == 2'd0) ? cmd_session0_attributes_reg :
    (session_index_reg == 2'd1) ? cmd_session1_attributes_reg :
                              cmd_session2_attributes_reg;

	assign current_session_hmac_size =
    (session_index_reg == 2'd0) ? cmd_session0_hmac_size_reg :
    (session_index_reg == 2'd1) ? cmd_session1_hmac_size_reg :
                              cmd_session2_hmac_size_reg;

	assign current_session_valid =
		(session_index_reg == 2'd0) ? cmd_session0_valid_reg :
		(session_index_reg == 2'd1) ? cmd_session1_valid_reg :
											cmd_session2_valid_reg;
	assign session_handle_type = current_session_handle[31:24];
	// ============================================================================
	// SEQUENTIAL LOGIC BLOCK - STATE TRANSITIONS ONLY
	// ============================================================================
		always@(posedge clock_i, negedge reset_n_i) begin
			if(!reset_n_i) begin
				current_state_reg_o <= STATE_IDLE;
				mode_check_error_reg <= 1'b0;
				header_valid_error_reg <= 1'b0;
				param_unmarshall_error_reg <= 1'b0;
				param_decrypt_error_reg <= 1'b0;
				handle_count_reg <= 2'd0;
				handle_error_reg <= 1'b0;
				handle_index_reg <= 3'd0;
				session_index_reg <= 2'd0;
				audit_reg <= 1'b0;
				decrypt_reg <= 1'b0;
				encrypt_reg <= 1'b0;
				audit_reset_reg <= 1'b0;
				audit_exclusive_reg <= 1'b0;
				continue_session_reg <= 1'b0;

				session_error_reg <= 1'b0;
				audit_count_reg <= 2'd0;
				decrypt_count_reg <= 2'd0;
				encrypt_count_reg <= 2'd0;
				auth_check_error_reg <= 1'b0;
				initialized_reg_o <= 1'b0;
				response_code_reg_o <= 32'd0;
			end
			else begin
				response_code_reg_o <= s_response_code;
				current_state_reg_o <= state;
				mode_check_error_reg <= s_mode_check_error;
				header_valid_error_reg <= s_header_valid_error;
				param_unmarshall_error_reg <= s_param_unmarshall_error;
				param_decrypt_error_reg <= s_param_decrypt_error;
				handle_count_reg <= s_handle_count;
				handle_error_reg <= s_handle_error;

				

				handle_index_reg <= s_handle_index;
				session_index_reg <= s_session_index;
				audit_reg <= s_audit;
				decrypt_reg <= s_decrypt;
				encrypt_reg <= s_encrypt;
				audit_reset_reg <= s_audit_reset;
				audit_exclusive_reg <= s_audit_exclusive;
				continue_session_reg <= s_continue_session;


				
				session_error_reg <= s_session_error;
				audit_count_reg <= s_audit_count;
				decrypt_count_reg <= s_decrypt_count;
				encrypt_count_reg <= s_encrypt_count;
				auth_check_error_reg <= s_auth_check_error;
				initialized_reg_o <= s_initialized;

			end
		end
		
		assign orderly_input_o = mem_orderly_i;
		assign tests_run_o = st_tests_run_i;
		assign tests_passed_o = st_tests_passed_i;
		assign untested_o	 = st_untested_i;
		assign nv_ph_en_nv_o = nv_ph_en_nv_in_i;
		assign nv_sh_en_o = nv_sh_en_in_i;
		assign nv_eh_en_o = nv_eh_en_in_i;
		
		assign nv_tag = tpm_nv_index_i[31:24];
		assign nv_index = tpm_nv_index_i[23:0];

		// Object Attributes
		// object_attributes bits[31:20] reserved
		assign x509sign = object_attributes_i[19];
		assign sign = object_attributes_i[18];
		assign object_encrypt = object_attributes_i[18];
		assign object_decrypt = object_attributes_i[17];
		assign restricted = object_attributes_i[16];
		// object_attributes bits[15:12] reserved
		assign encrypted_duplication = object_attributes_i[11];
		assign no_da = object_attributes_i[10];
		// object_attributes bits[9:8] reserved
		assign admin_with_policy = object_attributes_i[7];
		assign user_with_auth = object_attributes_i[6];
		assign sensitive_data_origin = object_attributes_i[5];
		assign fixed_parent = object_attributes_i[4];
		assign st_clear = object_attributes_i[2];
		assign fixed_tpm = object_attributes_i[1];
		// object_attributes bit[0] reserved
		
		// Non-Volatile Index Attributes
		// Reference: TCG TPM2.0 Specification Rev. 1.59, Part 2: Structures, Section 13.4 TPMA_NV (NV Index Attributes)
		assign tpma_nv_read_st_clear = nv_index_attributes_i[31];
		assign tpma_nv_platform_create = nv_index_attributes_i[30];
		assign tpma_nv_written = nv_index_attributes_i[29];
		assign tpma_nv_read_locked = nv_index_attributes_i[28];
		assign tpma_nv_clear_st_clear = nv_index_attributes_i[27];
		assign tpma_nv_orderly = nv_index_attributes_i[26];
		assign tpma_nv_no_da = nv_index_attributes_i[25];
		// nv_index_attributes bits[24:20] reserved for future use
		assign tpma_nv_policy_read = nv_index_attributes_i[19];
		assign tpma_nv_auth_read = nv_index_attributes_i[18];
		assign tpma_nv_owner_read = nv_index_attributes_i[17];
		assign tpma_nv_pp_read = nv_index_attributes_i[16];
		assign tpma_nv_global_lock = nv_index_attributes_i[15];
		assign tpma_nv_write_st_clear = nv_index_attributes_i[14];
		assign tpma_nv_write_define = nv_index_attributes_i[13];
		assign tpma_nv_write_all = nv_index_attributes_i[12];
		assign tpma_nv_write_locked = nv_index_attributes_i[11];
		assign tpma_nv_policy_delete = nv_index_attributes_i[10];
		// nv_index_attributes bits[9:8] reserved for future use
		assign tpm_nt = nv_index_attributes_i[7:4];
		assign tpma_nv_policy_write = nv_index_attributes_i[3];
		assign tpma_nv_auth_write = nv_index_attributes_i[2];
		assign tpma_nv_owner_write = nv_index_attributes_i[1];
		assign tpma_nv_pp_write = nv_index_attributes_i[0];
	assign nv_write = (command_index == TPM_CC_NV_DEFINE_SPACE ||
								 command_index == TPM_CC_NV_WRITE ||
								 command_index == TPM_CC_NV_INCREMENT ||
								 command_index == TPM_CC_NV_EXTEND);
								 
		// Signal indicating that command
	assign nv_read = (command_index == TPM_CC_NV_DEFINE_SPACE || command_index == TPM_CC_NV_READ);
					
		// Reference: TCG TPM2.0 Specification Rev. 1.59, Part 2: Structures, Section 8.9.2 TPMA_CC (Command Code Attributes): Structure Definition
		assign command_index = cmd_command_code_reg[15:0];			// Indicates the command being selected
		
		assign nv = cmd_command_code_reg[22];							// SET(1): indicates that the command may write to NV
																		// CLEAR(0): indicates that the command does not write to NV
																		
		assign extensive = cmd_command_code_reg[23];				// SET(1): This command could flush any number of loaded contexts
																		// CLEAR(0): no additional changes other than indicated by the flushed attribute
																		
		assign flushed = cmd_command_code_reg[24];					// SET(1): The context associated with any transient handle in the command will be flushed when this command completes.
																		// CLEAR(0): No context is flushed as a side effect of this command.
																		
		assign c_handles = cmd_command_code_reg[27:25];				// indicates the number of the handles in the handle area for this command
		
		assign r_handle = cmd_command_code_reg[28];					// SET(1): indicates the presence of the handle area in the response
		
		assign v = cmd_command_code_reg[29];							// SET(1): indicates that the command is vendor-specific
																		// CLEAR(0): indicates that the command is defined in a version of this specification
		assign command_valid = (command_index == TPM_CC_NV_UNDEFINE_SPACE_SPECIAL ||
					command_index == TPM_CC_EVICT_CONTROL ||
					command_index == TPM_CC_HIERARCHY_CONTROL ||
					command_index == TPM_CC_NV_UNDEFINE_SPACE ||
					command_index == TPM_CC_CHANGE_EPS ||
					command_index == TPM_CC_CHANGE_PPS ||
					command_index == TPM_CC_CLEAR ||
					command_index == TPM_CC_CLEAR_CONTROL ||
					command_index == TPM_CC_CLOCK_SET ||
					command_index == TPM_CC_HIERARCHY_CHANGE_AUTH ||
					command_index == TPM_CC_NV_DEFINE_SPACE ||
					command_index == TPM_CC_PCR_ALLOCATE ||
					command_index == TPM_CC_PCR_SET_AUTH_POLICY ||
					command_index == TPM_CC_PP_COMMANDS ||
					command_index == TPM_CC_SET_PRIMARY_POLICY ||
					command_index == TPM_CC_CLOCK_RATE_ADJUST ||
					command_index == TPM_CC_CREATE_PRIMARY ||
					command_index == TPM_CC_NV_GLOBAL_WRITE_LOCK ||
					command_index == TPM_CC_GET_COMMAND_AUDIT_DIGEST ||
					command_index == TPM_CC_NV_INCREMENT ||
					command_index == TPM_CC_NV_SET_BITS ||
					command_index == TPM_CC_NV_EXTEND ||
					command_index == TPM_CC_NV_WRITE ||
					command_index == TPM_CC_NV_WRITE_LOCK ||
					command_index == TPM_CC_DICTIONARY_ATTACK_LOCK_RESET ||
					command_index == TPM_CC_DICTIONARY_ATTACK_PARAMETERS ||
					command_index == TPM_CC_NV_CHANGE_AUTH ||
					command_index == TPM_CC_PCR_EVENT ||
					command_index == TPM_CC_PCR_RESET ||
					command_index == TPM_CC_SEQUENCE_COMPLETE ||
					command_index == TPM_CC_SET_ALGORITHM_SET ||
					command_index == TPM_CC_SET_COMMAND_CODE_AUDIT_STATUS ||
					command_index == TPM_CC_INCREMENTAL_SELF_TEST ||
					command_index == TPM_CC_SELF_TEST ||
					command_index == TPM_CC_STARTUP ||
					command_index == TPM_CC_SHUTDOWN ||
					command_index == TPM_CC_STIR_RANDOM ||
					command_index == TPM_CC_ACTIVATE_CREDENTIAL ||
					command_index == TPM_CC_CERTIFY ||
					command_index == TPM_CC_POLICY_NV ||
					command_index == TPM_CC_CERTIFY_CREATION ||
					command_index == TPM_CC_DUPLICATE ||
					command_index == TPM_CC_GET_TIME ||
					command_index == TPM_CC_GET_SESSION_AUDIT_DIGEST ||
					command_index == TPM_CC_NV_READ ||
					command_index == TPM_CC_NV_READ_LOCK ||
					command_index == TPM_CC_OBJECT_CHANGE_AUTH ||
					command_index == TPM_CC_POLICY_SECRET ||
					command_index == TPM_CC_REWRAP ||
					command_index == TPM_CC_CREATE ||
					command_index == TPM_CC_ECDH_ZGEN ||
					command_index == TPM_CC_HMAC ||
					command_index == TPM_CC_IMPORT ||
					command_index == TPM_CC_LOAD ||
					command_index == TPM_CC_QUOTE ||
					command_index == TPM_CC_RSA_DECRYPT ||
					command_index == TPM_CC_HMAC_START ||
					command_index == TPM_CC_SEQUENCE_UPDATE ||
					command_index == TPM_CC_SIGN ||
					command_index == TPM_CC_UNSEAL ||
					command_index == TPM_CC_POLICY_SIGNED ||
					command_index == TPM_CC_CONTEXT_LOAD ||
					command_index == TPM_CC_CONTEXT_SAVE ||
					command_index == TPM_CC_ECDH_KEY_GEN ||
					command_index == TPM_CC_ENCRYPT_DECRYPT ||
					command_index == TPM_CC_FLUSH_CONTEXT ||
					command_index == TPM_CC_LOAD_EXTERNAL ||
					command_index == TPM_CC_MAKE_CREDENTIAL ||
					command_index == TPM_CC_NV_READ_PUBLIC ||
					command_index == TPM_CC_POLICY_AUTHORIZE ||
					command_index == TPM_CC_POLICY_AUTH_VALUE ||
					command_index == TPM_CC_POLICY_COMMAND_CODE ||
					command_index == TPM_CC_POLICY_COUNTER_TIMER ||
					command_index == TPM_CC_POLICY_CP_HASH ||
					command_index == TPM_CC_POLICY_LOCALITY ||
					command_index == TPM_CC_POLICY_NAME_HASH ||
					command_index == TPM_CC_POLICY_OR ||
					command_index == TPM_CC_POLICY_TICKET ||
					command_index == TPM_CC_READ_PUBLIC ||
					command_index == TPM_CC_RSA_ENCRYPT ||
					command_index == TPM_CC_START_AUTH_SESSION ||
					command_index == TPM_CC_VERIFY_SIGNATURE ||
					command_index == TPM_CC_ECC_PARAMETERS ||
					command_index == TPM_CC_FIRMWARE_READ ||
					command_index == TPM_CC_GET_CAPABILITY ||
					command_index == TPM_CC_GET_RANDOM ||
					command_index == TPM_CC_GET_TEST_RESULT ||
					command_index == TPM_CC_HASH ||
					command_index == TPM_CC_PCR_READ ||
					command_index == TPM_CC_POLICY_PCR ||
					command_index == TPM_CC_POLICY_RESTART ||
					command_index == TPM_CC_READ_CLOCK ||
					command_index == TPM_CC_PCR_EXTEND ||
					command_index == TPM_CC_PCR_SET_AUTH_VALUE ||
					command_index == TPM_CC_NV_CERTIFY ||
					command_index == TPM_CC_EVENT_SEQUENCE_COMPLETE ||
					command_index == TPM_CC_HASH_SEQUENCE_START ||
					command_index == TPM_CC_POLICY_PHYSICAL_PRESENCE ||
					command_index == TPM_CC_POLICY_DUPLICATION_SELECT ||
					command_index == TPM_CC_POLICY_GET_DIGEST ||
					command_index == TPM_CC_TEST_PARMS ||
					command_index == TPM_CC_COMMIT ||
					command_index == TPM_CC_POLICY_PASSWORD ||
					command_index == TPM_CC_ZGEN_2_PHASE ||
					command_index == TPM_CC_EC_EPHEMERAL ||
					command_index == TPM_CC_POLICY_NV_WRITTEN ||
					command_index == TPM_CC_POLICY_TEMPLATE ||
					command_index == TPM_CC_CREATE_LOADED ||
					command_index == TPM_CC_POLICY_AUTHORIZE_NV ||
					command_index == TPM_CC_ENCRYPT_DECRYPT_2 ||
					command_index == TPM_CC_AC_GET_CAPABILITY ||
					command_index == TPM_CC_AC_SEND ||
					command_index == TPM_CC_POLICY_AC_SEND_SELECT);
					
		always@(*) begin
			if(command_index == TPM_CC_CLEAR ||
				command_index == TPM_CC_HIERARCHY_CONTROL ||
				command_index == TPM_CC_CLEAR_CONTROL ||
				command_index == TPM_CC_CLOCK_SET ||
				command_index == TPM_CC_CLOCK_RATE_ADJUST ||
				command_index == TPM_CC_HIERARCHY_CHANGE_AUTH ||
				command_index == TPM_CC_NV_DEFINE_SPACE ||
				command_index == TPM_CC_PCR_ALLOCATE ||
				command_index == TPM_CC_PCR_SET_AUTH_POLICY ||
				command_index == TPM_CC_PP_COMMANDS ||
				command_index == TPM_CC_SET_PRIMARY_POLICY ||
				command_index == TPM_CC_SET_ALGORITHM_SET ||
				command_index == TPM_CC_SET_COMMAND_CODE_AUDIT_STATUS ||
				command_index == TPM_CC_CREATE_PRIMARY ||
				command_index == TPM_CC_NV_GLOBAL_WRITE_LOCK ||
				command_index == TPM_CC_NV_INCREMENT ||
				command_index == TPM_CC_NV_SET_BITS ||
				command_index == TPM_CC_NV_EXTEND ||
				command_index == TPM_CC_NV_WRITE_LOCK ||
				command_index == TPM_CC_DICTIONARY_ATTACK_LOCK_RESET ||
				command_index == TPM_CC_DICTIONARY_ATTACK_PARAMETERS ||
				command_index == TPM_CC_NV_CHANGE_AUTH ||
				command_index == TPM_CC_PCR_EVENT ||
				command_index == TPM_CC_PCR_RESET ||
				command_index == TPM_CC_PCR_EXTEND ||
				command_index == TPM_CC_PCR_SET_AUTH_VALUE ||
				command_index == TPM_CC_SEQUENCE_COMPLETE ||
				command_index == TPM_CC_EVENT_SEQUENCE_COMPLETE ||
				command_index == TPM_CC_FLUSH_CONTEXT ||
				command_index == TPM_CC_CREATE ||
				command_index == TPM_CC_LOAD ||
				command_index == TPM_CC_UNSEAL ||
				command_index == TPM_CC_SIGN ||
				command_index == TPM_CC_READ_PUBLIC ||
				command_index == TPM_CC_ECDH_KEY_GEN ||
				command_index == TPM_CC_RSA_DECRYPT ||
				command_index == TPM_CC_ECDH_ZGEN ||
				command_index == TPM_CC_CONTEXT_SAVE ||
				command_index == TPM_CC_CONTEXT_LOAD ||
				command_index == TPM_CC_NV_READ ||
				command_index == TPM_CC_NV_READ_LOCK ||
				command_index == TPM_CC_OBJECT_CHANGE_AUTH ||
				command_index == TPM_CC_POLICY_SECRET ||
				command_index == TPM_CC_REWRAP ||
				command_index == TPM_CC_RSA_ENCRYPT ||
				command_index == TPM_CC_VERIFY_SIGNATURE ||
				command_index == TPM_CC_COMMIT ||
				command_index == TPM_CC_EC_EPHEMERAL ||
				command_index == TPM_CC_CREATE_LOADED ||
				command_index == TPM_CC_AC_SEND) begin
				s_handle_count = 3'b001;
			end
			else if(command_index == TPM_CC_NV_UNDEFINE_SPACE ||
					  command_index == TPM_CC_NV_UNDEFINE_SPACE_SPECIAL ||
					  command_index == TPM_CC_EVICT_CONTROL ||
					  command_index == TPM_CC_CHANGE_EPS ||
					  command_index == TPM_CC_CHANGE_PPS ||
					  command_index == TPM_CC_NV_WRITE ||
					  command_index == TPM_CC_START_AUTH_SESSION ||
					  command_index == TPM_CC_ACTIVATE_CREDENTIAL ||
					  command_index == TPM_CC_CERTIFY ||
					  command_index == TPM_CC_POLICY_NV ||
					  command_index == TPM_CC_CERTIFY_CREATION ||
					  command_index == TPM_CC_DUPLICATE ||
					  command_index == TPM_CC_QUOTE ||
					  command_index == TPM_CC_HMAC ||
					  command_index == TPM_CC_IMPORT ||
					  command_index == TPM_CC_POLICY_SIGNED ||
					  command_index == TPM_CC_ENCRYPT_DECRYPT ||
					  command_index == TPM_CC_MAKE_CREDENTIAL ||
					  command_index == TPM_CC_POLICY_AUTHORIZE ||
					  command_index == TPM_CC_POLICY_AUTH_VALUE ||
					  command_index == TPM_CC_POLICY_COMMAND_CODE ||
					  command_index == TPM_CC_POLICY_COUNTER_TIMER ||
					  command_index == TPM_CC_POLICY_CP_HASH ||
					  command_index == TPM_CC_POLICY_LOCALITY ||
					  command_index == TPM_CC_POLICY_NAME_HASH ||
					  command_index == TPM_CC_POLICY_OR ||
					  command_index == TPM_CC_POLICY_TICKET ||
					  command_index == TPM_CC_POLICY_PCR ||
					  command_index == TPM_CC_POLICY_RESTART ||
					  command_index == TPM_CC_POLICY_PHYSICAL_PRESENCE ||
					  command_index == TPM_CC_POLICY_DUPLICATION_SELECT ||
					  command_index == TPM_CC_POLICY_GET_DIGEST ||
					  command_index == TPM_CC_POLICY_PASSWORD ||
					  command_index == TPM_CC_ZGEN_2_PHASE ||
					  command_index == TPM_CC_POLICY_NV_WRITTEN ||
					  command_index == TPM_CC_POLICY_TEMPLATE ||
					  command_index == TPM_CC_POLICY_AUTHORIZE_NV ||
					  command_index == TPM_CC_ENCRYPT_DECRYPT_2 ||
					  command_index == TPM_CC_POLICY_AC_SEND_SELECT ||
					  command_index == TPM_CC_NV_CERTIFY) begin
				s_handle_count = 3'b010;
			end
			else begin
				s_handle_count = 3'b000;
			end
		end
					

		// Session tag necessary for each command type:
		always@(*) begin
			if(command_index == TPM_CC_STARTUP ||
				command_index == TPM_CC_CONTEXT_SAVE ||
				command_index == TPM_CC_CONTEXT_LOAD ||
				command_index == TPM_CC_FLUSH_CONTEXT) begin
				command_code_tag = TPM_ST_NO_SESSIONS;
			end
			else begin
				command_code_tag = TPM_ST_SESSIONS;
				if(!audit_reg) begin
					if(command_index == TPM_CC_SHUTDOWN ||
						command_index == TPM_CC_SELF_TEST ||
						command_index == TPM_CC_INCREMENTAL_SELF_TEST ||
						command_index == TPM_CC_GET_TEST_RESULT ||
						command_index == TPM_CC_POLICY_RESTART ||
						command_index == TPM_CC_ECC_PARAMETERS ||
						command_index == TPM_CC_PCR_READ ||
						command_index == TPM_CC_POLICY_OR ||
						command_index == TPM_CC_POLICY_LOCALITY ||
						command_index == TPM_CC_POLICY_COMMAND_CODE ||
						command_index == TPM_CC_POLICY_PHYSICAL_PRESENCE ||
						command_index == TPM_CC_POLICY_AUTH_VALUE ||
						command_index == TPM_CC_POLICY_PASSWORD ||
						command_index == TPM_CC_POLICY_NV_WRITTEN ||
						command_index == TPM_CC_READ_CLOCK ||
						command_index == TPM_CC_GET_CAPABILITY ||
						command_index == TPM_CC_TEST_PARMS ||
						command_index == TPM_CC_AC_GET_CAPABILITY) begin
						command_code_tag = TPM_ST_NO_SESSIONS;
					end
					else if((command_index == TPM_CC_START_AUTH_SESSION ||
								command_index == TPM_CC_LOAD_EXTERNAL ||
								command_index == TPM_CC_MAKE_CREDENTIAL ||
								command_index == TPM_CC_RSA_ENCRYPT ||
								command_index == TPM_CC_HASH ||
								command_index == TPM_CC_POLICY_SIGNED) && !encrypt_reg && !decrypt_reg) begin
						command_code_tag = TPM_ST_NO_SESSIONS;
					end
					else if((command_index == TPM_CC_STIR_RANDOM ||
								command_index == TPM_CC_HASH_SEQUENCE_START ||
								command_index == TPM_CC_POLICY_TICKET ||
								command_index == TPM_CC_POLICY_PCR ||
								command_index == TPM_CC_POLICY_COUNTER_TIMER ||
								command_index == TPM_CC_POLICY_CP_HASH ||
								command_index == TPM_CC_POLICY_NAME_HASH ||
								command_index == TPM_CC_POLICY_DUPLICATION_SELECT ||
								command_index == TPM_CC_POLICY_AUTHORIZE ||
								command_index == TPM_CC_POLICY_TEMPLATE) && !decrypt_reg) begin
						command_code_tag = TPM_ST_NO_SESSIONS;
					end
					else if((command_index == TPM_CC_READ_PUBLIC ||
								command_index == TPM_CC_ECDH_KEY_GEN ||
								command_index == TPM_CC_GET_RANDOM ||
								command_index == TPM_CC_EC_EPHEMERAL ||
								command_index == TPM_CC_VERIFY_SIGNATURE ||
								command_index == TPM_CC_POLICY_GET_DIGEST ||
								command_index == TPM_CC_NV_READ_PUBLIC) && !encrypt_reg) begin
						command_code_tag = TPM_ST_NO_SESSIONS;
					end
				end
			end
		end
		
		always@(*) begin
			s_audit = audit_reg;
			s_decrypt = decrypt_reg;
			s_encrypt = encrypt_reg;
			s_audit_reset = audit_reset_reg;
			s_audit_exclusive = audit_exclusive_reg;
			s_continue_session = continue_session_reg;
			s_session_handle_type = session_handle_type;
			s_current_session_handle = current_session_handle;
			s_current_session_attributes = current_session_attributes;
			s_current_session_hmac_size = current_session_hmac_size;
			s_current_session_valid = current_session_valid;
			if(cmd_command_tag_reg == TPM_ST_SESSIONS) begin
			// Map flattened inputs into a common structure for session processing.
				if (session_index_reg == 2'd0) begin
					s_current_session_handle     = cmd_session0_handle_reg;
					s_current_session_attributes = cmd_session0_attributes_reg;
					s_current_session_hmac_size  = cmd_session0_hmac_size_reg;
					s_current_session_valid      = cmd_session0_valid_reg;
				end
				else if (session_index_reg == 2'd1) begin
					s_current_session_handle     = cmd_session1_handle_reg;
					s_current_session_attributes = cmd_session1_attributes_reg;
					s_current_session_hmac_size  = cmd_session1_hmac_size_reg;
					s_current_session_valid      = cmd_session1_valid_reg;
				end
				else begin
					s_current_session_handle     = cmd_session2_handle_reg;
					s_current_session_attributes = cmd_session2_attributes_reg;
					s_current_session_hmac_size  = cmd_session2_hmac_size_reg;
					s_current_session_valid      = cmd_session2_valid_reg;
				end

				// ----------------------------------------------------------------
				// If the session is valid and within the allowed limit, process it.
				// ----------------------------------------------------------------
				if (session_index_reg < 2'd3 && current_session_valid) begin

					
					s_audit = current_session_attributes[7];
					s_encrypt = current_session_attributes[6];
					s_decrypt = current_session_attributes[5];
					s_audit_reset = current_session_attributes[2];
					s_audit_exclusive = current_session_attributes[1];
					s_continue_session = current_session_attributes[0];
					
					s_session_handle_type = current_session_handle[31:24];

				end
			end
		end
		always@(*) begin
			s_session_error = session_error_reg;
			s_audit_count = audit_count_reg;
			s_decrypt_count = decrypt_count_reg;
			s_encrypt_count = encrypt_count_reg;
			state = current_state_reg_o;
			s_session_index = 3'b000;
			case(current_state_reg_o)
				// ====================================================================
				// STAGE 1: IDLE - Wait for command
				// ====================================================================
				STATE_IDLE: begin
					s_session_error = 1'b0;
					s_audit_count = 2'b0;
					s_decrypt_count = 2'b0;
					s_encrypt_count = 2'b0;
					if(command_ready_i && command_armed_reg) begin
						state = STATE_HEADER_VALID;
					end
				end

				// ====================================================================
				// STAGE 2: HEADER VALIDATION - TPM 2.0 Part 3, Section 5.2
				// ====================================================================
				STATE_HEADER_VALID: begin
					if((cmd_command_tag_reg != TPM_ST_NO_SESSIONS && cmd_command_tag_reg != TPM_ST_SESSIONS) ||
						 cmd_command_size_reg != cmd_command_length_reg ||
						 (!command_valid || cmd_command_code_reg[31:16] !== 16'd0)) begin
						state = STATE_POST_PROCESS;
					end
					else begin
						state = STATE_MODE_CHECK;
					end
				end
				
				// ====================================================================
				// STAGE 3: MODE CHECKS - TPM 2.0 Part 3, Section 5.3
				// ====================================================================
				STATE_MODE_CHECK: begin
					// IMPLEMENTED: Basic mode checks
					if(op_state_i == FAILURE_MODE_STATE) begin
						// In Failure mode, only TPM2_GetTestResult or TPM2_GetCapability allowed with no sessions
						if((command_index != TPM_CC_GET_TEST_RESULT && command_index != TPM_CC_GET_CAPABILITY) || cmd_command_tag_reg != TPM_ST_NO_SESSIONS) begin
							state = STATE_POST_PROCESS;
						end
						else begin
							state = STATE_HANDLE_VALID;
						end
					end
					else if(op_state_i == OPERATIONAL_STATE)begin
							state = STATE_HANDLE_VALID;
					end
					else begin
						// TPM not initialized - first command must be TPM2_Startup
						if(command_index != TPM_CC_STARTUP) begin
							state = STATE_POST_PROCESS;
						end
						else begin
							state = STATE_HANDLE_VALID;
						end
					end
				end
				
				// ====================================================================
				// STAGE 4: HANDLE VALIDATION - TPM 2.0 Part 3, Section 5.4
				// ====================================================================
				STATE_HANDLE_VALID: begin
                    if (is_creation) begin
                        // No production template/session validator is implemented here.
                        if (cmd_command_code_reg === 32'h153 && cmd_keygen_descriptor_valid_reg === 1'b1 && cmd_keygen_session_validated_reg === 1'b1)
                            state = STATE_AUTH_CHECK;
                        else state = STATE_POST_PROCESS;
                    end else if (s_handle_error || handle_error_reg) state = STATE_POST_PROCESS;
                    else if (handle_index_reg >= handle_count_reg) state = STATE_SESSION_VALID;
				end

				// ====================================================================
				STATE_SESSION_VALID: begin
                    // Legacy session parser is not trusted: fail closed until separately repaired.
                    if (cmd_command_tag_reg == TPM_ST_NO_SESSIONS && command_code_tag == TPM_ST_NO_SESSIONS)
                        state = STATE_AUTH_CHECK;
                    else state = STATE_POST_PROCESS;
				end

				// ====================================================================
				STATE_AUTH_CHECK: begin
                    if (cmd_auth_necessary_reg === 1'b0 && !is_creation) state = STATE_PARAM_DECRYPT;
                    else if (auth_done_i) begin
                        if (!(auth_success_i === 1'b1 && auth_response_code_i === 12'd0)) state = STATE_POST_PROCESS;
                        else state = STATE_PARAM_DECRYPT;
                    end
				end

				// ====================================================================
				STATE_PARAM_DECRYPT: begin
                    if (param_decrypt_fail_i) state = STATE_POST_PROCESS;
                    else if (param_decrypt_success_i === 1'b1 && param_decrypt_fail_i === 1'b0) state = STATE_PARAM_UNMARSH;
				end

				// ====================================================================
				STATE_PARAM_UNMARSH: begin
                    if (param_unmarshall_fail_i) state = STATE_POST_PROCESS;
                    else if (param_unmarshall_success_i === 1'b1 && param_unmarshall_fail_i === 1'b0) state = STATE_EXECUTE;
				end

				// ====================================================================
				STATE_EXECUTE: begin
                    if (is_creation) begin
                        if (kg_terminal_valid) state = STATE_POST_PROCESS;
                    end else if (command_done_i) state = STATE_POST_PROCESS;
				end

				// ====================================================================
                STATE_POST_PROCESS: begin
                    if (response_ready_i) state = STATE_IDLE;
                end
				default: begin
						state = STATE_IDLE;
				end
		endcase
        if (command_cancel_i && current_state_reg_o != STATE_IDLE && current_state_reg_o != STATE_POST_PROCESS &&
            !(current_state_reg_o == STATE_EXECUTE && is_creation)) state = STATE_POST_PROCESS;
	end
	// ============================================================================
	// COMBINATIONAL LOGIC BLOCK - ALL OUTPUTS AND NEXT STATE
	// ============================================================================
	always@(*) begin
		// carry error values from previous state
		s_mode_check_error = mode_check_error_reg;
		s_header_valid_error = header_valid_error_reg;
		s_handle_error = handle_error_reg;
		s_auth_check_error = auth_check_error_reg;
		s_param_unmarshall_error = param_unmarshall_error_reg;
		s_param_decrypt_error = param_decrypt_error_reg;
		s_execution_startup_done = execution_startup_done_i;
		s_initialized = initialized_reg_o;
		s_handle_index = handle_index_reg;
		
		// Default output values
		response_valid_o =   1'b0;
		s_response_code = response_code_reg_o;
		response_length_o = 16'h0;
		command_start_o   = 1'b0;
		session_present = 1'b0;
		auth_hierarchy_o = 32'h00000000;

		if(current_state_reg_o == STATE_HANDLE_VALID && !is_creation) begin			// Check that the TPM shall successfully unmarshal the number of handles required by the command and validate that the value of the handle is consistent with the command syntax
			s_current_handle = current_handle;
			s_handle_type = handle_type;
			s_handle_index_bits = handle_index_bits;
			s_handle_index = handle_index_reg;
			if(c_handles > handle_count_reg) begin
	                		s_handle_error = 1'b1;
		        		s_response_code = TPM_RC_VALUE;
		        	end
		    		// If the handle references a transient object, check that the handle references a loaded object
		        	else if(handle_type == TPM_HT_TRANSIENT) begin
		                	if(!loaded_object_present_i) begin
					        s_handle_error = 1'b1;
						s_response_code = TPM_RC_REFERENCE_H0 + handle_index_reg;
					end else begin
						// Extract current handle
						s_handle_index = handle_index_reg + 1'b1;
					end
				end
				else if(handle_type == TPM_HT_PERSISTENT) begin
					if((entity_hierarchy_i == TPM_RH_PLATFORM && !ph_en_i) || 
			                   (entity_hierarchy_i == TPM_RH_OWNER && !sh_en_i) || 
				           (entity_hierarchy_i == TPM_RH_ENDORSEMENT && !eh_en_i) ||
			                   !nv_object_present_i) begin
						s_handle_error = 1'b1;
						s_response_code = TPM_RC_HANDLE; 
					end
					else if(!ram_available_i) begin
						s_handle_error = 1'b1;
						s_response_code = TPM_RC_OBJECT_MEMORY;
					end else begin
						s_handle_index = handle_index_reg + 1'b1;
					end
				end
			else if(handle_type == TPM_HT_NV_INDEX) begin
				if(!nv_index_present_i ||
			           (entity_hierarchy_i == TPM_RH_PLATFORM && !ph_en_i) || 
			            (entity_hierarchy_i == TPM_RH_OWNER && !sh_en_i) || 
						(entity_hierarchy_i == TPM_RH_ENDORSEMENT && !eh_en_i)) begin
						s_handle_error = 1'b1;
						s_response_code = TPM_RC_HANDLE;
					end
					else if((nv_write && tpma_nv_write_locked) || (nv_read && tpma_nv_read_locked)) begin
						s_handle_error = 1'b1;
						s_response_code = TPM_RC_NV_LOCKED;
					end else begin
						s_handle_index = handle_index_reg + 1'b1;
					end
				end
				else if(handle_type == TPM_HT_HMAC_SESSION || 
						  handle_type == TPM_HT_LOADED_SESSION || 
						  handle_type == TPM_HT_POLICY_SESSION || 
						  handle_type == TPM_HT_SAVED_SESSION) begin
					if(!session_present) begin
						s_handle_error = 1'b1;
						s_response_code = TPM_RC_REFERENCE_H0 + handle_index_reg;
					end else begin
						// Extract current handle
						s_handle_index = handle_index_reg + 1'b1;
					end
				end
				else if(handle_type == TPM_HT_PERMANENT) begin
					if((current_handle == TPM_RH_PLATFORM && !ph_en_i) || 
						(current_handle == TPM_RH_OWNER && !sh_en_i) || 
						(current_handle == TPM_RH_ENDORSEMENT && !eh_en_i)) begin
						s_handle_error = 1'b1;
						s_response_code = TPM_RC_HIERARCHY;
					end else begin
						// Extract current handle
						s_handle_index = handle_index_reg + 1'b1;
					end
				end
				// Check if the handle references a PCR, then the value is within the range of PCR supported by the TPM
				else if(handle_type == TPM_HT_PCR && cmd_pcr_select_reg > PCR_SELECT_MAX) begin
					s_handle_error = 1'b1;
					s_response_code = TPM_RC_VALUE;
				end else begin
					s_handle_index = handle_index_reg + 1'b1;
				end
				
            end


		case(current_state_reg_o)
			// ====================================================================
			// STAGE 1: IDLE - Wait for command
			// ====================================================================
			STATE_IDLE: begin
					response_valid_o =   1'b0;
					if (command_ready_i && command_armed_reg) s_response_code = 32'b0;
					response_length_o = 16'h0;
					s_handle_error = 1'b0;
                    s_header_valid_error = 0; s_mode_check_error = 0; s_auth_check_error = 0;
                    s_param_decrypt_error = 0; s_param_unmarshall_error = 0;
					s_handle_index = 3'b000;
				if(command_ready_i) begin
					session_present = (cmd_command_tag_reg == TPM_ST_SESSIONS);
				end
			end
			
			// ====================================================================
			// STAGE 2: HEADER VALIDATION - TPM 2.0 Part 3, Section 5.2
			// ===================================================================
			STATE_HEADER_VALID: begin
				// IMPLEMENTED: Basic header validation
				if(cmd_command_tag_reg != TPM_ST_NO_SESSIONS && cmd_command_tag_reg != TPM_ST_SESSIONS) begin
					s_header_valid_error = 1'b1;
					s_response_code = TPM_RC_BAD_TAG;
				end
				else if(cmd_command_size_reg != cmd_command_length_reg) begin
					s_header_valid_error = 1'b1;
					s_response_code = TPM_RC_COMMAND_SIZE;
				end
				else if((!command_valid || cmd_command_code_reg[31:16] !== 16'd0)) begin
					s_header_valid_error = 1'b1;
					s_response_code = TPM_RC_COMMAND_CODE;
				end

			end
			
			// ====================================================================
			// STAGE 3: MODE CHECKS - TPM 2.0 Part 3, Section 5.3
			// ====================================================================
			STATE_MODE_CHECK: begin
				// IMPLEMENTED: Basic mode checks
				if(op_state_i == FAILURE_MODE_STATE) begin
					// In Failure mode, only TPM2_GetTestResult or TPM2_GetCapability allowed with no sessions
					if((command_index != TPM_CC_GET_TEST_RESULT && command_index != TPM_CC_GET_CAPABILITY) || cmd_command_tag_reg != TPM_ST_NO_SESSIONS) begin
						s_mode_check_error = 1'b1;
						s_response_code = TPM_RC_FAILURE;
					end
				end
				else if(op_state_i != OPERATIONAL_STATE) begin
					// TPM not initialized - first command must be TPM2_Startup
					if(command_index != TPM_CC_STARTUP) begin
						s_mode_check_error = 1'b1;
						s_response_code = TPM_RC_INITIALIZE;
					end
				end
			end
			
			// ====================================================================
			// STAGE 4: HANDLE VALIDATION - TPM 2.0 Part 3, Section 5.4
			// ====================================================================
            STATE_HANDLE_VALID: begin
                if (is_creation && !(cmd_command_code_reg === 32'h153 && cmd_keygen_descriptor_valid_reg === 1'b1 && cmd_keygen_session_validated_reg === 1'b1)) begin
                    s_handle_error = 1;
                    s_response_code = 32'h00000143;
                end
            end
            STATE_SESSION_VALID: begin
                if (!(cmd_command_tag_reg == TPM_ST_NO_SESSIONS && command_code_tag == TPM_ST_NO_SESSIONS))
                    s_response_code = 32'h00000124;
            end
			STATE_AUTH_CHECK: begin
				// Check to see if authorization subsystem has finished before updating authorization dependent information
				if(auth_done_i && (is_creation || cmd_auth_necessary_reg !== 1'b0)) begin
					// Response code will come from authorization subsystem
					if (auth_success_i === 1'b1 && auth_response_code_i === 12'd0) s_response_code = 0;
                    else if (auth_response_code_i != 0) s_response_code = {20'd0,auth_response_code_i};
                    else s_response_code = 32'h101;
					
					// If authorization successful tell other modules the authorization hierarchy, if it fails tell them the null hierarchy
					if(auth_success_i === 1'b1 && auth_response_code_i === 12'd0) begin
						auth_hierarchy_o = cmd_auth_handle_reg;
					end
					else begin
						auth_hierarchy_o = TPM_RH_NULL;
						s_auth_check_error = 1'b1;
					end
				end
			end
			
			// ====================================================================
			// STAGE 7: PARAMETER DECRYPTION - TPM 2.0 Part 3, Section 5.7
			// ====================================================================
			STATE_PARAM_DECRYPT: begin
				//Do not do yet implement some sort of signal
				// For now, always proceed to parameter unmarshaling
				if(param_decrypt_success_i == 1'b1 && !param_decrypt_fail_i)begin
					
				end
				else if(param_decrypt_fail_i == 1'b1)begin
					//placeholder there are many specific response codes that would be determined by the submodule
					s_response_code = TPM_RC_ATTRIBUTES;
					s_param_decrypt_error = 1'b1;
				end
			end
			
			// ====================================================================
			// STAGE 8: PARAMETER UNMARSHALING - TPM 2.0 Part 3, Section 5.8
			// ====================================================================
			STATE_PARAM_UNMARSH: begin
				// TODO: IMPLEMENT PARAMETER UNMARSHALING:
				// 1. Calculate parameter start offset (after header + handles + auth area)
				// 2. For each parameter in command schema:
				//    - Parse parameter based on type (TPM2B, TPM_ALG_ID, TPM_HANDLE, etc.)
				//    - Validate parameter value ranges and constraints
				//    - Check algorithm selections are supported
				//    - Verify reserved fields are zero
				// 3. Handle TPM2B structures with size prefixes
				// 4. Return appropriate error codes (TPM_RC_SIZE, TPM_RC_VALUE, TPM_RC_SCHEME, etc.)
				if(param_unmarshall_success_i == 1'b1 && !param_unmarshall_fail_i)begin
					
				end
				else if(param_unmarshall_fail_i == 1'b1)begin
					//placeholder there are many specific response codes that would be determined by the submodule
					s_response_code = TPM_RC_ATTRIBUTES;
					s_param_unmarshall_error = 1'b1;
				end
				// For now, always proceed to execution
			end
			
			// ====================================================================
			// STAGE 9: COMMAND EXECUTION - TPM 2.0 Part 3, Section 5.9
			// ====================================================================
            STATE_EXECUTE: begin
                if (is_creation) begin
                    if (kg_terminal_valid) s_response_code = kg_terminal_code;
                end else begin
                    command_start_o = !execution_started_reg && !command_cancel_i;
                    if (command_done_i) s_response_code = execution_response_code_i;
                end
            end
			STATE_POST_PROCESS: begin
				// TODO: IMPLEMENT POST-PROCESSING:
				// 1. Build response buffer with response header and parameters
				// 2. Update session nonces and compute response HMACs if sessions present
				// 3. Encrypt response parameters if sessions have encrypt attribute
				// 4. Update audit log if command auditing enabled
				// 5. Calculate final response_length
				// 6. Format proper response structure
				
				// Only validated, successful completed Startup initializes the engine.
                if (command_index == TPM_CC_STARTUP && startup_success_reg && response_code_reg_o == 0 &&
                    !session_error_reg && !handle_error_reg && !header_valid_error_reg && !mode_check_error_reg &&
                    !auth_check_error_reg && !param_decrypt_error_reg && !param_unmarshall_error_reg)
                    s_initialized = 1'b1;
				response_valid_o = 1'b1;
				response_length_o = 16'h0A; // Minimum response size for success
			end
			default: begin
			end
		endcase
        if (command_cancel_i && current_state_reg_o != STATE_IDLE && current_state_reg_o != STATE_POST_PROCESS &&
            !(current_state_reg_o == STATE_EXECUTE && is_creation)) s_response_code = 32'h00000101;
	end
endmodule












