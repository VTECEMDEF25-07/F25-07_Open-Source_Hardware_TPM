////////////////////////////////////////////////////////////////////////////////////////
// Filename:     tb_managementmodule_startuptypes.v
// Author:       Emma Wallace
// Date Created: 25/09/25
// Version:      1
// Description:  This module serves as a simple testbench for the management module.
//               One management module is instantiated and stimulated with a simple
//               sequence to test the startup type logic in the Startup state.
//
//               There are no inputs or outputs to this module.
//
//
// Modification History:
// Date        By   Version  Change Description
// ============================================
// 25/09/2025  EKRW    1     Original
///////////////////////////////////////////////////////////////////////////////////////

`timescale 1ns/1ps

module tb_managementmodule_startuptypes();
// Declare local wires and regs
   reg         clk_enable;				// Locally-created clock enable signal
   wire        clk_out;					// Clock produced by the clk module
	
   reg         tpm_reset_n;			// Locally-created active-low TPM reset signal
   reg         tpm_enable_n;			// Locally-created active-low tpm enable signal for testing
	reg  [31:0] tpm_cc_in;				// Locally-created command code input signal
	reg  [32:0] cmd_param_in;			// Locally-created command parameters input signal
	reg  [15:0] orderlyInput_in;		// Locally-created orderly shutdown input signal from NV memory
	reg			initialized_in;		// Locally-created initialized input signal from execution engine
	reg  [31:0] authHierarchy_in;		// Locally-created 4-byte input verifying which hiearchy was authorized (from execution engine)
	reg  [31:0] executionEng_rc_in;	// Locally-created 4-byte execution engine response code input
	reg  [7:0]  locality_in;			// Locally-created 8-bit input of current locality
	reg  [15:0] testsRun_in;			// Locally-created input from self-test module of amount of tests run
	reg  [15:0] testsPassed_in;		// Locally-created input from self-test module of amount of tests passed
	reg  [15:0] untested_in;			// Locally-created input from self-test module of amount of tests not run
	reg 		   nv_phEnableNV_in;		// Locally-created input of Non-Volatile memory of last phEnableNV state
	reg	      nv_shEnable_in;		// Locally-created input of Non-Volatile memory of last shEnable state
	reg         nv_ehEnable_in;		// Locally-created input of Non-Volatile memory of last ehEnable state
								
	wire [2:0]  op_state_out;			// 3-bit operational state output to execution engine
	wire [2:0]  startup_type_out;		// 3-bit startup type output to execution engine
	wire [31:0] tpm_rc_out;				// 4-byte output response code
	wire 		   phEnable_out;			// 1-bit output platform hierarchy enable
	wire 		   phEnableNV_out;		// 1-bit output platform hiearchy NV memory enable
	wire 		   shEnable_out;			// 1-bit output owner hierarchy enable
	wire 		   ehEnable_out;			// 1-bit output privacy administrator hierarchy enable
	wire [15:0] shutdownSave_out;		// 1-bit output shutdownType
	

// Instantiate the clock generator with a period of 20 ns
   clk CLK1(clk_enable, clk_out);

// Instantiate the management module
	
	management_module MM1(.clock_i(clk_out),
								 .reset_n_i(tpm_reset_n),
								 .keyStart_n_i(tpm_enable_n),
								 .tpm_cc_i(tpm_cc_in),
								 .cmd_param_i(cmd_param_in),
								 .orderlyInput_i(orderlyInput_in),
								 .initialized_i(initialized_in),
								 .authHierarchy_i(authHierarchy_in),
								 .executionEng_rc_i(executionEng_rc_in),
								 .locality_i(locality_in),
								 .testsRun_i(testsRun_in),
								 .testsPassed_i(testsPassed_in),
								 .untested_i(untested_in),
								 .nv_phEnableNV_i(nv_phEnableNV_in),
								 .nv_shEnable_i(nv_shEnable_in),
								 .nv_ehEnable_i(nv_ehEnable_in),
								 .op_state_o(op_state_out),
								 .startup_type_o(startup_type_out),
								 .tpm_rc_o(tpm_rc_out),
								 .phEnable_o(phEnable_out),
								 .phEnableNV_o(phEnableNV_out),
								 .shEnable_o(shEnable_out),
								 .ehEnable_o(ehEnable_out),
								 .shutdownSave_o(shutdownSave_out)
								 );


	// Stimulus logic
  initial begin
	 clk_enable = 1'b1;
	 #20;
	 
    // Initialize all inputs
    tpm_reset_n = 1'b0;
    tpm_enable_n = 1'b1;
    tpm_cc_in = 32'd0;
    cmd_param_in = 33'd0;
    orderlyInput_in = 16'd0;
    initialized_in = 1'b0;
    authHierarchy_in = 32'd0;
    executionEng_rc_in = 32'd0;
    locality_in = 8'd1;
    testsRun_in = 16'd0;
    testsPassed_in = 16'd0;
    untested_in = 16'd0;
    nv_phEnableNV_in = 1'b1;
    nv_shEnable_in = 1'b1;
    nv_ehEnable_in = 1'b1;

	 // Test 0: TPM_RESET
	 // Change operational state to INITIALIZATION_STATE to set up management module for testing.
    #40;
	 tpm_reset_n = 1'b0;
	 #20;
    tpm_reset_n = 1'b1;			// Apply reset
	 
	 #20;
	 tpm_enable_n = 1'b0; 		// Send enable low
    #20;
    tpm_enable_n = 1'b1; 		// Send enable high
	
	 // Issue STARTUP command
    #20;
    tpm_cc_in = 32'h00000144; // TPM_CC_STARTUP
    cmd_param_in = 33'd0;     // startup_state = TPM_SU_CLEAR
    orderlyInput_in = 16'd0;	// shutdown_input = TPM_SU_CLEAR
	 tpm_enable_n = 1'b0; 		// Send enable low
    #40;
    tpm_enable_n = 1'b1; 		// Send enable high
	 // Expected Result: startup_type_out == 3'b001 (changes to TPM_RESET)
	 
	 
	 
	 // Test 1: TPM_RESTART
	 // Change operational state to INITIALIZATION_STATE to set up management module for testing.
    #40;
	 tpm_reset_n = 1'b0;
	 #20;
    tpm_reset_n = 1'b1;			  // Apply reset
	 
	 #20;
	 tpm_enable_n = 1'b0; 		  // Send enable low
    #20;
    tpm_enable_n = 1'b1; 		  // Send enable high
	
	 // Issue STARTUP command
    #20;
    tpm_cc_in = 32'h00000144;   // TPM_CC_STARTUP
    cmd_param_in = 33'd0;       // startup_state = TPM_SU_CLEAR
    orderlyInput_in = 16'h0001; // shutdown_input = TPM_SU_STATE
	 tpm_enable_n = 1'b0;        // Send enable low
    #40;
    tpm_enable_n = 1'b1; 		  // Send enable high
	 // Expected Result: startup_type_out == 3'b010 (changes to TPM_RESTART)
	 
	 
	 
	 // Test 2: TPM_RESUME
	 // Change operational state to INITIALIZATION_STATE to set up management module for testing.
    #40;
	 tpm_reset_n = 1'b0;
	 #20;
    tpm_reset_n = 1'b1;			  		// Apply reset
	 
	 #20;
	 tpm_enable_n = 1'b0; 		  		// Send enable low
    #20;
    tpm_enable_n = 1'b1; 		  		// Send enable high
	
	 // Issue STARTUP command
    #20;
    tpm_cc_in = 32'h00000144;   		// TPM_CC_STARTUP
    cmd_param_in = 33'h000000001;   // startup_state = TPM_SU_STATE
    orderlyInput_in = 16'h0001; 		// shutdown_input = TPM_SU_STATE
	 tpm_enable_n = 1'b0;        		// Send enable low
    #40;
    tpm_enable_n = 1'b1; 		  		// Send enable high
	 // Expected Result: startup_type_out == 3'b011 (changes to TPM_RESUME)
	 
	 
	 
	 // Test 3: TPM_TYPE (Fails to set a startup type)
	 // Change operational state to INITIALIZATION_STATE to set up management module for testing.
    #40;
	 tpm_reset_n = 1'b0;
	 #20;
    tpm_reset_n = 1'b1;					// Apply reset
	 
	 #20;
	 tpm_enable_n = 1'b0; 				// Send enable low
    #20;
    tpm_enable_n = 1'b1; 				// Send enable high
	
	 // Issue STARTUP command
    #20;
    tpm_cc_in = 32'h00000144; 		// TPM_CC_STARTUP
    cmd_param_in = 33'h000000001;   // startup_state = TPM_SU_STATE
    orderlyInput_in = 16'd0;			// shutdown_input = TPM_SU_CLEAR
	 tpm_enable_n = 1'b0; 				// Send enable low
    #40;	
    tpm_enable_n = 1'b1; 				// Send enable high
	 
	 #20;
	 tpm_enable_n = 1'b0; 				// Send enable low
    #20;	
    tpm_enable_n = 1'b1; 				// Send enable high
	 
	 
	 // Expected Result: startup_type_out == 3'b100 (changes to TPM_TYPE),
	 //						op_state_out     == 3'b001 (goes back to INITIALIZATION_STATE),
	 //					   tpm_rc_out       == 32'h00000084 (changes to TPM_RC_VALUE)
  end

endmodule


