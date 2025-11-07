module execution_engine(
		clock,
		reset_n,
		command_ready,
		command_tag,
		command_size,
		command_code,
		command_length,
		//command buffer inputs
		handle_0,
		handle_1,
		handle_2,
		session0_handle,
		session1_handle,
		session2_handle,
		session0_attributes,
		session1_attributes,
		session2_attributes,
		session0_hmac_size,
		session1_hmac_size,
		session2_hmac_size,
		session0_valid,
		session1_valid,
		session2_valid,
		authorization_size,
		session_loaded,
		max_session_amount,
		auth_session,
		auth_necessary,
		authHandle,
		pcrSelect,
		// Authorization submodule inputs
		auth_done,
		auth_success,
		auth_response_code,
		//inputs from param decrypt submodule
		param_decrypt_success,
		param_decrypt_fail,
		param_unmarshall_success,
		param_unmarshall_fail,
		//execution engine inputs
		execution_startup_done,
		execution_response_code,
		// NV memory submodule inputs
		nv_phEnableNV_in,
		nv_shEnable_in,
		nv_ehEnable_in,
		tpm_nv_index,
		nv_index_attributes,
		nv_object_present,
		nv_index_present,
		entity_hierarchy,
		// Memory submodule inputs
		mem_orderly,
		ram_available,
		loaded_object_present,
		object_attributes,
		// Self-test submodule inputs
		st_testsRun,
		st_testsPassed,
		st_untested,
		// Management module inputs 
		op_state,
		startup_type,
		phEnable,
		phEnableNV,
		shEnable,
		ehEnable,
		shutdownSave,
		command_done,
		//management outputs
		testsPassed,
		untested,
		nv_phEnableNV,
		nv_shEnable,
		nv_ehEnable,
		orderlyInput,
		initialized,
		testsRun,
		authHierarchy,
		// Response outputs
		response_valid,
		response_code,
		response_length,
		current_state,
		command_start
	);

	// Inputs
	input         clock;					// Input clock signal
	input         reset_n;				// Active-low input reset signal
	input         command_ready;	// Active-high input command valid signal perhaps we can create a combinational logic check for this in a separate module
	input  [15:0] command_tag;
	input	 [31:0] command_size;
	input  [31:0] command_code;
	input  [15:0] command_length;		// 16-bit input command length
	
	input [31:0] handle_0;
	input [31:0] handle_1;
	input [31:0] handle_2;	
	// Inputs from managemnt module - EXACT MATCH to management_module outputs
	input  [2:0]  op_state;				// 3-bit input operational state from management module
	input  [2:0]  startup_type;		// 3-bit input startup type from management module
	input         phEnable;				// 1-bit input platform hierarchy enable from management module
	input         phEnableNV;			// 1-bit input platform hierarchy NV memory enable from management module
	input         shEnable;				// 1-bit input owner hierarchy enable from management module
	input         ehEnable;				// 1-bit input endorsement hierarchy enable from management module
	input  [15:0] shutdownSave;		// 16-bit input shutdown type from management module
	//Inputs from command processing
	input 		  command_done;
	//inputs for session validation
	input [31:0] session0_handle;
	input [31:0] session1_handle;
	input [31:0] session2_handle;


	input [7:0] session0_attributes;
	input [7:0] session1_attributes;
	input [7:0] session2_attributes;


	input [15:0] session0_hmac_size;
	input [15:0] session1_hmac_size;
	input [15:0] session2_hmac_size;


	input session0_valid;
	input session1_valid;
	input session2_valid;
	input [31:0] authorization_size;
	input	session_loaded;
	input [15:0] max_session_amount;
	input auth_session;
	input auth_necessary;
	
	input [31:0] authHandle;			// 32-bit input signal from command buffer indicating authorization control domain requested by command

	input [7:0] pcrSelect;
	
	// Authorization inputs for authorization checks
	input auth_done;			// 1-bit input signal from authorization submodule indicating completion of authorization checks
	input auth_success;			// 1-bit input signal from authorization submodule indicating successful authorization
	input [11:0] auth_response_code;
	
	input param_decrypt_success;
	input param_decrypt_fail;
	input param_unmarshall_success;
	input param_unmarshall_fail;
	//startup error signal
	input execution_startup_done;
	//execution response code
	input execution_response_code;
	
	// NV memory submodule inputs
	input nv_phEnableNV_in;
	input nv_shEnable_in;
	input nv_ehEnable_in;
	input [31:0] tpm_nv_index;
	input [31:0] nv_index_attributes;
	input nv_object_present;
	input nv_index_present;
	input [31:0] entity_hierarchy;
	
	// Memory submodule inputs
	input [15:0] mem_orderly;
	input ram_available;
	input loaded_object_present;
	input [31:0] object_attributes;
	
	// Self-test submodule inputs
	input [15:0] st_testsRun;
	input [15:0] st_testsPassed;
	input [15:0] st_untested;
	
	// Outputs
	output        response_valid;		// 1-bit output response valid signal
	output [31:0] response_code;		// 32-bit output response code
	output [15:0] response_length;		// 16-bit output response length
	output [3:0]  current_state;		// 4-bit output current pipeline stage
   output reg    command_start;
	   
	//////////////////////////////////////////////////////////////////////////////////////////////////////////
	output	 [15:0] orderlyInput;		// 2-byte (16 bits) input from memory of state of last shutdown state
	output reg	     initialized;			// 1-bit input intialized bit (from execution engine)
	output	 [15:0] testsRun;				// 2-byte (16 bits) input of amount of tests run by the self-test module, from the execution engine
	output	 [15:0] testsPassed;			// 2-byte (16 bits) input of amount of tests that have run and passed by the self-test module, from the execution engine
	output	 [15:0] untested;				// 2-byte (16 bits) input of amount of tests that still need to be run by the self-test module, from the execution engine
	output 		     nv_phEnableNV;		// 1-bit input of state of phEnableNV switch, from Non-Volatile memory
	output	        nv_shEnable;			// 1-bit input of state of shEnable switch, from Non-Volatile memory
	output           nv_ehEnable;			// 1-bit input of state of ehEnable switch, from Non-Volatile memory
	// Outputs to management module - EXACT MATCH to management_module inputs
	output	 [31:0] authHierarchy;		// 2-byte (16 bits) input verifying which hiearchy was authorized (from execution engine)
	
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
	reg 		  response_valid;
	reg [11:0] s_response_code;
	reg [15:0] response_length;
	reg [3:0]  current_state;
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
	reg [31:0] authHierarchy;
	reg		  audit;
	reg		  decrypt;
	reg		  encrypt;
	reg		  auditReset;
	reg		  auditExclusive;
	reg		  continueSession;
	reg [1:0]  audit_count;
	reg [1:0]  decrypt_count;
	reg [1:0]  encrypt_count;
	
	reg [31:0] response_code;
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
   		(handle_index == 3'b000) ? handle_0 :
                (handle_index == 3'b001) ? handle_1 :
                                           handle_2;

	assign handle_type       = current_handle[31:24];
	assign handle_index_bits = current_handle[23:0];
	assign current_session_handle =
    (session_index == 2'd0) ? session0_handle :
    (session_index == 2'd1) ? session1_handle :
                              session2_handle;

	assign current_session_attributes =
    (session_index == 2'd0) ? session0_attributes :
    (session_index == 2'd1) ? session1_attributes :
                              session2_attributes;

	assign current_session_hmac_size =
    (session_index == 2'd0) ? session0_hmac_size :
    (session_index == 2'd1) ? session1_hmac_size :
                              session2_hmac_size;

	assign current_session_valid =
		(session_index == 2'd0) ? session0_valid :
		(session_index == 2'd1) ? session1_valid :
											session2_valid;
	assign session_handle_type = current_session_handle[31:24];
	// ============================================================================
	// SEQUENTIAL LOGIC BLOCK - STATE TRANSITIONS ONLY
	// ============================================================================
		always@(posedge clock, negedge reset_n) begin
			if(!reset_n) begin
				current_state <= STATE_IDLE;
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
				initialized <= 1'b0;
				response_code <= 32'd0;
			end
			else begin
				response_code <= {20'h0, s_response_code};
				current_state <= state;
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
				initialized <= s_initialized;

			end
		end
		
		assign orderlyInput = mem_orderly;
		assign testsRun = st_testsRun;
		assign testsPassed = st_testsPassed;
		assign untested	 = st_untested;
		assign nv_phEnableNV = nv_phEnableNV_in;
		assign nv_shEnable = nv_shEnable_in;
		assign nv_ehEnable = nv_ehEnable_in;
		
		assign nv_tag = tpm_nv_index[31:24];
		assign nv_index = tpm_nv_index[23:0];

		// Object Attributes
		// object_attributes bits[31:20] reserved
		assign x509sign = object_attributes[19];
		assign sign = object_attributes[18];
		assign object_encrypt = object_attributes[18];
		assign object_decrypt = object_attributes[17];
		assign restricted = object_attributes[16];
		// object_attributes bits[15:12] reserved
		assign encryptedDuplication = object_attributes[11];
		assign noDA = object_attributes[10];
		// object_attributes bits[9:8] reserved
		assign adminWithPolicy = object_attributes[7];
		assign userWithAuth = object_attributes[6];
		assign sensitiveDataOrigin = object_attributes[5];
		assign fixedParent = object_attributes[4];
		assign stClear = object_attributes[2];
		assign fixedTPM = object_attributes[1];
		// object_attributes bit[0] reserved
		
		// Non-Volatile Index Attributes
		// Reference: TCG TPM2.0 Specification Rev. 1.59, Part 2: Structures, Section 13.4 TPMA_NV (NV Index Attributes)
		assign tpma_nv_read_stClear = nv_index_attributes[31];
		assign tpma_nv_platformCreate = nv_index_attributes[30];
		assign tpma_nv_written = nv_index_attributes[29];
		assign tpma_nv_readLocked = nv_index_attributes[28];
		assign tpma_nv_clear_stClear = nv_index_attributes[27];
		assign tpma_nv_orderly = nv_index_attributes[26];
		assign tpma_nv_no_DA = nv_index_attributes[25];
		// nv_index_attributes bits[24:20] reserved for future use
		assign tpma_nv_policyRead = nv_index_attributes[19];
		assign tpma_nv_authRead = nv_index_attributes[18];
		assign tpma_nv_ownerRead = nv_index_attributes[17];
		assign tpma_nv_ppRead = nv_index_attributes[16];
		assign tpma_nv_globalLock = nv_index_attributes[15];
		assign tpma_nv_write_stClear = nv_index_attributes[14];
		assign tpma_nv_writeDefine = nv_index_attributes[13];
		assign tpma_nv_writeAll = nv_index_attributes[12];
		assign tpma_nv_writeLocked = nv_index_attributes[11];
		assign tpma_nv_policy_delete = nv_index_attributes[10];
		// nv_index_attributes bits[9:8] reserved for future use
		assign tpm_nt = nv_index_attributes[7:4];
		assign tpma_nv_policyWrite = nv_index_attributes[3];
		assign tpma_nv_authWrite = nv_index_attributes[2];
		assign tpma_nv_ownerWrite = nv_index_attributes[1];
		assign tpma_nv_ppWrite = nv_index_attributes[0];
	assign nv_write = (commandIndex == TPM_CC_NV_DEFINE_SPACE ||
								 commandIndex == TPM_CC_NV_WRITE ||
								 commandIndex == TPM_CC_NV_INCREMENT ||
								 commandIndex == TPM_CC_NV_EXTEND);
								 
		// Signal indicating that command
	assign nv_read = (commandIndex == TPM_CC_NV_DEFINE_SPACE || commandIndex == TPM_CC_NV_READ);
					
		// Reference: TCG TPM2.0 Specification Rev. 1.59, Part 2: Structures, Section 8.9.2 TPMA_CC (Command Code Attributes): Structure Definition
		assign commandIndex = command_code[15:0];			// Indicates the command being selected
		
		assign nv = command_code[22];							// SET(1): indicates that the command may write to NV
																		// CLEAR(0): indicates that the command does not write to NV
																		
		assign extensive = command_code[23];				// SET(1): This command could flush any number of loaded contexts
																		// CLEAR(0): no additional changes other than indicated by the flushed attribute
																		
		assign flushed = command_code[24];					// SET(1): The context associated with any transient handle in the command will be flushed when this command completes.
																		// CLEAR(0): No context is flushed as a side effect of this command.
																		
		assign cHandles = command_code[27:25];				// indicates the number of the handles in the handle area for this command
		
		assign rHandle = command_code[28];					// SET(1): indicates the presence of the handle area in the response
		
		assign v = command_code[29];							// SET(1): indicates that the command is vendor-specific
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
			if(command_tag == TPM_ST_SESSIONS) begin
			// Map flattened inputs into a common structure for session processing.
				if (session_index == 2'd0) begin
					s_current_session_handle     = session0_handle;
					s_current_session_attributes = session0_attributes;
					s_current_session_hmac_size  = session0_hmac_size;
					s_current_session_valid      = session0_valid;
				end
				else if (session_index == 2'd1) begin
					s_current_session_handle     = session1_handle;
					s_current_session_attributes = session1_attributes;
					s_current_session_hmac_size  = session1_hmac_size;
					s_current_session_valid      = session1_valid;
				end
				else begin
					s_current_session_handle     = session2_handle;
					s_current_session_attributes = session2_attributes;
					s_current_session_hmac_size  = session2_hmac_size;
					s_current_session_valid      = session2_valid;
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
			s_session_index = 3'b000;
			case(current_state)
				// ====================================================================
				// STAGE 1: IDLE - Wait for command
				// ====================================================================
				STATE_IDLE: begin
					s_session_error = 1'b0;
					s_audit_count = 2'b0;
					s_decrypt_count = 2'b0;
					s_encrypt_count = 2'b0;
					if(command_ready) begin
						state = STATE_HEADER_VALID;
					end
				end

				// ====================================================================
				// STAGE 2: HEADER VALIDATION - TPM 2.0 Part 3, Section 5.2
				// ====================================================================
				STATE_HEADER_VALID: begin
					if((command_tag != TPM_ST_NO_SESSIONS && command_tag != TPM_ST_SESSIONS) || 
						 command_size != command_length ||
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
					if(op_state == FAILURE_MODE_STATE) begin
						// In Failure mode, only TPM2_GetTestResult or TPM2_GetCapability allowed with no sessions
						if(commandIndex != TPM_CC_GET_TEST_RESULT || commandIndex != TPM_CC_GET_CAPABILITY || command_tag != TPM_ST_NO_SESSIONS) begin
							state = STATE_POST_PROCESS;
						end
						else begin
							state = STATE_HANDLE_VALID;
						end
					end
					else if(op_state == OPERATIONAL_STATE)begin
							state = STATE_HANDLE_VALID;
					end
					else begin
						// TPM not initialized - first command must be TPM2_Startup
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
					
					if((command_tag == TPM_ST_NO_SESSIONS && command_code_tag == TPM_ST_SESSIONS) || (command_tag == TPM_ST_SESSIONS && command_code_tag == TPM_ST_NO_SESSIONS)) begin
						s_session_error = 1'b1;
					end
					else if(command_tag == TPM_ST_SESSIONS && command_code_tag == TPM_ST_SESSIONS) begin
						// Step 1: Validate the session handle's type.
						// The top 8 bits of the handle indicate its type.
						// Valid session types include HMAC (0x01), Policy (0x02), and Password (0x03).
						if(session_handle_type != 8'h01 && session_handle_type != 8'h02 && session_handle_type != 8'h03) begin
							s_session_error = 1'b1;
						end

						// Step 2: Ensure each role (audit/decrypt/encrypt) is only used once.
						// Bits 7, 6, and 5 in the session attributes represent audit, decrypt,
						// and encrypt flags respectively. Multiple sessions cannot share roles.

						if (audit) begin // Audit bit
							s_audit_count = audit_count + 1'b1;
							if (audit_count > 2'd1) s_session_error = 1'b1;
						end

						if (decrypt) begin // Decrypt bit
							s_decrypt_count = decrypt_count + 1'b1;
							if (decrypt_count > 2'd1) s_session_error = 1'b1;
						end

						if (encrypt) begin // Encrypt bit
							s_encrypt_count = encrypt_count + 1'b1;
							if (encrypt_count > 2'd1) s_session_error = 1'b1;
						end
		
						// Step 3: Validate that empty sessions (no HMAC) are used only if
						// they are performing other roles (audit/decrypt/encrypt).
						if (current_session_hmac_size == 16'b0 && (!audit || !decrypt || !encrypt)) begin
							s_session_error = 1'b1; // An empty session must be doing something
						end
						
						if(max_session_amount == session_index && authorization_size > 32'd0) s_session_error = 1'b1;
						
						if(!session_loaded) s_session_error = 1'b1;
						
						if(!auth_session && auth_necessary) s_session_error = 1'b1;
					end 
					else if(!session_error &&  session_index < 2'd3 && current_session_valid) begin
							s_session_index = session_index + 1'b1;
					end
					else begin
						// Final step after checking all sessions
						// If we validated more than 3, that's an error
						if (session_index > 2'd3)begin
							s_session_error = 1'b1;
							s_session_index = 3'b000;
						end
						// If all sessions are valid, move to the next FSM stage
						if (!session_error) begin
							s_session_index = 3'b000;
							state = STATE_AUTH_CHECK;
						end else begin
							// If we encountered any error, prepare a failure response
							s_session_index = 3'b000;
							state = STATE_POST_PROCESS;
						end
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
					// 1. Execute command-specific logic based on command_code
					// 2. For TPM_CC_STARTUP: Set initialized state
					// 3. For TPM_CC_GET_TEST_RESULT: Return self-test results
					// 4. For cryptographic commands: Perform operations via crypto engine
					// 5. Update TPM state (objects, NV, PCRs, sessions) as required
					// 6. Handle multi-cycle operations with proper state management
					// 7. Return TPM_RC_FAILURE on execution errors
					
					// For now, always proceed to post-processing
					if(command_done) begin
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
					// 5. Calculate final response_length
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
		s_execution_startup_done = execution_startup_done;
		s_initialized = initialized;
		
		// Default output values
		response_valid =   1'b0;
		s_response_code = response_code[11:0];
		response_length = 16'h0;
		command_start   = 1'b0;
		session_present = 1'b0;
		authHierarchy = 32'h00000000;

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
		                	if(!loaded_object_present) begin
					        s_handle_error = 1'b1;
						s_response_code = TPM_RC_REFERENCE_H0 + handle_index;
					end
				end
				else if(handle_type == TPM_HT_PERSISTENT) begin
					if((entity_hierarchy == TPM_RH_PLATFORM && !phEnable) || 
			                   (entity_hierarchy == TPM_RH_OWNER && !shEnable) || 
				           (entity_hierarchy == TPM_RH_ENDORSEMENT && !ehEnable) ||
			                   !nv_object_present) begin
						s_handle_error = 1'b1;
						s_response_code = TPM_RC_HANDLE; 
					end
					else if(!ram_available) begin
						s_handle_error = 1'b1;
						s_response_code = TPM_RC_OBJECT_MEMORY;
					end
				end
			else if(handle_type == TPM_HT_NV_INDEX) begin
				if(!nv_index_present ||
			           (entity_hierarchy == TPM_RH_PLATFORM && !phEnable) || 
			            (entity_hierarchy == TPM_RH_OWNER && !shEnable) || 
						(entity_hierarchy == TPM_RH_ENDORSEMENT && !ehEnable)) begin
						s_handle_error = 1'b1;
						s_response_code = TPM_RC_HANDLE;
					end
					else if((nv_write && tpma_nv_writeLocked) || (nv_read && tpma_nv_readLocked)) begin
						s_handle_error = 1'b1;
						s_response_code = TPM_RC_NV_LOCKED;
					end
				end
				else if(handle_type == TPM_HT_HMAC_SESSION || 
						  handle_type == TPM_HT_LOADED_SESSION || 
						  handle_type == TPM_HT_POLICY_SESSION || 
						  handle_type == TPM_HT_SAVED_SESSION) begin
					if(!session_present) begin
						s_handle_error = 1'b1;
						s_response_code = TPM_RC_REFERENCE_H0 + handle_index;
					end
				end
				else if(handle_type == TPM_HT_PERMANENT) begin
					if((current_handle == TPM_RH_PLATFORM && !phEnable) || 
						(current_handle == TPM_RH_OWNER && !shEnable) || 
						(current_handle == TPM_RH_ENDORSEMENT && !ehEnable)) begin
						s_handle_error = 1'b1;
						s_response_code = TPM_RC_HIERARCHY;
					end
				end
				// Check if the handle references a PCR, then the value is within the range of PCR supported by the TPM
				else if(handle_type == TPM_HT_PCR && pcrSelect > PCR_SELECT_MAX) begin
					s_handle_error = 1'b1;
					s_response_code = TPM_RC_VALUE;
				end else if (handle_index < handle_count) begin
					// Extract current handle
					s_handle_index = handle_index + 1'b1;
				end
            end


		case(current_state)
			// ====================================================================
			// STAGE 1: IDLE - Wait for command
			// ====================================================================
			STATE_IDLE: begin
					response_valid =   1'b0;
					s_response_code =   12'b0;
					response_length = 16'h0;
					s_handle_error = 1'b0;
					s_handle_index = 3'b000;
				if(command_ready) begin
					session_present = (command_tag == TPM_ST_SESSIONS);
				end
			end
			
			// ====================================================================
			// STAGE 2: HEADER VALIDATION - TPM 2.0 Part 3, Section 5.2
			// ===================================================================
			STATE_HEADER_VALID: begin
				// IMPLEMENTED: Basic header validation
				if(command_tag != TPM_ST_NO_SESSIONS && command_tag != TPM_ST_SESSIONS) begin
					s_header_valid_error = 1'b1;
					s_response_code = TPM_RC_BAD_TAG;
				end
				else if(command_size != command_length) begin
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
				if(op_state == FAILURE_MODE_STATE) begin
					// In Failure mode, only TPM2_GetTestResult or TPM2_GetCapability allowed with no sessions
					if(commandIndex != TPM_CC_GET_TEST_RESULT || commandIndex != TPM_CC_GET_CAPABILITY || command_tag != TPM_ST_NO_SESSIONS) begin
						s_mode_check_error = 1'b1;
						s_response_code = TPM_RC_FAILURE;
					end
				end
				else if(op_state != OPERATIONAL_STATE) begin
					// TPM not initialized - first command must be TPM2_Startup
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
				if(command_tag == TPM_ST_NO_SESSIONS) begin
					if(command_code_tag == TPM_ST_SESSIONS) begin
						s_response_code = TPM_RC_AUTH_CONTEXT;
					end
				end
				else if(command_tag == TPM_ST_SESSIONS) begin
					if(command_code_tag == TPM_ST_NO_SESSIONS) begin
						s_response_code = TPM_RC_AUTH_MISSING;
					end
					else if(command_code_tag == TPM_ST_SESSIONS) begin
						if (session_handle_type != TPM_HT_HMAC_SESSION &&
    						    session_handle_type != TPM_HT_POLICY_SESSION &&
    						    current_session_handle != TPM_RS_PW) begin
							if(!session_loaded) begin
								s_response_code = TPM_RC_REFERENCE_S0 + session_index;
							end
							else if(max_session_amount == session_index && authorization_size > 32'd0) begin
								s_response_code = TPM_RC_AUTHSIZE;
							end
							else if(audit_count > 2'd1 || decrypt_count > 2'd1 || encrypt_count > 2'd1 || (!auth_session && !audit && !decrypt && !encrypt)) begin
								s_response_code = TPM_RC_ATTRIBUTES;
							end
							else if(!auth_session && auth_necessary) begin
								s_response_code = TPM_RC_AUTH_MISSING;
							end
						end
						else begin
							s_response_code = TPM_RC_HANDLE;
						end
					end
				end
			end
			
			// ====================================================================
			// STAGE 6: AUTHORIZATION CHECKS - TPM 2.0 Part 3, Section 5.6
			// ====================================================================
			STATE_AUTH_CHECK: begin
				// Check to see if authorization subsystem has finished before updating authorization dependent information
				if(auth_done) begin
					// Response code will come from authorization subsystem
					s_response_code = auth_response_code;
					
					// If authorization successful tell other modules the authorization hierarchy, if it fails tell them the null hierarchy
					if(auth_success) begin
						authHierarchy = authHandle;
					end
					else begin
						authHierarchy = TPM_RH_NULL;
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
				if(param_decrypt_success == 1'b1)begin
					
				end
				else if(param_decrypt_fail == 1'b1)begin
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
				if(param_unmarshall_success == 1'b1)begin
					
				end
				else if(param_unmarshall_fail == 1'b1)begin
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
				s_execution_startup_done = execution_startup_done;
				s_response_code = execution_response_code;
				command_start = 1'b1;
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
				// 5. Calculate final response_length
				// 6. Format proper response structure
				
				//Check whether the initiliazed signal can be sent based on if previous errors were set
				if(commandIndex == TPM_CC_STARTUP || op_state != OPERATIONAL_STATE || !s_session_error || !s_handle_error || !s_header_valid_error || 
						   !s_mode_check_error ||!s_auth_check_error || !s_param_decrypt_error || !s_param_unmarshall_error || !s_execution_startup_done)begin
					s_initialized = 1'b1;
				end
				response_valid = 1'b1;
				response_length = 16'h0A; // Minimum response size for success
			end
			default: begin
			end
		endcase
	end
endmodule











