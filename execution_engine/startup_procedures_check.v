// startup_procedures_check.v
// This module will send startup type signal to submodules as a reset and recieve the startup done from all relevant modules

module startup_procedures_check(clock,
										  reset_n,
										  op_state,
										  startup_type,
										  phEnable,
										  shEnable,
										  ehEnable,
										  phEnableNV,
										  nv_shEnable,
										  nv_ehEnable,
										  nv_phEnableNV,
										  nv_index_startup_done,
										  clock_startup_done,
										  pcr_startup_done,
										  act_startup_done,
										  mem_startup_done,
										  startup_done
										  );
	input clock;
	input reset_n;
	input [2:0] op_state;
	input [2:0] startup_type;
	input phEnable;
	input shEnable;
	input ehEnable;
	input phEnableNV;
	input nv_shEnable;
	input nv_ehEnable;
	input nv_phEnableNV;
	input nv_index_startup_done;
	input clock_startup_done;
	input pcr_startup_done;
	input act_startup_done;
	input mem_startup_done;
	output startup_done;
	
	reg startup_done, s_startup_done;
	
	// ============================================================================
	// OPERATIONAL STATES FROM MANAGEMENT MODULE
	// ============================================================================
	localparam POWER_OFF_STATE       = 3'b000,
				  INITIALIZATION_STATE = 3'b001, 
				  STARTUP_STATE        = 3'b010,
				  OPERATIONAL_STATE    = 3'b011,
				  SELF_TEST_STATE      = 3'b100,
				  FAILURE_MODE_STATE   = 3'b101,
				  SHUTDOWN_STATE       = 3'b110;
				  
	// Startup types
	localparam TPM_DONE = 3'd0, TPM_RESET = 3'd1, TPM_RESTART = 3'd2, TPM_RESUME = 3'd3, TPM_TYPE = 3'd4;
	
	always@(posedge clock or negedge reset_n) begin
		if(!reset_n) begin
			startup_done <= 1'b0;
		end
		else begin
			startup_done <= s_startup_done;
		end
	end
	
	always@(*) begin
		s_startup_done = startup_done;
		if(op_state == STARTUP_STATE) begin
			if(nv_index_startup_done && clock_startup_done && pcr_startup_done && act_startup_done && mem_startup_done) s_startup_done = 1'b1;
			if(!phEnable) s_startup_done = 1'b0;
			if(startup_type == TPM_RESET || startup_type == TPM_RESTART) begin
				if(!shEnable || !ehEnable || !phEnableNV) s_startup_done = 1'b0;
			end
			else if(startup_type == TPM_RESUME) begin
				if(shEnable != nv_shEnable || ehEnable != nv_ehEnable || phEnableNV != nv_phEnableNV) s_startup_done = 1'b0;
			end
			else begin
				s_startup_done = 1'b0;
			end
		end
		else begin
			s_startup_done = 1'b0;
		end
	end
	
endmodule