module tpm_command_processor(
		clock,
		reset_n,
		command_valid,
		command_buffer,
		command_length,
		physical_presence,
		// Management module inputs - EXACT MATCH to management_module outputs
		op_state,
		startup_type,
		phEnable,
		phEnableNV,
		shEnable,
		ehEnable,
		shutdownSave,
		// Response outputs
		response_valid,
		response_code,
		response_buffer,
		response_length,
		current_stage
	);

	// Inputs
	input         clock;					// Input clock signal
	input         reset_n;				// Active-low input reset signal
	input         command_valid;		// Active-high input command valid signal perhaps we can create a combinational logic check for this in a separate module
	input  [7:0]  command_buffer [0:1023];	// 1024-byte input command buffer
	input  [15:0] command_length;		// 16-bit input command length
	input         physical_presence;	// 1-bit input physical presence signal results from testing functions basically a safety check somewhere else
		
	// Inputs from managemnt module - EXACT MATCH to management_module outputs
	input  [2:0]  op_state;				// 3-bit input operational state from management module
	input  [2:0]  startup_type;		// 3-bit input startup type from management module
	input         phEnable;				// 1-bit input platform hierarchy enable from management module
	input         phEnableNV;			// 1-bit input platform hierarchy NV memory enable from management module
	input         shEnable;				// 1-bit input owner hierarchy enable from management module
	input         ehEnable;				// 1-bit input endorsement hierarchy enable from management module
	input  [15:0] shutdownSave;		// 16-bit input shutdown type from management module
	
	// Outputs
	output        response_valid;		// 1-bit output response valid signal
	output [31:0] response_code;		// 32-bit output response code
	output [7:0]  response_buffer [0:1023];	// 1024-byte output response buffer
	output [15:0] response_length;		// 16-bit output response length
	output [3:0]  current_stage;		// 4-bit output current pipeline stage

	// Outputs to management module - EXACT MATCH to management_module inputs
	/*
	output	 [15:0] orderlyInput;		// 2-byte (16 bits) input from memory of state of last shutdown state
	output 		    initialized;			// 1-bit input intialized bit (from execution engine)
	output	 [31:0] authHierarchy;		// 2-byte (16 bits) input verifying which hiearchy was authorized (from execution engine)
	output   [31:0] executionEng_rc;	// 2-byte (16 bits) input of execution engine response code
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
	localparam STAGE_IDLE          = 4'b0000,	// Wait for command
				  STAGE_HEADER_VALID  = 4'b0001,	// Section 5.2: Command Header Validation
				  STAGE_MODE_CHECK    = 4'b0010,	// Section 5.3: Mode Checks  
				  STAGE_HANDLE_VALID  = 4'b0011,	// Section 5.4: Handle Area Validation
				  STAGE_SESSION_VALID = 4'b0100,	// Section 5.5: Session Area Validation
				  STAGE_AUTH_CHECK    = 4'b0101,	// Section 5.6: Authorization Checks
				  STAGE_PARAM_DECRYPT = 4'b0110,	// Section 5.7: Parameter Decryption
				  STAGE_PARAM_UNMARSH = 4'b0111,	// Section 5.8: Parameter Unmarshaling
				  STAGE_EXECUTE       = 4'b1000,	// Section 5.9: Command Execution
				  STAGE_POST_PROCESS  = 4'b1001;	// Section 5.10: Command Post-Processing
	
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
	localparam TPM_RC_SUCCESS      = 32'h00000000,
				  TPM_RC_BAD_TAG      = 32'h0000001E,	// Bad command tag
				  TPM_RC_COMMAND_SIZE = 32'h00000042,	// Command size mismatch
				  TPM_RC_COMMAND_CODE = 32'h00000043,	// Unimplemented command code
				  TPM_RC_FAILURE      = 32'h00000101,	// TPM in failure mode
				  TPM_RC_INITIALIZE   = 32'h0000012B,	// TPM not initialized
				  TPM_RC_HANDLE       = 32'h0000000B,	// Invalid handle
				  TPM_RC_AUTH_MISSING = 32'h00000124,	// Authorization required but not provided
				  TPM_RC_AUTH_FAIL    = 32'h00000125,	// Authorization failure
				  TPM_RC_PP           = 32'h00000028;	// Physical presence required
				  // TODO: ADD MORE RESPONSE CODES AS NEEDED:
				  // TPM_RC_AUTHSIZE, TPM_RC_REFERENCE_H0-H3, TPM_RC_REFERENCE_S0-S2,
				  // TPM_RC_NV_LOCKED, TPM_RC_HIERARCHY, TPM_RC_ATTRIBUTES, TPM_RC_POLICY_FAIL
	
	// ============================================================================
	// COMMAND TAGS AND CODES
	// ============================================================================
	localparam TPM_ST_NO_SESSIONS = 16'h8001,	// Command has no sessions
				  TPM_ST_SESSIONS    = 16'h8002;	// Command has sessions
	
	localparam TPM_CC_STARTUP        = 32'h00000144,	// TPM2_Startup command
				  TPM_CC_GET_TEST_RESULT = 32'h00000145,	// TPM2_GetTestResult command
				  TPM_CC_CLEAR           = 32'h00000126;	// TPM2_Clear command (requires physical presence)
				  // TODO: ADD ALL SUPPORTED TPM COMMAND CODES
	
	// ============================================================================
	// INTERNAL REGISTERS
	// ============================================================================
	reg [3:0] current_stage, next_stage;
	reg [15:0] command_tag;
	reg [31:0] command_size;
	reg [31:0] command_code;
	reg session_present;
	reg response_valid;
	reg [31:0] response_code;
	reg [7:0] response_buffer [0:1023];
	reg [15:0] response_length;
	
	// ============================================================================
	// TODO: ADD MISSING INTERNAL REGISTERS AND WIRES:
	// ============================================================================
	// reg [2:0] handle_count;                    // Number of handles for current command
	// reg [31:0] handle_values [0:2];            // Extracted handle values (max 3 handles)
	// reg [31:0] authorization_size;             // Size of authorization area
	// reg [2:0] session_count;                   // Number of sessions in command
	// reg session_handles_loaded [0:2];          // Which session handles are valid
	// reg [7:0] session_attributes [0:2];        // Session attributes for each session
	// reg [255:0] session_hmacs [0:2];           // HMAC values for each session
	
	// ============================================================================
	// TODO: ADD MISSING INPUT INTERFACES:
	// ============================================================================
	// input [255:0] object_loaded,               // Bitmask of loaded transient objects  
	// input [255:0] persistent_objects,          // Bitmask of existing persistent objects
	// input [255:0] nv_indices,                  // Bitmask of existing NV indices
	// input [7:0] session_loaded,                // Bitmask of loaded sessions
	// input [63:0] session_attributes_db,        // Session attributes from session context
	// input lockout_mode,                        // TPM in lockout mode
	// input hmac_verify_done, hmac_valid,        // HMAC verification results
	// input policy_check_done, policy_valid,     // Policy evaluation results
	
	// ============================================================================
	// TODO: ADD MISSING OUTPUT INTERFACES:
	// ============================================================================
	// output reg hmac_verify_start,              // Start HMAC verification
	// output reg [255:0] hmac_data,              // Data for HMAC computation
	// output reg [255:0] hmac_key,               // Key for HMAC computation
	// output reg policy_check_start,             // Start policy evaluation
	// output reg [255:0] policy_digest,          // Policy digest to verify
	
	// ============================================================================
	// SEQUENTIAL LOGIC BLOCK - STATE TRANSITIONS ONLY
	// ============================================================================
	always@(posedge clock or negedge reset_n) begin
		if(!reset_n) begin
			current_stage <= STAGE_IDLE;
		end
		else begin
			current_stage <= next_stage;					// update pipeline stage from combinational logic
		end
	end
	// Emma's Notes: - looks like a sequential logic block just for the state transitions but do not recommend multiple sequential logic blocks! 
	//				 - Also highly recommend having your outputs be sequential to avoid giving an output at the wrong time.
	
	// ============================================================================
	// COMBINATIONAL LOGIC BLOCK - ALL OUTPUTS AND NEXT STATE
	// ============================================================================
	always@(*) begin
		
		// Default output values
		response_valid = 1'b0;
		response_code = TPM_RC_SUCCESS;
		response_length = 16'h0;
		next_stage = current_stage;
		
		// Parse command header when in IDLE state with valid command
		if(current_stage == STAGE_IDLE && command_valid) begin
			command_tag = {command_buffer[0], command_buffer[1]};
			command_size = {command_buffer[2], command_buffer[3], 
								 command_buffer[4], command_buffer[5]};
			command_code = {command_buffer[6], command_buffer[7],
								 command_buffer[8], command_buffer[9]};
			session_present = (command_tag == TPM_ST_SESSIONS);
		end
		// Emma's Notes: - not really sure what command_valid is a check for?
		//				 - if this logic block is only determining the next state and the outputs, this "if" block should not be in this always block, recommend making these register assignments sequential.
		case(current_stage)
			// ====================================================================
			// STAGE 1: IDLE - Wait for command
			// ====================================================================
			STAGE_IDLE: begin
				if(command_valid) begin
					next_stage = STAGE_HEADER_VALID;
				end
			end

			// Emma's Notes: you said that it should be a command_ready signal which transitions to stage 2 not command_valid
			
			// ====================================================================
			// STAGE 2: HEADER VALIDATION - TPM 2.0 Part 3, Section 5.2
			// ====================================================================
			STAGE_HEADER_VALID: begin
				// IMPLEMENTED: Basic header validation
				if(command_tag != TPM_ST_NO_SESSIONS && command_tag != TPM_ST_SESSIONS) begin
					response_valid = 1'b1;
					response_code = TPM_RC_BAD_TAG;
					next_stage = STAGE_IDLE;
				end
				else if(command_size != command_length) begin
					response_valid = 1'b1;
					response_code = TPM_RC_COMMAND_SIZE;
					next_stage = STAGE_IDLE;
				end
				else if(command_code != TPM_CC_STARTUP && command_code != TPM_CC_GET_TEST_RESULT && command_code != TPM_CC_CLEAR) begin
					response_valid = 1'b1;
					response_code = TPM_RC_COMMAND_CODE;
					next_stage = STAGE_IDLE;
				end
				else begin
					next_stage = STAGE_MODE_CHECK;
				end
				
				// TODO: EXPAND COMMAND CODE VALIDATION FOR ALL SUPPORTED COMMANDS
			end

			// Emma's Notes: if the command code is not startup, gettest, or clear, they should still be able to run. check for command_valid signal instead.
			
			// ====================================================================
			// STAGE 3: MODE CHECKS - TPM 2.0 Part 3, Section 5.3
			// ====================================================================
			STAGE_MODE_CHECK: begin
				// IMPLEMENTED: Basic mode checks
				// Emma's Notes: make sure to include a check for TPM_CC_GETCAPABILITY in the failure mode state. also might make more sense to use an AND gate between the command code and tag and an OR gate between the 2 command codes, just for clarity's sake.
				if(op_state == FAILURE_MODE_STATE) begin
					// In Failure mode, only TPM2_GetTestResult allowed with no sessions
					if(command_code != TPM_CC_GET_TEST_RESULT || command_tag != TPM_ST_NO_SESSIONS) begin
						response_valid = 1'b1;
						response_code = TPM_RC_FAILURE;
						next_stage = STAGE_IDLE;
					end
					else begin
						next_stage = STAGE_HANDLE_VALID;
					end
				end
				else if(op_state != OPERATIONAL_STATE) begin
					// TPM not initialized - first command must be TPM2_Startup
					if(command_code != TPM_CC_STARTUP) begin
						response_valid = 1'b1;
						response_code = TPM_RC_INITIALIZE;
						next_stage = STAGE_IDLE;
					end
					else begin
						next_stage = STAGE_HANDLE_VALID;
					end
				end
				else begin
					next_stage = STAGE_HANDLE_VALID;
				end
				
				// TODO: ADD FIELD UPGRADE MODE CHECK IF SUPPORTED
				// Emma's Notes: no field upgrade mode check, we don't have a field upgrade mode.
			end
			
			// ====================================================================
			// STAGE 4: HANDLE VALIDATION - TPM 2.0 Part 3, Section 5.4
			// ====================================================================
			STAGE_HANDLE_VALID: begin
				// TODO: IMPLEMENT HANDLE VALIDATION:
				// 1. Extract handle count based on command_code using command schema
				// 2. For each handle (0 to handle_count-1):
				//    - Extract handle value from command_buffer[10 + i*4]
				//    - Validate handle type and range
				//    - Check if handle exists in TPM:
				//        * Transient objects: check object_loaded[handle_index]
				//        * Persistent objects: check persistent_objects[handle_index] + hierarchy enable
				//        * NV indices: check nv_indices[handle_index] + hierarchy enable + lock status
				//        * Sessions: check session_loaded[handle_index]
				//    - Validate hierarchy enable matches handle requirements
				//    - For PCR handles: validate PCR number is in supported range
				// 3. Return TPM_RC_HANDLE or TPM_RC_REFERENCE_Hx on failure
				
				if(1'b0) begin // PLACEHOLDER: Replace with actual handle validation
					response_valid = 1'b1;
					response_code = TPM_RC_HANDLE;
					next_stage = STAGE_IDLE;
				end
				else begin
					next_stage = STAGE_SESSION_VALID;
				end
			end
			// Emma's Notes: - I mean this really needs a for-loop with a case statement, try using a counter to keep track of which bit in the handle area you are checking and then add the amount of bits used by the handle type to the counter at the end	
			//				 - DO NOT move to the next stage before every handle has been checked!!!!
			
			// ====================================================================
			// STAGE 5: SESSION VALIDATION - TPM 2.0 Part 3, Section 5.5
			// ====================================================================
			STAGE_SESSION_VALID: begin
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
					
					if(1'b0) begin // PLACEHOLDER: Replace with actual session validation
						response_valid = 1'b1;
						response_code = TPM_RC_AUTH_MISSING;
						next_stage = STAGE_IDLE;
					end
					else begin
						next_stage = STAGE_AUTH_CHECK;
					end
				end
				else begin
					// TODO: CHECK IF COMMAND REQUIRES SESSIONS BUT NONE PROVIDED
					// Check command schema to see if handles have "@" decoration requiring auth
					
					if(1'b0) begin // PLACEHOLDER: Replace with command-specific session requirement check
						response_valid = 1'b1;
						response_code = TPM_RC_AUTH_MISSING;
						next_stage = STAGE_IDLE;
					end
					else begin
						next_stage = STAGE_AUTH_CHECK;
					end
				end
			end
			
			// ====================================================================
			// STAGE 6: AUTHORIZATION CHECKS - TPM 2.0 Part 3, Section 5.6
			// ====================================================================
			STAGE_AUTH_CHECK: begin
				// IMPLEMENTED: Basic physical presence check
				if(command_code == TPM_CC_CLEAR && !physical_presence) begin
					response_valid = 1'b1;
					response_code = TPM_RC_PP;
					next_stage = STAGE_IDLE;
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
					next_stage = STAGE_IDLE;
				end
				else begin
					next_stage = STAGE_PARAM_DECRYPT;
				end
			end
			
			// ====================================================================
			// STAGE 7: PARAMETER DECRYPTION - TPM 2.0 Part 3, Section 5.7
			// ====================================================================
			STAGE_PARAM_DECRYPT: begin
				// TODO: IMPLEMENT PARAMETER DECRYPTION:
				// 1. Check if any session has decrypt attribute SET
				// 2. Verify command allows parameter encryption
				// 3. Identify which parameters are encrypted
				// 4. Decrypt parameters using session symmetric key
				// 5. Validate decryption success
				// 6. Return TPM_RC_ATTRIBUTES if command doesn't allow encryption
				
				// For now, always proceed to parameter unmarshaling
				next_stage = STAGE_PARAM_UNMARSH;
			end
			
			// ====================================================================
			// STAGE 8: PARAMETER UNMARSHALING - TPM 2.0 Part 3, Section 5.8
			// ====================================================================
			STAGE_PARAM_UNMARSH: begin
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
				next_stage = STAGE_EXECUTE;
			end
			
			// ====================================================================
			// STAGE 9: COMMAND EXECUTION - TPM 2.0 Part 3, Section 5.9
			// ====================================================================
			STAGE_EXECUTE: begin
				// TODO: IMPLEMENT COMMAND EXECUTION:
				// 1. Execute command-specific logic based on command_code
				// 2. For TPM_CC_STARTUP: Set initialized state
				// 3. For TPM_CC_GET_TEST_RESULT: Return self-test results
				// 4. For cryptographic commands: Perform operations via crypto engine
				// 5. Update TPM state (objects, NV, PCRs, sessions) as required
				// 6. Handle multi-cycle operations with proper state management
				// 7. Return TPM_RC_FAILURE on execution errors
				
				// For now, always proceed to post-processing
				next_stage = STAGE_POST_PROCESS;
			end
			
			// ====================================================================
			// STAGE 10: POST-PROCESSING - TPM 2.0 Part 3, Section 5.10
			// ====================================================================
			STAGE_POST_PROCESS: begin
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
				next_stage = STAGE_IDLE;
			end
		endcase
	end
	
endmodule

