////////////////////////////////////////////////////////////////////////////////////////
// Filename:     tb_managementmodule_hierarchyenables.v
// Author:       Emma Wallace
// Date Created: 26/09/25
// Version:      2
// Description:  This module serves as a simple testbench for the management module.
//               One management module is instantiated and stimulated with a simple
//               sequence to test the hierarchy enable logic.
//
//               There are no inputs or outputs to this module.
//
//
// Modification History:
// Date        By   Version  Change Description
// ============================================
// 26/09/2025  EKRW    1     Original
// 30/09/2025  EKRW    2     Added additional commands to make testing more accurate
//									  and updated comments accordingly.
///////////////////////////////////////////////////////////////////////////////////////

`timescale 1ns/1ps

module tb_managementmodule_hierarchyenables();
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
    nv_shEnable_in = 1'b0;
    nv_ehEnable_in = 1'b1;

	 // Test 0: TPM_RESUME
	 // Change operational state to INITIALIZATION_STATE to set up management module for testing.
    #40;
	 tpm_reset_n = 1'b0;
	 #20;
    tpm_reset_n = 1'b1;					// Apply reset
	 // Initialization check: phEnable_out   == 1'b0,
	 //							  phEnableNV_out == 1'b0,
	 //							  shEnable_out   == 1'b0,
	 //							  ehEnable_out   == 1'b0
	 
	 #20;
	 tpm_enable_n = 1'b0; 				// Send enable low
    #20;
    tpm_enable_n = 1'b1; 				// Send enable high
	
	 // Issue STARTUP command
    #40;
    tpm_cc_in = 32'h00000144; 		// TPM_CC_STARTUP
    cmd_param_in = 33'h000000001;	// startup_state = TPM_SU_STATE
    orderlyInput_in = 16'h0001;		// shutdown_input = TPM_SU_STATE
	 tpm_enable_n = 1'b0; 				// Send enable low
    #40;
    tpm_enable_n = 1'b1; 				// Send enable high
	 // Expected Result: phEnable_out   == 1'b1,
	 //						phEnableNV_out == 1'b1,
	 //						shEnable_out   == 1'b0,
	 //						ehEnable_out   == 1'b1,
	 //						tpm_rc_out     == 32'h00000000 (TPM_RC_SUCCESS)
	 
	 
	 
	 // Test 1: TPM_RESTART
	 // Change operational state to INITIALIZATION_STATE to set up management module for testing.
    #100;
	 tpm_reset_n = 1'b0;
	 #20;
    tpm_reset_n = 1'b1;			  // Apply reset
	 // Initialization check: phEnable_out   == 1'b0,
	 //							  phEnableNV_out == 1'b0,
	 //							  shEnable_out   == 1'b0,
	 //							  ehEnable_out   == 1'b0
	 
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
    #40;
    tpm_enable_n = 1'b1; 		  // Send enable high
	 // Expected Result: phEnable_out   == 1'b1,
	 //						phEnableNV_out == 1'b1,
	 //						shEnable_out   == 1'b1,
	 //						ehEnable_out   == 1'b1,
	 //						tpm_rc_out     == 32'h00000000 (TPM_RC_SUCCESS)
	 
	 
	 
	 // Test 2: TPM_RESET
	 // Change operational state to INITIALIZATION_STATE to set up management module for testing.
    #100;
	 tpm_reset_n = 1'b0;
	 #20;
    tpm_reset_n = 1'b1;			  		// Apply reset
	 // Initialization check: phEnable_out   == 1'b0,
	 //							  phEnableNV_out == 1'b0,
	 //							  shEnable_out   == 1'b0,
	 //							  ehEnable_out   == 1'b0
	 
	 #20;
	 tpm_enable_n = 1'b0; 		  		// Send enable low
    #60;
    tpm_enable_n = 1'b1; 		  		// Send enable high
	
	 // Issue STARTUP command
    #40;
    tpm_cc_in = 32'h00000144;   		// TPM_CC_STARTUP
    cmd_param_in = 33'd0;   // startup_state = TPM_SU_CLEAR
    orderlyInput_in = 16'd0; 		// shutdown_input = TPM_SU_CLEAR
	 tpm_enable_n = 1'b0;        		// Send enable low
    #40;
    tpm_enable_n = 1'b1; 		  		// Send enable high
	 // Expected Result: phEnable_out   == 1'b1,
	 //						phEnableNV_out == 1'b1,
	 //						shEnable_out   == 1'b1,
	 //						ehEnable_out   == 1'b1,
	 //						tpm_rc_out     == 32'h00000000 (TPM_RC_SUCCESS)
	 
	 
	 // Test 3: TPM_CC_HIERARCHYCONTROL
	 
	 // Test 3.1: TPMI_RH_HIERARCHY == TPM_RH_PLATFORM
	 #100;
    initialized_in = 1'b1;
    tpm_enable_n = 1'b0; 					// Send enable low
    #40;
    tpm_enable_n = 1'b1; 					// Send enable high
	 
	 #40;
    tpm_cc_in = 32'h00000121;				// TPM_CC_HIERARCHY
    cmd_param_in[32:1] = 32'h4000000C; // tpmi_rh_enables == TPM_RH_PLATFORM
	 cmd_param_in[0] = 1'b0;			   // tpmi_yes_no == TPMI_NO
    authHierarchy_in = 32'h4000000C;   // tpmi_rh_hierarchy == TPM_RH_PLATFORM
    tpm_enable_n = 1'b0; 					// Send enable low
    #40;
    tpm_enable_n = 1'b1; // Send enable high
	 // Expected Result: phEnable_out   == 1'b0,
	 //						phEnableNV_out == 1'b1,
	 //						shEnable_out   == 1'b1,
	 //						ehEnable_out   == 1'b1,
	 //						tpm_rc         == 32'h00000000 (TPM_RC_SUCCESS)
	 
	 
	 #40;
    tpm_cc_in = 32'h00000121;				// TPM_CC_HIERARCHY
    cmd_param_in[32:1] = 32'h4000000C; // tpmi_rh_enables == TPM_RH_PLATFORM
	 cmd_param_in[0] = 1'b1;			   // tpmi_yes_no == TPMI_YES
    tpm_enable_n = 1'b0; 					// Send enable low
    #40;
    tpm_enable_n = 1'b1; // Send enable high
	 // Expected Result: phEnable_out   == 1'b0,
	 //						phEnableNV_out == 1'b1,
	 //						shEnable_out   == 1'b1,
	 //						ehEnable_out   == 1'b1,
	 //						tpm_rc         == 32'h00000124 (TPM_RC_VALUE)
	 
	 
	 #40;
    tpm_cc_in = 32'h00000121;				// TPM_CC_HIERARCHY
    cmd_param_in[32:1] = 32'h4000000D; // tpmi_rh_enables == TPM_RH_PLATFORM_NV
	 cmd_param_in[0] = 1'b0;			   // tpmi_yes_no == TPMI_NO
    tpm_enable_n = 1'b0; 					// Send enable low
    #40;
    tpm_enable_n = 1'b1; // Send enable high
	 // Expected Result: phEnable_out   == 1'b0,
	 //						phEnableNV_out == 1'b0,
	 //						shEnable_out   == 1'b1,
	 //						ehEnable_out   == 1'b1,
	 //						tpm_rc         == 32'h00000000 (TPM_RC_SUCCESS)
	 
	 
	 #40;
    tpm_cc_in = 32'h00000121;				// TPM_CC_HIERARCHY
    cmd_param_in[32:1] = 32'h4000000D; // tpmi_rh_enables == TPM_RH_PLATFORM_NV
	 cmd_param_in[0] = 1'b1;			   // tpmi_yes_no == TPMI_YES
    tpm_enable_n = 1'b0; 					// Send enable low
    #40;
    tpm_enable_n = 1'b1; // Send enable high
	 // Expected Result: phEnable_out   == 1'b0,
	 //						phEnableNV_out == 1'b1,
	 //						shEnable_out   == 1'b1,
	 //						ehEnable_out   == 1'b1,
	 //						tpm_rc         == 32'h00000000 (TPM_RC_SUCCESS)
	 
	 
	 #40;
    tpm_cc_in = 32'h00000121;				// TPM_CC_HIERARCHY
    cmd_param_in[32:1] = 32'h40000001; // tpmi_rh_enables == TPM_RH_OWNER
	 cmd_param_in[0] = 1'b0;			   // tpmi_yes_no == TPMI_NO
    tpm_enable_n = 1'b0; 					// Send enable low
    #40;
    tpm_enable_n = 1'b1; // Send enable high
	 // Expected Result: phEnable_out   == 1'b0,
	 //						phEnableNV_out == 1'b1,
	 //						shEnable_out   == 1'b0,
	 //						ehEnable_out   == 1'b1,
	 //						tpm_rc         == 32'h00000000 (TPM_RC_SUCCESS)
	 
	 
	 #40;
    tpm_cc_in = 32'h00000121;				// TPM_CC_HIERARCHY
    cmd_param_in[32:1] = 32'h40000001; // tpmi_rh_enables == TPM_RH_OWNER
	 cmd_param_in[0] = 1'b1;			   // tpmi_yes_no == TPMI_YES
    tpm_enable_n = 1'b0; 					// Send enable low
    #40;
    tpm_enable_n = 1'b1; // Send enable high
	 // Expected Result: phEnable_out   == 1'b0,
	 //						phEnableNV_out == 1'b1,
	 //						shEnable_out   == 1'b1,
	 //						ehEnable_out   == 1'b1,
	 //						tpm_rc         == 32'h00000000 (TPM_RC_SUCCESS)
	 
	 
	 #40;
    tpm_cc_in = 32'h00000121;				// TPM_CC_HIERARCHY
    cmd_param_in[32:1] = 32'h4000000B; // tpmi_rh_enables == TPM_RH_ENDORSEMENT
	 cmd_param_in[0] = 1'b0;			   // tpmi_yes_no == TPMI_NO
    tpm_enable_n = 1'b0; 					// Send enable low
    #40;
    tpm_enable_n = 1'b1; // Send enable high
	 // Expected Result: phEnable_out   == 1'b0,
	 //						phEnableNV_out == 1'b1,
	 //						shEnable_out   == 1'b1,
	 //						ehEnable_out   == 1'b0,
	 //						tpm_rc         == 32'h00000000 (TPM_RC_SUCCESS)
	 
	 
	 #40;
    tpm_cc_in = 32'h00000121;				// TPM_CC_HIERARCHY
    cmd_param_in[32:1] = 32'h4000000B; // tpmi_rh_enables == TPM_RH_ENDORSEMENT
	 cmd_param_in[0] = 1'b1;			   // tpmi_yes_no == TPMI_YES
    tpm_enable_n = 1'b0; 					// Send enable low
    #40;
    tpm_enable_n = 1'b1; // Send enable high
	 // Expected Result: phEnable_out   == 1'b0,
	 //						phEnableNV_out == 1'b1,
	 //						shEnable_out   == 1'b1,
	 //						ehEnable_out   == 1'b1,
	 //						tpm_rc         == 32'h00000000 (TPM_RC_SUCCESS)
	 
	 
	 // Test 3.2: TPMI_RH_HIERARCHY == TPM_RH_OWNER
	 // TPMI_NO
	 // First, reset and startup hierarchy enables for informative testing.
	 #100;
	 tpm_reset_n = 1'b0;
	 #20;
    tpm_reset_n = 1'b1;			  		// Apply reset
	 // Initialization check: phEnable_out   == 1'b0,
	 //							  phEnableNV_out == 1'b0,
	 //							  shEnable_out   == 1'b0,
	 //							  ehEnable_out   == 1'b0
	 
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
    #40;
    tpm_enable_n = 1'b1; 		  		// Send enable high
	 // Expected Result: phEnable_out   == 1'b1,
	 //						phEnableNV_out == 1'b1,
	 //						shEnable_out   == 1'b1,
	 //						ehEnable_out   == 1'b1,
	 //						tpm_rc_out     == 32'h00000000 (TPM_RC_SUCCESS)
	 
	 #40;
    tpm_cc_in = 32'h00000121;				// TPM_CC_HIERARCHY
    cmd_param_in[32:1] = 32'h4000000C; // tpmi_rh_enables == TPM_RH_PLATFORM
	 cmd_param_in[0] = 1'b0;			   // tpmi_yes_no == TPMI_NO
    authHierarchy_in = 32'h40000001;   // tpmi_rh_hierarchy == TPM_RH_OWNER
    tpm_enable_n = 1'b0; 					// Send enable low
    #40;
    tpm_enable_n = 1'b1; // Send enable high
	 // Expected Result: phEnable_out   == 1'b1,
	 //						phEnableNV_out == 1'b1,
	 //						shEnable_out   == 1'b1,
	 //						ehEnable_out   == 1'b1,
	 //						tpm_rc         == 32'h00000124 (TPM_RC_AUTH_TYPE)
	 
	 
	 #40;
    tpm_cc_in = 32'h00000121;				// TPM_CC_HIERARCHY
    cmd_param_in[32:1] = 32'h4000000D; // tpmi_rh_enables == TPM_RH_PLATFORM_NV
	 cmd_param_in[0] = 1'b0;			   // tpmi_yes_no == TPMI_NO
    tpm_enable_n = 1'b0; 					// Send enable low
    #40;
    tpm_enable_n = 1'b1; // Send enable high
	 // Expected Result: phEnable_out   == 1'b1,
	 //						phEnableNV_out == 1'b1,
	 //						shEnable_out   == 1'b1,
	 //						ehEnable_out   == 1'b1,
	 //						tpm_rc         == 32'h00000124 (TPM_RC_AUTH_TYPE)
	 
	 #40;
    tpm_cc_in = 32'h00000121;				// TPM_CC_HIERARCHY
    cmd_param_in[32:1] = 32'h40000001; // tpmi_rh_enables == TPM_RH_OWNER
	 cmd_param_in[0] = 1'b0;			   // tpmi_yes_no == TPMI_NO
    tpm_enable_n = 1'b0; 					// Send enable low
    #40;
    tpm_enable_n = 1'b1; // Send enable high
	 // Expected Result: phEnable_out   == 1'b1,
	 //						phEnableNV_out == 1'b1,
	 //						shEnable_out   == 1'b0,
	 //						ehEnable_out   == 1'b1,
	 //						tpm_rc         == 32'h00000000 (TPM_RC_SUCCESS)
	 
	 
	 #40;
    tpm_cc_in = 32'h00000121;				// TPM_CC_HIERARCHY
    cmd_param_in[32:1] = 32'h4000000B; // tpmi_rh_enables == TPM_RH_ENDORSEMENT
	 cmd_param_in[0] = 1'b0;			   // tpmi_yes_no == TPMI_NO
    tpm_enable_n = 1'b0; 					// Send enable low
    #40;
    tpm_enable_n = 1'b1; // Send enable high
	 // Expected Result: phEnable_out   == 1'b1,
	 //						phEnableNV_out == 1'b1,
	 //						shEnable_out   == 1'b0,
	 //						ehEnable_out   == 1'b1,
	 //						tpm_rc         == 32'h00000124 (TPM_RC_AUTH_TYPE)
	 
	 //TPMI_YES
	 // First, reset and startup hierarchy enables for informative testing.
	 #40;
	 nv_phEnableNV_in = 1'b0;
	 nv_shEnable_in   = 1'b0;
	 nv_ehEnable_in   = 1'b0;
	 tpm_reset_n = 1'b0;
	 #20;
    tpm_reset_n = 1'b1;			  		// Apply reset
	 // Initialization check: phEnable_out   == 1'b0,
	 //							  phEnableNV_out == 1'b0,
	 //							  shEnable_out   == 1'b0,
	 //							  ehEnable_out   == 1'b0
	 
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
    #40;
    tpm_enable_n = 1'b1; 		  		// Send enable high
	 // Expected Result: phEnable_out   == 1'b1,
	 //						phEnableNV_out == 1'b0,
	 //						shEnable_out   == 1'b0,
	 //						ehEnable_out   == 1'b0,
	 //						tpm_rc_out     == 32'h00000000 (TPM_RC_SUCCESS)
	 
	 #40;
	 // Set phEnable_out to 1'b0 for accurate testing:
    tpm_cc_in = 32'h00000121;				// TPM_CC_HIERARCHY
    cmd_param_in[32:1] = 32'h4000000C; // tpmi_rh_enables == TPM_RH_PLATFORM
	 cmd_param_in[0] = 1'b0;			   // tpmi_yes_no == TPMI_NO
	 authHierarchy_in = 32'h4000000C;	// tpmi_rh_hierarchy == TPM_RH_PLATFORM
    tpm_enable_n = 1'b0; 					// Send enable low
    #40;
    tpm_enable_n = 1'b1; // Send enable high
	 // Expected Result: phEnable_out   == 1'b0,
	 //						phEnableNV_out == 1'b0,
	 //						shEnable_out   == 1'b0,
	 //						ehEnable_out   == 1'b0,
	 //						tpm_rc         == 32'h00000000 (TPM_RC_SUCCESS)
	 
	 #40;
	 // Begin testing tpmi_rh_hierarchy == TPM_RH_OWNER:
    tpm_cc_in = 32'h00000121;				// TPM_CC_HIERARCHY
	 cmd_param_in[0] = 1'b1;			   // tpmi_yes_no == TPMI_YES
	 authHierarchy_in = 32'h40000001;	// tpmi_rh_hierarchy == TPM_RH_OWNER
    tpm_enable_n = 1'b0; 					// Send enable low
    #40;
    tpm_enable_n = 1'b1; // Send enable high
	 // Expected Result: phEnable_out   == 1'b0,
	 //						phEnableNV_out == 1'b0,
	 //						shEnable_out   == 1'b0,
	 //						ehEnable_out   == 1'b0,
	 //						tpm_rc         == 32'h00000124 (TPM_RC_AUTH_TYPE)
	 
	 
	 #40;
    tpm_cc_in = 32'h00000121;				// TPM_CC_HIERARCHY
    cmd_param_in[32:1] = 32'h4000000D; // tpmi_rh_enables == TPM_RH_PLATFORM_NV
	 cmd_param_in[0] = 1'b1;			   // tpmi_yes_no == TPMI_YES
    tpm_enable_n = 1'b0; 					// Send enable low
    #40;
    tpm_enable_n = 1'b1; // Send enable high
	 // Expected Result: phEnable_out   == 1'b0,
	 //						phEnableNV_out == 1'b0,
	 //						shEnable_out   == 1'b0,
	 //						ehEnable_out   == 1'b0,
	 //						tpm_rc         == 32'h00000124 (TPM_RC_AUTH_TYPE)
	 
	 
	 
	 #40;
    tpm_cc_in = 32'h00000121;				// TPM_CC_HIERARCHY
    cmd_param_in[32:1] = 32'h40000001; // tpmi_rh_enables == TPM_RH_OWNER
	 cmd_param_in[0] = 1'b1;			   // tpmi_yes_no == TPMI_YES
    tpm_enable_n = 1'b0; 					// Send enable low
    #40;
    tpm_enable_n = 1'b1; // Send enable high
	 // Expected Result: phEnable_out   == 1'b0,
	 //						phEnableNV_out == 1'b0,
	 //						shEnable_out   == 1'b0,
	 //						ehEnable_out   == 1'b0,
	 //						tpm_rc         == 32'h00000124 (TPM_RC_AUTH_TYPE)
	 
	 
	 #40;
    tpm_cc_in = 32'h00000121;				// TPM_CC_HIERARCHY
    cmd_param_in[32:1] = 32'h4000000B; // tpmi_rh_enables == TPM_RH_ENDORSEMENT
	 cmd_param_in[0] = 1'b1;			   // tpmi_yes_no == TPMI_YES
    tpm_enable_n = 1'b0; 					// Send enable low
    #40;
    tpm_enable_n = 1'b1; // Send enable high
	 // Expected Result: phEnable_out   == 1'b0,
	 //						phEnableNV_out == 1'b0,
	 //						shEnable_out   == 1'b0,
	 //						ehEnable_out   == 1'b0,
	 //						tpm_rc         == 32'h00000124 (TPM_RC_AUTH_TYPE)
	 
	 
	 // Test 3.3: TPMI_RH_HIERARCHY == TPM_RH_ENDORSEMENT
	 // TPMI_NO
	 // First, reset and startup hierarchy enables for informative testing.
	 #100;
	 nv_phEnableNV_in = 1'b1;
	 nv_shEnable_in   = 1'b1;
	 nv_ehEnable_in   = 1'b1;
	 tpm_reset_n = 1'b0;
	 #20;
    tpm_reset_n = 1'b1;			  		// Apply reset
	 // Initialization check: phEnable_out   == 1'b0,
	 //							  phEnableNV_out == 1'b0,
	 //							  shEnable_out   == 1'b0,
	 //							  ehEnable_out   == 1'b0
	 
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
    #40;
    tpm_enable_n = 1'b1; 		  		// Send enable high
	 // Expected Result: phEnable_out   == 1'b1,
	 //						phEnableNV_out == 1'b1,
	 //						shEnable_out   == 1'b1,
	 //						ehEnable_out   == 1'b1,
	 //						tpm_rc_out     == 32'h00000000 (TPM_RC_SUCCESS)
	 
	 #40;
    tpm_cc_in = 32'h00000121;				// TPM_CC_HIERARCHY
    cmd_param_in[32:1] = 32'h4000000C; // tpmi_rh_enables == TPM_RH_PLATFORM
	 cmd_param_in[0] = 1'b0;			   // tpmi_yes_no == TPMI_NO
    authHierarchy_in = 32'h4000000B;   // tpmi_rh_hierarchy == TPM_RH_ENDORSEMENT
    tpm_enable_n = 1'b0; 					// Send enable low
    #40;
    tpm_enable_n = 1'b1; // Send enable high
	 // Expected Result: phEnable_out   == 1'b1,
	 //						phEnableNV_out == 1'b1,
	 //						shEnable_out   == 1'b1,
	 //						ehEnable_out   == 1'b1,
	 //						tpm_rc         == 32'h00000124 (TPM_RC_AUTH_TYPE)
	 
	 
	 #40;
    tpm_cc_in = 32'h00000121;				// TPM_CC_HIERARCHY
    cmd_param_in[32:1] = 32'h4000000D; // tpmi_rh_enables == TPM_RH_PLATFORM_NV
	 cmd_param_in[0] = 1'b0;			   // tpmi_yes_no == TPMI_NO
    tpm_enable_n = 1'b0; 					// Send enable low
    #40;
    tpm_enable_n = 1'b1; // Send enable high
	 // Expected Result: phEnable_out   == 1'b1,
	 //						phEnableNV_out == 1'b1,
	 //						shEnable_out   == 1'b1,
	 //						ehEnable_out   == 1'b1,
	 //						tpm_rc         == 32'h00000124 (TPM_RC_AUTH_TYPE)
	 
	 #40;
    tpm_cc_in = 32'h00000121;				// TPM_CC_HIERARCHY
    cmd_param_in[32:1] = 32'h40000001; // tpmi_rh_enables == TPM_RH_OWNER
	 cmd_param_in[0] = 1'b0;			   // tpmi_yes_no == TPMI_NO
    tpm_enable_n = 1'b0; 					// Send enable low
    #40;
    tpm_enable_n = 1'b1; // Send enable high
	 // Expected Result: phEnable_out   == 1'b1,
	 //						phEnableNV_out == 1'b1,
	 //						shEnable_out   == 1'b1,
	 //						ehEnable_out   == 1'b1,
	 //						tpm_rc         == 32'h00000124 (TPM_RC_AUTH_TYPE)
	 
	 
	 #40;
    tpm_cc_in = 32'h00000121;				// TPM_CC_HIERARCHY
    cmd_param_in[32:1] = 32'h4000000B; // tpmi_rh_enables == TPM_RH_ENDORSEMENT
	 cmd_param_in[0] = 1'b0;			   // tpmi_yes_no == TPMI_NO
    tpm_enable_n = 1'b0; 					// Send enable low
    #40;
    tpm_enable_n = 1'b1; // Send enable high
	 // Expected Result: phEnable_out   == 1'b1,
	 //						phEnableNV_out == 1'b1,
	 //						shEnable_out   == 1'b1,
	 //						ehEnable_out   == 1'b0,
	 //						tpm_rc         == 32'h00000000 (TPM_RC_SUCCESS)
	 
	 //TPMI_YES
	 // First, reset and startup hierarchy enables for informative testing.
	 #40;
	 nv_phEnableNV_in = 1'b0;
	 nv_shEnable_in   = 1'b0;
	 nv_ehEnable_in   = 1'b0;
	 tpm_reset_n = 1'b0;
	 #20;
    tpm_reset_n = 1'b1;			  		// Apply reset
	 // Initialization check: phEnable_out   == 1'b0,
	 //							  phEnableNV_out == 1'b0,
	 //							  shEnable_out   == 1'b0,
	 //							  ehEnable_out   == 1'b0
	 
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
    #40;
    tpm_enable_n = 1'b1; 		  		// Send enable high
	 // Expected Result: phEnable_out   == 1'b1,
	 //						phEnableNV_out == 1'b0,
	 //						shEnable_out   == 1'b0,
	 //						ehEnable_out   == 1'b0,
	 //						tpm_rc_out     == 32'h00000000 (TPM_RC_SUCCESS)
	 
	 #40;
	 // Set phEnable_out to 1'b0 for accurate testing:
    tpm_cc_in = 32'h00000121;				// TPM_CC_HIERARCHY
    cmd_param_in[32:1] = 32'h4000000C; // tpmi_rh_enables == TPM_RH_PLATFORM
	 cmd_param_in[0] = 1'b0;			   // tpmi_yes_no == TPMI_NO
	 authHierarchy_in = 32'h4000000C;	// tpmi_rh_hierarchy == TPM_RH_PLATFORM
    tpm_enable_n = 1'b0; 					// Send enable low
    #40;
    tpm_enable_n = 1'b1; // Send enable high
	 // Expected Result: phEnable_out   == 1'b0,
	 //						phEnableNV_out == 1'b0,
	 //						shEnable_out   == 1'b0,
	 //						ehEnable_out   == 1'b0,
	 //						tpm_rc         == 32'h00000000 (TPM_RC_SUCCESS)
	 
	 #40;
	 // Begin testing tpmi_rh_enables == TPM_RH_ENDORSEMENT:
    tpm_cc_in = 32'h00000121;				// TPM_CC_HIERARCHY
    cmd_param_in[32:1] = 32'h4000000C; // tpmi_rh_enables == TPM_RH_PLATFORM
	 cmd_param_in[0] = 1'b1;			   // tpmi_yes_no == TPMI_YES
	 authHierarchy_in = 32'h4000000D;	// tpmi_rh_hierarchy == TPM_RH_ENDORSEMENT
    tpm_enable_n = 1'b0; 					// Send enable low
    #40;
    tpm_enable_n = 1'b1; // Send enable high
	 // Expected Result: phEnable_out   == 1'b0,
	 //						phEnableNV_out == 1'b0,
	 //						shEnable_out   == 1'b0,
	 //						ehEnable_out   == 1'b0,
	 //						tpm_rc         == 32'h00000124 (TPM_RC_AUTH_TYPE)
	 
	 
	 #40;
    tpm_cc_in = 32'h00000121;				// TPM_CC_HIERARCHY
    cmd_param_in[32:1] = 32'h4000000D; // tpmi_rh_enables == TPM_RH_PLATFORM_NV
	 cmd_param_in[0] = 1'b1;			   // tpmi_yes_no == TPMI_YES
    tpm_enable_n = 1'b0; 					// Send enable low
    #40;
    tpm_enable_n = 1'b1; // Send enable high
	 // Expected Result: phEnable_out   == 1'b0,
	 //						phEnableNV_out == 1'b0,
	 //						shEnable_out   == 1'b0,
	 //						ehEnable_out   == 1'b0,
	 //						tpm_rc         == 32'h00000124 (TPM_RC_AUTH_TYPE)
	 
	 
	 
	 #40;
    tpm_cc_in = 32'h00000121;				// TPM_CC_HIERARCHY
    cmd_param_in[32:1] = 32'h40000001; // tpmi_rh_enables == TPM_RH_OWNER
	 cmd_param_in[0] = 1'b1;			   // tpmi_yes_no == TPMI_YES
    tpm_enable_n = 1'b0; 					// Send enable low
    #40;
    tpm_enable_n = 1'b1; // Send enable high
	 // Expected Result: phEnable_out   == 1'b0,
	 //						phEnableNV_out == 1'b0,
	 //						shEnable_out   == 1'b0,
	 //						ehEnable_out   == 1'b0,
	 //						tpm_rc         == 32'h00000124 (TPM_RC_AUTH_TYPE)
	 
	 
	 #40;
    tpm_cc_in = 32'h00000121;				// TPM_CC_HIERARCHY
    cmd_param_in[32:1] = 32'h4000000B; // tpmi_rh_enables == TPM_RH_ENDORSEMENT
	 cmd_param_in[0] = 1'b1;			   // tpmi_yes_no == TPMI_YES
    tpm_enable_n = 1'b0; 					// Send enable low
    #40;
    tpm_enable_n = 1'b1; // Send enable high
	 // Expected Result: phEnable_out   == 1'b0,
	 //						phEnableNV_out == 1'b0,
	 //						shEnable_out   == 1'b0,
	 //						ehEnable_out   == 1'b0,
	 //						tpm_rc         == 32'h00000124 (TPM_RC_AUTH_TYPE)
	 
  end

endmodule
