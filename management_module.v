// management_module.v

module management_module(		 
		clock,						// Input clock signal
		reset_n,						// Input reset signal
		keyStart_n,

		tpm_cc,					// 4-byte input command
		cmd_param,				// 4086-byte input command parameters
		
		orderlyInput,
		initialized,			// 1-bit input intialized bit (from execution engine)
		authHierarchy,		// 4-byte input verifying which hiearchy was authorized (from execution engine)
		executionEng_rc,	// 4-byte execution engine response code
		locality,				// 8-bit input of current locality
		testsRun,
		testsPassed,
		untested,
		nv_phEnableNV,
	   nv_shEnable,
		nv_ehEnable,
		
		op_state,
		startup_type,
		tpm_rc,					// 4-byte response code
		phEnable,					// 1-bit output platform hierarchy enable
		phEnableNV,				// 1-bit output platform hiearchy NV memory enable
		shEnable,					// 1-bit output owner hierarchy enable
		ehEnable,					// 1-bit output privacy administrator hierarchy enable
		shutdownSave			// 1-bit output shutdownType
		);
		 
	input 		  clock;						// Input clock signal
	input 		  reset_n;						// Input reset signal
	input			  keyStart_n;

	input  [31:0] tpm_cc;					// 4-byte input command
	input  [32:0] cmd_param;				// 4086-byte input command parameters
		
	input	 [15:0] orderlyInput;
	input 		  initialized;			// 1-bit input intialized bit (from execution engine)
	input	 [31:0] authHierarchy;		// 4-byte input verifying which hiearchy was authorized (from execution engine)
	input  [31:0] executionEng_rc;	// 4-byte execution engine response code
	input  [7:0]  locality;				// 8-bit input of current locality
	input	 [15:0] testsRun;
	input	 [15:0] testsPassed;
	input	 [15:0] untested;
	input 		  nv_phEnableNV;
	input	        nv_shEnable;
	input         nv_ehEnable;
		
	output [2:0]  op_state;
	output [2:0]  startup_type;
	output [31:0] tpm_rc;					// 4-byte response code
	output 		  phEnable;					// 1-bit output platform hierarchy enable
	output 		  phEnableNV;				// 1-bit output platform hiearchy NV memory enable
	output 		  shEnable;					// 1-bit output owner hierarchy enable
	output 		  ehEnable;					// 1-bit output privacy administrator hierarchy enable
	output [15:0] shutdownSave;			// 1-bit output shutdownType
	
	
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
	
	reg pHierarchy, pHierarchyNV, sHierarchy, eHierarchy;
	reg phEnable, phEnableNV, shEnable, ehEnable, tpmi_yes_no, authPassed, s_initialized;
	
	reg [15:0] startup_state, shutdown_input, shutdownSave;
		 
	reg [2:0] startup_type;
	reg [2:0] op_state, state;
	reg [31:0] tpm_rc_state, tpmi_rh_enables, tpmi_rh_hierarchy, tpm_rc;
	
	wire startupEnable, operationEnable, shutdownEnable;
	
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
			if(!keyStart_n) begin
				op_state     <= state;
				phEnable     <= pHierarchy;
				phEnableNV   <= pHierarchyNV;
				shEnable     <= sHierarchy;
				ehEnable     <= eHierarchy;
				
				tpm_rc		 <= tpm_rc_state;
				if(startupEnable) begin
					startup_state <= cmd_param[15:0];
					shutdown_input <= orderlyInput;
					s_initialized <= initialized;
					
				end
				else if(operationEnable) begin
					tpmi_rh_hierarchy <= authHierarchy;
					tpmi_rh_enables <= cmd_param[32:1];
					tpmi_yes_no    <= cmd_param[0];
				end
				else if(shutdownEnable) begin
					shutdownSave <= cmd_param[15:0];
				end
			end
		end
	end

	// Enable signals to activate input information collection at startup and shutdown stages
	assign startupEnable = (op_state == STARTUP_STATE);
	assign operationEnable = (op_state == OPERATIONAL_STATE);
	assign shutdownEnable = (op_state == SHUTDOWN_STATE);
	
	// Always block for managing operatonal states FSM
	
	always@(tpm_cc, op_state, s_initialized, startup_type, cmd_param, untested, testsPassed, testsRun) begin
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
											 if(s_initialized == 1'b1) begin
												state = OPERATIONAL_STATE;
											 end
											 else if(startup_type == TPM_TYPE) begin
												state = INITIALIZATION_STATE;
											 end
											 else begin
												state = STARTUP_STATE;
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
											 state = OPERATIONAL_STATE;
										 end
			default:					 begin
											 state = 3'bxxx;
										 end
		endcase
	end
	
	
	//Always block for managing response codes
	always@(tpm_rc, tpm_cc, op_state, shutdown_input, startup_state, s_initialized, executionEng_rc, locality, tpmi_rh_hierarchy, tpmi_rh_enables, tpmi_yes_no, untested, testsPassed, testsRun) begin
		tpm_rc_state = tpm_rc;
		if(op_state == INITIALIZATION_STATE) begin
			if(tpm_cc != TPM_CC_STARTUP) begin
				tpm_rc_state = TPM_RC_INITIALIZE;
			end
		end
	   else if(op_state == STARTUP_STATE) begin
			if((startup_state != TPM_SU_CLEAR && startup_state != TPM_SU_STATE) || (shutdown_input == TPM_SU_CLEAR && startup_state == TPM_SU_STATE)) begin
				tpm_rc_state = TPM_RC_VALUE;
			end
											 
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
						tpm_rc_state = TPM_RC_VALUE;
					end
				end
				else if(tpmi_rh_hierarchy == TPM_RH_OWNER) begin
					if(tpmi_yes_no == TPMI_NO && tpmi_rh_enables == TPM_RH_OWNER) begin
						tpm_rc_state = TPM_RC_SUCCESS;
					end
					else begin
						tpm_rc_state = TPM_RC_AUTH_TYPE;
					end
				end
				else if(tpmi_rh_hierarchy == TPM_RH_ENDORSEMENT) begin
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
				tpm_rc_state = TPM_RC_FAILURE;
			end
		end
	end
	
	// Always block for managing startup state
	
	always@(op_state, startup_state, shutdown_input) begin
		startup_type = TPM_DONE;
		if(op_state == STARTUP_STATE) begin
			if(shutdown_input == TPM_SU_STATE) begin
				if(startup_state == TPM_SU_STATE) begin
					startup_type = TPM_RESUME;
				end
				else begin
					startup_type = TPM_RESTART;
				end
			end
			else begin
				if(startup_state == TPM_SU_STATE) begin
					startup_type = TPM_TYPE;
				end
				else begin
					startup_type = TPM_RESET;
				end
			end
		end
	end
	
	// Always block for managing hierarchy enables
	
	always@(op_state, startup_type, locality, tpmi_rh_hierarchy, tpmi_rh_enables, tpmi_yes_no, tpm_cc, phEnableNV, phEnable, shEnable, ehEnable, nv_phEnableNV, nv_shEnable, nv_ehEnable) begin
		// default values for safe behavior:
		pHierarchy   = phEnable;
		pHierarchyNV = phEnableNV;
		sHierarchy   = shEnable;
		eHierarchy   = ehEnable;
		
		// cases where hierarchy enables change:
		if(op_state == STARTUP_STATE) begin
			pHierarchy = 1'b1;
			if(startup_type == TPM_RESUME) begin
				pHierarchyNV = nv_phEnableNV;
				sHierarchy = nv_shEnable;
				eHierarchy = nv_ehEnable;
			end
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
				else if(tpmi_rh_hierarchy == TPM_RH_OWNER) begin
					if(tpmi_yes_no == TPMI_NO) begin
						sHierarchy = tpmi_yes_no;
					end
				end
				else if(tpmi_rh_hierarchy == TPM_RH_ENDORSEMENT) begin
					if(tpmi_yes_no == TPMI_NO) begin
						eHierarchy = tpmi_yes_no;
					end
				end
			end
		end
	end
	
endmodule


