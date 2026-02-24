////////////////////////////////////////////////////////////////////////////////////////
// Filename:     management_module_top.v
// Author:       Emma Wallace
// Date Created: 23/04/25
// Version:      3
// Description:  This module is the top-level module for created for synthesizable 
//               testing of the management_module.v Verilog design of a management module
//					  for a discrete Trusted Platform Module (TPM).
//               The management module design is based off the Trusted Computing Group's
//					  Trusted Platform Module 2.0 Specification Revision 1.59.
//
//					  This module instantiates 1 management module from management_module.v and
//					  1 keypress module from keypress.v.
//
//               This module has 3 inputs:
//					  - CLOCK_50 - The 50 MHz system clock.
//					  - KEY - 2 keypress devices.
//					  - SW - 10 switches.
//
//					  This module has 6 outputs:
//					  - LED - 10 red LEDs.
//					  - HEX4 - Seven-segment Hex display 4.
//					  - HEX3 - Seven-segment Hex display 3.
//					  - HEX2 - Seven-segment Hex display 2.
//					  - HEX1 - Seven-segment Hex display 1.
//					  - HEX0 - Seven-segment Hex display 0.
//
// Modification History:
// Date        By   Version  Change Description
// ============================================
// 23/04/2025  EKRW    1     Original
// 24/09/2025  EKRW	  2     Changed instantiation of management module to match changes made to management_module.v.
// 01/10/2025  EKRW    3     Changes made to test according to "Management Module Synthesizable Testing Procedures" document.
///////////////////////////////////////////////////////////////////////////////////////

module management_module_top(CLOCK_50, KEY, SW, HEX4, HEX3, HEX2, HEX1, HEX0, LED);
	input        CLOCK_50;
	input  [1:0] KEY;
	input  [9:0] SW;
	output [6:0] HEX4;
	output [6:0] HEX3;
	output [6:0] HEX2;
	output [6:0] HEX1;
	output [6:0] HEX0;
	output [9:0] LED;
	
	
	
	wire [15:0] orderly_in;
	wire [15:0] testsRunIn;
	wire [15:0] testsPassedIn;
	wire [15:0] untestedIn;
	wire [31:0] ee_rc_in;
	
	wire [7:0]  locality_in;
	
	wire [2:0] op_state_out;
	wire [2:0] startup_type_out;
	wire [31:0] tpm_rc_out;
	wire [15:0] shutdownSaveOut;
	
	wire s_initialized, nv_phEnableNV_in, nv_ehEnable_in, nv_shEnable_in;
					
	reg  [3:0] hex4, hex3, hex2, hex1, hex0;
	wire keyStart;
	
	localparam POWER_OFF_STATE = 3'b000, INITIALIZATION_STATE = 3'b001, STARTUP_STATE = 3'b010, OPERATIONAL_STATE = 3'b011, SELF_TEST_STATE = 3'b100, FAILURE_MODE_STATE = 3'b101, SHUTDOWN_STATE = 3'b110;	// Operational states
	localparam TPM_DONE = 3'b000, TPM_RESET = 3'b001, TPM_RESTART = 3'b010, TPM_RESUME = 3'b011, TPM_TYPE = 3'b100;
	
	// Relevant Response Codes to managment module			  
	localparam TPM_RC_FAILURE		= 32'h00000101,
				  TPM_RC_SUCCESS 		= 32'h00000000,
				  TPM_RC_INITIALIZE	= 32'h00000100,
				  TPM_RC_VALUE			= 32'h00000084,
				  TPM_RC_AUTH_TYPE   = 32'h00000124;
	
	assign ee_rc_in = 32'hFFFFFFFF;								// Set faux execution engine response code input to unique value for testing
	assign testsRunIn = 16'd40;
	assign untestedIn = 16'd0;
	
	/* Uncomment the block corresponding to the type of tests you are running */
	
	// Operational state testing:
	/*
	wire [31:0] tpm_cc_in;
	wire [32:0] cc_param_in;
	wire [31:0] authHierarchy_in;
	assign tpm_cc_in = {25'h0000002, SW[9:3]};
	assign cc_param_in = {32'h4000000C, SW[2]};
	assign orderly_in = 16'h0000;
	assign s_initialized = (SW[1] == 1'b1)? 1'b1 : 1'b0;
	assign testsPassedIn = (SW[0] == 1'b1)? 16'd40 : 16'd3;
	assign locality_in = 8'b00000001;
	assign authHierarchy_in = 32'h4000000C;
	assign nv_phEnableNV_in = 1'b0;
	assign nv_ehEnable_in = 1'b0;
	assign nv_shEnable_in = 1'b0;
	*/
	
	// Startup type testing:
	/*
	wire [31:0] tpm_cc_in;
	wire [32:0] cc_param_in;
	wire [31:0] authHierarchy_in;
	assign tpm_cc_in = {25'h0000002, SW[9:3]};
	assign cc_param_in = {32'h00000000, SW[2]};
	assign orderly_in = (SW[0] == 1'b1)? 16'h0001 : 16'h0000;
	assign s_initialized = (SW[1] == 1'b1)? 1'b1 : 1'b0;
	assign testsPassedIn = 16'd40;
	assign locality_in = 8'b00000001;
	assign authHierarchy_in = 32'h4000000C;
	assign nv_phEnableNV_in = 1'b0;
	assign nv_ehEnable_in = 1'b0;
	assign nv_shEnable_in = 1'b0;
	*/
	
	// Hierarchy enables testing:
	/*
	wire [31:0] tpm_cc_in;
	wire [32:0] cc_param_in;
	reg [31:0] cc_param_enables;
	reg [31:0] authHierarchy_in;
	assign locality_in = 8'b00000001;
	assign tpm_cc_in = (SW[9] == 1'b1)? 32'h00000144 : 32'h00000121;
	always@(SW[8:6]) begin
		case(SW[8:6])
			3'b000:  cc_param_enables  = 32'h00000000;
			3'b001:  cc_param_enables  = 32'h00000001;
			3'b010:  cc_param_enables  = 32'h40000001;
			3'b011:  cc_param_enables  = 32'h4000000B;
			3'b100:  cc_param_enables  = 32'h4000000C;
			3'b101:  cc_param_enables  = 32'h4000000D;
			default: cc_param_enables  = 32'h40000007;
		endcase
	end
	always@(SW[5:4]) begin
		case(SW[5:4])
			2'b00:	authHierarchy_in = 32'h4000000C;
			2'b01:	authHierarchy_in = 32'h40000001;
			2'b10:	authHierarchy_in = 32'h4000000B;
			2'b11:	authHierarchy_in = 32'h40000007;
			default: authHierarchy_in = 32'h40000007;
		endcase
	end
	
	assign {orderly_in, testsPassedIn} = (SW[3] == 1'b1)? {16'h0001, 16'd40} : {16'h0000, 16'd3};
	assign cc_param_in[0] = (SW[2] == 1'b1)? 1'b1 : 1'b0;
	assign s_initialized = (SW[1] == 1'b1)? 1'b1 : 1'b0;
	assign {nv_phEnableNV_in, nv_shEnable_in, nv_ehEnable_in} = (SW[0] == 1'b1)? 3'b101 : 3'b000;
	assign cc_param_in[32:1] = cc_param_enables;
	*/
	
	// Response codes testing:
	/*
	wire [32:0] cc_param_in;
	reg [31:0] cc_param_enables;
	reg [31:0] authHierarchy_in;
	reg [31:0] tpm_cc_in;
	assign locality_in = 8'b00000001;
	always@(SW[9:7]) begin
		case(SW[9:7])
			3'b000: tpm_cc_in = 32'h00000000;
			3'b001: tpm_cc_in = 32'h00000144;
			3'b010: tpm_cc_in = 32'h00000121;
			3'b011: tpm_cc_in = 32'h00000131;
			3'b100: tpm_cc_in = 32'h00000143;
			3'b101: tpm_cc_in = 32'h0000017C;
			3'b110: tpm_cc_in = 32'h0000017A;
			default: tpm_cc_in = 32'h00000000;
		endcase
	end
	always@(SW[6:4]) begin
		case(SW[6:4])
			3'b000:  cc_param_enables  = 32'h00000000;
			3'b001:  cc_param_enables  = 32'h00000001;
			3'b010:  cc_param_enables  = 32'h40000001;
			3'b011:  cc_param_enables  = 32'h4000000B;
			3'b100:  cc_param_enables  = 32'h4000000C;
			3'b101:  cc_param_enables  = 32'h4000000D;
			default: cc_param_enables  = 32'h40000007;
		endcase
	end
	always@(SW[3:2]) begin
		case(SW[3:2])
			2'b00:	authHierarchy_in = 32'h4000000C;
			2'b01:	authHierarchy_in = 32'h40000001;
			2'b10:	authHierarchy_in = 32'h4000000B;
			2'b11:	authHierarchy_in = 32'h40000007;
			default: authHierarchy_in = 32'h40000007;
		endcase
	end
	
	assign {orderly_in, testsPassedIn} = (SW[1] == 1'b1)? {16'h0001, 16'd40} : {16'h0000, 16'd3};
	assign cc_param_in[0] = (SW[0] == 1'b1)? 1'b1 : 1'b0;
	assign s_initialized = 1'b1;
	assign {nv_phEnableNV_in, nv_shEnable_in, nv_ehEnable_in} = 3'b101;
	assign cc_param_in[32:1] = cc_param_enables;
	*/
	
	// Operational state testing:
	/*
	assign LED[9] = (tpm_rc_out == TPM_RC_SUCCESS);
	assign LED[8] = (tpm_rc_out == TPM_RC_FAILURE);
	assign LED[7] = (tpm_rc_out == TPM_RC_INITIALIZE);
	assign LED[6] = (tpm_rc_out == TPM_RC_VALUE);
	assign LED[5] = (tpm_rc_out == TPM_RC_AUTH_TYPE);
	assign LED[4] = (shutdownSaveOut == 16'h0001);
	*/
	
	// Startup type testing:
	/*
	assign LED[9] = (startup_type_out == TPM_DONE);
	assign LED[8] = (startup_type_out == TPM_RESET);
	assign LED[7] = (startup_type_out == TPM_RESTART);
	assign LED[6] = (startup_type_out == TPM_RESUME);
	assign LED[5] = (startup_type_out == TPM_TYPE);
	assign LED[4] = (tpm_rc_out == TPM_RC_VALUE);
	*/
	
	// Hierarchy enables testing:
	/*
	assign LED[9] = (tpm_rc_out == TPM_RC_SUCCESS);
	assign LED[8] = (tpm_rc_out == TPM_RC_FAILURE);
	assign LED[7] = (tpm_rc_out == TPM_RC_INITIALIZE);
	assign LED[6] = (tpm_rc_out == TPM_RC_VALUE);
	assign LED[5] = (tpm_rc_out == TPM_RC_AUTH_TYPE);
	assign LED[4] = (shutdownSaveOut == 16'h0001);
	*/
	
	// Response code testing:
	/*
	assign LED[9] = (tpm_rc_out == TPM_RC_SUCCESS);
	assign LED[8] = (tpm_rc_out == TPM_RC_FAILURE);
	assign LED[7] = (tpm_rc_out == TPM_RC_INITIALIZE);
	assign LED[6] = (tpm_rc_out == TPM_RC_VALUE);
	assign LED[5] = (tpm_rc_out == TPM_RC_AUTH_TYPE);
	assign LED[4] = (tpm_rc_out == 32'hFFFFFFFF);
	*/
	
	//  Instantiation of push button for enable
	keypress B1(.clock(CLOCK_50), .reset_n(KEY[0]), .key_in(KEY[1]), .enable_out(keyStart));
		 
	// Instantiation of management module
	management_module U1(		 
		.clock(CLOCK_50),
		.reset_n(KEY[0]),
		.keyStart_n(!keyStart),
		.tpm_cc(tpm_cc_in),
		.cmd_param(cc_param_in),
		.orderlyInput(orderly_in),
		.initialized(s_initialized),
		.authHierarchy(authHierarchy_in),
		.executionEng_rc(ee_rc_in),
		.locality(locality_in),
		.testsRun(testsRunIn),
		.testsPassed(testsPassedIn),
		.untested(untestedIn),
		.nv_phEnableNV(nv_phEnableNV_in),
	   .nv_shEnable(nv_shEnable_in),
		.nv_ehEnable(nv_ehEnable_in),
		.op_state(op_state_out),
		.startup_type(startup_type_out),
		.tpm_rc(tpm_rc_out),
		.phEnable(LED[3]),
		.phEnableNV(LED[2]),
		.shEnable(LED[1]),
		.ehEnable(LED[0]),
		.shutdownSave(shutdownSaveOut)
		);
		 
	sevensegdecoder_proc U2(hex4, HEX4);
	sevensegdecoder_proc U3(hex3, HEX3);
	sevensegdecoder_proc U4(hex2, HEX2);
	sevensegdecoder_proc U5(hex1, HEX1);
	sevensegdecoder_proc U6(hex0, HEX0);

	// Combinational logic block to show current operational state on board's hex display
	always@(op_state_out) begin
		case(op_state_out)
			POWER_OFF_STATE: 		 {hex4, hex3, hex2, hex1, hex0} = 20'h20FF5;
			INITIALIZATION_STATE: {hex4, hex3, hex2, hex1, hex0} = 20'h17195;
			STARTUP_STATE: 		 {hex4, hex3, hex2, hex1, hex0} = 20'h59A89;
			OPERATIONAL_STATE: 	 {hex4, hex3, hex2, hex1, hex0} = 20'h02E89;
			SELF_TEST_STATE: 		 {hex4, hex3, hex2, hex1, hex0} = 20'h5E6F9;
			FAILURE_MODE_STATE: 	 {hex4, hex3, hex2, hex1, hex0} = 20'hFA165;
			SHUTDOWN_STATE:		 {hex4, hex3, hex2, hex1, hex0} = 20'h53495;
			default:		 			 {hex4, hex3, hex2, hex1, hex0} = 20'h00000;
		endcase
	end
		 
	endmodule



