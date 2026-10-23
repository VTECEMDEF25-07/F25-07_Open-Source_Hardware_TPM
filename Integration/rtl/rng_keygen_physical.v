`timescale 1ns/1ps
// Physical frontend for the shared system; production admission disabled by default.
// VALIDATED_ENTROPY may only be enabled after board source characterization.
module rng_keygen_physical #(
 parameter VALIDATED_ENTROPY=0,parameter RSA_SOFTCORE=0,parameter ROM_FILE="rsa_control.hex"
) (
 input wire clock_i,reset_n_i,abort_i,
 input wire request_valid_i,output wire request_ready_o,input wire [1:0] request_profile_i,request_mode_i,
 input wire [31:0] request_id_i,input wire [255:0] test_seed_i,
 input wire receiver_ready_i,receiver_scrub_done_i,
 output wire result_valid_o,input wire result_ready_i,output wire [31:0] result_data_o,
 output wire [2:0] result_component_o,output wire [6:0] result_index_o,
 output wire result_component_last_o,result_last_o,output wire [31:0] result_id_o,
 input wire ownership_valid_i,ownership_accept_i,output wire ownership_ready_o,output wire result_discard_o,
 output wire status_valid_o,input wire status_ready_i,output wire [3:0] status_code_o,
 output wire [31:0] status_id_o,output wire ownership_committed_o,teardown_failed_o,source_fault_after_commit_o,
 input wire [7:0] cmd_data_i,input wire cmd_valid_i,cmd_last_i,output wire cmd_ready_o,
 output wire [7:0] rsp_data_o,output wire rsp_valid_o,rsp_last_o,input wire rsp_ready_i,
 input wire tpm_initialized_i,
 output wire health_fault_o,
 output wire operation_reset_n_o,
 output wire recovery_valid_o,input wire recovery_ready_i,output wire [31:0] recovery_id_o,
 output wire recovery_owned_o,output wire recovery_keygen_o,recovery_getrandom_o
);
 wire source_reset_n;
 rng_reset_sync reset_sync(.clock_i(clock_i),.reset_n_i(reset_n_i),.reset_n_o(source_reset_n));
 wire sample,sample_valid,seed_valid,seed_ready;
 wire [383:0] seed;
 entropy_source source(.clk(clock_i),.rst_n(source_reset_n),.enable(1'b1),
  .entropy_output(),.entropy_valid(),.raw_sample(sample),.raw_sample_valid(sample_valid));
 rng_entropy_seed #(.VALIDATED(VALIDATED_ENTROPY)) entropy(
  .clock_i(clock_i),.reset_n_i(source_reset_n),.clear_i(!operation_reset_n_o),
  .sample_i(sample),.sample_valid_i(sample_valid),.seed_valid_o(seed_valid),.seed_ready_i(seed_ready),.seed_o(seed),.health_fault_o(health_fault_o));
 rng_keygen_system #(.TEST_BUILD(0),.RSA_SOFTCORE(RSA_SOFTCORE),.ROM_FILE(ROM_FILE)) system(
 .clock_i(clock_i),
 .reset_n_i(source_reset_n),
 .abort_i(abort_i),
 .request_valid_i(request_valid_i),
 .request_ready_o(request_ready_o),
 .request_profile_i(request_profile_i),
 .request_mode_i(request_mode_i),
 .request_id_i(request_id_i),
 .test_seed_i(test_seed_i),
 .receiver_ready_i(receiver_ready_i),
 .receiver_scrub_done_i(receiver_scrub_done_i),
 .result_valid_o(result_valid_o),
 .result_ready_i(result_ready_i),
 .result_data_o(result_data_o),
 .result_component_o(result_component_o),
 .result_index_o(result_index_o),
 .result_component_last_o(result_component_last_o),
 .result_last_o(result_last_o),
 .result_id_o(result_id_o),
 .ownership_valid_i(ownership_valid_i),
 .ownership_accept_i(ownership_accept_i),
 .ownership_ready_o(ownership_ready_o),
 .result_discard_o(result_discard_o),
 .status_valid_o(status_valid_o),
 .status_ready_i(status_ready_i),
 .status_code_o(status_code_o),
 .status_id_o(status_id_o),
 .ownership_committed_o(ownership_committed_o),
 .teardown_failed_o(teardown_failed_o),
 .source_fault_after_commit_o(source_fault_after_commit_o),
 .cmd_data_i(cmd_data_i),
 .cmd_valid_i(cmd_valid_i),
 .cmd_last_i(cmd_last_i),
 .cmd_ready_o(cmd_ready_o),
 .rsp_data_o(rsp_data_o),
 .rsp_valid_o(rsp_valid_o),
 .rsp_last_o(rsp_last_o),
 .rsp_ready_i(rsp_ready_i),
 .tpm_initialized_i(tpm_initialized_i),
 .seed_valid_i(seed_valid),
 .seed_ready_o(seed_ready),
 .seed_i(seed),
 .health_fault_i(health_fault_o),
 .operation_reset_n_o(operation_reset_n_o),
 .recovery_valid_o(recovery_valid_o),
 .recovery_ready_i(recovery_ready_i),
 .recovery_id_o(recovery_id_o),
 .recovery_owned_o(recovery_owned_o),
 .recovery_keygen_o(recovery_keygen_o),
 .recovery_getrandom_o(recovery_getrandom_o));
endmodule
