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
   reg         clk_enable;	// Locally-created clock enable signal
   wire        clk_out;		// Clock produced by the clk module
	
   reg         tpm_reset_n;	// Locally-created active-low TPM reset signal
   reg         tpm_enable_n;	// Locally-created active-low tpm enable signal for testing
	reg  [31:0] tpm_cc_in;
	reg  [32:0] cmd_param_in;
	reg  [15:0] orderlyInput_in;
	reg			initialized_in;
	reg  [31:0] authHierarchy_in;		// 4-byte input verifying which hiearchy was authorized (from execution engine)
	reg  [31:0] executionEng_rc_in;	// 4-byte execution engine response code
	reg  [7:0]  locality_in;				// 8-bit input of current locality
	reg  [15:0] testsRun_in;
	reg  [15:0] testsPassed_in;
	reg  [15:0] untested_in;
	reg 		   nv_phEnableNV_in;			// Non-Volatile memory of last phEnableNV state
	reg	      nv_shEnable_in;			// Non-Volatile memory of last shEnable state
	reg         nv_ehEnable_in;			// Non-Volatile memory of last ehEnable state
								
	wire [2:0]  op_state_out;
	wire [2:0]  startup_type_out;
	wire [31:0] tpm_rc_out;					// 4-byte response code
	wire 		   phEnable_out;					// 1-bit output platform hierarchy enable
	wire 		   phEnableNV_out;				// 1-bit output platform hiearchy NV memory enable
	wire 		   shEnable_out;					// 1-bit output owner hierarchy enable
	wire 		   ehEnable_out;					// 1-bit output privacy administrator hierarchy enable
	wire [15:0] shutdownSave_out;			// 1-bit output shutdownType
	

// Instantiate the clock generator with a period of 100 ns
   clk CLK1(clk_enable, clk_out);

// Instantiate the management module
	
	management_module MM1(.clock(clk_out),
								 .reset_n(tpm_reset_n),
								 .keyStart_n(tpm_enable_n),
								 .tpm_cc(tpm_cc_in),
								 .cmd_param(cmd_param_in),
								 .orderlyInput(orderlyInput_in),
								 .initialized(initialized_in),
								 .authHierarchy(authHierarchy_in),
								 .executionEng_rc(executionEng_rc_in),
								 .locality(locality_in),
								 .testsRun(testsRun_in),
								 .testsPassed(testsPassed_in),
								 .untested(untested_in),
								 .nv_phEnableNV(nv_phEnableNV_in),
								 .nv_shEnable(nv_shEnable_in),
								 .nv_ehEnable(nv_ehEnable_in),
								 .op_state(op_state_out),
								 .startup_type(startup_type_out),
								 .tpm_rc(tpm_rc_out),
								 .phEnable(phEnable_out),
								 .phEnableNV(phEnableNV_out),
								 .shEnable(shEnable_out),
								 .ehEnable(ehEnable_out),
								 .shutdownSave(shutdownSave_out)
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
    #100;
	 tpm_reset_n = 1'b0;
	 #20;
    tpm_reset_n = 1'b1;			// Apply reset
	 
	 #20;
	 tpm_enable_n = 1'b0; 		// Send enable low
    #60;
    tpm_enable_n = 1'b1; 		// Send enable high
	
	 // Issue STARTUP command
    #40;
    tpm_cc_in = 32'h00000144; // TPM_CC_STARTUP
    cmd_param_in = 33'd0;     // startup_state = TPM_SU_CLEAR
    orderlyInput_in = 16'd0;	// shutdown_input = TPM_SU_CLEAR
	 tpm_enable_n = 1'b0; 		// Send enable low
    #100;
    tpm_enable_n = 1'b1; 		// Send enable high
	 // Expected Result: startup_type_out == 3'b001 (changes to TPM_RESET)
	 
	 
	 
	 // Test 1: TPM_RESTART
	 // Change operational state to INITIALIZATION_STATE to set up management module for testing.
    #100;
	 tpm_reset_n = 1'b0;
	 #20;
    tpm_reset_n = 1'b1;			  // Apply reset
	 
	 #20;
	 tpm_enable_n = 1'b0; 		  // Send enable low
    #60;
    tpm_enable_n = 1'b1; 		  // Send enable high
	
	 // Issue STARTUP command
    #40;
    tpm_cc_in = 32'h00000144;   // TPM_CC_STARTUP
    cmd_param_in = 33'd0;       // startup_state = TPM_SU_CLEAR
    orderlyInput_in = 16'h0001; // shutdown_input = TPM_SU_STATE
	 tpm_enable_n = 1'b0;        // Send enable low
    #100;
    tpm_enable_n = 1'b1; 		  // Send enable high
	 // Expected Result: startup_type_out == 3'b010 (changes to TPM_RESTART)
	 
	 
	 
	 // Test 2: TPM_TYPE (Fails to set a startup type)
	 // Change operational state to INITIALIZATION_STATE to set up management module for testing.
    #100;
	 tpm_reset_n = 1'b0;
	 #20;
    tpm_reset_n = 1'b1;			  		// Apply reset
	 
	 #20;
	 tpm_enable_n = 1'b0; 		  		// Send enable low
    #60;
    tpm_enable_n = 1'b1; 		  		// Send enable high
	
	 // Issue STARTUP command
    #40;
    tpm_cc_in = 32'h00000144;   		// TPM_CC_STARTUP
    cmd_param_in = 33'h000000001;   // startup_state = TPM_SU_STATE
    orderlyInput_in = 16'h0001; 		// shutdown_input = TPM_SU_STATE
	 tpm_enable_n = 1'b0;        		// Send enable low
    #100;
    tpm_enable_n = 1'b1; 		  		// Send enable high
	 // Expected Result: startup_type_out == 3'b011 (changes to TPM_RESTART)
	 
	 
	 
	 // Test 3: TPM_RESET
	 // Change operational state to INITIALIZATION_STATE to set up management module for testing.
    #100;
	 tpm_reset_n = 1'b0;
	 #20;
    tpm_reset_n = 1'b1;					// Apply reset
	 
	 #20;
	 tpm_enable_n = 1'b0; 				// Send enable low
    #60;
    tpm_enable_n = 1'b1; 				// Send enable high
	
	 // Issue STARTUP command
    #40;
    tpm_cc_in = 32'h00000144; 		// TPM_CC_STARTUP
    cmd_param_in = 33'h000000001;   // startup_state = TPM_SU_STATE
    orderlyInput_in = 16'd0;			// shutdown_input = TPM_SU_CLEAR
	 tpm_enable_n = 1'b0; 				// Send enable low
    #100;	
    tpm_enable_n = 1'b1; 				// Send enable high
	 
	 #40;
	 tpm_enable_n = 1'b0; 				// Send enable low
    #60;	
    tpm_enable_n = 1'b1; 				// Send enable high
	 
	 
	 // Expected Result: startup_type_out == 3'b100 (changes to TPM_TYPE),
	 //						op_state_out     == 3'b001 (goes back to INITIALIZATION_STATE),
	 //					   tpm_rc_out       == 32'h00000084 (changes to TPM_RC_VALUE)
  end

endmodule