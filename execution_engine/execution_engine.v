module execution_engine(
		clock,
		reset_n,
		command_ready,
		command_tag,
		command_size,
		command_code,
		command_length,
		physical_presence,
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
		// Management module inputs 
		op_state,
		startup_type,
		phEnable,
		phEnableNV,
		shEnable,
		ehEnable,
		shutdownSave,
		command_done,
		// Response outputs
		response_valid,
		response_code,
		response_length,
		current_stage,
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
	input         physical_presence;	// 1-bit input physical presence signal results from testing functions basically a safety check somewhere else
	
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
	input [15:0] authorization_size;
	
	// Outputs
	output        response_valid;		// 1-bit output response valid signal
	output [31:0] response_code;		// 32-bit output response code
	output [15:0] response_length;		// 16-bit output response length
	output [3:0]  current_stage;		// 4-bit output current pipeline stage
   output reg    command_start;
	// Outputs to management module - EXACT MATCH to management_module inputs
	/*
	output	 [15:0] orderlyInput;		// 2-byte (16 bits) input from memory of state of last shutdown state
	output 		    initialized;			// 1-bit input intialized bit (from execution engine)
	output	 [31:0] authHierarchy;		// 2-byte (16 bits) input verifying which hiearchy was authorized (from execution engine)
	output   [7:0]  locality;				// 4-bit input of current locality
	output	 [15:0] testsRun;				// 2-byte (16 bits) input of amount of tests run by the self-test module, from the execution engine
	output	 [15:0] testsPassed;			// 2-byte (16 bits) input of amount of tests that have run and passed by the self-test module, from the execution engine
	output	 [15:0] untested;				// 2-byte (16 bits) input of amount of tests that still need to be run by the self-test module, from the execution engine
	output 		    nv_phEnableNV;		// 1-bit input of state of phEnableNV switch, from Non-Volatile memory
	output	        nv_shEnable;			// 1-bit input of state of shEnable switch, from Non-Volatile memory
	output          nv_ehEnable;			// 1-bit input of state of ehEnable switch, from Non-Volatile memory
	*/
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
 localparam TPM_RC_SUCCESS       = 32'h00000000,
               TPM_RC_BAD_TAG       = 32'h0000001E,  // Bad command tag:contentReference[oaicite:22]{index=22}
               TPM_RC_COMMAND_SIZE  = 32'h00000042,  // Command size mismatch
               TPM_RC_COMMAND_CODE  = 32'h00000043,  // Unimplemented/unsupported command
               TPM_RC_FAILURE       = 32'h00000101,  // TPM in failure mode
               TPM_RC_INITIALIZE    = 32'h0000012B,  // TPM not initialized
               TPM_RC_HANDLE        = 32'h0000000B,  // Handle error (e.g., invalid handle or hierarchy disabled)
               TPM_RC_AUTH_MISSING  = 32'h00000124,  // Authorization required but not provided
               TPM_RC_AUTH_FAIL     = 32'h00000125,  // Authorization failure
               TPM_RC_PP            = 32'h00000028,  // Physical presence required (e.g., for TPM2_Clear)
               // Additional response codes for handle-specific errors:
               TPM_RC_REFERENCE_H0  = 32'h00000120,  // 1st handle references a transient object or session that is not loaded:contentReference[oaicite:23]{index=23}
               TPM_RC_REFERENCE_H1  = 32'h00000121,  // 2nd handle not loaded
               TPM_RC_REFERENCE_H2  = 32'h00000122,  // 3rd handle not loaded
               // (TPM_RC_REFERENCE_H3, H4... would continue if more handles)
               TPM_RC_NV_LOCKED     = 32'h000000E0,  // NV index is locked (NOTE: spec combines RC_NV_LOCKED with parameter/handle index coding, but using a generic code here)
               TPM_RC_HIERARCHY     = 32'h0000010A,  // Hierarchy is disabled:contentReference[oaicite:24]{index=24}
               TPM_RC_VALUE         = 32'h0000000F;  // Value is out of range or inconsistent (e.g., bad PCR index or handle type):contentReference[oaicite:25]{index=25}

	
	// ============================================================================
	// COMMAND TAGS AND CODES
	// ============================================================================
	localparam TPM_ST_NO_SESSIONS = 16'h8001,	// Command has no sessions
				  TPM_ST_SESSIONS    = 16'h8002;	// Command has sessions
	
    localparam TPM_CC_NV_UNDEFINE_SPACE_SPECIAL = 32'h0000011F,
               TPM_CC_EVICT_CONTROL            = 32'h00000120,
               TPM_CC_HIERARCHY_CONTROL        = 32'h00000121,
               TPM_CC_NV_UNDEFINE_SPACE        = 32'h00000122,
               TPM_CC_CHANGE_EPS               = 32'h00000124,
               TPM_CC_CHANGE_PPS               = 32'h00000125,
               TPM_CC_CLEAR                    = 32'h00000126,  // TPM2_Clear
               TPM_CC_CLEAR_CONTROL            = 32'h00000127,
               TPM_CC_CLOCK_SET                = 32'h00000128,
               TPM_CC_HIERARCHY_CHANGE_AUTH    = 32'h00000129,
               TPM_CC_NV_DEFINE_SPACE          = 32'h0000012A,
               TPM_CC_PCR_ALLOCATE             = 32'h0000012B,
               TPM_CC_PCR_SET_AUTH_POLICY      = 32'h0000012C,
               TPM_CC_PP_COMMANDS              = 32'h0000012D,
               TPM_CC_SET_PRIMARY_POLICY       = 32'h0000012E,
               // FieldUpgradeStart (0x0000012F) and FieldUpgradeData (0x00000141) are *not* supported in this implementation
               TPM_CC_CLOCK_RATE_ADJUST        = 32'h00000130,
               TPM_CC_CREATE_PRIMARY           = 32'h00000131,
               TPM_CC_NV_GLOBAL_WRITE_LOCK     = 32'h00000132,
               TPM_CC_GET_COMMAND_AUDIT_DIGEST = 32'h00000133,
               TPM_CC_NV_INCREMENT             = 32'h00000134,
               TPM_CC_NV_SET_BITS              = 32'h00000135,
               TPM_CC_NV_EXTEND                = 32'h00000136,
               TPM_CC_NV_WRITE                 = 32'h00000137,
               TPM_CC_NV_WRITE_LOCK            = 32'h00000138,
               TPM_CC_DICTIONARY_ATTACK_LOCK_RESET = 32'h00000139,
               TPM_CC_DICTIONARY_ATTACK_PARAMETERS = 32'h0000013A,
               TPM_CC_NV_CHANGE_AUTH           = 32'h0000013B,
               TPM_CC_PCR_EVENT                = 32'h0000013C,
               TPM_CC_PCR_RESET                = 32'h0000013D,
               TPM_CC_SEQUENCE_COMPLETE        = 32'h0000013E,
               TPM_CC_SET_ALGORITHM_SET        = 32'h0000013F,
               TPM_CC_SET_COMMAND_CODE_AUDIT_STATUS = 32'h00000140,
               TPM_CC_INCREMENTAL_SELF_TEST    = 32'h00000142,
               TPM_CC_SELF_TEST                = 32'h00000143,
               TPM_CC_STARTUP                  = 32'h00000144,  // TPM2_Startup
               TPM_CC_SHUTDOWN                 = 32'h00000145,
               TPM_CC_STIR_RANDOM              = 32'h00000146,
               TPM_CC_ACTIVATE_CREDENTIAL      = 32'h00000147,
               TPM_CC_CERTIFY                  = 32'h00000148,
               TPM_CC_POLICY_NV                = 32'h00000149,
               TPM_CC_CERTIFY_CREATION         = 32'h0000014A,
               TPM_CC_DUPLICATE                = 32'h0000014B,
               TPM_CC_GET_TIME                 = 32'h0000014C,
               TPM_CC_GET_SESSION_AUDIT_DIGEST = 32'h0000014D,
               TPM_CC_NV_READ                  = 32'h0000014E,
               TPM_CC_NV_READ_LOCK             = 32'h0000014F,
               TPM_CC_OBJECT_CHANGE_AUTH       = 32'h00000150,
               TPM_CC_POLICY_SECRET            = 32'h00000151,
               TPM_CC_REWRAP                   = 32'h00000152,
               TPM_CC_CREATE                   = 32'h00000153,
               TPM_CC_ECDH_ZGEN                = 32'h00000154,
               TPM_CC_HMAC                     = 32'h00000155,
               TPM_CC_IMPORT                   = 32'h00000156,
               TPM_CC_LOAD                     = 32'h00000157,
               TPM_CC_QUOTE                    = 32'h00000158,
               TPM_CC_RSA_DECRYPT              = 32'h00000159,
               TPM_CC_HMAC_START               = 32'h0000015B,
               TPM_CC_SEQUENCE_UPDATE          = 32'h0000015C,
               TPM_CC_SIGN                     = 32'h0000015D,
               TPM_CC_UNSEAL                   = 32'h0000015E,
               TPM_CC_POLICY_SIGNED            = 32'h00000160,
               TPM_CC_CONTEXT_LOAD             = 32'h00000161,
               TPM_CC_CONTEXT_SAVE             = 32'h00000162,
               TPM_CC_ECDH_KEY_GEN             = 32'h00000163,
               TPM_CC_ENCRYPT_DECRYPT          = 32'h00000164,
               TPM_CC_FLUSH_CONTEXT            = 32'h00000165,
               TPM_CC_LOAD_EXTERNAL            = 32'h00000167,
               TPM_CC_MAKE_CREDENTIAL          = 32'h00000168,
               TPM_CC_NV_READ_PUBLIC           = 32'h00000169,
               TPM_CC_POLICY_AUTHORIZE         = 32'h0000016A,
               TPM_CC_POLICY_AUTH_VALUE        = 32'h0000016B,
               TPM_CC_POLICY_COMMAND_CODE      = 32'h0000016C,
               TPM_CC_POLICY_COUNTER_TIMER     = 32'h0000016D,
               TPM_CC_POLICY_CP_HASH           = 32'h0000016E,
               TPM_CC_POLICY_LOCALITY          = 32'h0000016F,
               TPM_CC_POLICY_NAME_HASH         = 32'h00000170,
               TPM_CC_POLICY_OR                = 32'h00000171,
               TPM_CC_POLICY_TICKET            = 32'h00000172,
               TPM_CC_READ_PUBLIC              = 32'h00000173,
               TPM_CC_RSA_ENCRYPT              = 32'h00000174,
               TPM_CC_START_AUTH_SESSION       = 32'h00000176,
               TPM_CC_VERIFY_SIGNATURE         = 32'h00000177,
               TPM_CC_ECC_PARAMETERS           = 32'h00000178,
               TPM_CC_FIRMWARE_READ            = 32'h00000179,
               TPM_CC_GET_CAPABILITY           = 32'h0000017A,
               TPM_CC_GET_RANDOM               = 32'h0000017B,
               TPM_CC_GET_TEST_RESULT          = 32'h0000017C,  // TPM2_GetTestResult
               TPM_CC_HASH                     = 32'h0000017D,
               TPM_CC_PCR_READ                 = 32'h0000017E,
               TPM_CC_POLICY_PCR               = 32'h0000017F,
               TPM_CC_POLICY_RESTART           = 32'h00000180,
               TPM_CC_READ_CLOCK               = 32'h00000181,
               TPM_CC_PCR_EXTEND               = 32'h00000182,
               TPM_CC_PCR_SET_AUTH_VALUE       = 32'h00000183,
               TPM_CC_NV_CERTIFY               = 32'h00000184,
               TPM_CC_EVENT_SEQUENCE_COMPLETE  = 32'h00000185,
               TPM_CC_HASH_SEQUENCE_START      = 32'h00000186,
               TPM_CC_POLICY_PHYSICAL_PRESENCE = 32'h00000187,
               TPM_CC_POLICY_DUPLICATION_SELECT= 32'h00000188,
               TPM_CC_POLICY_GET_DIGEST        = 32'h00000189,
               TPM_CC_TEST_PARMS               = 32'h0000018A,
               TPM_CC_COMMIT                   = 32'h0000018B,
               TPM_CC_POLICY_PASSWORD          = 32'h0000018C,
               TPM_CC_ZGEN_2PHASE              = 32'h0000018D,
               TPM_CC_EC_EPHEMERAL             = 32'h0000018E,
               TPM_CC_POLICY_NV_WRITTEN        = 32'h0000018F,
               TPM_CC_POLICY_TEMPLATE          = 32'h00000190,
               TPM_CC_CREATE_LOADED            = 32'h00000191,
               TPM_CC_POLICY_AUTHORIZE_NV      = 32'h00000192,
               TPM_CC_ENCRYPT_DECRYPT_2        = 32'h00000193,
               TPM_CC_AC_GET_CAPABILITY        = 32'h00000194,
               TPM_CC_AC_SEND                  = 32'h00000195,
               TPM_CC_POLICY_AC_SEND_SELECT    = 32'h00000196;
	
	// ============================================================================
	// INTERNAL REGISTERS
	// ============================================================================
	reg [3:0] state;
	reg session_present;
	reg response_valid;
	reg [31:0] response_code;
	reg [15:0] response_length;
	reg [3:0] current_state;
	reg [2:0] handle_index;
	reg [2:0] handle_count;
	reg [31:0] current_handle;
	reg [7:0] handle_type;
	reg [23:0] handle_index_bits;
	reg handle_error;
	reg command_valid;
	reg [1:0] session_index;     // Index of the session currently being processed (0–2)
	reg [1:0] session_count;     // Number of valid sessions encountered
	reg       session_error;     // Flag to detect session validation failure
	reg       audit_used;        // Track if audit session already found
	reg       decrypt_used;      // Track if decrypt session already found
	reg       encrypt_used;      // Track if encrypt session already found
	reg [31:0] current_session_handle;
	reg [7:0]  current_session_attributes;
	reg [15:0] current_session_hmac_size;
	reg        current_session_valid;
	
	// ============================================================================
	// SEQUENTIAL LOGIC BLOCK - STATE TRANSITIONS ONLY
	// ============================================================================
		always@(posedge clock, negedge reset_n) begin
			if(!reset_n) begin
				current_state <= STATE_IDLE;
			end
			else begin
				current_state <= state;
			end
		end
		
		always@(*) begin
		case(current_state)
			// ====================================================================
			// STAGE 1: IDLE - Wait for command
			// ====================================================================
			STATE_IDLE: begin
				if(command_ready) begin
					state = STATE_HEADER_VALID;
				end
			end

			// ====================================================================
			// STAGE 2: HEADER VALIDATION - TPM 2.0 Part 3, Section 5.2
			// ====================================================================
			STATE_HEADER_VALID: begin
				case (command_code)
					TPM_CC_NV_UNDEFINE_SPACE_SPECIAL,
					TPM_CC_EVICT_CONTROL,
					TPM_CC_HIERARCHY_CONTROL,
					TPM_CC_NV_UNDEFINE_SPACE,
					TPM_CC_CHANGE_EPS,
					TPM_CC_CHANGE_PPS,
					TPM_CC_CLEAR,
					TPM_CC_CLEAR_CONTROL,
					TPM_CC_CLOCK_SET,
					TPM_CC_HIERARCHY_CHANGE_AUTH,
					TPM_CC_NV_DEFINE_SPACE,
					TPM_CC_PCR_ALLOCATE,
					TPM_CC_PCR_SET_AUTH_POLICY,
					TPM_CC_PP_COMMANDS,
					TPM_CC_SET_PRIMARY_POLICY,
					TPM_CC_CLOCK_RATE_ADJUST,
					TPM_CC_CREATE_PRIMARY,
					TPM_CC_NV_GLOBAL_WRITE_LOCK,
					TPM_CC_GET_COMMAND_AUDIT_DIGEST,
					TPM_CC_NV_INCREMENT,
					TPM_CC_NV_SET_BITS,
					TPM_CC_NV_EXTEND,
					TPM_CC_NV_WRITE,
					TPM_CC_NV_WRITE_LOCK,
					TPM_CC_DICTIONARY_ATTACK_LOCK_RESET,
					TPM_CC_DICTIONARY_ATTACK_PARAMETERS,
					TPM_CC_NV_CHANGE_AUTH,
					TPM_CC_PCR_EVENT,
					TPM_CC_PCR_RESET,
					TPM_CC_SEQUENCE_COMPLETE,
					TPM_CC_SET_ALGORITHM_SET,
					TPM_CC_SET_COMMAND_CODE_AUDIT_STATUS,
					TPM_CC_INCREMENTAL_SELF_TEST,
					TPM_CC_SELF_TEST,
					TPM_CC_STARTUP,
					TPM_CC_SHUTDOWN,
					TPM_CC_STIR_RANDOM,
					TPM_CC_ACTIVATE_CREDENTIAL,
					TPM_CC_CERTIFY,
					TPM_CC_POLICY_NV,
					TPM_CC_CERTIFY_CREATION,
					TPM_CC_DUPLICATE,
					TPM_CC_GET_TIME,
					TPM_CC_GET_SESSION_AUDIT_DIGEST,
					TPM_CC_NV_READ,
					TPM_CC_NV_READ_LOCK,
					TPM_CC_OBJECT_CHANGE_AUTH,
					TPM_CC_POLICY_SECRET,
					TPM_CC_REWRAP,
					TPM_CC_CREATE,
					TPM_CC_ECDH_ZGEN,
					TPM_CC_HMAC,
					TPM_CC_IMPORT,
					TPM_CC_LOAD,
					TPM_CC_QUOTE,
					TPM_CC_RSA_DECRYPT,
					TPM_CC_HMAC_START,
					TPM_CC_SEQUENCE_UPDATE,
					TPM_CC_SIGN,
					TPM_CC_UNSEAL,
					TPM_CC_POLICY_SIGNED,
					TPM_CC_CONTEXT_LOAD,
					TPM_CC_CONTEXT_SAVE,
					TPM_CC_ECDH_KEY_GEN,
					TPM_CC_ENCRYPT_DECRYPT,
					TPM_CC_FLUSH_CONTEXT,
					TPM_CC_LOAD_EXTERNAL,
					TPM_CC_MAKE_CREDENTIAL,
					TPM_CC_NV_READ_PUBLIC,
					TPM_CC_POLICY_AUTHORIZE,
					TPM_CC_POLICY_AUTH_VALUE,
					TPM_CC_POLICY_COMMAND_CODE,
					TPM_CC_POLICY_COUNTER_TIMER,
					TPM_CC_POLICY_CP_HASH,
					TPM_CC_POLICY_LOCALITY,
					TPM_CC_POLICY_NAME_HASH,
					TPM_CC_POLICY_OR,
					TPM_CC_POLICY_TICKET,
					TPM_CC_READ_PUBLIC,
					TPM_CC_RSA_ENCRYPT,
					TPM_CC_START_AUTH_SESSION,
					TPM_CC_VERIFY_SIGNATURE,
					TPM_CC_ECC_PARAMETERS,
					TPM_CC_FIRMWARE_READ,
					TPM_CC_GET_CAPABILITY,
					TPM_CC_GET_RANDOM,
					TPM_CC_GET_TEST_RESULT,
					TPM_CC_HASH,
					TPM_CC_PCR_READ,
					TPM_CC_POLICY_PCR,
					TPM_CC_POLICY_RESTART,
					TPM_CC_READ_CLOCK,
					TPM_CC_PCR_EXTEND,
					TPM_CC_PCR_SET_AUTH_VALUE,
					TPM_CC_NV_CERTIFY,
					TPM_CC_EVENT_SEQUENCE_COMPLETE,
					TPM_CC_HASH_SEQUENCE_START,
					TPM_CC_POLICY_PHYSICAL_PRESENCE,
					TPM_CC_POLICY_DUPLICATION_SELECT,
					TPM_CC_POLICY_GET_DIGEST,
					TPM_CC_TEST_PARMS,
					TPM_CC_COMMIT,
					TPM_CC_POLICY_PASSWORD,
					TPM_CC_ZGEN_2PHASE,
					TPM_CC_EC_EPHEMERAL,
					TPM_CC_POLICY_NV_WRITTEN,
					TPM_CC_POLICY_TEMPLATE,
					TPM_CC_CREATE_LOADED,
					TPM_CC_POLICY_AUTHORIZE_NV,
					TPM_CC_ENCRYPT_DECRYPT_2,
					TPM_CC_AC_GET_CAPABILITY,
					TPM_CC_AC_SEND,
					TPM_CC_POLICY_AC_SEND_SELECT: command_valid = 1'b1;
					default: command_valid = 1'b0;
				endcase
				
				if(command_tag != TPM_ST_NO_SESSIONS && command_tag != TPM_ST_SESSIONS) begin
					state = STATE_POST_PROCESS;
				end
				else if(command_size != command_length) begin
					state = STATE_POST_PROCESS;
				end
				else if(command_valid) begin
					state = STATE_POST_PROCESS;
				end
				else begin
					state = STATE_MODE_CHECK;
				end
				// TODO: EXPAND COMMAND CODE VALIDATION FOR ALL SUPPORTED COMMANDS
			end

			// Emma's Notes: if the command code is not startup, gettest, or clear, they should still be able to run. check for command_valid signal instead.
			
			// ====================================================================
			// STAGE 3: MODE CHECKS - TPM 2.0 Part 3, Section 5.3
			// ====================================================================
			STATE_MODE_CHECK: begin
				// IMPLEMENTED: Basic mode checks
				// Emma's Notes: make sure to include a check for TPM_CC_GETCAPABILITY in the failure mode state. also might make more sense to use an AND gate between the command code and tag and an OR gate between the 2 command codes, just for clarity's sake.
				if(op_state == FAILURE_MODE_STATE) begin
					// In Failure mode, only TPM2_GetTestResult allowed with no sessions
					if(command_code != TPM_CC_GET_TEST_RESULT || command_tag != TPM_ST_NO_SESSIONS) begin
						state = STATE_POST_PROCESS;
					end
					else begin
						state = STATE_HANDLE_VALID;
					end
				end
				else if(op_state != OPERATIONAL_STATE) begin
					// TPM not initialized - first command must be TPM2_Startup
					if(command_code != TPM_CC_STARTUP) begin
						state = STATE_POST_PROCESS;
					end
					else begin
						state = STATE_HANDLE_VALID;
					end
				end
				else begin
					state = STATE_HANDLE_VALID;
				end
				
			end
			
			// ====================================================================
			// STAGE 4: HANDLE VALIDATION - TPM 2.0 Part 3, Section 5.4
			// ====================================================================
         STATE_HANDLE_VALID: begin
				case (command_code)
		  			TPM_CC_STARTUP: handle_count = 0;
			      TPM_CC_SHUTDOWN: handle_count = 0;
      			TPM_CC_SELF_TEST: handle_count = 0;
    			   TPM_CC_INCREMENTAL_SELF_TEST: handle_count = 0;
    			   TPM_CC_GET_TEST_RESULT: handle_count = 0;
   			   TPM_CC_STIR_RANDOM: handle_count = 0;
   			   TPM_CC_GET_RANDOM: handle_count = 0;
    			   TPM_CC_GET_CAPABILITY: handle_count = 0;
   			   TPM_CC_FIRMWARE_READ: handle_count = 0;
   			   TPM_CC_GET_TIME: handle_count = 0;
   			   TPM_CC_READ_CLOCK: handle_count = 0;
   			   TPM_CC_ECC_PARAMETERS: handle_count = 0;
    			   TPM_CC_TEST_PARMS: handle_count = 0;
   			   TPM_CC_HASH: handle_count = 0;
				   TPM_CC_PCR_READ: handle_count = 0;
					TPM_CC_GET_COMMAND_AUDIT_DIGEST: handle_count = 0;
					TPM_CC_GET_SESSION_AUDIT_DIGEST: handle_count = 0;
					TPM_CC_NV_READ_PUBLIC: handle_count = 0;
					TPM_CC_AC_GET_CAPABILITY: handle_count = 0;
        
					// Commands with 1 handle
					TPM_CC_CLEAR: handle_count = 1;
					TPM_CC_HIERARCHY_CONTROL: handle_count = 1;
					TPM_CC_CLEAR_CONTROL: handle_count = 1;
					TPM_CC_CLOCK_SET: handle_count = 1;
					TPM_CC_CLOCK_RATE_ADJUST: handle_count = 1;
					TPM_CC_HIERARCHY_CHANGE_AUTH: handle_count = 1;
					TPM_CC_NV_DEFINE_SPACE: handle_count = 1;
					TPM_CC_PCR_ALLOCATE: handle_count = 1;
					TPM_CC_PCR_SET_AUTH_POLICY: handle_count = 1;
					TPM_CC_PP_COMMANDS: handle_count = 1;
					TPM_CC_SET_PRIMARY_POLICY: handle_count = 1;
					TPM_CC_SET_ALGORITHM_SET: handle_count = 1;
					TPM_CC_SET_COMMAND_CODE_AUDIT_STATUS: handle_count = 1;
					TPM_CC_CREATE_PRIMARY: handle_count = 1;
					TPM_CC_NV_GLOBAL_WRITE_LOCK: handle_count = 1;
					TPM_CC_NV_INCREMENT: handle_count = 1;
					TPM_CC_NV_SET_BITS: handle_count = 1;
					TPM_CC_NV_EXTEND: handle_count = 1;
					TPM_CC_NV_WRITE_LOCK: handle_count = 1;
					TPM_CC_DICTIONARY_ATTACK_LOCK_RESET: handle_count = 1;
					TPM_CC_DICTIONARY_ATTACK_PARAMETERS: handle_count = 1;
					TPM_CC_NV_CHANGE_AUTH: handle_count = 1;
					TPM_CC_PCR_EVENT: handle_count = 1;
					TPM_CC_PCR_RESET: handle_count = 1;
					TPM_CC_PCR_EXTEND: handle_count = 1;
					TPM_CC_PCR_SET_AUTH_VALUE: handle_count = 1;
					TPM_CC_SEQUENCE_COMPLETE: handle_count = 1;
					TPM_CC_EVENT_SEQUENCE_COMPLETE: handle_count = 1;
					TPM_CC_FLUSH_CONTEXT: handle_count = 1;
					TPM_CC_CREATE: handle_count = 1;
					TPM_CC_LOAD: handle_count = 1;
					TPM_CC_UNSEAL: handle_count = 1;
					TPM_CC_SIGN: handle_count = 1;
					TPM_CC_READ_PUBLIC: handle_count = 1;
					TPM_CC_ECDH_KEY_GEN: handle_count = 1;
					TPM_CC_RSA_DECRYPT: handle_count = 1;
					TPM_CC_ECDH_ZGEN: handle_count = 1;
					TPM_CC_CONTEXT_SAVE: handle_count = 1;
					TPM_CC_CONTEXT_LOAD: handle_count = 1;
					TPM_CC_NV_READ: handle_count = 1;
					TPM_CC_NV_READ_LOCK: handle_count = 1;
					TPM_CC_OBJECT_CHANGE_AUTH: handle_count = 1;
					TPM_CC_POLICY_SECRET: handle_count = 1;
					TPM_CC_REWRAP: handle_count = 1;
					TPM_CC_RSA_ENCRYPT: handle_count = 1;
					TPM_CC_VERIFY_SIGNATURE: handle_count = 1;
					TPM_CC_COMMIT: handle_count = 1;
					TPM_CC_EC_EPHEMERAL: handle_count = 1;
					TPM_CC_CREATE_LOADED: handle_count = 1;
					TPM_CC_AC_SEND: handle_count = 1;
        
					// Commands with 2 handles
					TPM_CC_NV_UNDEFINE_SPACE: handle_count = 2;
					TPM_CC_NV_UNDEFINE_SPACE_SPECIAL: handle_count = 2;
					TPM_CC_EVICT_CONTROL: handle_count = 2;
					TPM_CC_CHANGE_EPS: handle_count = 2;
					TPM_CC_CHANGE_PPS: handle_count = 2;
					TPM_CC_NV_WRITE: handle_count = 2;
					TPM_CC_START_AUTH_SESSION: handle_count = 2;
					TPM_CC_ACTIVATE_CREDENTIAL: handle_count = 2;
					TPM_CC_CERTIFY: handle_count = 2;
					TPM_CC_POLICY_NV: handle_count = 2;
					TPM_CC_CERTIFY_CREATION: handle_count = 2;
					TPM_CC_DUPLICATE: handle_count = 2;
					TPM_CC_QUOTE: handle_count = 2;
					TPM_CC_HMAC: handle_count = 2;
					TPM_CC_IMPORT: handle_count = 2;
					TPM_CC_POLICY_SIGNED: handle_count = 2;
					TPM_CC_ENCRYPT_DECRYPT: handle_count = 2;
					TPM_CC_MAKE_CREDENTIAL: handle_count = 2;
					TPM_CC_POLICY_AUTHORIZE: handle_count = 2;
					TPM_CC_POLICY_AUTH_VALUE: handle_count = 2;
					TPM_CC_POLICY_COMMAND_CODE: handle_count = 2;
					TPM_CC_POLICY_COUNTER_TIMER: handle_count = 2;
					TPM_CC_POLICY_CP_HASH: handle_count = 2;
					TPM_CC_POLICY_LOCALITY: handle_count = 2;
					TPM_CC_POLICY_NAME_HASH: handle_count = 2;
					TPM_CC_POLICY_OR: handle_count = 2;
					TPM_CC_POLICY_TICKET: handle_count = 2;
					TPM_CC_POLICY_PCR: handle_count = 2;
					TPM_CC_POLICY_RESTART: handle_count = 2;
					TPM_CC_POLICY_PHYSICAL_PRESENCE: handle_count = 2;
					TPM_CC_POLICY_DUPLICATION_SELECT: handle_count = 2;
					TPM_CC_POLICY_GET_DIGEST: handle_count = 2;
					TPM_CC_POLICY_PASSWORD: handle_count = 2;
					TPM_CC_ZGEN_2PHASE: handle_count = 2;
					TPM_CC_POLICY_NV_WRITTEN: handle_count = 2;
					TPM_CC_POLICY_TEMPLATE: handle_count = 2;
					TPM_CC_POLICY_AUTHORIZE_NV: handle_count = 2;
					TPM_CC_ENCRYPT_DECRYPT_2: handle_count = 2;
					TPM_CC_POLICY_AC_SEND_SELECT: handle_count = 2;
					TPM_CC_NV_CERTIFY: handle_count = 2;
        
					// Commands with 0 handles (session/sequence starters)
					TPM_CC_HASH_SEQUENCE_START: handle_count = 0;
					TPM_CC_HMAC_START: handle_count = 0;
					TPM_CC_SEQUENCE_UPDATE: handle_count = 0;
					TPM_CC_LOAD_EXTERNAL: handle_count = 0;
        
					default: handle_count = 0;
				endcase
				
                if (handle_index < handle_count) begin
                    // Extract current handle
                    current_handle = (handle_index == 0) ? handle_0 :
                                     (handle_index == 1) ? handle_1 :
                                                          handle_2;

                    handle_type  = current_handle[31:24];
                    handle_index_bits = current_handle[23:0];

                    handle_error = 1'b0;

                    case (handle_type)
                        8'h80: begin // Transient object
                            // No hierarchy check for transient
                            // No existence check per user
                        end
                        8'h81: begin // Persistent object
                            if (!phEnable && !shEnable && !ehEnable)
                                handle_error = 1'b1;
                        end
                        8'h01: begin // PCR
                            if (handle_index_bits > 8'd23)
                                handle_error = 1'b1;
                        end
                        8'h01, 8'h02, 8'h03: begin // NV Indices (0x0100_0000 - 0x01FF_FFFF)
                            if (!phEnableNV && !shEnable && !ehEnable)
                                handle_error = 1'b1;
                        end
                        default: begin
                            handle_error = 1'b1;
                        end
                    endcase
						  
						  //////////////////////////////////////////////////////////////////////////////////////////////////////////////
						  //cant currently check if handles are loaded in the appropriate spots add submodule
						  /////////////////////////////////////////////////////////////////////////////////////////////////////////////
						  
						  
                    if (!handle_error) begin
                        handle_index = handle_index + 1;
                    end else begin
                        state = STATE_POST_PROCESS;
                    end
                end else begin
                    state = STATE_SESSION_VALID;
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

				// Map flattened inputs into a common structure for session processing.
				if (session_index == 0) begin
					current_session_handle     = session0_handle;
					current_session_attributes = session0_attributes;
					current_session_hmac_size  = session0_hmac_size;
					current_session_valid      = session0_valid;
				end else if (session_index == 1) begin
					current_session_handle     = session1_handle;
					current_session_attributes = session1_attributes;
					current_session_hmac_size  = session1_hmac_size;
					current_session_valid      = session1_valid;
				end else begin
					current_session_handle     = session2_handle;
					current_session_attributes = session2_attributes;
					current_session_hmac_size  = session2_hmac_size;
					current_session_valid      = session2_valid;
				end

				// ----------------------------------------------------------------
				// If the session is valid and within the allowed limit, process it.
				// ----------------------------------------------------------------
				if (session_index < 3 && current_session_valid) begin

					// Count how many sessions we've processed so far.
					session_count = session_count + 1;

					// Step 1: Validate the session handle's type.
					// The top 8 bits of the handle indicate its type.
					// Valid session types include HMAC (0x01), Policy (0x02), and Password (0x03).
					case (current_session_handle[31:24])
						8'h01, 8'h02, 8'h03: ; // Acceptable session types
						default: session_error = 1'b1; // Invalid session handle type
					endcase

					// Step 2: Ensure each role (audit/decrypt/encrypt) is only used once.
					// Bits 7, 6, and 5 in the session attributes represent audit, decrypt,
					// and encrypt flags respectively. Multiple sessions cannot share roles.

					if (current_session_attributes[7]) begin // Audit bit
						if (audit_used) session_error = 1'b1;
						audit_used = 1;
					end

					if (current_session_attributes[6]) begin // Decrypt bit
						if (decrypt_used) session_error = 1'b1;
						decrypt_used = 1;
					end

					if (current_session_attributes[5]) begin // Encrypt bit
						if (encrypt_used) session_error = 1'b1;
						encrypt_used = 1;
					end

					// Step 3: Validate that empty sessions (no HMAC) are used only if
					// they are performing other roles (audit/decrypt/encrypt).
					if (current_session_hmac_size == 0 &&
						!(current_session_attributes[5] ||
						  current_session_attributes[6] ||
						  current_session_attributes[7])) begin
						session_error = 1'b1; // An empty session must be doing something
					end

					// Step 4: Move on to the next session
					session_index = session_index + 1;

				end else begin
					// Final step after checking all sessions
					// If we validated more than 3, that's an error
					if (session_count > 3) session_error = 1'b1;

					// If all sessions are valid, move to the next FSM stage
					if (!session_error) begin
						state = STATE_AUTH_CHECK;
					end else begin
						// If we encountered any error, prepare a failure response

						state = STATE_POST_PROCESS;
					end
				end
			end
			// ====================================================================
			// STAGE 6: AUTHORIZATION CHECKS - TPM 2.0 Part 3, Section 5.6
			// ====================================================================
			STATE_AUTH_CHECK: begin
				// IMPLEMENTED: Basic physical presence check
				if(command_code == TPM_CC_CLEAR && !physical_presence) begin
					state = STATE_POST_PROCESS;
				end
				
				////////////////////////////////////
				//To be implemented with a submodule
				/////////////////////////////////////
				
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
		endcase
	end
	// ============================================================================
	// COMBINATIONAL LOGIC BLOCK - ALL OUTPUTS AND NEXT STATE
	// ============================================================================
	always@(*) begin
		
		// Default output values
		response_valid =   1'b0;
		response_code =   32'b0;
		response_length = 16'h0;
		// Emma's Notes: - not really sure what command_valid is a check for?
		//				 - if this logic block is only determining the next state and the outputs, this "if" block should not be in this always block, recommend making these register assignments sequential.
		case(state)
			// ====================================================================
			// STAGE 1: IDLE - Wait for command
			// ====================================================================
			STATE_IDLE: begin
					response_valid =   1'b0;
					response_code =   32'b0;
					response_length = 16'h0;
				if(command_ready) begin
					session_present = (command_tag == TPM_ST_SESSIONS);
				end
			end

			// Emma's Notes: you said that it should be a command_ready signal which transitions to stage 2 not command_valid
			
			// ====================================================================
			// STAGE 2: HEADER VALIDATION - TPM 2.0 Part 3, Section 5.2
			// ====================================================================
			STATE_HEADER_VALID: begin
				// IMPLEMENTED: Basic header validation
				if(command_tag != TPM_ST_NO_SESSIONS && command_tag != TPM_ST_SESSIONS) begin
					response_code = TPM_RC_BAD_TAG;
				end
				else if(command_size != command_length) begin
					response_code = TPM_RC_COMMAND_SIZE;
				end
				else if(!command_valid) begin
					response_code = TPM_RC_COMMAND_CODE;
				end

			end

			// Emma's Notes: if the command code is not startup, gettest, or clear, they should still be able to run. check for command_valid signal instead.
			
			// ====================================================================
			// STAGE 3: MODE CHECKS - TPM 2.0 Part 3, Section 5.3
			// ====================================================================
			STATE_MODE_CHECK: begin
				// IMPLEMENTED: Basic mode checks
				// Emma's Notes: make sure to include a check for TPM_CC_GETCAPABILITY in the failure mode state. also might make more sense to use an AND gate between the command code and tag and an OR gate between the 2 command codes, just for clarity's sake.
				if(op_state == FAILURE_MODE_STATE) begin
					// In Failure mode, only TPM2_GetTestResult allowed with no sessions
					if(command_code != TPM_CC_GET_TEST_RESULT || command_tag != TPM_ST_NO_SESSIONS) begin
						response_code = TPM_RC_FAILURE;
					end
				end
				else if(op_state != OPERATIONAL_STATE) begin
					// TPM not initialized - first command must be TPM2_Startup
					if(command_code != TPM_CC_STARTUP) begin
						response_code = TPM_RC_INITIALIZE;
					end
				end
			end
			
			// ====================================================================
			// STAGE 4: HANDLE VALIDATION - TPM 2.0 Part 3, Section 5.4
			// ====================================================================
			STATE_HANDLE_VALID: begin
				if(handle_error) begin
					response_code = TPM_RC_HANDLE;
				end
			end
			// ====================================================================
			// STAGE 5: SESSION VALIDATION - TPM 2.0 Part 3, Section 5.5
			// ====================================================================
			STATE_SESSION_VALID: begin
				if(session_present) begin
					// TODO: IMPLEMENT SESSION VALIDATION:
					// 1. Extract authorizationSize from command buffer after handles
					// 2. Validate authorizationSize bounds (min 9 bytes, max based on command)
					// 3. Parse session structures:
					//    - For each session: handle(4) + nonceSize(2) + nonce + attributes(1) + hmacSize(2) + hmac
					// 4. Validate each session:
					//    - Session handle is valid type (HMAC, Policy, or TPM_RS_PW)
					//    - Session is loaded (session_loaded[session_handle])
					//    - Session attributes are consistent:
					//        * Only one session for audit/decrypt/encrypt
					//        * If not used for auth, must have decrypt/encrypt/audit set
					//    - Session count doesn't exceed maximum (3)
					// 5. Return TPM_RC_AUTH_MISSING, TPM_RC_AUTHSIZE, or TPM_RC_ATTRIBUTES on failure
					
					if(session_error) begin
						response_valid = 1'b1;
						response_code = TPM_RC_AUTH_MISSING;
					end
				end
			end
			
			// ====================================================================
			// STAGE 6: AUTHORIZATION CHECKS - TPM 2.0 Part 3, Section 5.6
			// ====================================================================
			STATE_AUTH_CHECK: begin
				// IMPLEMENTED: Basic physical presence check
				if(command_code == TPM_CC_CLEAR && !physical_presence) begin
					response_valid = 1'b1;
					response_code = TPM_RC_PP;
				end
				// TODO: IMPLEMENT COMPREHENSIVE AUTHORIZATION:
				// 1. Check lockout mode and DA protection
				// 2. For each entity requiring authorization:
				//    - HMAC Authorization: Verify HMAC using authValue and session secret
				//    - Policy Authorization: Validate policySession against authPolicy
				//    - Password Authorization: Compare password with authValue
				// 3. Check role authorization (ADMIN/DUP/USER) requirements
				// 4. Validate policy session contents:
				//    - policyDigest matches authPolicy
				//    - cpHash matches command
				//    - commandCode matches
				//    - Session not expired
				//    - PCR values match if specified
				// 5. Return TPM_RC_AUTH_FAIL, TPM_RC_POLICY_FAIL, TPM_RC_LOCKOUT on failure
				
				else if(1'b0) begin // PLACEHOLDER: Replace with actual authorization checks
					response_valid = 1'b1;
					response_code = TPM_RC_AUTH_FAIL;
				end
			end
			
			// ====================================================================
			// STAGE 7: PARAMETER DECRYPTION - TPM 2.0 Part 3, Section 5.7
			// ====================================================================
			STATE_PARAM_DECRYPT: begin
				//Do not do yet implement some sort of signal
				// For now, always proceed to parameter unmarshaling
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
				
				// For now, always proceed to execution
			end
			
			// ====================================================================
			// STAGE 9: COMMAND EXECUTION - TPM 2.0 Part 3, Section 5.9
			// ====================================================================
			STATE_EXECUTE: begin
				//start command processing
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
				
				response_valid = 1'b1;
				response_code = TPM_RC_SUCCESS;
				response_length = 16'h0A; // Minimum response size for success
			end
		endcase
	end
endmodule

