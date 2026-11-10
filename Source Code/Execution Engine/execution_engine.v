module execution_engine(
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
		authHandle_i,
		pcrSelect_i,
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
		nv_phEnableNV_in_i,
		nv_shEnable_in_i,
		nv_ehEnable_in_i,
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
		st_testsRun_i,
		st_testsPassed_i,
		st_untested_i,
		// Management module inputs 
		op_state_i,
		startup_type_i,
		phEnable_i,
		phEnableNV_i,
		shEnable_i,
		ehEnable_i,
		shutdownSave_i,
		command_done_i,
		//management outputs
		testsPassed_o,
		untested_o,
		nv_phEnableNV_o,
		nv_shEnable_o,
		nv_ehEnable_o,
		orderlyInput_o,
		initialized_o,
		testsRun_o,
		authHierarchy_o,
		// Response outputs
		response_valid_o,
		response_code_o,
		response_length_o,
		current_state_o,
		command_start_o
	);

	// Inputs
	input         clock_i;					// Input clock_i signal
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
	input         phEnable_i;				// 1-bit input platform hierarchy enable from management module
	input         phEnableNV_i;			// 1-bit input platform hierarchy NV memory enable from management module
	input         shEnable_i;				// 1-bit input owner hierarchy enable from management module
	input         ehEnable_i;				// 1-bit input endorsement hierarchy enable from management module
	input  [15:0] shutdownSave_i;		// 16-bit input shutdown type from management module
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
	
	input [31:0] authHandle_i;			// 32-bit input signal from command buffer indicating authorization control domain requested by command

	input [7:0] pcrSelect_i;
	
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
	input execution_response_code_i;
	
	// NV memory submodule inputs
	input nv_phEnableNV_in_i;
	input nv_shEnable_in_i;
	input nv_ehEnable_in_i;
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
	input [15:0] st_testsRun_i;
	input [15:0] st_testsPassed_i;
	input [15:0] st_untested_i;
	
	// Outputs
	output        response_valid_o;		// 1-bit output response valid signal
	output [31:0] response_code_o;		// 32-bit output response code
	output [15:0] response_length_o;		// 16-bit output response length
	output [3:0]  current_state_o;		// 4-bit output current pipeline stage
   output reg    command_start_o;
	   
	//////////////////////////////////////////////////////////////////////////////////////////////////////////
	output	 [15:0] orderlyInput_o;		// 2-byte (16 bits) input from memory of state of last shutdown state
	output reg	     initialized_o;			// 1-bit input intialized bit (from execution engine)
	output	 [15:0] testsRun_o;				// 2-byte (16 bits) input of amount of tests run by the self-test module, from the execution engine
	output	 [15:0] testsPassed_o;			// 2-byte (16 bits) input of amount of tests that have run and passed by the self-test module, from the execution engine
	output	 [15:0] untested_o;				// 2-byte (16 bits) input of amount of tests that still need to be run by the self-test module, from the execution engine
	output 		     nv_phEnableNV_o;		// 1-bit input of state of phEnableNV_i switch, from Non-Volatile memory
	output	        nv_shEnable_o;			// 1-bit input of state of shEnable_i switch, from Non-Volatile memory
	output           nv_ehEnable_o;			// 1-bit input of state of ehEnable_i switch, from Non-Volatile memory
	// Outputs to management module - EXACT MATCH to management_module inputs
	output	 [31:0] authHierarchy_o;		// 2-byte (16 bits) input verifying which hiearchy was authorized (from execution engine)
	
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
				TPM_RC_INITIALIZE    = RC_VER1 + 12'h000,  // TPM not initialized_o
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
               TPM_CC_ZGEN_2PHASE              = 16'h018D,
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
	reg [3:0]  state;
	reg 		  session_present;
	reg 		  response_valid_o;
	reg [11:0] s_response_code;
	reg [15:0] response_length_o;
	reg [3:0]  current_state_o;
	reg [2:0]  handle_index;
	reg [2:0]  handle_count;
	wire [31:0] current_handle;
	wire [7:0]  handle_type;
	wire [23:0] handle_index_bits;
	reg 		  handle_error;
	reg [15:0] command_code_tag;
	reg [1:0]  session_index;     // Index of the session currently being processed 
	reg        session_error;     // Flag to detect session validation failure
	wire [7:0]  session_handle_type;
	wire [31:0] current_session_handle;
	wire [7:0]  current_session_attributes;
	wire [15:0] current_session_hmac_size;
	wire        current_session_valid;
	reg [31:0] authHierarchy_o;
	reg		  audit;
	reg		  decrypt;
	reg		  encrypt;
	reg		  auditReset;
	reg		  auditExclusive;
	reg		  continueSession;
	reg [1:0]  audit_count;
	reg [1:0]  decrypt_count;
	reg [1:0]  encrypt_count;
	
	reg [31:0] response_code_o;
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
	reg		  s_auditReset;
	reg		  s_auditExclusive;
	reg		  s_continueSession;
	reg [1:0]  s_audit_count;
	reg [1:0]  s_decrypt_count;
	reg [1:0]  s_encrypt_count;
	reg auth_check_error;
	
	reg s_execution_startup_done;
	reg header_valid_error, s_header_valid_error;
	reg mode_check_error, s_mode_check_error;
	reg s_auth_check_error;
	reg param_decrypt_error, s_param_decrypt_error;
	reg param_unmarshall_error, s_param_unmarshall_error;
	reg s_initialized;
	
	wire [15:0] commandIndex;
	wire nv;
	wire extensive;
	wire flushed;
	wire [2:0] cHandles;
	wire rHandle;
	wire v;

	wire x509sign;
	wire sign;
	wire object_encrypt;
	wire object_decrypt;
	wire restricted;
	wire encryptedDuplication;
	wire noDA;
	wire adminWithPolicy;
	wire userWithAuth;
	wire sensitiveDataOrigin;
	wire fixedParent;
	wire stClear;
	wire fixedTPM;
	
	wire [7:0] nv_tag;
	wire [23:0] nv_index;
	
	wire nv_write;
	wire nv_read;
	
	wire tpma_nv_read_stClear;
	wire tpma_nv_platformCreate;
	wire tpma_nv_written;
	wire tpma_nv_readLocked;
	wire tpma_nv_clear_stClear;
	wire tpma_nv_orderly;
	wire tpma_nv_no_DA;
	wire tpma_nv_policyRead;
	wire tpma_nv_authRead;
	wire tpma_nv_ownerRead;
	wire tpma_nv_ppRead;
	wire tpma_nv_globalLock;
	wire tpma_nv_write_stClear;
	wire tpma_nv_writeDefine;
	wire tpma_nv_writeAll;
	wire tpma_nv_writeLocked;
	wire tpma_nv_policy_delete;
	wire [3:0] tpm_nt;
	wire tpma_nv_policyWrite;
	wire tpma_nv_authWrite;
	wire tpma_nv_ownerWrite;
	wire tpma_nv_ppWrite;
	
	wire command_valid;

	assign current_handle =
   		(handle_index == 3'b000) ? handle_0_i :
                (handle_index == 3'b001) ? handle_1_i :
                                           handle_2_i;

	assign handle_type       = current_handle[31:24];
	assign handle_index_bits = current_handle[23:0];
	assign current_session_handle =
    (session_index == 2'd0) ? session0_handle_i :
    (session_index == 2'd1) ? session1_handle_i :
                              session2_handle_i;

	assign current_session_attributes =
    (session_index == 2'd0) ? session0_attributes_i :
    (session_index == 2'd1) ? session1_attributes_i :
                              session2_attributes_i;

	assign current_session_hmac_size =
    (session_index == 2'd0) ? session0_hmac_size_i :
    (session_index == 2'd1) ? session1_hmac_size_i :
                              session2_hmac_size_i;

	assign current_session_valid =
		(session_index == 2'd0) ? session0_valid_i :
		(session_index == 2'd1) ? session1_valid_i :
											session2_valid_i;
	assign session_handle_type = current_session_handle[31:24];
	// ============================================================================
	// SEQUENTIAL LOGIC BLOCK - STATE TRANSITIONS ONLY
	// ============================================================================
		always@(posedge clock_i, negedge reset_n_i) begin
			if(!reset_n_i) begin
				current_state_o <= STATE_IDLE;
				mode_check_error <= 1'b0;
				header_valid_error <= 1'b0;
				param_unmarshall_error <= 1'b0;
				param_decrypt_error <= 1'b0;
				handle_count <= 2'd0;
				handle_error <= 1'b0;
				handle_index <= 3'd0;
				session_index <= 2'd0;
				audit <= 1'b0;
				decrypt <= 1'b0;
				encrypt <= 1'b0;
				auditReset <= 1'b0;
				auditExclusive <= 1'b0;
				continueSession <= 1'b0;

				session_error <= 1'b0;
				audit_count <= 2'd0;
				decrypt_count <= 2'd0;
				encrypt_count <= 2'd0;
				auth_check_error <= 1'b0;
				initialized_o <= 1'b0;
				response_code_o <= 32'd0;
			end
			else begin
				response_code_o <= {20'h0, s_response_code};
				current_state_o <= state;
				mode_check_error <= s_mode_check_error;
				header_valid_error <= s_header_valid_error;
				param_unmarshall_error <= s_param_unmarshall_error;
				param_decrypt_error <= s_param_decrypt_error;
				handle_count <= s_handle_count;
				handle_error <= s_handle_error;

				

				handle_index <= s_handle_index;
				session_index <= s_session_index;
				audit <= s_audit;
				decrypt <= s_decrypt;
				encrypt <= s_encrypt;
				auditReset <= s_auditReset;
				auditExclusive <= s_auditExclusive;
				continueSession <= s_continueSession;


				
				session_error <= s_session_error;
				audit_count <= s_audit_count;
				decrypt_count <= s_decrypt_count;
				encrypt_count <= s_encrypt_count;
				auth_check_error <= s_auth_check_error;
				initialized_o <= s_initialized;

			end
		end
		
		assign orderlyInput_o = mem_orderly_i;
		assign testsRun_o = st_testsRun_i;
		assign testsPassed_o = st_testsPassed_i;
		assign untested_o	 = st_untested_i;
		assign nv_phEnableNV_o = nv_phEnableNV_in_i;
		assign nv_shEnable_o = nv_shEnable_in_i;
		assign nv_ehEnable_o = nv_ehEnable_in_i;
		
		assign nv_tag = tpm_nv_index_i[31:24];
		assign nv_index = tpm_nv_index_i[23:0];

		// Object Attributes
		// object_attributes_i bits[31:20] reserved
		assign x509sign = object_attributes_i[19];
		assign sign = object_attributes_i[18];
		assign object_encrypt = object_attributes_i[18];
		assign object_decrypt = object_attributes_i[17];
		assign restricted = object_attributes_i[16];
		// object_attributes_i bits[15:12] reserved
		assign encryptedDuplication = object_attributes_i[11];
		assign noDA = object_attributes_i[10];
		// object_attributes_i bits[9:8] reserved
		assign adminWithPolicy = object_attributes_i[7];
		assign userWithAuth = object_attributes_i[6];
		assign sensitiveDataOrigin = object_attributes_i[5];
		assign fixedParent = object_attributes_i[4];
		assign stClear = object_attributes_i[2];
		assign fixedTPM = object_attributes_i[1];
		// object_attributes_i bit[0] reserved
		
		// Non-Volatile Index Attributes
		// Reference: TCG TPM2.0 Specification Rev. 1.59, Part 2: Structures, Section 13.4 TPMA_NV (NV Index Attributes)
		assign tpma_nv_read_stClear = nv_index_attributes_i[31];
		assign tpma_nv_platformCreate = nv_index_attributes_i[30];
		assign tpma_nv_written = nv_index_attributes_i[29];
		assign tpma_nv_readLocked = nv_index_attributes_i[28];
		assign tpma_nv_clear_stClear = nv_index_attributes_i[27];
		assign tpma_nv_orderly = nv_index_attributes_i[26];
		assign tpma_nv_no_DA = nv_index_attributes_i[25];
		// nv_index_attributes_i bits[24:20] reserved for future use
		assign tpma_nv_policyRead = nv_index_attributes_i[19];
		assign tpma_nv_authRead = nv_index_attributes_i[18];
		assign tpma_nv_ownerRead = nv_index_attributes_i[17];
		assign tpma_nv_ppRead = nv_index_attributes_i[16];
		assign tpma_nv_globalLock = nv_index_attributes_i[15];
		assign tpma_nv_write_stClear = nv_index_attributes_i[14];
		assign tpma_nv_writeDefine = nv_index_attributes_i[13];
		assign tpma_nv_writeAll = nv_index_attributes_i[12];
		assign tpma_nv_writeLocked = nv_index_attributes_i[11];
		assign tpma_nv_policy_delete = nv_index_attributes_i[10];
		// nv_index_attributes_i bits[9:8] reserved for future use
		assign tpm_nt = nv_index_attributes_i[7:4];
		assign tpma_nv_policyWrite = nv_index_attributes_i[3];
		assign tpma_nv_authWrite = nv_index_attributes_i[2];
		assign tpma_nv_ownerWrite = nv_index_attributes_i[1];
		assign tpma_nv_ppWrite = nv_index_attributes_i[0];
	assign nv_write = (commandIndex == TPM_CC_NV_DEFINE_SPACE ||
								 commandIndex == TPM_CC_NV_WRITE ||
								 commandIndex == TPM_CC_NV_INCREMENT ||
								 commandIndex == TPM_CC_NV_EXTEND);
								 
		// Signal indicating that command
	assign nv_read = (commandIndex == TPM_CC_NV_DEFINE_SPACE || commandIndex == TPM_CC_NV_READ);
					
		// Reference: TCG TPM2.0 Specification Rev. 1.59, Part 2: Structures, Section 8.9.2 TPMA_CC (Command Code Attributes): Structure Definition
		assign commandIndex = command_code_i[15:0];			// Indicates the command being selected
		
		assign nv = command_code_i[22];							// SET(1): indicates that the command may write to NV
																		// CLEAR(0): indicates that the command does not write to NV
																		
		assign extensive = command_code_i[23];				// SET(1): This command could flush any number of loaded contexts
																		// CLEAR(0): no additional changes other than indicated by the flushed attribute
																		
		assign flushed = command_code_i[24];					// SET(1): The context associated with any transient handle in the command will be flushed when this command completes.
																		// CLEAR(0): No context is flushed as a side effect of this command.
																		
		assign cHandles = command_code_i[27:25];				// indicates the number of the handles in the handle area for this command
		
		assign rHandle = command_code_i[28];					// SET(1): indicates the presence of the handle area in the response
		
		assign v = command_code_i[29];							// SET(1): indicates that the command is vendor-specific
																		// CLEAR(0): indicates that the command is defined in a version of this specification
		assign command_valid = (commandIndex == TPM_CC_NV_UNDEFINE_SPACE_SPECIAL ||
					commandIndex == TPM_CC_EVICT_CONTROL ||
					commandIndex == TPM_CC_HIERARCHY_CONTROL ||
					commandIndex == TPM_CC_NV_UNDEFINE_SPACE ||
					commandIndex == TPM_CC_CHANGE_EPS ||
					commandIndex == TPM_CC_CHANGE_PPS ||
					commandIndex == TPM_CC_CLEAR ||
					commandIndex == TPM_CC_CLEAR_CONTROL ||
					commandIndex == TPM_CC_CLOCK_SET ||
					commandIndex == TPM_CC_HIERARCHY_CHANGE_AUTH ||
					commandIndex == TPM_CC_NV_DEFINE_SPACE ||
					commandIndex == TPM_CC_PCR_ALLOCATE ||
					commandIndex == TPM_CC_PCR_SET_AUTH_POLICY ||
					commandIndex == TPM_CC_PP_COMMANDS ||
					commandIndex == TPM_CC_SET_PRIMARY_POLICY ||
					commandIndex == TPM_CC_CLOCK_RATE_ADJUST ||
					commandIndex == TPM_CC_CREATE_PRIMARY ||
					commandIndex == TPM_CC_NV_GLOBAL_WRITE_LOCK ||
					commandIndex == TPM_CC_GET_COMMAND_AUDIT_DIGEST ||
					commandIndex == TPM_CC_NV_INCREMENT ||
					commandIndex == TPM_CC_NV_SET_BITS ||
					commandIndex == TPM_CC_NV_EXTEND ||
					commandIndex == TPM_CC_NV_WRITE ||
					commandIndex == TPM_CC_NV_WRITE_LOCK ||
					commandIndex == TPM_CC_DICTIONARY_ATTACK_LOCK_RESET ||
					commandIndex == TPM_CC_DICTIONARY_ATTACK_PARAMETERS ||
					commandIndex == TPM_CC_NV_CHANGE_AUTH ||
					commandIndex == TPM_CC_PCR_EVENT ||
					commandIndex == TPM_CC_PCR_RESET ||
					commandIndex == TPM_CC_SEQUENCE_COMPLETE ||
					commandIndex == TPM_CC_SET_ALGORITHM_SET ||
					commandIndex == TPM_CC_SET_COMMAND_CODE_AUDIT_STATUS ||
					commandIndex == TPM_CC_INCREMENTAL_SELF_TEST ||
					commandIndex == TPM_CC_SELF_TEST ||
					commandIndex == TPM_CC_STARTUP ||
					commandIndex == TPM_CC_SHUTDOWN ||
					commandIndex == TPM_CC_STIR_RANDOM ||
					commandIndex == TPM_CC_ACTIVATE_CREDENTIAL ||
					commandIndex == TPM_CC_CERTIFY ||
					commandIndex == TPM_CC_POLICY_NV ||
					commandIndex == TPM_CC_CERTIFY_CREATION ||
					commandIndex == TPM_CC_DUPLICATE ||
					commandIndex == TPM_CC_GET_TIME ||
					commandIndex == TPM_CC_GET_SESSION_AUDIT_DIGEST ||
					commandIndex == TPM_CC_NV_READ ||
					commandIndex == TPM_CC_NV_READ_LOCK ||
					commandIndex == TPM_CC_OBJECT_CHANGE_AUTH ||
					commandIndex == TPM_CC_POLICY_SECRET ||
					commandIndex == TPM_CC_REWRAP ||
					commandIndex == TPM_CC_CREATE ||
					commandIndex == TPM_CC_ECDH_ZGEN ||
					commandIndex == TPM_CC_HMAC ||
					commandIndex == TPM_CC_IMPORT ||
					commandIndex == TPM_CC_LOAD ||
					commandIndex == TPM_CC_QUOTE ||
					commandIndex == TPM_CC_RSA_DECRYPT ||
					commandIndex == TPM_CC_HMAC_START ||
					commandIndex == TPM_CC_SEQUENCE_UPDATE ||
					commandIndex == TPM_CC_SIGN ||
					commandIndex == TPM_CC_UNSEAL ||
					commandIndex == TPM_CC_POLICY_SIGNED ||
					commandIndex == TPM_CC_CONTEXT_LOAD ||
					commandIndex == TPM_CC_CONTEXT_SAVE ||
					commandIndex == TPM_CC_ECDH_KEY_GEN ||
					commandIndex == TPM_CC_ENCRYPT_DECRYPT ||
					commandIndex == TPM_CC_FLUSH_CONTEXT ||
					commandIndex == TPM_CC_LOAD_EXTERNAL ||
					commandIndex == TPM_CC_MAKE_CREDENTIAL ||
					commandIndex == TPM_CC_NV_READ_PUBLIC ||
					commandIndex == TPM_CC_POLICY_AUTHORIZE ||
					commandIndex == TPM_CC_POLICY_AUTH_VALUE ||
					commandIndex == TPM_CC_POLICY_COMMAND_CODE ||
					commandIndex == TPM_CC_POLICY_COUNTER_TIMER ||
					commandIndex == TPM_CC_POLICY_CP_HASH ||
					commandIndex == TPM_CC_POLICY_LOCALITY ||
					commandIndex == TPM_CC_POLICY_NAME_HASH ||
					commandIndex == TPM_CC_POLICY_OR ||
					commandIndex == TPM_CC_POLICY_TICKET ||
					commandIndex == TPM_CC_READ_PUBLIC ||
					commandIndex == TPM_CC_RSA_ENCRYPT ||
					commandIndex == TPM_CC_START_AUTH_SESSION ||
					commandIndex == TPM_CC_VERIFY_SIGNATURE ||
					commandIndex == TPM_CC_ECC_PARAMETERS ||
					commandIndex == TPM_CC_FIRMWARE_READ ||
					commandIndex == TPM_CC_GET_CAPABILITY ||
					commandIndex == TPM_CC_GET_RANDOM ||
					commandIndex == TPM_CC_GET_TEST_RESULT ||
					commandIndex == TPM_CC_HASH ||
					commandIndex == TPM_CC_PCR_READ ||
					commandIndex == TPM_CC_POLICY_PCR ||
					commandIndex == TPM_CC_POLICY_RESTART ||
					commandIndex == TPM_CC_READ_CLOCK ||
					commandIndex == TPM_CC_PCR_EXTEND ||
					commandIndex == TPM_CC_PCR_SET_AUTH_VALUE ||
					commandIndex == TPM_CC_NV_CERTIFY ||
					commandIndex == TPM_CC_EVENT_SEQUENCE_COMPLETE ||
					commandIndex == TPM_CC_HASH_SEQUENCE_START ||
					commandIndex == TPM_CC_POLICY_PHYSICAL_PRESENCE ||
					commandIndex == TPM_CC_POLICY_DUPLICATION_SELECT ||
					commandIndex == TPM_CC_POLICY_GET_DIGEST ||
					commandIndex == TPM_CC_TEST_PARMS ||
					commandIndex == TPM_CC_COMMIT ||
					commandIndex == TPM_CC_POLICY_PASSWORD ||
					commandIndex == TPM_CC_ZGEN_2PHASE ||
					commandIndex == TPM_CC_EC_EPHEMERAL ||
					commandIndex == TPM_CC_POLICY_NV_WRITTEN ||
					commandIndex == TPM_CC_POLICY_TEMPLATE ||
					commandIndex == TPM_CC_CREATE_LOADED ||
					commandIndex == TPM_CC_POLICY_AUTHORIZE_NV ||
					commandIndex == TPM_CC_ENCRYPT_DECRYPT_2 ||
					commandIndex == TPM_CC_AC_GET_CAPABILITY ||
					commandIndex == TPM_CC_AC_SEND ||
					commandIndex == TPM_CC_POLICY_AC_SEND_SELECT);
					
		always@(*) begin
			if(commandIndex == TPM_CC_CLEAR ||
				commandIndex == TPM_CC_HIERARCHY_CONTROL ||
				commandIndex == TPM_CC_CLEAR_CONTROL ||
				commandIndex == TPM_CC_CLOCK_SET ||
				commandIndex == TPM_CC_CLOCK_RATE_ADJUST ||
				commandIndex == TPM_CC_HIERARCHY_CHANGE_AUTH ||
				commandIndex == TPM_CC_NV_DEFINE_SPACE ||
				commandIndex == TPM_CC_PCR_ALLOCATE ||
				commandIndex == TPM_CC_PCR_SET_AUTH_POLICY ||
				commandIndex == TPM_CC_PP_COMMANDS ||
				commandIndex == TPM_CC_SET_PRIMARY_POLICY ||
				commandIndex == TPM_CC_SET_ALGORITHM_SET ||
				commandIndex == TPM_CC_SET_COMMAND_CODE_AUDIT_STATUS ||
				commandIndex == TPM_CC_CREATE_PRIMARY ||
				commandIndex == TPM_CC_NV_GLOBAL_WRITE_LOCK ||
				commandIndex == TPM_CC_NV_INCREMENT ||
				commandIndex == TPM_CC_NV_SET_BITS ||
				commandIndex == TPM_CC_NV_EXTEND ||
				commandIndex == TPM_CC_NV_WRITE_LOCK ||
				commandIndex == TPM_CC_DICTIONARY_ATTACK_LOCK_RESET ||
				commandIndex == TPM_CC_DICTIONARY_ATTACK_PARAMETERS ||
				commandIndex == TPM_CC_NV_CHANGE_AUTH ||
				commandIndex == TPM_CC_PCR_EVENT ||
				commandIndex == TPM_CC_PCR_RESET ||
				commandIndex == TPM_CC_PCR_EXTEND ||
				commandIndex == TPM_CC_PCR_SET_AUTH_VALUE ||
				commandIndex == TPM_CC_SEQUENCE_COMPLETE ||
				commandIndex == TPM_CC_EVENT_SEQUENCE_COMPLETE ||
				commandIndex == TPM_CC_FLUSH_CONTEXT ||
				commandIndex == TPM_CC_CREATE ||
				commandIndex == TPM_CC_LOAD ||
				commandIndex == TPM_CC_UNSEAL ||
				commandIndex == TPM_CC_SIGN ||
				commandIndex == TPM_CC_READ_PUBLIC ||
				commandIndex == TPM_CC_ECDH_KEY_GEN ||
				commandIndex == TPM_CC_RSA_DECRYPT ||
				commandIndex == TPM_CC_ECDH_ZGEN ||
				commandIndex == TPM_CC_CONTEXT_SAVE ||
				commandIndex == TPM_CC_CONTEXT_LOAD ||
				commandIndex == TPM_CC_NV_READ ||
				commandIndex == TPM_CC_NV_READ_LOCK ||
				commandIndex == TPM_CC_OBJECT_CHANGE_AUTH ||
				commandIndex == TPM_CC_POLICY_SECRET ||
				commandIndex == TPM_CC_REWRAP ||
				commandIndex == TPM_CC_RSA_ENCRYPT ||
				commandIndex == TPM_CC_VERIFY_SIGNATURE ||
				commandIndex == TPM_CC_COMMIT ||
				commandIndex == TPM_CC_EC_EPHEMERAL ||
				commandIndex == TPM_CC_CREATE_LOADED ||
				commandIndex == TPM_CC_AC_SEND) begin
				s_handle_count = 3'b001;
			end
			else if(commandIndex == TPM_CC_NV_UNDEFINE_SPACE ||
					  commandIndex == TPM_CC_NV_UNDEFINE_SPACE_SPECIAL ||
					  commandIndex == TPM_CC_EVICT_CONTROL ||
					  commandIndex == TPM_CC_CHANGE_EPS ||
					  commandIndex == TPM_CC_CHANGE_PPS ||
					  commandIndex == TPM_CC_NV_WRITE ||
					  commandIndex == TPM_CC_START_AUTH_SESSION ||
					  commandIndex == TPM_CC_ACTIVATE_CREDENTIAL ||
					  commandIndex == TPM_CC_CERTIFY ||
					  commandIndex == TPM_CC_POLICY_NV ||
					  commandIndex == TPM_CC_CERTIFY_CREATION ||
					  commandIndex == TPM_CC_DUPLICATE ||
					  commandIndex == TPM_CC_QUOTE ||
					  commandIndex == TPM_CC_HMAC ||
					  commandIndex == TPM_CC_IMPORT ||
					  commandIndex == TPM_CC_POLICY_SIGNED ||
					  commandIndex == TPM_CC_ENCRYPT_DECRYPT ||
					  commandIndex == TPM_CC_MAKE_CREDENTIAL ||
					  commandIndex == TPM_CC_POLICY_AUTHORIZE ||
					  commandIndex == TPM_CC_POLICY_AUTH_VALUE ||
					  commandIndex == TPM_CC_POLICY_COMMAND_CODE ||
					  commandIndex == TPM_CC_POLICY_COUNTER_TIMER ||
					  commandIndex == TPM_CC_POLICY_CP_HASH ||
					  commandIndex == TPM_CC_POLICY_LOCALITY ||
					  commandIndex == TPM_CC_POLICY_NAME_HASH ||
					  commandIndex == TPM_CC_POLICY_OR ||
					  commandIndex == TPM_CC_POLICY_TICKET ||
					  commandIndex == TPM_CC_POLICY_PCR ||
					  commandIndex == TPM_CC_POLICY_RESTART ||
					  commandIndex == TPM_CC_POLICY_PHYSICAL_PRESENCE ||
					  commandIndex == TPM_CC_POLICY_DUPLICATION_SELECT ||
					  commandIndex == TPM_CC_POLICY_GET_DIGEST ||
					  commandIndex == TPM_CC_POLICY_PASSWORD ||
					  commandIndex == TPM_CC_ZGEN_2PHASE ||
					  commandIndex == TPM_CC_POLICY_NV_WRITTEN ||
					  commandIndex == TPM_CC_POLICY_TEMPLATE ||
					  commandIndex == TPM_CC_POLICY_AUTHORIZE_NV ||
					  commandIndex == TPM_CC_ENCRYPT_DECRYPT_2 ||
					  commandIndex == TPM_CC_POLICY_AC_SEND_SELECT ||
					  commandIndex == TPM_CC_NV_CERTIFY) begin
				s_handle_count = 3'b010;
			end
			else begin
				s_handle_count = 3'b000;
			end
		end
					

		// Session tag necessary for each command type:
		always@(*) begin
			if(commandIndex == TPM_CC_STARTUP ||
				commandIndex == TPM_CC_CONTEXT_SAVE ||
				commandIndex == TPM_CC_CONTEXT_LOAD ||
				commandIndex == TPM_CC_FLUSH_CONTEXT) begin
				command_code_tag = TPM_ST_NO_SESSIONS;
			end
			else begin
				command_code_tag = TPM_ST_SESSIONS;
				if(!audit) begin
					if(commandIndex == TPM_CC_SHUTDOWN ||
						commandIndex == TPM_CC_SELF_TEST ||
						commandIndex == TPM_CC_INCREMENTAL_SELF_TEST ||
						commandIndex == TPM_CC_GET_TEST_RESULT ||
						commandIndex == TPM_CC_POLICY_RESTART ||
						commandIndex == TPM_CC_ECC_PARAMETERS ||
						commandIndex == TPM_CC_PCR_READ ||
						commandIndex == TPM_CC_POLICY_OR ||
						commandIndex == TPM_CC_POLICY_LOCALITY ||
						commandIndex == TPM_CC_POLICY_COMMAND_CODE ||
						commandIndex == TPM_CC_POLICY_PHYSICAL_PRESENCE ||
						commandIndex == TPM_CC_POLICY_AUTH_VALUE ||
						commandIndex == TPM_CC_POLICY_PASSWORD ||
						commandIndex == TPM_CC_POLICY_NV_WRITTEN ||
						commandIndex == TPM_CC_READ_CLOCK ||
						commandIndex == TPM_CC_GET_CAPABILITY ||
						commandIndex == TPM_CC_TEST_PARMS ||
						commandIndex == TPM_CC_AC_GET_CAPABILITY) begin
						command_code_tag = TPM_ST_NO_SESSIONS;
					end
					else if((commandIndex == TPM_CC_START_AUTH_SESSION ||
								commandIndex == TPM_CC_LOAD_EXTERNAL ||
								commandIndex == TPM_CC_MAKE_CREDENTIAL ||
								commandIndex == TPM_CC_RSA_ENCRYPT ||
								commandIndex == TPM_CC_HASH ||
								commandIndex == TPM_CC_POLICY_SIGNED) && !encrypt && !decrypt) begin
						command_code_tag = TPM_ST_NO_SESSIONS;
					end
					else if((commandIndex == TPM_CC_STIR_RANDOM ||
								commandIndex == TPM_CC_HASH_SEQUENCE_START ||
								commandIndex == TPM_CC_POLICY_TICKET ||
								commandIndex == TPM_CC_POLICY_PCR ||
								commandIndex == TPM_CC_POLICY_COUNTER_TIMER ||
								commandIndex == TPM_CC_POLICY_CP_HASH ||
								commandIndex == TPM_CC_POLICY_NAME_HASH ||
								commandIndex == TPM_CC_POLICY_DUPLICATION_SELECT ||
								commandIndex == TPM_CC_POLICY_AUTHORIZE ||
								commandIndex == TPM_CC_POLICY_TEMPLATE) && !decrypt) begin
						command_code_tag = TPM_ST_NO_SESSIONS;
					end
					else if((commandIndex == TPM_CC_READ_PUBLIC ||
								commandIndex == TPM_CC_ECDH_KEY_GEN ||
								commandIndex == TPM_CC_GET_RANDOM ||
								commandIndex == TPM_CC_EC_EPHEMERAL ||
								commandIndex == TPM_CC_VERIFY_SIGNATURE ||
								commandIndex == TPM_CC_POLICY_GET_DIGEST ||
								commandIndex == TPM_CC_NV_READ_PUBLIC) && !encrypt) begin
						command_code_tag = TPM_ST_NO_SESSIONS;
					end
				end
			end
		end
		
		always@(*) begin
			s_audit = audit;
			s_decrypt = decrypt;
			s_encrypt = encrypt;
			s_auditReset = auditReset;
			s_auditExclusive = auditExclusive;
			s_continueSession = continueSession;
			s_session_handle_type = session_handle_type;
			s_current_session_handle = current_session_handle;
			s_current_session_attributes = current_session_attributes;
			s_current_session_hmac_size = current_session_hmac_size;
			s_current_session_valid = current_session_valid;
			if(command_tag_i == TPM_ST_SESSIONS) begin
			// Map flattened inputs into a common structure for session processing.
				if (session_index == 2'd0) begin
					s_current_session_handle     = session0_handle_i;
					s_current_session_attributes = session0_attributes_i;
					s_current_session_hmac_size  = session0_hmac_size_i;
					s_current_session_valid      = session0_valid_i;
				end
				else if (session_index == 2'd1) begin
					s_current_session_handle     = session1_handle_i;
					s_current_session_attributes = session1_attributes_i;
					s_current_session_hmac_size  = session1_hmac_size_i;
					s_current_session_valid      = session1_valid_i;
				end
				else begin
					s_current_session_handle     = session2_handle_i;
					s_current_session_attributes = session2_attributes_i;
					s_current_session_hmac_size  = session2_hmac_size_i;
					s_current_session_valid      = session2_valid_i;
				end

				// ----------------------------------------------------------------
				// If the session is valid and within the allowed limit, process it.
				// ----------------------------------------------------------------
				if (session_index < 2'd3 && current_session_valid) begin

					
					s_audit = current_session_attributes[7];
					s_encrypt = current_session_attributes[6];
					s_decrypt = current_session_attributes[5];
					s_auditReset = current_session_attributes[2];
					s_auditExclusive = current_session_attributes[1];
					s_continueSession = current_session_attributes[0];
					
					s_session_handle_type = current_session_handle[31:24];

				end
			end
		end
		always@(*) begin
			s_session_error = session_error;
			s_audit_count = audit_count;
			s_decrypt_count = decrypt_count;
			s_encrypt_count = encrypt_count;
			state = STATE_IDLE;   
			s_session_index = 3'b000;
			case(current_state_o)
				// ====================================================================
				// STAGE 1: IDLE - Wait for command
				// ====================================================================
				STATE_IDLE: begin
					s_session_error = 1'b0;
					s_audit_count = 2'b0;
					s_decrypt_count = 2'b0;
					s_encrypt_count = 2'b0;
					if(command_ready_i) begin
						state = STATE_HEADER_VALID;
					end
				end

				// ====================================================================
				// STAGE 2: HEADER VALIDATION - TPM 2.0 Part 3, Section 5.2
				// ====================================================================
				STATE_HEADER_VALID: begin
					if((command_tag_i != TPM_ST_NO_SESSIONS && command_tag_i != TPM_ST_SESSIONS) || 
						 command_size_i != command_length_i ||
						 !command_valid) begin
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
						if(commandIndex != TPM_CC_GET_TEST_RESULT || commandIndex != TPM_CC_GET_CAPABILITY || command_tag_i != TPM_ST_NO_SESSIONS) begin
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
						// TPM not initialized_o - first command must be TPM2_Startup
						if(commandIndex != TPM_CC_STARTUP) begin
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
					 	if (handle_error) begin
							state = STATE_POST_PROCESS;
						end
						else if (handle_index < handle_count) begin
							  //////////////////////////////////////////////////////////////////////////////////////////////////////////////
							  //cant currently check if handles are loaded in the appropriate spots add submodule
							  /////////////////////////////////////////////////////////////////////////////////////////////////////////////
							  state = STATE_HANDLE_VALID;
						 end
						 else begin
					 		if (handle_error) begin

								state = STATE_POST_PROCESS;
							end
							else begin
						 	state = STATE_SESSION_VALID;
							end
						 end
					end

				// ====================================================================
				// STAGE 5: SESSION VALIDATION - TPM 2.0 Part 3, Section 5.5
				// ====================================================================
				STATE_SESSION_VALID: begin
					// ----------------------------------------------------------------
					// This stage validates the structure and content of each session
					// in the command. Each session provides authorization or performs
					// special actions like encryption, decryption, or auditing.
					// Up to 3 sessions can be present. Each has a handle, attributes,
					// and an HMAC value. This logic loops over all valid sessions,
					// checks for valid types, ensures constraints, and flags errors.
					// ----------------------------------------------------------------
					
					state = STATE_SESSION_VALID;
					
					if (session_error)
						state = STATE_POST_PROCESS;
					
					if((command_tag_i == TPM_ST_NO_SESSIONS && command_code_tag == TPM_ST_SESSIONS) || (command_tag_i == TPM_ST_SESSIONS && command_code_tag == TPM_ST_NO_SESSIONS)) begin
						s_session_error = 1'b1;
					end
					else if(command_tag_i == TPM_ST_SESSIONS && command_code_tag == TPM_ST_SESSIONS) begin
						// Step 1: Validate the session handle's type.
						// The top 8 bits of the handle indicate its type.
						// Valid session types include HMAC (0x01), Policy (0x02), and Password (0x03).
						if(session_handle_type != 8'h01 && session_handle_type != 8'h02 && session_handle_type != 8'h03) begin
							s_session_error = 1'b1;
						end

						// Step 2: Ensure each role (audit/decrypt/encrypt) is only used once.
						// Bits 7, 6, and 5 in the session attributes represent audit, decrypt,
						// and encrypt flags respectively. Multiple sessions cannot share roles.
		
						// Step 3: Validate that empty sessions (no HMAC) are used only if
						// they are performing other roles (audit/decrypt/encrypt).
						if (current_session_hmac_size == 16'b0 && (!audit || !decrypt || !encrypt)) begin
							s_session_error = 1'b1; // An empty session must be doing something
						end
						else if(max_session_amount_i == session_index && authorization_size_i > 32'd0) s_session_error = 1'b1;
						
						else if(!session_loaded_i) s_session_error = 1'b1;
						
						else if(!auth_session_i && auth_necessary_i) s_session_error = 1'b1;
						else if(!session_error &&  session_index < 2'd3 && current_session_valid) begin
						s_session_index = session_index + 1'b1;
									
						if (s_audit) begin // Audit bit
						s_audit_count = audit_count + 1'b1;
							if (s_audit_count > 2'd1) s_session_error = 1'b1;
						end

						if (s_decrypt) begin // Decrypt bit
							s_decrypt_count = decrypt_count + 1'b1;
							if (s_decrypt_count > 2'd1) s_session_error = 1'b1;
						end

						if (s_encrypt) begin // Encrypt bit
							s_encrypt_count = encrypt_count + 1'b1;
							if (s_encrypt_count > 2'd1) s_session_error = 1'b1;
						end
					end
						// Final step after checking all sessions
						// If we validated more than 3, that's an error
						if (session_index == 2'd3)begin
							s_session_error = 1'b1;
							s_session_index = 3'b000;
						end
						if(s_session_error) begin
													// If we encountered any error, prepare a failure response
							s_session_index = 3'b000;
							state = STATE_POST_PROCESS;
						end else if (session_index == max_session_amount_i) begin
							s_session_index = 3'b000;
							state = STATE_AUTH_CHECK;
						end else state = STATE_SESSION_VALID;

						end
				end
				// ====================================================================
				// STAGE 6: AUTHORIZATION CHECKS - TPM 2.0 Part 3, Section 5.6
				// ====================================================================
				STATE_AUTH_CHECK: begin
					// Check for error from authorization subsystem
					if(auth_check_error == 1'b1) begin
						state = STATE_POST_PROCESS;
					end
					else begin
						state = STATE_PARAM_DECRYPT;
					end
				end
				// ====================================================================
				// STAGE 7: PARAMETER DECRYPTION - TPM 2.0 Part 3, Section 5.7
				// ====================================================================
				STATE_PARAM_DECRYPT: begin
					// To be implemented with a submodule
					// For now, always proceed to parameter unmarshaling
					state = STATE_PARAM_UNMARSH;
				end
				
				// ====================================================================
				// STAGE 8: PARAMETER UNMARSHALING - TPM 2.0 Part 3, Section 5.8
				// ====================================================================
				STATE_PARAM_UNMARSH: begin
				
					////////////////////////////////////
					//To be implemented with a submodule
					/////////////////////////////////////
					
					// TODO: IMPLEMENT PARAMETER UNMARSHALING: RAM operation
					// 1. Calculate parameter start offset (after header + handles + auth area)
					// 2. For each parameter in command schema:
					//    - Parse parameter based on type (TPM2B, TPM_ALG_ID, TPM_HANDLE, etc.)
					//    - Validate parameter value ranges and constraints
					//    - Check algorithm selections are supported
					//    - Verify reserved fields are zero
					// 3. Handle TPM2B structures with size prefixes
					// 4. Return appropriate error codes (TPM_RC_SIZE, TPM_RC_VALUE, TPM_RC_SCHEME, etc.)
					
					// For now, always proceed to execution
					state = STATE_EXECUTE;
				end
				
				// ====================================================================
				// STAGE 9: COMMAND EXECUTION - TPM 2.0 Part 3, Section 5.9
				// ====================================================================
				STATE_EXECUTE: begin
					// TODO: IMPLEMENT COMMAND EXECUTION:
					// 1. Execute command-specific logic based on command_code_i
					// 2. For TPM_CC_STARTUP: Set initialized_o state
					// 3. For TPM_CC_GET_TEST_RESULT: Return self-test results
					// 4. For cryptographic commands: Perform operations via crypto engine
					// 5. Update TPM state (objects, NV, PCRs, sessions) as required
					// 6. Handle multi-cycle operations with proper state management
					// 7. Return TPM_RC_FAILURE on execution errors
					
					// For now, always proceed to post-processing
					if(command_done_i) begin
						state = STATE_POST_PROCESS;
					end
				end
				
				// ====================================================================
				// STAGE 10: POST-PROCESSING - TPM 2.0 Part 3, Section 5.10
				// ====================================================================
				STATE_POST_PROCESS: begin
					// TODO: IMPLEMENT POST-PROCESSING:
					// 1. Build response buffer with response header and parameters
					// 2. Update session nonces and compute response HMACs if sessions present
					// 3. Encrypt response parameters if sessions have encrypt attribute
					// 4. Update audit log if command auditing enabled
					// 5. Calculate final response_length_o
					// 6. Format proper response structure
					state = STATE_IDLE;
				end
				default: begin
						state = STATE_IDLE;
				end
		endcase
	end
	// ============================================================================
	// COMBINATIONAL LOGIC BLOCK - ALL OUTPUTS AND NEXT STATE
	// ============================================================================
	always@(*) begin
		// carry error values from previous state
		s_mode_check_error = mode_check_error;
		s_header_valid_error = header_valid_error;
		s_handle_error = handle_error;
		s_auth_check_error = auth_check_error;
		s_param_unmarshall_error = param_unmarshall_error;
		s_param_decrypt_error = param_decrypt_error;
		s_execution_startup_done = execution_startup_done_i;
		s_initialized = initialized_o;
		s_handle_index = handle_index;
		
		// Default output values
		response_valid_o =   1'b0;
		s_response_code = response_code_o[11:0];
		response_length_o = 16'h0;
		command_start_o   = 1'b0;
		session_present = 1'b0;
		authHierarchy_o = 32'h00000000;

		if(state == STATE_HANDLE_VALID) begin			// Check that the TPM shall successfully unmarshal the number of handles required by the command and validate that the value of the handle is consistent with the command syntax
			s_current_handle = current_handle;
			s_handle_type = handle_type;
			s_handle_index_bits = handle_index_bits;
			s_handle_index = handle_index;
			if(cHandles > handle_count) begin
	                		s_handle_error = 1'b1;
		        		s_response_code = TPM_RC_VALUE;
		        	end
		    		// If the handle references a transient object, check that the handle references a loaded object
		        	else if(handle_type == TPM_HT_TRANSIENT) begin
		                	if(!loaded_object_present_i) begin
					        s_handle_error = 1'b1;
						s_response_code = TPM_RC_REFERENCE_H0 + handle_index;
					end else begin
						// Extract current handle
						s_handle_index = handle_index + 1'b1;
					end
				end
				else if(handle_type == TPM_HT_PERSISTENT) begin
					if((entity_hierarchy_i == TPM_RH_PLATFORM && !phEnable_i) || 
			                   (entity_hierarchy_i == TPM_RH_OWNER && !shEnable_i) || 
				           (entity_hierarchy_i == TPM_RH_ENDORSEMENT && !ehEnable_i) ||
			                   !nv_object_present_i) begin
						s_handle_error = 1'b1;
						s_response_code = TPM_RC_HANDLE; 
					end
					else if(!ram_available_i) begin
						s_handle_error = 1'b1;
						s_response_code = TPM_RC_OBJECT_MEMORY;
					end else begin
						s_handle_index = handle_index + 1'b1;
					end
				end
			else if(handle_type == TPM_HT_NV_INDEX) begin
				if(!nv_index_present_i ||
			           (entity_hierarchy_i == TPM_RH_PLATFORM && !phEnable_i) || 
			            (entity_hierarchy_i == TPM_RH_OWNER && !shEnable_i) || 
						(entity_hierarchy_i == TPM_RH_ENDORSEMENT && !ehEnable_i)) begin
						s_handle_error = 1'b1;
						s_response_code = TPM_RC_HANDLE;
					end
					else if((nv_write && tpma_nv_writeLocked) || (nv_read && tpma_nv_readLocked)) begin
						s_handle_error = 1'b1;
						s_response_code = TPM_RC_NV_LOCKED;
					end else begin
						s_handle_index = handle_index + 1'b1;
					end
				end
				else if(handle_type == TPM_HT_HMAC_SESSION || 
						  handle_type == TPM_HT_LOADED_SESSION || 
						  handle_type == TPM_HT_POLICY_SESSION || 
						  handle_type == TPM_HT_SAVED_SESSION) begin
					if(!session_present) begin
						s_handle_error = 1'b1;
						s_response_code = TPM_RC_REFERENCE_H0 + handle_index;
					end else begin
						// Extract current handle
						s_handle_index = handle_index + 1'b1;
					end
				end
				else if(handle_type == TPM_HT_PERMANENT) begin
					if((current_handle == TPM_RH_PLATFORM && !phEnable_i) || 
						(current_handle == TPM_RH_OWNER && !shEnable_i) || 
						(current_handle == TPM_RH_ENDORSEMENT && !ehEnable_i)) begin
						s_handle_error = 1'b1;
						s_response_code = TPM_RC_HIERARCHY;
					end else begin
						// Extract current handle
						s_handle_index = handle_index + 1'b1;
					end
				end
				// Check if the handle references a PCR, then the value is within the range of PCR supported by the TPM
				else if(handle_type == TPM_HT_PCR && pcrSelect_i > PCR_SELECT_MAX) begin
					s_handle_error = 1'b1;
					s_response_code = TPM_RC_VALUE;
				end else begin
					s_handle_index = handle_index + 1'b1;
				end
				
            end


		case(current_state_o)
			// ====================================================================
			// STAGE 1: IDLE - Wait for command
			// ====================================================================
			STATE_IDLE: begin
					response_valid_o =   1'b0;
					s_response_code =   12'b0;
					response_length_o = 16'h0;
					s_handle_error = 1'b0;
					s_handle_index = 3'b000;
				if(command_ready_i) begin
					session_present = (command_tag_i == TPM_ST_SESSIONS);
				end
			end
			
			// ====================================================================
			// STAGE 2: HEADER VALIDATION - TPM 2.0 Part 3, Section 5.2
			// ===================================================================
			STATE_HEADER_VALID: begin
				// IMPLEMENTED: Basic header validation
				if(command_tag_i != TPM_ST_NO_SESSIONS && command_tag_i != TPM_ST_SESSIONS) begin
					s_header_valid_error = 1'b1;
					s_response_code = TPM_RC_BAD_TAG;
				end
				else if(command_size_i != command_length_i) begin
					s_header_valid_error = 1'b1;
					s_response_code = TPM_RC_COMMAND_SIZE;
				end
				else if(!command_valid) begin
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
					if(commandIndex != TPM_CC_GET_TEST_RESULT || commandIndex != TPM_CC_GET_CAPABILITY || command_tag_i != TPM_ST_NO_SESSIONS) begin
						s_mode_check_error = 1'b1;
						s_response_code = TPM_RC_FAILURE;
					end
				end
				else if(op_state_i != OPERATIONAL_STATE) begin
					// TPM not initialized_o - first command must be TPM2_Startup
					if(commandIndex != TPM_CC_STARTUP) begin
						s_mode_check_error = 1'b1;
						s_response_code = TPM_RC_INITIALIZE;
					end
				end
			end
			
			// ====================================================================
			// STAGE 4: HANDLE VALIDATION - TPM 2.0 Part 3, Section 5.4
			// ====================================================================
			STATE_HANDLE_VALID: begin
    				
			end
			// ====================================================================
			// STAGE 5: SESSION VALIDATION - TPM 2.0 Part 3, Section 5.5
			// ====================================================================
			STATE_SESSION_VALID: begin
				//s_session_index = session_index;
				if(s_session_index == max_session_amount_i || s_session_error)begin
				if(command_tag_i == TPM_ST_NO_SESSIONS) begin
					if(command_code_tag == TPM_ST_SESSIONS) begin
						s_response_code = TPM_RC_AUTH_CONTEXT;
					end
				end
				else if(command_tag_i == TPM_ST_SESSIONS) begin
					if(command_code_tag == TPM_ST_NO_SESSIONS) begin
						s_response_code = TPM_RC_AUTH_MISSING;
					end
					else if(command_code_tag == TPM_ST_SESSIONS) begin
						if (session_handle_type != TPM_HT_HMAC_SESSION &&
    						    session_handle_type != TPM_HT_POLICY_SESSION &&
    						    current_session_handle != TPM_RS_PW) begin
							s_response_code = TPM_RC_HANDLE;
						end
						else begin
							if(!session_loaded_i) begin
								s_response_code = TPM_RC_REFERENCE_S0 + session_index;
							end
							else if(max_session_amount_i == session_index && authorization_size_i > 32'd0) begin
								s_response_code = TPM_RC_AUTHSIZE;
							end
							else if(s_audit_count > 2'd1 || s_decrypt_count > 2'd1 || s_encrypt_count > 2'd1 || (!auth_session_i && !audit && !decrypt && !encrypt)) begin
								s_response_code = TPM_RC_ATTRIBUTES;
							end
							else if(!auth_session_i && auth_necessary_i) begin
								s_response_code = TPM_RC_AUTH_MISSING;
							end
						end
					end
				end
				end
			end
			
			// ====================================================================
			// STAGE 6: AUTHORIZATION CHECKS - TPM 2.0 Part 3, Section 5.6
			// ====================================================================
			STATE_AUTH_CHECK: begin
				// Check to see if authorization subsystem has finished before updating authorization dependent information
				if(auth_done_i) begin
					// Response code will come from authorization subsystem
					s_response_code = auth_response_code_i;
					
					// If authorization successful tell other modules the authorization hierarchy, if it fails tell them the null hierarchy
					if(auth_success_i) begin
						authHierarchy_o = authHandle_i;
					end
					else begin
						authHierarchy_o = TPM_RH_NULL;
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
				if(param_decrypt_success_i == 1'b1)begin
					
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
				if(param_unmarshall_success_i == 1'b1)begin
					
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
				//start command processing
				s_execution_startup_done = execution_startup_done_i;
				s_response_code = execution_response_code_i;
				command_start_o = 1'b1;
			end
			
			// ====================================================================
			// STAGE 10: POST-PROCESSING - TPM 2.0 Part 3, Section 5.10
			// ====================================================================
			STATE_POST_PROCESS: begin
				// TODO: IMPLEMENT POST-PROCESSING:
				// 1. Build response buffer with response header and parameters
				// 2. Update session nonces and compute response HMACs if sessions present
				// 3. Encrypt response parameters if sessions have encrypt attribute
				// 4. Update audit log if command auditing enabled
				// 5. Calculate final response_length_o
				// 6. Format proper response structure
				
				//Check whether the initiliazed signal can be sent based on if previous errors were set
				if(commandIndex == TPM_CC_STARTUP || op_state_i != OPERATIONAL_STATE || !s_session_error || !s_handle_error || !s_header_valid_error || 
						   !s_mode_check_error ||!s_auth_check_error || !s_param_decrypt_error || !s_param_unmarshall_error || !s_execution_startup_done)begin
					s_initialized = 1'b1;
				end
				response_valid_o = 1'b1;
				response_length_o = 16'h0A; // Minimum response size for success
			end
			default: begin
			end
		endcase
	end
endmodule

// Scoped host command executor. The CRB provides a synchronous packet read
// and reads the response payload by offset after response_valid pulses.
//
// TCG TPM 2.0 Library Part 3, section 5 describes the processing stages.
// Section 15.4 defines the Hash request and reply. This executor implements
// the no-session SHA-256 case with TPM_RH_NULL. The SHA math lives downstream.
module execution_engine_hash (
    input wire clock_i, reset_n_i, start_i, operational_i,
    input wire [15:0] command_tag_i,
    input wire [31:0] command_code_i, command_size_i,
    // Full packet byte address, including the 10-byte command header.
    output reg [11:0] command_addr_o,
    input wire [7:0] command_byte_i,
    output reg response_valid_o,
    output reg [31:0] response_code_o,
    output wire [11:0] response_length_o,
    // Response payload offset. The CRB writes the response header separately.
    input wire [11:0] response_addr_i,
    output reg [7:0] response_byte_o,
    output wire hash_request_o,
    input wire hash_grant_i,
    output wire [7:0] hash_data_o,
    output wire hash_valid_o, hash_end_o,
    input wire hash_ready_i,
    input wire [255:0] hash_digest_i,
    input wire hash_digest_valid_i,
    output wire hash_digest_ready_o
);
    localparam [3:0] IDLE=0, READ_WAIT=1, READ_FIELD=2, REQUEST=3,
        DATA_WAIT=4, SEND=5, DIGEST=6, RESPOND=7;
    localparam [31:0] RC_BAD_TAG=32'h01e, RC_INITIALIZE=32'h100,
        RC_FAILURE=32'h101, RC_COMMAND_SIZE=32'h142, RC_COMMAND_CODE=32'h143,
        RC_SIZE_DATA=32'h1d5, RC_HASH_ALG=32'h2c3, RC_VALUE_HIERARCHY=32'h3c4;
    reg [3:0] state;
    reg [2:0] field_index;
    reg [15:0] data_length;
    reg [31:0] field_bytes;
    reg [11:0] remaining;
    reg [255:0] digest;
    reg success;
    // Assemble multibyte packet fields in wire order, most significant byte first.
    wire [31:0] next_field = {field_bytes[23:0], command_byte_i};

    // Request/grant reserves SHA. Ready/valid then transfers each message byte.
    assign hash_request_o = reset_n_i && state == REQUEST;
    assign hash_data_o = command_byte_i;
    assign hash_valid_o = reset_n_i && state == SEND && remaining != 0;
    // End accompanies the last byte, or travels alone for an empty input.
    assign hash_end_o = reset_n_i && state == SEND && remaining <= 1;
    assign hash_digest_ready_o = reset_n_i && state == DIGEST;
    assign response_length_o = success ? 12'd52 : 12'd10;

    // A successful reply has 10 header bytes and 42 payload bytes.
    // Payload 0..1 is the TPM2B_DIGEST length (32), 2..33 is the digest,
    // and 34..41 is the null TPMT_TK_HASHCHECK (tag, hierarchy, empty proof).
    // Keep the digest available while the CRB reads the payload by offset.
    always @* begin
        response_byte_o = 0;
        case (response_addr_i)
            12'd1: response_byte_o = 8'h20;
            12'd34: response_byte_o = 8'h80;
            12'd35: response_byte_o = 8'h24;
            12'd36: response_byte_o = 8'h40;
            12'd39: response_byte_o = 8'h07;
            default: if (response_addr_i >= 2 && response_addr_i < 34)
                response_byte_o = digest[255-(response_addr_i-2)*8 -: 8];
        endcase
    end

    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            state <= IDLE;
            command_addr_o <= 0;
            field_index <= 0;
            field_bytes <= 0;
            data_length <= 0;
            remaining <= 0;
            digest <= 0;
            success <= 0;
            response_valid_o <= 0;
            response_code_o <= 0;
        end else begin
            response_valid_o <= 0;
            case (state)
                IDLE: if (start_i) begin
                    success <= 0;
                    digest <= 0;
                    response_code_o <= 0;
                    // Reject requests outside the supported path before touching SHA.
                    // No key handle lookup or authorization is needed for this case.
                    if (command_tag_i != 16'h8001 && command_tag_i != 16'h8002) begin
                        response_code_o <= RC_BAD_TAG;
                        state <= RESPOND;
                    end else if (command_code_i != 32'h0000017d) begin
                        response_code_o <= RC_COMMAND_CODE;
                        state <= RESPOND;
                    end else if (command_size_i < 18 || command_size_i > 1042) begin
                        response_code_o <= RC_COMMAND_SIZE;
                        state <= RESPOND;
                    end else if (!operational_i) begin
                        response_code_o <= RC_INITIALIZE;
                        state <= RESPOND;
                    end else if (command_tag_i != 16'h8001) begin
                        response_code_o <= RC_FAILURE;
                        state <= RESPOND;
                    end else begin
                        command_addr_o <= 12'd10;
                        field_index <= 0;
                        field_bytes <= 0;
                        state <= READ_WAIT;
                    end
                end
                // The CRB packet RAM returns data one clock after the address.
                // Hash layout after the header: 2-byte size, data, 2-byte
                // hash algorithm, and 4-byte hierarchy selector.
                READ_WAIT: state <= READ_FIELD;
                READ_FIELD: begin
                    field_bytes <= next_field;
                    field_index <= field_index + 1'b1;
                    command_addr_o <= command_addr_o + 1'b1;
                    state <= READ_WAIT;
                    case (field_index)
                        // Check the total size before jumping over the data to
                        // validate the algorithm and hierarchy fields.
                        3'd1: begin
                            data_length <= next_field[15:0];
                            if (next_field[15:0] > 1024 ||
                                ({16'd0,next_field[15:0]} + 32'd18) != command_size_i) begin
                                response_code_o <= RC_SIZE_DATA;
                                state <= RESPOND;
                            end else command_addr_o <= 12'd12 + next_field[11:0];
                        end
                        3'd3: if (next_field[15:0] != 16'h000b) begin
                            response_code_o <= RC_HASH_ALG;
                            state <= RESPOND;
                        end
                        3'd7: if (next_field != 32'h40000007) begin
                            response_code_o <= RC_VALUE_HIERARCHY;
                            state <= RESPOND;
                        end else begin
                            remaining <= data_length[11:0];
                            // Return to the first payload byte. Only message
                            // bytes go to SHA, excluding all framing fields.
                            command_addr_o <= 12'd12;
                            state <= REQUEST;
                        end
                        default: begin end
                    endcase
                end
                REQUEST: if (hash_grant_i) state <= DATA_WAIT;
                DATA_WAIT: state <= SEND;
                // The read address stays put during SHA backpressure, so the
                // byte and end flag stay stable until accepted.
                SEND: if (hash_ready_i) begin
                    if (remaining <= 1) state <= DIGEST;
                    else begin
                        remaining <= remaining - 1'b1;
                        command_addr_o <= command_addr_o + 1'b1;
                        state <= DATA_WAIT;
                    end
                end
                // A real SHA digest completes a successful command. Latch it
                // before telling the CRB it can begin returning response bytes.
                DIGEST: if (hash_digest_valid_i) begin
                    digest <= hash_digest_i;
                    success <= 1;
                    state <= RESPOND;
                end
                RESPOND: begin
                    response_valid_o <= 1;
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule

// EncryptDecrypt2 execution after packet decoding. The object service returns
// a resolved key only on success, or a TPM error for lookup/authorization.
// The board host path does not instantiate this handler until that service exists.
module execution_engine_encryptdecrypt2 #(
    parameter RAM_ADDR_WIDTH=12
) (
    input wire clock_i, reset_n_i, start_i,
    input wire [31:0] key_handle_i, data_length_i,
    input wire [RAM_ADDR_WIDTH-1:0] input_base_i, output_base_i,
    input wire [127:0] iv_i,
    input wire decrypt_i,
    input wire [2:0] mode_i,
    output wire key_request_o,
    input wire key_request_ready_i,
    output reg [31:0] key_handle_o,
    input wire key_reply_valid_i,
    output wire key_reply_ready_o,
    input wire [255:0] resolved_key_i,
    input wire [31:0] key_reply_code_i,

    output wire aes_start_o,
    output reg [255:0] aes_key_o,
    output reg [127:0] aes_iv_o,
    output reg aes_decrypt_o,
    output reg [2:0] aes_mode_o,
    output reg [RAM_ADDR_WIDTH-1:0] aes_input_base_o, aes_output_base_o,
    output reg [31:0] aes_length_o,
    input wire aes_busy_i, aes_done_i,
    input wire [11:0] aes_rc_i,
    input wire [127:0] aes_final_iv_i,
    input wire [31:0] aes_completed_length_i,

    output wire busy_o,
    output reg done_o,
    output reg [31:0] response_code_o, response_length_o,
    output reg [127:0] response_iv_o
);
    localparam [2:0] IDLE=0, LOOKUP=1, KEY_REPLY=2, LAUNCH=3,
        AES_WAIT=4, COMPLETE=5, RELEASE=6;
    reg [2:0] state;

    assign busy_o = reset_n_i && state != IDLE;
    assign key_request_o = reset_n_i && state == LOOKUP;
    assign key_reply_ready_o = reset_n_i && state == KEY_REPLY;
    assign aes_start_o = reset_n_i && state == LAUNCH && !aes_busy_i;

    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            state <= IDLE;
            key_handle_o <= 0;
            aes_key_o <= 0;
            aes_iv_o <= 0;
            aes_decrypt_o <= 0;
            aes_mode_o <= 0;
            aes_input_base_o <= 0;
            aes_output_base_o <= 0;
            aes_length_o <= 0;
            done_o <= 0;
            response_code_o <= 0;
            response_length_o <= 0;
            response_iv_o <= 0;
        end else begin
            done_o <= 0;
            case (state)
                IDLE: if (start_i) begin
                    key_handle_o <= key_handle_i;
                    aes_iv_o <= iv_i;
                    aes_decrypt_o <= decrypt_i;
                    aes_mode_o <= mode_i;
                    aes_input_base_o <= input_base_i;
                    aes_output_base_o <= output_base_i;
                    aes_length_o <= data_length_i;
                    response_code_o <= 0;
                    response_length_o <= 0;
                    response_iv_o <= 0;
                    state <= LOOKUP;
                end
                LOOKUP: if (key_request_ready_i) state <= KEY_REPLY;
                KEY_REPLY: if (key_reply_valid_i) begin
                    if (key_reply_code_i != 0) begin
                        response_code_o <= key_reply_code_i;
                        state <= COMPLETE;
                    end else begin
                        aes_key_o <= resolved_key_i;
                        state <= LAUNCH;
                    end
                end
                LAUNCH: if (aes_start_o) begin
                    // The symmetric controller captures the key on this edge.
                    aes_key_o <= 0;
                    state <= AES_WAIT;
                end
                AES_WAIT: if (aes_done_i) begin
                    response_code_o <= {20'd0,aes_rc_i};
                    if (aes_rc_i == 0) begin
                        response_length_o <= aes_completed_length_i;
                        response_iv_o <= aes_final_iv_i;
                    end
                    state <= COMPLETE;
                end
                COMPLETE: begin
                    done_o <= 1;
                    state <= RELEASE;
                end
                RELEASE: if (!start_i && !aes_busy_i) state <= IDLE;
                default: state <= IDLE;
            endcase
        end
    end
endmodule

// Scoped EncryptDecrypt2 packet path. Accepts AES-256 CFB and one empty
// password authorization record. Permission comes from the object service.
// The packet scratch buffer is reused in place and contains no key objects.
module execution_engine_aes_packet #(
    parameter ENABLE_DEMO_LIFECYCLE=0
)(
    // Demo build retains response until final FIFO copy and sweeps all scratch.
    input wire response_consumed_i,
    output wire busy_o, scrub_done_o, recovery_required_o,
    input wire clock_i, reset_n_i, start_i, operational_i,
    input wire [15:0] command_tag_i,
    input wire [31:0] command_size_i,
    output reg [11:0] command_addr_o,
    input wire [7:0] command_byte_i,
    output reg response_valid_o,
    output reg [31:0] response_code_o,
    output wire [11:0] response_length_o,
    input wire [11:0] response_addr_i,
    output reg [7:0] response_byte_o,
    output wire key_request_o,
    input wire key_request_ready_i,
    output wire [31:0] key_handle_o,
    input wire key_reply_valid_i,
    output wire key_reply_ready_o,
    input wire [255:0] resolved_key_i,
    input wire [31:0] key_reply_code_i
);
    localparam [3:0] IDLE=0, READ_WAIT=1, READ_BYTE=2, LAUNCH=3,
        WAIT_RESULT=4, REPLY=5, SCRUB=6, SECRET_CLEAR_WAIT=7, HOLD_REPLY=8,
        WORKER_RELEASE=9;
    reg [3:0] state;
    reg [9:0] scrub_index;
    reg [1:0] release_count;
    reg scrub_for_reply, error_scrubbed, worker_reset_n;
    reg [31:0] saved_job_length;
    reg [127:0] saved_job_iv;
    wire local_reset_n = ENABLE_DEMO_LIFECYCLE ? worker_reset_n : reset_n_i;
    assign busy_o = reset_n_i && state != IDLE;
    assign scrub_done_o = reset_n_i && state == IDLE;
    assign recovery_required_o = 1'b0; // Global supervisor owns stalls/abort recovery.
    reg [31:0] handle;
    reg [15:0] data_length;
    reg [127:0] iv;
    reg decrypt, success;
    reg [71:0] field;
    reg [7:0] payload [0:1023];
    wire [71:0] next_field = {field[63:0],command_byte_i};
    wire [11:0] data_end = 12'd29 + data_length[11:0];
    wire [11:0] trailer_offset = command_addr_o - data_end;

    wire aes_start, aes_busy, aes_done, decrypt_job, job_done;
    wire [255:0] aes_key;
    wire [127:0] aes_iv, aes_final_iv, job_iv;
    wire [2:0] aes_mode;
    wire [9:0] aes_in_base, aes_out_base, ram_addr;
    wire [31:0] aes_length, aes_completed, job_rc, job_length;
    wire [31:0] public_job_length = ENABLE_DEMO_LIFECYCLE ? saved_job_length : job_length;
    wire [127:0] public_job_iv = ENABLE_DEMO_LIFECYCLE ? saved_job_iv : job_iv;

    wire [11:0] aes_rc;
    wire ram_req_valid, ram_req_write, ram_rsp_ready;
    wire [7:0] ram_write_data;
    reg ram_rsp_valid;
    reg [7:0] ram_read_data;
    wire [11:0] reply_data_end = 12'd6 + public_job_length[11:0];
    wire [15:0] parameter_size = public_job_length[15:0] + 16'd20;
    wire [11:0] reply_iv_byte = response_addr_i - reply_data_end - 12'd2;

    // Successful session-tagged response: parameterSize, outData, ivOut,
    // and a password acknowledgment (empty nonce, continueSession, empty HMAC).
    assign response_length_o = success ? 12'd39 + public_job_length[11:0] : 12'd10;
    always @* begin
        response_byte_o = 0;
        case (response_addr_i)
            12'd2: response_byte_o = parameter_size[15:8];
            12'd3: response_byte_o = parameter_size[7:0];
            12'd4: response_byte_o = public_job_length[15:8];
            12'd5: response_byte_o = public_job_length[7:0];
            default: begin
                if (response_addr_i >= 6 && response_addr_i < reply_data_end)
                    response_byte_o = payload[response_addr_i-6];
                else if (response_addr_i == reply_data_end + 1)
                    response_byte_o = 8'd16;
                else if (reply_iv_byte < 16)
                    response_byte_o = public_job_iv[127-reply_iv_byte*8 -: 8];
                else if (response_addr_i == reply_data_end + 20)
                    response_byte_o = 8'd1;
            end
        endcase
    end

    always @(posedge clock_i) begin
        if (ENABLE_DEMO_LIFECYCLE && reset_n_i && state == SCRUB)
            payload[scrub_index] <= 0;
        else if (reset_n_i && state == READ_BYTE && command_addr_o >= 29 && command_addr_o < data_end)
            payload[command_addr_o-29] <= command_byte_i;
        else if (reset_n_i && ram_req_valid && !ram_rsp_valid && ram_req_write)
            payload[ram_addr] <= ram_write_data;
        if (!reset_n_i || (ENABLE_DEMO_LIFECYCLE && state == SCRUB)) ram_read_data <= 0;
        else if (ram_req_valid && !ram_rsp_valid && !ram_req_write)
            ram_read_data <= payload[ram_addr];
    end

    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            state <= ENABLE_DEMO_LIFECYCLE ? SCRUB : IDLE;
            scrub_index <= 0; release_count <= 0; scrub_for_reply <= 0;
            error_scrubbed <= 0; worker_reset_n <= 0;
            saved_job_length <= 0; saved_job_iv <= 0;
            command_addr_o <= 0;
            response_valid_o <= 0;
            response_code_o <= 0;
            ram_rsp_valid <= 0;
            field <= 0;
            handle <= 0;
            data_length <= 0;
            iv <= 0;
            decrypt <= 0;
            success <= 0;
        end else begin
            response_valid_o <= 0;
            if (ram_rsp_ready) ram_rsp_valid <= 0;
            if (ram_req_valid && !ram_rsp_valid) ram_rsp_valid <= 1;
            case (state)
                IDLE: if (start_i) begin
                    error_scrubbed <= 0; scrub_for_reply <= 0;
                    saved_job_length <= 0; saved_job_iv <= 0;
                    success <= 0;
                    response_code_o <= 0;
                    command_addr_o <= 12'd10;
                    data_length <= 0;
                    field <= 0;
                    iv <= 0;
                    state <= REPLY;
                    if (command_tag_i != 16'h8001 && command_tag_i != 16'h8002)
                        response_code_o <= 32'h01e;
                    else if (!operational_i)
                        response_code_o <= 32'h100;
                    else if (command_tag_i != 16'h8002)
                        response_code_o <= 32'h125;
                    else if (command_size_i < 50 || command_size_i > 1074)
                        response_code_o <= 32'h142;
                    else state <= READ_WAIT;
                end
                READ_WAIT: state <= READ_BYTE;
                READ_BYTE: begin
                    field <= next_field;
                    command_addr_o <= command_addr_o + 1'b1;
                    state <= READ_WAIT;
                    case (command_addr_o)
                        12'd13: handle <= next_field[31:0];
                        12'd17: if (next_field[31:0] != 9) begin
                            response_code_o <= 32'h144;
                            state <= REPLY;
                        end
                        // Only a single TPM_RS_PW record with empty nonce and
                        // password is supported. Ignore its continueSession bit.
                        12'd26: if ((next_field & 72'hfffffffffffffeffff) != 72'h400000090000000000) begin
                            response_code_o <= 32'h101;
                            state <= REPLY;
                        end
                        12'd28: begin
                            data_length <= next_field[15:0];
                            if (next_field[15:0] > 1024 ||
                                {16'd0,next_field[15:0]} + 32'd50 != command_size_i) begin
                                response_code_o <= 32'h1d5;
                                state <= REPLY;
                            end
                        end
                        default: if (command_addr_o >= data_end) begin
                            case (trailer_offset)
                                12'd0: begin
                                    decrypt <= command_byte_i[0];
                                    if (command_byte_i > 1) begin
                                        response_code_o <= 32'h2c4;
                                        state <= REPLY;
                                    end
                                end
                                12'd2: if (next_field[15:0] != 16'h0043) begin
                                    response_code_o <= 32'h3c9;
                                    state <= REPLY;
                                end
                                12'd4: if (next_field[15:0] != 16'd16) begin
                                    response_code_o <= 32'h4d5;
                                    state <= REPLY;
                                end
                                default: if (trailer_offset >= 5) begin
                                    iv <= {iv[119:0],command_byte_i};
                                    if (trailer_offset == 20) state <= LAUNCH;
                                end
                            endcase
                        end
                    endcase
                end
                LAUNCH: state <= WAIT_RESULT;
                WAIT_RESULT: if (job_done) begin
                    response_code_o <= job_rc;
                    success <= job_rc == 0;
                    saved_job_length <= job_rc == 0 ? job_length : 0;
                    saved_job_iv <= job_rc == 0 ? job_iv : 0;
                    if (ENABLE_DEMO_LIFECYCLE) begin
                        worker_reset_n <= 0; release_count <= 0; state <= SECRET_CLEAR_WAIT;
                    end else state <= REPLY;
                end
                REPLY: begin
                    if (ENABLE_DEMO_LIFECYCLE && !success && !error_scrubbed) begin
                        worker_reset_n <= 0; scrub_index <= 0;
                        scrub_for_reply <= 1; state <= SCRUB;
                    end else begin
                        response_valid_o <= 1;
                        state <= ENABLE_DEMO_LIFECYCLE ? HOLD_REPLY : IDLE;
                    end
                end
                SECRET_CLEAR_WAIT: if (release_count == 2) state <= REPLY;
                    else release_count <= release_count + 1'b1;
                HOLD_REPLY: if (response_consumed_i) begin
                    scrub_index <= 0; scrub_for_reply <= 0;
                    saved_job_iv <= 0; saved_job_length <= 0;
                    field <= 0; iv <= 0; data_length <= 0; handle <= 0;
                    worker_reset_n <= 0; state <= SCRUB;
                end
                SCRUB: if (scrub_index == 1023) begin
                    scrub_index <= 0;
                    if (scrub_for_reply) begin error_scrubbed <= 1; state <= REPLY; end
                    else begin
                        worker_reset_n <= 1; release_count <= 0; state <= WORKER_RELEASE;
                    end
                end else scrub_index <= scrub_index + 1'b1;
                WORKER_RELEASE: if (release_count == 2) state <= IDLE;
                    else release_count <= release_count + 1'b1;
                default: state <= IDLE;
            endcase
        end
    end

    execution_engine_encryptdecrypt2 #(.RAM_ADDR_WIDTH(10)) job (
        .clock_i(clock_i), .reset_n_i(local_reset_n), .start_i(state == LAUNCH),
        .key_handle_i(handle), .data_length_i({16'd0,data_length}),
        .input_base_i(10'd0), .output_base_i(10'd0), .iv_i(iv),
        .decrypt_i(decrypt), .mode_i(3'd1), .key_request_o(key_request_o),
        .key_request_ready_i(key_request_ready_i), .key_handle_o(key_handle_o),
        .key_reply_valid_i(key_reply_valid_i), .key_reply_ready_o(key_reply_ready_o),
        .resolved_key_i(resolved_key_i), .key_reply_code_i(key_reply_code_i),
        .aes_start_o(aes_start), .aes_key_o(aes_key), .aes_iv_o(aes_iv),
        .aes_decrypt_o(decrypt_job), .aes_mode_o(aes_mode), .aes_input_base_o(aes_in_base),
        .aes_output_base_o(aes_out_base), .aes_length_o(aes_length),
        .aes_busy_i(aes_busy), .aes_done_i(aes_done), .aes_rc_i(aes_rc),
        .aes_final_iv_i(aes_final_iv), .aes_completed_length_i(aes_completed),
        .busy_o(), .done_o(job_done), .response_code_o(job_rc),
        .response_length_o(job_length), .response_iv_o(job_iv)
    );

    symm_top #(.RAM_ADDR_WIDTH(10), .MAX_SECRET_BYTES(32), .MAX_NONCE_BYTES(32)) aes (
        .clock_i(clock_i), .reset_n_i(local_reset_n), .start_i(aes_start),
        .command_code_i(16'h0193), .key_valid_i(1'b1), .session_protect_i(1'b0),
        .session_valid_i(1'b0), .session_decrypt_i(1'b0), .session_encrypt_i(1'b0),
        .session_use_xor_i(1'b0), .mode_i(aes_mode),
        .session_value_i(256'd0), .session_value_bytes_i(16'd0),
        .nonce_newer_i(256'd0), .nonce_older_i(256'd0),
        .nonce_newer_bytes_i(16'd0), .nonce_older_bytes_i(16'd0),
        .hmac_start_o(), .hmac_key_data_o(), .hmac_message_data_o(),
        .hmac_key_valid_o(), .hmac_key_end_o(), .hmac_key_ready_i(1'b0),
        .hmac_message_valid_o(), .hmac_message_end_o(), .hmac_message_ready_i(1'b0),
        .hmac_busy_i(1'b0), .hmac_digest_i(256'd0), .hmac_digest_valid_i(1'b0),
        .hmac_digest_ready_o(),
        .key_i(aes_key), .iv_i(aes_iv), .decrypt_i(decrypt_job),
        .input_base_i(aes_in_base), .output_base_i(aes_out_base),
        .data_length_i(aes_length), .busy_o(aes_busy), .done_o(aes_done),
        .error_o(), .tpm_rc_o(aes_rc), .final_iv_o(aes_final_iv),
        .completed_length_o(aes_completed),
        .ram_req_valid_o(ram_req_valid), .ram_req_ready_i(!ram_rsp_valid),
        .ram_req_write_o(ram_req_write), .ram_req_addr_o(ram_addr),
        .ram_req_data_o(ram_write_data), .ram_rsp_valid_i(ram_rsp_valid),
        .ram_rsp_ready_o(ram_rsp_ready), .ram_rsp_data_i(ram_read_data),
        .ram_rsp_error_i(1'b0)
    );
endmodule
