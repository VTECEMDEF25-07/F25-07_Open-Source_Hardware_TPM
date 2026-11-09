// startup_procedures_check.v
// This module will send startup type signal to submodules as a reset and recieve the startup done from all relevant modules

module startup_procedures_check(clock_i,
										  reset_n_i,
										  op_state_i,
										  startup_type_i,
										  phEnable_i,
										  shEnable_i,
										  ehEnable_i,
										  phEnableNV_i,
										  nv_shEnable_i,
										  nv_ehEnable_i,
										  nv_phEnableNV_i,
										  nv_index_startup_done_i,
										  clock_startup_done_i,
										  pcr_startup_done_i,
										  act_startup_done_i,
										  mem_startup_done_i,
										  startup_done_o
										  );
	input clock_i;
	input reset_n_i;
	input [2:0] op_state_i;
	input [2:0] startup_type_i;
	input phEnable_i;
	input shEnable_i;
	input ehEnable_i;
	input phEnableNV_i;
	input nv_shEnable_i;
	input nv_ehEnable_i;
	input nv_phEnableNV_i;
	input nv_index_startup_done_i;
	input clock_startup_done_i;
	input pcr_startup_done_i;
	input act_startup_done_i;
	input mem_startup_done_i;
	output startup_done_o;
	
	reg startup_done_o, s_startup_done;
	
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
	
	always@(posedge clock_i or negedge reset_n_i) begin
		if(!reset_n_i) begin
			startup_done_o <= 1'b0;
		end
		else begin
			startup_done_o <= s_startup_done;
		end
	end
	
	always@(*) begin
		s_startup_done = startup_done_o;
		if(op_state_i == STARTUP_STATE) begin
			if(nv_index_startup_done_i && clock_startup_done_i && pcr_startup_done_i && act_startup_done_i && mem_startup_done_i) s_startup_done = 1'b1;
			if(!phEnable_i) s_startup_done = 1'b0;
			if(startup_type_i == TPM_RESET || startup_type_i == TPM_RESTART) begin
				if(!shEnable_i || !ehEnable_i || !phEnableNV_i) s_startup_done = 1'b0;
			end
			else if(startup_type_i == TPM_RESUME) begin
				if(shEnable_i != nv_shEnable_i || ehEnable_i != nv_ehEnable_i || phEnableNV_i != nv_phEnableNV_i) s_startup_done = 1'b0;
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