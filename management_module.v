////////////////////////////////////////////////////////////////////////////////////////
// Filename:     management_module.v
// Author:       Emma Wallace
// Date Created: 23/04/25
// Version:      5
// Description:  This module is designed to be a management module for a discrete 
//					  Trusted Platform Module (TPM).
//               The management module design is based off the Trusted Computing Group's
//					  Trusted Platform Module 2.0 Specification Revision 1.59.
//
//               This module has 16 inputs:
//					  - clock - The system clock.
//					  - reset_n - An asynchronous active-low reset signal
//					  - keyStart_n - A synchronous active-low enable signal.
//					  - tpm_cc - A 32-bit command code input signal to the TPM.
//					  - cmd_param - The 33 least significant bits of the command parameter input to the TPM.
//					  - orderlyInput - From memory, the orderly state of the last system shutdown.
//					  - initialized - From the execution engine, the state of system initialization.
//					  - authHierarchy - From the execution engine, the authorization hierarchy of the current command.
//					  - executionEng_rc - A 32-bit response code produced by the execution engine module.
//					  - locality - From the I/O module, the locality of the current command.
//					  - testsRun - From the Self-Test submodule, a 16-bit input of the amount of tests it has run.
//					  - testsPassed - From the Self-Test submodule, a 16-bit input of the amount of tests it has run and passed.
//					  - untested - From the Self-Test submodule, a 16-bit input of the amount of algorithms which still need to be tested.
//					  - nv_phEnableNV - From Non-Volatile memory, the state of the NV hierarchy enable before loss of power.
//					  - nv_shEnable - From Non-Volatile memory, the state of the platform owner hierarchy enable before loss of power.
//					  - nv_ehEnable - From Non-Volatile memory, the state of the privacy administrator hierarchy enable before loss of power.
//
//					  This module has 8 outputs:
//					  - op_state - The operational state of the TPM.
//					  - startup_type - The startup type used for the execution engine to initialize the TPM.
//					  - tpm_rc - The response code to go to the command response buffer of the TPM.
//					  - phEnable - The platform firmware hierarchy control enable for the execution engine.
//					  - phEnableNV - The Non-Volatile memory space hierarchy control enable for the execution engine.
//					  - shEnable - The platform owner hierarchy control enable for the execution engine.
//					  - ehEnable - The privacy administrator hierarchy control enable for the execution engine.
//					  - shutdownSave - The orderly state of the most recent shutdown.
//
// Modification History:
// Date        By   Version  Change Description
// ============================================
// 23/04/2025  EKRW    1     Original
// 24/09/2025  EKRW    2     Rewrote combinational logic for clarity and removed
//									  unneccessary signals.
// 25/09/2025  EKRW    3     Edits were made to the timing and tests for the failure
//					 				  mode state and incremental self test transtion were added.
//	26/09/2025  EKRW    4     Added comments for clarity.
// 30/09/2025  EKRW    5     Changes made to sequential logic block to fix timing of
//									  outputs. Changes made to hierarchy enable combinational
//									  logic block to fix logic because of board testing. Added
//									  comments for clarity.
///////////////////////////////////////////////////////////////////////////////////////

module management_module(		 
		clock,
		reset_n,
		keyStart_n,
		tpm_cc,
		cmd_param,
		orderlyInput,
		initialized,
		authHierarchy,
		executionEng_rc,
		locality,
		testsRun,
		testsPassed,
		untested,
		nv_phEnableNV,
	   nv_shEnable,
		nv_ehEnable,
		op_state,
		startup_type,
		tpm_rc,
		phEnable,
		phEnableNV,
		shEnable,
		ehEnable,
		shutdownSave
		);
		 
	input 		  clock;					// Input clock signal
	input 		  reset_n;				// Active-low input reset signal
	input			  keyStart_n;			// Active-low input enable signal

	input  [31:0] tpm_cc;				// 4-byte (16 bits) input command
	input  [32:0] cmd_param;			// 33 least-significant bits of 4086-byte input command parameters
		
	input	 [15:0] orderlyInput;		// 4-byte (16 bits) input from memory of state of last shutdown state
	input 		  initialized;			// 1-bit input intialized bit (from execution engine)
	input	 [31:0] authHierarchy;		// 4-byte (16 bits) input verifying which hiearchy was authorized (from execution engine)
	input  [31:0] executionEng_rc;	// 4-byte (16 bits) input of execution engine response code
	input  [7:0]  locality;				// 8-bit input of current locality
	input	 [15:0] testsRun;				// 4-byte (16 bits) input of amount of tests run by the self-test module, from the execution engine
	input	 [15:0] testsPassed;			// 4-byte (16 bits) input of amount of tests that have run and passed by the self-test module, from the execution engine
	input	 [15:0] untested;				// 4-byte (16 bits) input of amount of tests that still need to be run by the self-test module, from the execution engine
	input 		  nv_phEnableNV;		// 1-bit input of state of phEnableNV switch, from Non-Volatile memory
	input	        nv_shEnable;			// 1-bit input of state of shEnable switch, from Non-Volatile memory
	input         nv_ehEnable;			// 1-bit input of state of ehEnable switch, from Non-Volatile memory
		
	output [2:0]  op_state;				// 3-bit output operational state to execution engine
	output [2:0]  startup_type;		// 3-bit output startup type to execution engine
	output [31:0] tpm_rc;				// 8-byte (32 bits) output response code to command response buffer
	output 		  phEnable;				// 1-bit output platform hierarchy enable 
	output 		  phEnableNV;			// 1-bit output platform hiearchy NV memory enable
	output 		  shEnable;				// 1-bit output owner hierarchy enable
	output 		  ehEnable;				// 1-bit output privacy administrator hierarchy enable
	output [15:0] shutdownSave;		// 1-bit output shutdownType
	
	
	// Relevant Command Codes to Management module
	localparam TPM_CC_HIERARCHYCONTROL    = 32'h00000121,
				  TPM_CC_INCREMENTALSELFTEST = 32'h00000142,
				  TPM_CC_SELFTEST 			  = 32'h00000143,
				  TPM_CC_STARTUP 				  = 32'h00000144, 
				  TPM_CC_SHUTDOWN 		     = 32'h00000145,
				  TPM_CC_GETTESTRESULT 		  = 32'h0000017C,
				  TPM_CC_GETCAPABILITY 		  = 32'h0000017A;
				  
	// Relevant Response Codes to managment module			  
	localparam TPM_RC_FAILURE		= 32'h00000101,
				  TPM_RC_SUCCESS 		= 32'h00000000,
				  TPM_RC_INITIALIZE	= 32'h00000100,
				  TPM_RC_VALUE			= 32'h00000084,
				  TPM_RC_AUTH_TYPE   = 32'h00000124;
	
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
	
	// Startup types
	localparam TPM_DONE = 3'd0, TPM_RESET = 3'd1, TPM_RESTART = 3'd2, TPM_RESUME = 3'd3, TPM_TYPE = 3'd4;
	
	// Operational states
	localparam POWER_OFF_STATE = 3'b000, INITIALIZATION_STATE = 3'b001, STARTUP_STATE = 3'b010, OPERATIONAL_STATE = 3'b011, SELF_TEST_STATE = 3'b100, FAILURE_MODE_STATE = 3'b101, SHUTDOWN_STATE = 3'b110;	// Operational states
	
	// Registers for logic blocks
	reg pHierarchy, pHierarchyNV, sHierarchy, eHierarchy;
	reg phEnable, phEnableNV, shEnable, ehEnable, tpmi_yes_no, authPassed, s_initialized;
	
	reg [15:0] startup_input, shutdown_input, s_testsPassed, s_testsRun, s_untested, shutdownSave;
		 
	reg [2:0] startup_type, startup_state;
	reg [2:0] op_state, state;
	reg [31:0] tpm_rc_state, tpmi_rh_enables, tpmi_rh_hierarchy, tpm_rc;
	
	wire startupEnable, operationEnable, selftestEnable, shutdownEnable;
	
	// Sequential logic block for managing timing of inputs and outputs
	always@(posedge clock or negedge reset_n) begin
		if(!reset_n) begin
			phEnable     <= 1'b0;
			phEnableNV   <= 1'b0;
			shEnable   	 <= 1'b0;
			ehEnable   	 <= 1'b0;
			op_state     <= POWER_OFF_STATE;
			s_initialized <= 1'b0;
			shutdownSave <= TPM_SU_CLEAR;
			s_testsPassed<= 16'd0;
			s_testsRun	 <= 16'd0;
			s_untested   <= 16'd0;
		end
		else begin
			if(!keyStart_n) begin
				op_state     <= state;							// update operational state from combinational logic
				tpm_rc		 <= tpm_rc_state;					// update response code from combinational logic
				startup_input <= cmd_param[15:0];			// store startup input from command parameters input
				shutdown_input <= orderlyInput;				// reload orderly shutdown state from last shutdown
				if(startupEnable) begin
					startup_type <= startup_state;
					s_initialized <= initialized;
					phEnable     <= pHierarchy;
					phEnableNV   <= pHierarchyNV;
					shEnable     <= sHierarchy;
					ehEnable     <= eHierarchy;
				end
				else if(operationEnable) begin
					tpmi_rh_hierarchy <= authHierarchy;
					tpmi_rh_enables <= cmd_param[32:1];
					tpmi_yes_no    <= cmd_param[0];
					phEnable     <= pHierarchy;
					phEnableNV   <= pHierarchyNV;
					shEnable     <= sHierarchy;
					ehEnable     <= eHierarchy;
				end
				else if(selftestEnable) begin
					s_testsPassed<= testsPassed;
					s_testsRun	 <= testsRun;
					s_untested   <= untested;
				end
				else if(shutdownEnable) begin
					shutdownSave <= cmd_param[15:0];
				end
			end
		end
	end

	// Enable signals to activate input information collection at operational states
	assign startupEnable = (op_state == STARTUP_STATE);
	assign operationEnable = (op_state == OPERATIONAL_STATE);
	assign selftestEnable = (op_state == SELF_TEST_STATE);
	assign shutdownEnable = (op_state == SHUTDOWN_STATE);
	
	
	// Always block for managing operational states FSM
	// Reference: Trusted Computing Group TPM 2.0 Specification Rev. 1.59, Part 1: Architecture, Section 12: TPM Operational States
	// Note: We opted to not include the FPGA Field Upgrade Mode due to it being designed for upgrading firmware and not hardware.
	always@(tpm_cc, op_state, s_initialized, startup_type, s_untested, s_testsPassed, s_testsRun) begin
		case(op_state)
			POWER_OFF_STATE: 		 begin
											 state = INITIALIZATION_STATE;			// Initialize in the Power-Off state, then automatically move to the initialization state
										 end
			INITIALIZATION_STATE: begin
										    if(tpm_cc == TPM_CC_STARTUP) begin		// Only move to the Startup state when you recieve the startup command
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
											 else if(startup_type == TPM_TYPE) begin	// If startup type inputs are not valid, move back to initialization state, so ROT can force new inputs
												state = INITIALIZATION_STATE;
											 end
											 else begin
												state = STARTUP_STATE;
											 end
										 end
			OPERATIONAL_STATE: 	 begin
											if(tpm_cc == TPM_CC_SELFTEST || tpm_cc == TPM_CC_INCREMENTALSELFTEST) begin	// If command asks for self-test go to Self-Test state
												 state = SELF_TEST_STATE;
											end
											else if(tpm_cc == TPM_CC_SHUTDOWN) begin		// If command asks for shutdown go to Shutdown state
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
	always@(op_state, startup_input, shutdown_input) begin
		if(op_state == STARTUP_STATE) begin
			if(shutdown_input == TPM_SU_STATE) begin
				if(startup_input == TPM_SU_STATE) begin
					startup_state = TPM_RESUME;
				end
				else begin
					startup_state = TPM_RESTART;
				end
			end
			else begin
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
	always@(op_state, startup_type, locality, tpmi_rh_hierarchy, tpmi_rh_enables, tpmi_yes_no, tpm_cc, phEnableNV, phEnable, shEnable, ehEnable, nv_phEnableNV, nv_shEnable, nv_ehEnable) begin
		// default values for safe behavior:
		pHierarchy   = phEnable;
		pHierarchyNV = phEnableNV;
		sHierarchy   = shEnable;
		eHierarchy   = ehEnable;
		
		// cases where hierarchy enables change:
		if(op_state == STARTUP_STATE && startup_type != TPM_DONE && startup_type != TPM_TYPE) begin
			pHierarchy = 1'b1;
			// TPM Resume uploads previous states of hierarchy enables from Non-Volatile memory
			if(startup_type == TPM_RESUME) begin
				pHierarchyNV = nv_phEnableNV;
				sHierarchy = nv_shEnable;
				eHierarchy = nv_ehEnable;
			end
			// TPM Restart and TPM Reset set the hierarchy enable switches to on
			else if(startup_type == TPM_RESTART || startup_type == TPM_RESET) begin
				pHierarchyNV = 1'b1;
				sHierarchy = 1'b1;
				eHierarchy = 1'b1;
			end
		end
		else if(op_state == OPERATIONAL_STATE) begin
			if(tpm_cc == TPM_CC_HIERARCHYCONTROL && locality == 8'b00000001) begin
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
				else if(tpmi_rh_hierarchy == TPM_RH_OWNER && tpmi_rh_enables == TPM_RH_OWNER) begin
					if(tpmi_yes_no == TPMI_NO) begin
						sHierarchy = tpmi_yes_no;
					end
				end
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
	always@(tpm_rc, tpm_cc, op_state, shutdown_input, startup_input, s_initialized, executionEng_rc, locality, tpmi_rh_hierarchy, tpmi_rh_enables, tpmi_yes_no, untested, testsPassed, testsRun) begin
		tpm_rc_state = tpm_rc;								// Default of last response code
		if(op_state == INITIALIZATION_STATE) begin
			// If command code is not startup, return error
			if(tpm_cc != TPM_CC_STARTUP) begin
				tpm_rc_state = TPM_RC_INITIALIZE;
			end
		end
	   else if(op_state == STARTUP_STATE) begin
			// If startup_in = TPM_SU_STATE and shutdown_in = TPM_SU_CLEAR, return error
			if(startup_input == TPM_SU_STATE && shutdown_input == TPM_SU_CLEAR) begin
				tpm_rc_state = TPM_RC_VALUE;
			end
			
			// When execution engine finishes initializing, return success
			if(s_initialized == 1'b1) begin
				tpm_rc_state = TPM_RC_SUCCESS;
			end
		end
		else if(op_state == OPERATIONAL_STATE) begin
			if(tpm_cc == TPM_CC_HIERARCHYCONTROL && locality == 8'b00000001) begin
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
					tpm_rc_state = executionEng_rc;
				end
			end
			else begin
				tpm_rc_state = executionEng_rc;
			end
		end
		else if(op_state == SELF_TEST_STATE) begin
			if(testsPassed != testsRun) begin
				tpm_rc_state = TPM_RC_FAILURE;
			end
			else begin
				tpm_rc_state = executionEng_rc;
			end
		end
		else if(op_state == FAILURE_MODE_STATE) begin
			if(tpm_cc == TPM_CC_GETTESTRESULT) begin
				tpm_rc_state = executionEng_rc;
			end
			else if(tpm_cc == TPM_CC_GETCAPABILITY) begin
				tpm_rc_state = executionEng_rc;
			end
			else begin
				// If command code is not authorized by the FAILURE_MODE_STATE, return error
				tpm_rc_state = TPM_RC_FAILURE;
			end
		end
	end
	
endmodule




