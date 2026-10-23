`timescale 1ns/1ps
// Standalone GetRandom frontend. For shared keygen use rng_keygen_physical.
// Replaces the original hash/DRBG bypass. No tied-off startup or health status.
// VALIDATED_ENTROPY defaults OFF until physical entropy characterization.
module RNG #(parameter VALIDATED_ENTROPY=0) (
 input wire clk,rst_n,enable,tpm_initialized,
 input wire [7:0] cmd_data,input wire cmd_valid,cmd_last,output wire cmd_ready,
 output wire [7:0] rsp_data,output wire rsp_valid,rsp_last,input wire rsp_ready,
 output wire health_fault
);
 wire source_reset_n;
 rng_reset_sync reset_sync(.clock_i(clk),.reset_n_i(rst_n),.reset_n_o(source_reset_n));
 wire sample,sample_valid,seed_valid,seed_ready;
 wire [383:0] seed;
 wire open_valid,open_ready,open_rsp_valid,open_rsp_ready,word_valid,word_ready,fault;
 wire close_valid,close_ready,close_rsp_valid,close_rsp_ready,close_fault;
 wire [3:0] open_status;wire [31:0] word_data;
 entropy_source source(.clk(clk),.rst_n(source_reset_n),.enable(enable),.entropy_output(),.entropy_valid(),.raw_sample(sample),.raw_sample_valid(sample_valid));
 rng_entropy_seed #(.VALIDATED(VALIDATED_ENTROPY)) entropy(.clock_i(clk),.reset_n_i(source_reset_n),.clear_i(!enable),
 .sample_i(sample),.sample_valid_i(sample_valid),.seed_valid_o(seed_valid),.seed_ready_i(seed_ready),.seed_o(seed),.health_fault_o(health_fault));
 rng_service service(.clock_i(clk),.reset_n_i(source_reset_n),.open_valid_i(open_valid),.open_ready_o(open_ready),
 .client_i(1'b1),.operation_id_i(32'b0),.mode_i(2'b0),.profile_i(2'b0),.procedure_version_i(16'b0),.context_handle_i(32'b0),.test_seed_i(256'b0),
 .open_rsp_valid_o(open_rsp_valid),.open_rsp_ready_i(open_rsp_ready),.open_status_o(open_status),.client_o(),.operation_id_o(),
 .seed_valid_i(seed_valid),.seed_ready_o(seed_ready),.seed_i(seed),.health_fault_i(health_fault || !enable),
 .word_valid_o(word_valid),.word_ready_i(word_ready),.word_data_o(word_data),.context_fault_o(fault),
 .close_valid_i(close_valid),.close_ready_o(close_ready),.close_rsp_valid_o(close_rsp_valid),.close_rsp_ready_i(close_rsp_ready),.close_fault_o(close_fault));
 rng_getrandom frontend(.clock_i(clk),.reset_n_i(source_reset_n),.tpm_initialized_i(tpm_initialized),
 .cmd_data_i(cmd_data),.cmd_valid_i(cmd_valid),.cmd_last_i(cmd_last),.cmd_ready_o(cmd_ready),
 .rsp_data_o(rsp_data),.rsp_valid_o(rsp_valid),.rsp_last_o(rsp_last),.rsp_ready_i(rsp_ready),
 .open_valid_o(open_valid),.open_ready_i(open_ready),.open_rsp_valid_i(open_rsp_valid),.open_rsp_ready_o(open_rsp_ready),.open_status_i(open_status),
 .word_valid_i(word_valid),.word_ready_o(word_ready),.word_data_i(word_data),.context_fault_i(fault),
 .close_valid_o(close_valid),.close_ready_i(close_ready),.close_rsp_valid_i(close_rsp_valid),.close_rsp_ready_o(close_rsp_ready),.close_fault_i(close_fault),.busy_o());
endmodule
