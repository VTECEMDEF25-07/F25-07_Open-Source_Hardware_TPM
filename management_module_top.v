//management_module_top.v

module management_module_top(CLOCK_50, KEY, SW, HEX4, HEX3, HEX2, HEX1, HEX0, LED);
	input        CLOCK_50;
	input  [3:0] KEY;
	input  [9:0] SW;
	output [6:0] HEX4;
	output [6:0] HEX3;
	output [6:0] HEX2;
	output [6:0] HEX1;
	output [6:0] HEX0;
	output [9:0] LED;
	
	wire [31:0] tpm_cc_in;
	wire [15:0] cc_param_in;
	wire [15:0] testsRunIn;
	wire [15:0] testsPassedIn;
	wire [15:0] untestedIn;
	wire [31:0] ee_rc_in;
	
	wire [2:0] op_stateOut;
	wire [1:0] startup_typeOut;
	wire [31:0] tpm_rcOut;
	wire shutdownSaveOut;
	
	wire s_initialized;
					
	reg  [3:0] hex4, hex3, hex2, hex1, hex0;
	
	localparam POWER_OFF_STATE = 3'b000, INITIALIZATION_STATE = 3'b001, STARTUP_STATE = 3'b010, OPERATIONAL_STATE = 3'b011, SELF_TEST_STATE = 3'b100, FAILURE_MODE_STATE = 3'b101, SHUTDOWN_STATE = 3'b110;	// Operational states
	
	assign tpm_cc_in = {24'h1, SW[7:0]};
	assign cc_param_in = {15'h0, SW[8]};
	
	assign ee_rc_in = 32'h0;
	assign s_initialized = 1'b1;
	
	assign testsRunIn = 16'd40;
	assign testsPassedIn = (SW[9] == 1'b1)? 16'd40 : 16'd3;
	assign untestedIn = 16'd40;
	assign LED[5] = (op_stateOut == INITIALIZATION_STATE);
	assign LED[6] = (op_stateOut == STARTUP_STATE);
	assign LED[7] = (op_stateOut == OPERATIONAL_STATE);
	assign LED[8] = (op_stateOut == FAILURE_MODE_STATE);
	assign LED[9] = (op_stateOut == SHUTDOWN_STATE);
	
	management_module2 u1(CLOCK_50, 
		 KEY[0],
		 KEY[1],
		 tpm_cc_in,
		 cc_param_in,
		 1'b0,
		 s_initialized,
		 ee_rc_in,
		 testsRunIn,
		 testsPassedIn,
		 untestedIn,
		 op_stateOut,
		 startup_typeOut,
		 tpm_rcOut,
		 LED[3],
		 LED[2],
		 LED[1],
		 LED[0],
		 shutdownSaveOut
		 );
		 
	endmodule

