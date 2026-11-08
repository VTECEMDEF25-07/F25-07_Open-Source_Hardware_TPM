////////////////////////////////////////////////////////////////////////////////////////
// Filename:     management_module.v
// Author:       Emma Wallace
// Date Created: 23/04/25
// Version:      7
// Description:  This module is designed to be a management module for a discrete 
//					  Trusted Platform Module (TPM).
//               The management module design is based off the Trusted Computing Group's
//					  Trusted Platform Module 2.0 Specification Revision 1.59.
//
//               This module has 16 inputs:
//					  - clock_i - The system clock_i.
//					  - reset_n_i - An asynchronous active-low reset signal
//					  - keyStart_n_i - A synchronous active-low enable signal.
//					  - tpm_cc_i - A 16-bit command code index input signal to the TPM.
//					  - cmd_param_i - The 33 least significant bits of the command parameter input to the TPM.
//					  - orderlyInput_i - From memory, the orderly state of the last system shutdown.
//					  - initialized_i - From the execution engine, the state of system initialization.
//					  - authHierarchy_i - From the execution engine, the authorization hierarchy of the current command.
//					  - executionEng_rc_i - A 32-bit response code produced by the execution engine module.
//					  - locality_i - From the I/O module, the locality_i of the current command.
//					  - testsRun_i - From the Self-Test submodule, a 16-bit input of the amount of tests it has run.
//					  - testsPassed_i - From the Self-Test submodule, a 16-bit input of the amount of tests it has run and passed.
//					  - untested_i - From the Self-Test submodule, a 16-bit input of the amount of algorithms which still need to be tested.
//					  - nv_phEnableNV_i - From Non-Volatile memory, the state of the NV hierarchy enable before loss of power.
//					  - nv_shEnable_i - From Non-Volatile memory, the state of the platform owner hierarchy enable before loss of power.
//					  - nv_ehEnable_i - From Non-Volatile memory, the state of the privacy administrator hierarchy enable before loss of power.
//
//					  This module has 8 outputs:
//					  - op_state_o - The operational state of the TPM.
//					  - startup_type_o - The startup type used for the execution engine to initialize the TPM.
//					  - tpm_rc_o - The response code to go to the command response buffer of the TPM.
//					  - phEnable_o - The platform firmware hierarchy control enable for the execution engine.
//					  - phEnableNV_o - The Non-Volatile memory space hierarchy control enable for the execution engine.
//					  - shEnable_o - The platform owner hierarchy control enable for the execution engine.
//					  - ehEnable_o - The privacy administrator hierarchy control enable for the execution engine.
//					  - shutdownSave_o - The orderly state of the most recent shutdown.
//
// Modification History:
// Date        By   Version  Change Description
// ============================================
// 23/04/2025  EKRW    1     Original
// 24/09/2025  EKRW    2     Rewrote combinational logic for clarity and removed
//									  unneccessary signals.
// 25/09/2025  EKRW    3     Edits were made to the timing and tests for the failure
//					 				  mode state and incremental self test transtion were added.
// 26/09/2025  EKRW    4     Added comments for clarity.
// 30/09/2025  EKRW    5     Changes made to sequential logic block to fix timing of
//									  outputs. Changes made to hierarchy enable combinational
//									  logic block to fix logic because of board testing. Added
//									  comments for clarity.
// 01/10/2025  EKRW    6     Made changes to sequential block for Failure Mode State.
// 04/11/2025  EKRW    7     Fixed command code and response code formats, plus added 
//									  more comments
// 06/11/2025  EKRW    8     Added response code output for if command TPM_CC_Startup tries
//							 to run when startup procedures have already been run.
///////////////////////////////////////////////////////////////////////////////////////

module management_module(		 
		clock_i,
		reset_n_i,
		keyStart_n_i,
		tpm_cc_i,
		cmd_param_i,
		orderlyInput_i,
		initialized_i,
		authHierarchy_i,
		executionEng_rc_i,
		locality_i,
		testsRun_i,
		testsPassed_i,
		untested_i,
		nv_phEnableNV_i,
	   nv_shEnable_i,
		nv_ehEnable_i,
		op_state_o,
		startup_type_o,
		tpm_rc_o,
		phEnable_o,
		phEnableNV_o,
		shEnable_o,
		ehEnable_o,
		shutdownSave_o
		);
		 
	input 		  clock_i;					// Input clock_i signal
	input 		  reset_n_i;				// Active-low input reset signal
	input			  keyStart_n_i;			// Active-low input enable signal

	input  [15:0] tpm_cc_i;				// 2-byte (16 bits) input command
	input  [32:0] cmd_param_i;			// 33 least-significant bits of 4086-byte input command parameters
		
	input	 [15:0] orderlyInput_i;		// 2-byte (16 bits) input from memory of state of last shutdown state
	input 		  initialized_i;			// 1-bit input intialized bit (from execution engine)
	input	 [31:0] authHierarchy_i;		// 2-byte (16 bits) input verifying which hiearchy was authorized (from execution engine)
	input  [31:0] executionEng_rc_i;	// 2-byte (16 bits) input of execution engine response code
	input  [7:0]  locality_i;				// 4-bit input of current locality_i
	input	 [15:0] testsRun_i;				// 2-byte (16 bits) input of amount of tests run by the self-test module, from the execution engine
	input	 [15:0] testsPassed_i;			// 2-byte (16 bits) input of amount of tests that have run and passed by the self-test module, from the execution engine
	input	 [15:0] untested_i;				// 2-byte (16 bits) input of amount of tests that still need to be run by the self-test module, from the execution engine
	input 		  nv_phEnableNV_i;		// 1-bit input of state of phEnableNV_o switch, from Non-Volatile memory
	input	        nv_shEnable_i;			// 1-bit input of state of shEnable_o switch, from Non-Volatile memory
	input         nv_ehEnable_i;			// 1-bit input of state of ehEnable_o switch, from Non-Volatile memory
		
	output [2:0]  op_state_o;				// 3-bit output operational state to execution engine
	output [2:0]  startup_type_o;		// 3-bit output startup type to execution engine
	output [31:0] tpm_rc_o;				// 4-byte (32 bits) output response code to command response buffer
	output 		  phEnable_o;				// 1-bit output platform hierarchy enable 
	output 		  phEnableNV_o;			// 1-bit output platform hiearchy NV memory enable
	output 		  shEnable_o;				// 1-bit output owner hierarchy enable
	output 		  ehEnable_o;				// 1-bit output privacy administrator hierarchy enable
	output [15:0] shutdownSave_o;		// 2-byte (16 bits) output shutdownType
	
	
	// Relevant Command Codes to Management module
	localparam TPM_CC_HIERARCHYCONTROL    = 16'h0121,
				  TPM_CC_INCREMENTALSELFTEST = 16'h0142,
				  TPM_CC_SELFTEST 			  = 16'h0143,
				  TPM_CC_STARTUP 				  = 16'h0144, 
				  TPM_CC_SHUTDOWN 		     = 16'h0145,
				  TPM_CC_GETTESTRESULT 		  = 16'h017C,
				  TPM_CC_GETCAPABILITY 		  = 16'h017A;
				  
	// Relevant Response Codes to managment module	
	localparam RC_VER1 = 12'h100,	// set for all format 0 response codes
				  RC_FMT1 = 12'h080,	// This bit is SET in all format 1 response codes 
											// The codes in this group may have a value added to them to indicate the handle, session, or parameter to which they apply.
				  RC_WARN = 12'h900;	// set for warning response codes
				  
	localparam TPM_RC_SUCCESS 		= 12'h000,
				  TPM_RC_INITIALIZE	= RC_VER1 + 12'h000,		// TPM not initialized_i by TPM2_Startup or already initialized_i
				  TPM_RC_FAILURE		= RC_VER1 + 12'h001,		// commands not being accepted because of a TPM failure
				  TPM_RC_AUTH_TYPE   = RC_VER1 + 12'h024,		// authorization handle is not correct for command
				  TPM_RC_VALUE			= RC_FMT1 + 12'h004;		// value is out of range or is not correct for the context
	
	// TPM_SU command parameters:
	localparam TPM_SU_CLEAR = 4'h0000, TPM_SU_STATE = 4'h0001;
	
	// TPMI_YES_NO command parameters:
	localparam TPMI_YES = 1'b1, TPMI_NO = 1'b0;
				  
	// Relevant TPM_RH (TPMI_RH_ENABLES, TPMI_RH_HIERARCHY):
	localparam TPM_RH_NULL        = 32'h40000007,
				  TPM_RH_OWNER			= 32'h40000001,
				  TPM_RH_ENDORSEMENT = 32'h4000000B,
				  TPM_RH_PLATFORM    = 32'h4000000C,
				  TPM_RH_PLATFORM_NV = 32'h4000000D;
				  
	// Localities:
	localparam TPM_LOC_ZERO  = 8'b00000001,
				  TPM_LOC_ONE   = 8'b00000010,
				  TPM_LOC_TWO   = 8'b00000100,
				  TPM_LOC_THREE = 8'b00001000,
				  TPM_LOC_FOUR  = 8'b00010000;
	
	// Startup types
	localparam TPM_DONE = 3'd0, TPM_RESET = 3'd1, TPM_RESTART = 3'd2, TPM_RESUME = 3'd3, TPM_TYPE = 3'd4;
	
	// Operational states
	localparam POWER_OFF_STATE = 3'b000, INITIALIZATION_STATE = 3'b001, STARTUP_STATE = 3'b010, OPERATIONAL_STATE = 3'b011, SELF_TEST_STATE = 3'b100, FAILURE_MODE_STATE = 3'b101, SHUTDOWN_STATE = 3'b110;	// Operational states
	
	// Registers for logic blocks
	reg pHierarchy, pHierarchyNV, sHierarchy, eHierarchy;
	reg phEnable_o, phEnableNV_o, shEnable_o, ehEnable_o, tpmi_yes_no, authPassed, s_initialized;
	
	reg [15:0] startup_input, shutdown_input, s_testsPassed, s_testsRun, s_untested, shutdownSave_o;
		 
	reg [2:0] startup_type_o, startup_state;
	reg [2:0] op_state_o, state;
	reg [31:0] tpmi_rh_enables, tpmi_rh_hierarchy, tpm_rc_o;
	reg [11:0] tpm_rc_state;
	
	wire startupEnable, operationEnable, shutdownEnable; //, selftestEnable
	
	// Sequential logic block for managing timing of inputs and outputs
	always@(posedge clock_i or negedge reset_n_i) begin
		if(!reset_n_i) begin
			phEnable_o     <= 1'b0;
			phEnableNV_o   <= 1'b0;
			shEnable_o   	 <= 1'b0;
			ehEnable_o   	 <= 1'b0;
			op_state_o     <= POWER_OFF_STATE;
			s_initialized <= 1'b0;
			s_testsPassed <= 16'd0;
			s_testsRun	  <= 16'd0;
			s_untested    <= 16'd0;
			shutdownSave_o <= TPM_SU_CLEAR;
		end
		else begin
			tpm_rc_o		 <= {20'h0,tpm_rc_state};					// update response code from combinational logic
			if(!keyStart_n_i) begin
				op_state_o     <= state;							// update operational state from combinational logic
				startup_input <= cmd_param_i[15:0];			// store startup input from command parameters input
				shutdown_input <= orderlyInput_i;				// reload orderly shutdown state from last shutdown
				s_testsPassed <= testsPassed_i;
				s_testsRun	  <= testsRun_i;
				s_untested    <= untested_i;
				if(startupEnable) begin
					startup_type_o <= startup_state;
					s_initialized <= initialized_i;
					phEnable_o     <= pHierarchy;
					phEnableNV_o   <= pHierarchyNV;
					shEnable_o     <= sHierarchy;
					ehEnable_o     <= eHierarchy;
				end
				else if(operationEnable) begin
					tpmi_rh_hierarchy <= authHierarchy_i;
					tpmi_rh_enables <= cmd_param_i[32:1];
					tpmi_yes_no    <= cmd_param_i[0];
					phEnable_o     <= pHierarchy;
					phEnableNV_o   <= pHierarchyNV;
					shEnable_o     <= sHierarchy;
					ehEnable_o     <= eHierarchy;
				end
				else if(shutdownEnable) begin
					shutdownSave_o <= cmd_param_i[15:0];
				end
			end
		end
	end

	// Enable signals to activate input information collection at operational states
	assign startupEnable = (op_state_o == STARTUP_STATE);
	assign operationEnable = (op_state_o == OPERATIONAL_STATE);
	assign shutdownEnable = (op_state_o == SHUTDOWN_STATE);
	
	
	// Always block for managing operational states FSM
	// Reference: Trusted Computing Group TPM 2.0 Specification Rev. 1.59, Part 1: Architecture, Section 12: TPM Operational States
	// Note: We opted to not include the FPGA Field Upgrade Mode due to it being designed for upgrading firmware and not hardware.
	always@(tpm_cc_i, op_state_o, s_initialized, startup_type_o, s_untested, s_testsPassed, s_testsRun) begin
		case(op_state_o)
			POWER_OFF_STATE: 		 begin
											 state = INITIALIZATION_STATE;			// Initialize in the Power-Off state, then automatically move to the initialization state
										 end
			INITIALIZATION_STATE: begin
										    if(tpm_cc_i == TPM_CC_STARTUP) begin		// Only move to the Startup state when you recieve the startup command
											 	 state = STARTUP_STATE;
											 end
									 		 else begin
												 state = INITIALIZATION_STATE;
											 end
										 end
			STARTUP_STATE:			 begin
											 if(s_initialized == 1'b1) begin			// When execution engine finishes initializing, move to the operational state
												state = OPERATIONAL_STATE;
											 end
											 else if(startup_type_o == TPM_TYPE) begin	// If startup type inputs are not valid, move back to initialization state, so ROT can force new inputs
												state = INITIALIZATION_STATE;
											 end
											 else begin
												state = STARTUP_STATE;
											 end
										 end
			OPERATIONAL_STATE: 	 begin
											if(tpm_cc_i == TPM_CC_SELFTEST || tpm_cc_i == TPM_CC_INCREMENTALSELFTEST) begin	// If command asks for self-test go to Self-Test state
												 state = SELF_TEST_STATE;
											end
											else if(tpm_cc_i == TPM_CC_SHUTDOWN) begin		// If command asks for shutdown go to Shutdown state
												 state = SHUTDOWN_STATE;
											end
											else begin
												 // Execution engine processes command
												 state = OPERATIONAL_STATE;
											end
										 end
			SELF_TEST_STATE:		 begin
											if(s_testsPassed == s_testsRun) begin		
												if(s_untested == 16'd0) begin				// When no tests fail and all tests are run, go back to operational state
													state = OPERATIONAL_STATE;
												end
												else begin										
													state = SELF_TEST_STATE;				// When no tests have failed so far and testing is incomplete, stay in Self-Test state
												end
											 end
											 else begin
												 state = FAILURE_MODE_STATE;				// If a test fails, move to Failure Mode state
											 end
										 end
			FAILURE_MODE_STATE:	 begin
											 state = FAILURE_MODE_STATE;					// Stay in Failure Mode state forever
										 end
			SHUTDOWN_STATE:		 begin
											 state = OPERATIONAL_STATE;
										 end
			default:					 begin
											 state = 3'bxxx;
										 end
		endcase
	end
	
	
	// Combinational logic block for determining startup type output
	// Reference: Trusted Computing Group TPM 2.0 Specification Rev. 1.59, Part 1: Architecture, Section 12.2.3: Startup State
	always@(op_state_o, startup_input, shutdown_input) begin
		if(op_state_o == STARTUP_STATE) begin
			if(shutdown_input == TPM_SU_STATE) begin
				if(startup_input == TPM_SU_STATE) begin
					startup_state = TPM_RESUME;
				end
				else begin
					startup_state = TPM_RESTART;
				end
			end
			else begin
				// If previous shutdown was disorderly and startup type input is equal to STARTUP_STATE, 
				// send the TPM back to initialization state and CRT should force the input startup type to STARTUP_CLEAR.
				if(startup_input == TPM_SU_STATE) begin
					startup_state = TPM_TYPE;
				end
				else begin
					startup_state = TPM_RESET;
				end
			end
		end
		else begin
			startup_state = TPM_DONE;
		end
	end
	
	
	// Combinational logic block for managing states of hierarchy enable switches for control domains
	// Reference: Trusted Computing Group TPM 2.0 Specification Rev. 1.59, Part 1: Architecture, Section 13: TPM Control Domains
	//				  & Part 3: Commands, Section 24.2: TPM2_HierarchyControl
	always@(op_state_o, startup_type_o, locality_i, tpmi_rh_hierarchy, tpmi_rh_enables, tpmi_yes_no, tpm_cc_i, phEnableNV_o, phEnable_o, shEnable_o, ehEnable_o, nv_phEnableNV_i, nv_shEnable_i, nv_ehEnable_i) begin
		// default values for safe behavior:
		pHierarchy   = phEnable_o;
		pHierarchyNV = phEnableNV_o;
		sHierarchy   = shEnable_o;
		eHierarchy   = ehEnable_o;
		
		// cases where hierarchy enables change:
		if(op_state_o == STARTUP_STATE && startup_type_o != TPM_DONE && startup_type_o != TPM_TYPE) begin
			// In all startup cases platform hierarchy enable is set.
			pHierarchy = 1'b1;
			// TPM Resume uploads previous states of hierarchy enables from Non-Volatile memory
			if(startup_type_o == TPM_RESUME) begin
				pHierarchyNV = nv_phEnableNV_i;
				sHierarchy = nv_shEnable_i;
				eHierarchy = nv_ehEnable_i;
			end
			// TPM Restart and TPM Reset set the hierarchy enable switches to on
			else if(startup_type_o == TPM_RESTART || startup_type_o == TPM_RESET) begin
				pHierarchyNV = 1'b1;
				sHierarchy = 1'b1;
				eHierarchy = 1'b1;
			end
		end
		else if(op_state_o == OPERATIONAL_STATE) begin
			// TPM2_HierarchyControl is the only command code that directly changes the hierarchy enable switches
			// TPM must be in locality_i zero to do this command.
			if(tpm_cc_i == TPM_CC_HIERARCHYCONTROL && locality_i == TPM_LOC_ZERO) begin
				// Platform authorization will let you set or clear every hierarchy enable switch except its own, which it can only clear.
				if(tpmi_rh_hierarchy == TPM_RH_PLATFORM) begin
					if(tpmi_rh_enables == TPM_RH_ENDORSEMENT) begin
						eHierarchy = tpmi_yes_no;
					end
					else if(tpmi_rh_enables == TPM_RH_OWNER) begin
						sHierarchy = tpmi_yes_no;
					end
					else if(tpmi_rh_enables == TPM_RH_PLATFORM_NV) begin
						pHierarchyNV = tpmi_yes_no;
					end
					else if(tpmi_rh_enables == TPM_RH_PLATFORM) begin
						if(tpmi_yes_no == TPMI_NO) begin
							pHierarchy = tpmi_yes_no;
						end
					end
				end
				// Owner authorization will only give you the capability to clear the platform owner hierarchy enable switch
				else if(tpmi_rh_hierarchy == TPM_RH_OWNER && tpmi_rh_enables == TPM_RH_OWNER) begin
					if(tpmi_yes_no == TPMI_NO) begin
						sHierarchy = tpmi_yes_no;
					end
				end
				// Endorsement authorization will only give you the capability to clear the endorsement hierarchy enable switch
				else if(tpmi_rh_hierarchy == TPM_RH_ENDORSEMENT && tpmi_rh_enables == TPM_RH_ENDORSEMENT) begin
					if(tpmi_yes_no == TPMI_NO) begin
						eHierarchy = tpmi_yes_no;
					end
				end
			end
		end
	end
	
	
	// Combinational logic block to determine response code to output to command response buffer
	// Reference: Trusted Computing Group TPM 2.0 Specification Rev. 1.59, Part 1: Architecture, Section 12: TPM Operational States,
	//				  Section 13: TPM Control Domains, & Part 3: Commands, Section 24.2: TPM2_HierarchyControl
	always@(tpm_rc_o, tpm_cc_i, op_state_o, shutdown_input, startup_input, s_initialized, executionEng_rc_i, locality_i, tpmi_rh_hierarchy, tpmi_rh_enables, tpmi_yes_no, untested_i, testsPassed_i, testsRun_i) begin
		tpm_rc_state = tpm_rc_o;								// Default of last response code
		if(op_state_o == INITIALIZATION_STATE) begin
			// If command code is not startup, return error
			if(tpm_cc_i != TPM_CC_STARTUP) begin
				tpm_rc_state = TPM_RC_INITIALIZE;
			end
		end
	   else if(op_state_o == STARTUP_STATE) begin
			// If startup_in = TPM_SU_STATE and shutdown_in = TPM_SU_CLEAR, return error
			if(startup_input == TPM_SU_STATE && shutdown_input == TPM_SU_CLEAR) begin
				tpm_rc_state = TPM_RC_VALUE;
			end
			
			// When execution engine finishes initializing, return success
			if(s_initialized == 1'b1) begin
				tpm_rc_state = TPM_RC_SUCCESS;
			end
		end
		else if(op_state_o == OPERATIONAL_STATE) begin
			// If you reach the operational state, startup has completed, therefore TPM_CC_Startup is no longer a valid command
			if(tpm_cc_i == TPM_CC_STARTUP && initialized_i) begin
				tpm_rc_state = TPM_RC_INITIALIZE;
			end
			if(tpm_cc_i == TPM_CC_HIERARCHYCONTROL && locality_i == TPM_LOC_ZERO) begin
				if(tpmi_rh_hierarchy == TPM_RH_PLATFORM) begin
					if(tpmi_rh_enables == TPM_RH_ENDORSEMENT ||
						tpmi_rh_enables == TPM_RH_OWNER || 
						tpmi_rh_enables == TPM_RH_PLATFORM_NV ||
					   (tpmi_rh_enables == TPM_RH_PLATFORM && tpmi_yes_no == TPMI_NO)) begin
						tpm_rc_state = TPM_RC_SUCCESS;
					end
					else begin
						// When hierarchy is platform firmware and it tries to set platform enable, return error
						tpm_rc_state = TPM_RC_VALUE;
					end
				end
				else if(tpmi_rh_hierarchy == TPM_RH_OWNER) begin
					// Hierarchy platform owner may only clear its own enable switch
					if(tpmi_yes_no == TPMI_NO && tpmi_rh_enables == TPM_RH_OWNER) begin
						tpm_rc_state = TPM_RC_SUCCESS;
					end
					else begin
						tpm_rc_state = TPM_RC_AUTH_TYPE;
					end
				end
				else if(tpmi_rh_hierarchy == TPM_RH_ENDORSEMENT) begin
					// Hierarchy endorsement may only clear its own enable switch
					if(tpmi_yes_no == TPMI_NO && tpmi_rh_enables == TPM_RH_ENDORSEMENT) begin
						tpm_rc_state = TPM_RC_SUCCESS;
					end
					else begin
						tpm_rc_state = TPM_RC_AUTH_TYPE;
					end
				end
				else begin
					tpm_rc_state = executionEng_rc_i;
				end
			end
			else begin
				tpm_rc_state = executionEng_rc_i;
			end
		end
		else if(op_state_o == SELF_TEST_STATE) begin
			if(testsPassed_i != testsRun_i) begin
				tpm_rc_state = TPM_RC_FAILURE;
			end
			else begin
				tpm_rc_state = executionEng_rc_i;
			end
		end
		else if(op_state_o == FAILURE_MODE_STATE) begin
			// In failure mode, only TPM2_GetTestResult and TPM2_CetCapability commands can be run, all other commands induce failure.
			if(tpm_cc_i == TPM_CC_GETTESTRESULT) begin
				tpm_rc_state = executionEng_rc_i;
			end
			else if(tpm_cc_i == TPM_CC_GETCAPABILITY) begin
				tpm_rc_state = executionEng_rc_i;
			end
			else begin
				// If command code is not authorized by the FAILURE_MODE_STATE, return error
				tpm_rc_state = TPM_RC_FAILURE;
			end
		end
	end
	
endmodule








