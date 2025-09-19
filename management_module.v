// management_module.v

module management_module(		 
		 clock, 
		 reset_n,
		 keyStart_n,
		 tpm_cc,
		 cmd_param,
		 orderlyInput,
		 initialized,
		 executionEng_rc,
		 testsRun,
		 testsPassed,
		 untested,
		 op_state,
		 startup_type,
		 tpm_rc,
		 phEnable,
		 phEnableNV,
		 shEnable,
		 ehEnable,
		 shutdownSave
		 );
		 
	input 		  clock;						// Input clock signal
	input 		  reset_n;						// Input reset signal
	input			  keyStart_n;
	input  [31:0] tpm_cc;					// 32-bit input command
	input  [15:0] cmd_param;				// 16-bit input command parameters
	input			  orderlyInput;
	input 		  initialized;			// 1-bit input intialized bit (from execution engine)
	input  [31:0] executionEng_rc;	// 32-bit execution engine response code
	input	 [15:0] testsRun;
	input	 [15:0] testsPassed;
	input	 [15:0] untested;
	output [2:0]  op_state;
	output [1:0]  startup_type;
	output [31:0] tpm_rc;					// 32-bit response code
	output 		  phEnable;					// 1-bit output platform hierarchy enable
	output 		  phEnableNV;				// 1-bit output platform hiearchy NV memory enable
	output 		  shEnable;					// 1-bit output owner hierarchy enable
	output 		  ehEnable;					// 1-bit output privacy administrator hierarchy enable
	output        shutdownSave;			// 1-bit output shutdownType
	
	
	// Relevant Command Codes to Management module
	localparam TPM_CC_CHANGEEPS 		     = 32'h00000124,
				  TPM_CC_CHANGEPPS 			  = 32'h00000125,
				  TPM_CC_CLEAR 				  = 32'h00000126,
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
				  TPM_RC_NULL			= 32'h0;
	
	localparam TPM_SU_CLEAR = 1'b0, TPM_SU_STATE = 1'b1; // command parameters
	
	localparam TPMI_YES = 1'b1, TPMI_NO = 1'b0;
	
	// Startup types
	localparam TPM_DONE = 2'd0, TPM_RESET = 2'd1, TPM_RESTART = 2'd2, TPM_RESUME = 2'd3;
	
	// Operational states
	localparam POWER_OFF_STATE = 3'b000, INITIALIZATION_STATE = 3'b001, STARTUP_STATE = 3'b010, OPERATIONAL_STATE = 3'b011, SELF_TEST_STATE = 3'b100, FAILURE_MODE_STATE = 3'b101, SHUTDOWN_STATE = 3'b110;	// Operational states
	
	reg shutdown_state, shutdown_input, pHierarchy, nvEnable, sHierarchy, eHierarchy, shutdownSave;
	reg phEnable, phEnableNV, shEnable, ehEnable;
		 
	reg [1:0] startup_state, startup_type;
	reg [2:0] op_state, state;
	reg [31:0] tpm_rc;
	
	wire startupEnable, shutdownEnable;
	
	always@(posedge clock or negedge reset_n) begin
		if(!reset_n) begin
			phEnable     <= 1'b0;
			phEnableNV   <= 1'b0;
			shEnable   	 <= 1'b0;
			ehEnable   	 <= 1'b0;
			op_state     <= POWER_OFF_STATE;
			shutdownSave <= TPM_SU_CLEAR;
		end
		else begin
			phEnable     <= pHierarchy;
			if(!keyStart_n) begin
				op_state     <= state;
			end
			if(startupEnable) begin
				startup_state <= cmd_param[0];
				shutdown_input <= orderlyInput;
				phEnableNV   <= nvEnable;
				shEnable     <= sHierarchy;
				ehEnable     <= eHierarchy;
			end
			if(shutdownEnable) begin
				shutdown_input <= cmd_param[0];
				shutdownSave <= shutdown_state;
			end
		end
	end

	// Enable signals to activate input information collection at startup and shutdown stages
	assign startupEnable = (state == STARTUP_STATE);
	assign shutdownEnable = (state == SHUTDOWN_STATE);
	
	// Always block for managing operatonal states FSM
	
	always@(tpm_cc, op_state, initialized, cmd_param, untested, testsPassed, testsRun) begin
		case(op_state)
			POWER_OFF_STATE: 		 begin
											 state = INITIALIZATION_STATE;
										 end
			INITIALIZATION_STATE: begin
										    if(tpm_cc == TPM_CC_STARTUP) begin
											 	 state = STARTUP_STATE;
											 end
									 		 else begin
												 state = INITIALIZATION_STATE;
											 end
										 end
			STARTUP_STATE:			 begin
											 if(initialized == 1'b1) begin
												state = OPERATIONAL_STATE;
											 end
											 else begin
												state = INITIALIZATION_STATE;
											 end
										 end
			OPERATIONAL_STATE: 	 begin
											if(tpm_cc == TPM_CC_SELFTEST || tpm_cc == TPM_CC_INCREMENTALSELFTEST) begin
												 state = SELF_TEST_STATE;
											end
											else if(tpm_cc == TPM_CC_SHUTDOWN) begin
												 state = SHUTDOWN_STATE;
											end
											else begin
												 // Process command
												 state = OPERATIONAL_STATE;
											end
										 end
			SELF_TEST_STATE:		 begin
											 if(testsPassed == testsRun) begin
												if(cmd_param[0] == TPMI_YES) begin
													if(testsPassed == 16'd40) begin
														state = OPERATIONAL_STATE;
													end
													else begin
														state = SELF_TEST_STATE;
													end
												end
												else begin
													if(untested == 16'd0) begin
														state = OPERATIONAL_STATE;
													end
													else begin
														state = SELF_TEST_STATE;
													end
												end
											 end
											 else begin
												 state = FAILURE_MODE_STATE;
											 end
										 end
			FAILURE_MODE_STATE:	 begin
											 state = FAILURE_MODE_STATE;
										 end
			SHUTDOWN_STATE:		 begin
											 state = SHUTDOWN_STATE;
										 end
			default:					 begin
											 state = 3'bxxx;
										 end
		endcase
	end
	
	
	//Always block for managing response codes
	always@(tpm_cc, op_state, shutdown_input, startup_state, initialized, executionEng_rc, cmd_param, untested, testsPassed, testsRun) begin
		case(op_state)
			POWER_OFF_STATE: 		 begin
											 tpm_rc = TPM_RC_NULL;
										 end
			INITIALIZATION_STATE: begin
										    if(tpm_cc != TPM_CC_STARTUP) begin
												 tpm_rc = TPM_RC_INITIALIZE;
											 end
										 end
			STARTUP_STATE:			 begin
											 if(shutdown_input == TPM_SU_CLEAR && startup_state == TPM_SU_STATE) begin
												tpm_rc = TPM_RC_VALUE;
											 end
											 if(initialized == 1'b1) begin
												tpm_rc = TPM_RC_SUCCESS;
											 end
										 end
			OPERATIONAL_STATE: 	 begin
											tpm_rc = executionEng_rc;
										 end
			SELF_TEST_STATE:		 begin
											 if(testsPassed != testsRun) begin
												tpm_rc = TPM_RC_FAILURE;
											 end
											 else begin
												tpm_rc = executionEng_rc;
											 end
										 end
			FAILURE_MODE_STATE:	 begin
											 if(tpm_cc == TPM_CC_GETTESTRESULT) begin
												 tpm_rc = executionEng_rc;
											 end
											 else if(tpm_cc == TPM_CC_GETCAPABILITY) begin
												 tpm_rc = executionEng_rc;
											 end
											 else begin
												 tpm_rc = TPM_RC_FAILURE;
											 end
										 end
			SHUTDOWN_STATE:		 begin
											 tpm_rc = TPM_RC_NULL;
										 end
			default:					 begin
											 tpm_rc = 32'bx;
										 end
		endcase
	end
	
	// Always block for managing shutdown state
	
	always@(op_state, shutdown_input) begin
		if(op_state == SHUTDOWN_STATE) begin
			if(shutdown_input == TPM_SU_STATE) begin
				shutdown_state = TPM_SU_STATE;		// set shutdown as orderly
			end
			else begin
				shutdown_state = TPM_SU_CLEAR;
			end
		end
	end
	
	// Always block for managing startup state
	
	always@(op_state, startup_state, shutdown_state, phEnableNV, shEnable, ehEnable) begin
		if(op_state == STARTUP_STATE) begin
			// For all startups:
			pHierarchy = 1'b1;
			
			if(shutdown_state == TPM_SU_STATE) begin
				if(startup_state == TPM_SU_STATE) begin
					startup_type = TPM_RESUME;
					
					nvEnable = phEnableNV;
					sHierarchy = shEnable;
					eHierarchy = ehEnable;
				end
				else begin
					startup_type = TPM_RESTART;

					nvEnable = 1'b1;
					sHierarchy = 1'b1;
					eHierarchy = 1'b1;
				end
			end
			else begin
				if(startup_state == TPM_SU_STATE) begin
					startup_type = TPM_DONE;
				end
				else begin
					startup_type = TPM_RESET;
					
					nvEnable = 1'b1;
					sHierarchy = 1'b1;
					eHierarchy = 1'b1;
				end
			end
		end
	end
	
endmodule

