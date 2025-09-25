////////////////////////////////////////////////////////////////////////////////////////
// Filename:     tb_managementmodule_opstates.v
// Author:       Emma Wallace
// Date Created: 23/09/25
// Version:      2
// Description:  This module serves as a simple testbench for the management module.
//               One management module is instantiated and stimulated with a simple
//               sequence to test the operational state machine.
//
//               There are no inputs or outputs to this module.
//
//					  This testbench was initially generated using chatGPT AI. To read 
//					  the prompts used please refer to the document titled "Management 
//					  Module Testbench Writing Procedures".
//
//
// Modification History:
// Date        By   Version  Change Description
// ============================================
// 24/09/2025  EKRW    1     Original
// 25/09/2025  EKRW    2     Edits were made to the timing and tests for the failure
//					 				  mode state and incremental self test transtion were added.
///////////////////////////////////////////////////////////////////////////////////////

`timescale 1ns/1ps

module tb_managementmodule_opstates();

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

    // Test 0: POWER_OFF_STATE
	 // Apply reset
    #100;
    tpm_reset_n = 1'b1;
	 // Expected Result: op_state_out = 3'b000 (initializes to POWER_OFF_STATE)
	 
	 // Apply active-low enable signal
	 #20;
	 tpm_enable_n = 1'b0; // Send enable low
    #60;
    tpm_enable_n = 1'b1; // Send enable high
	 // Expected Result: op_state_out = 3'b001 (changes to INITIALIZATION_STATE)
	 
	 
	 // Test 1: INITIALIZATION_STATE
	 // Issue command other than TPM_CC_STARTUP
	 #40;
	 tpm_cc_in = 32'h00000145; // TPM_CC_SHUTDOWN
	 cmd_param_in = 33'd0;		// TPM_SU_CLEAR
	 tpm_enable_n = 1'b0; // Send enable low
    #60;
    tpm_enable_n = 1'b1; // Send enable high
	 //Expected Result: op_state_out = 3'b001 (no change in op_state_out)
	
	 // Issue TPM_CC_STARTUP
    #40;
    tpm_cc_in = 32'h00000144; // TPM_CC_STARTUP
    cmd_param_in = 33'd0;     // TPM_SU_CLEAR
    orderlyInput_in = 16'd0;
	 tpm_enable_n = 1'b0; // Send enable low
    #60;
    tpm_enable_n = 1'b1; // Send enable high
	 // Expected Result: op_state_out = 3'b010 (changes to STARTUP_STATE)
	 

    // Test 3: STARTUP_STATE
	 // Set initialized
    #40;
    initialized_in = 1'b1;
    tpm_enable_n = 1'b0; // Send enable low
    #60;
    tpm_enable_n = 1'b1; // Send enable high
	 
	 #40;
	 tpm_enable_n = 1'b0; // Send enable low
    #60;
    tpm_enable_n = 1'b1; // Send enable high
	 // Expected Result: op_state_out = 3'b011 (changes to OPERATIONAL_STATE)

	 
    // Test 4.1: OPERATIONAL_STATE
	 // Issue TPM_CC_HIERARCHYCONTROL
    #140;
    tpm_cc_in = 32'h00000121;
    cmd_param_in = 33'b000000000000000000000000000000001; // YES
    authHierarchy_in = 32'h4000000C; // TPM_RH_PLATFORM
    tpm_enable_n = 1'b0; // Send enable low
    #60;
    tpm_enable_n = 1'b1; // Send enable high
	 // Expected Result: op_state_out = 3'b011 (no changes to op_state_out)

	 // Issue SELFTEST
    #100;
    tpm_cc_in = 32'h00000143; // TPM_CC_SELFTEST
    cmd_param_in[0] = 1'b0;
    testsRun_in = 16'd40;
    testsPassed_in = 16'd40;
    untested_in = 16'd0;
    tpm_enable_n = 1'b0; // Send enable low
    #60;
    tpm_enable_n = 1'b1; // Send enable high
	 // Expected Result: op_state_out = 3'b010 (changes to SELF_TEST_STATE)

	 
    // Test 5.1: SELF_TEST_STATE
	  // Apply active-low enable signal
    #40;
    tpm_enable_n = 1'b0; // Send enable low
    #60;
    tpm_enable_n = 1'b1; // Send enable high
	 // Expected Result: op_state_out = 3'b011 (changes to OPERATIONAL_STATE)
	 
	 
	 // Test 4.2: OPERATIONAL_STATE
	 // Issue SHUTDOWN
	 #40;
	 tpm_cc_in = 32'h00000145; // TPM_CC_SHUTDOWN
    cmd_param_in = 33'h00000000001; // TPM_SU_STATE
	 tpm_enable_n = 1'b0; // Send enable low
    #60;
    tpm_enable_n = 1'b1; // Send enable high
	 // Expected Result: op_state_out = 3'b110 (changes to SHUTDOWN_STATE)
    
	 
	 // Test 5: SHUTDOWN_STATE
	 // Apply active-low enable signal
	 #40;
	 tpm_enable_n = 1'b0; // Send enable low
    #60;
    tpm_enable_n = 1'b1; // Send enable high
	 // Expected Result: op_state_out = 3'b011 (changes to OPERATIONAL_STATE)
	 
	 
	 // Test 4.3: OPERATIONAL_STATE
	 // Issue INCREMENTAL_SELFTEST
	 #40;
	 tpm_cc_in = 32'h00000142; // TPM_CC_INCREMENTALSELFTEST
    cmd_param_in[0] = 1'b0;
    testsRun_in = 16'd40;
    testsPassed_in = 16'd37;
    untested_in = 16'd0;
    tpm_enable_n = 1'b0; // Send enable low
    #60;
    tpm_enable_n = 1'b1; // Send enable high
	 // Expected Result: op_state_out = 3'b100 (changes to SELF_TEST_STATE)
	 
	 
	 // Test 5.1: SELF_TEST_STATE
	 // Apply active-low enable signal
	 #40;
	 tpm_enable_n = 1'b0; // Send enable low
    #60;
    tpm_enable_n = 1'b1; // Send enable high
	 // Expected Result: op_state_out = 3'b110 (changes to FAILURE_MODE_STATE)
	 
	 // Test 6: FAILURE_MODE_STATE
	 // Issue command in FAILURE_MODE_STATE
	 #80;
    tpm_cc_in = 32'h00000145; // SHUTDOWN
    cmd_param_in = 33'h00000000001; // TPM_SU_STATE
    tpm_enable_n = 1'b0; // Send enable low
    #60;
    tpm_enable_n = 1'b1; // Send enable high
	 // Expected Result: op_state_out = 3'b110 (no changes to op_state_out)
  end

endmodule
