`timescale 1ns/1ps
// Shared service integration. One source reservation, independent GetRandom TX buffer.
// Supervisor reset is distinct from operation abort; retained metadata reconciles ownership.
// AI-assisted integration, October 23 2026.
module rng_keygen_system #(
 parameter TEST_BUILD=0,parameter RSA_SOFTCORE=0,parameter ROM_FILE="rsa_control.hex",
 parameter [63:0] SETUP_LIMIT=64'd500000000,parameter [63:0] OPERATION_LIMIT=64'd9000000000
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
 input wire seed_valid_i,output wire seed_ready_o,input wire [383:0] seed_i,input wire health_fault_i,
 output wire operation_reset_n_o,
 output wire recovery_valid_o,input wire recovery_ready_i,output wire [31:0] recovery_id_o,
 output wire recovery_owned_o,output wire recovery_keygen_o,recovery_getrandom_o
);
 wire k_open,g_open,open_ready,owner,open_rsp,word_valid,context_fault,close_ready,close_rsp,close_fault;
 wire k_open_rsp_ready,g_open_rsp_ready,k_word_ready,g_word_ready,k_close,g_close,k_close_rsp_ready,g_close_rsp_ready;
 wire [31:0] k_id,word_data;
 wire [1:0] k_mode,k_profile;
 wire [3:0] open_status;
 reg last_owner_reg;
 wire choose_g=g_open && (!k_open || !last_owner_reg);
 wire k_request_ready,g_busy;
 reg keygen_busy_reg,getrandom_busy_reg,owned_reg,recovery_reg,recovery_owned_reg,recovery_keygen_reg,recovery_getrandom_reg;
 reg [31:0] active_id_reg,recovery_id_reg;
 reg [63:0] elapsed_reg,getrandom_elapsed_reg;
 reg [2:0] reset_count_reg;
 reg [1:0] release_reg;
 reg operation_reset_n_reg;
 // A terminal transfer at the deadline completes that client, not both success
 // and recovery. The other simultaneously active client can still time out.
 wire keygen_complete=status_valid_o && status_ready_i && !teardown_failed_o;
 wire getrandom_complete=rsp_valid_o && rsp_ready_i && rsp_last_o;
 wire keygen_pending=keygen_busy_reg && !keygen_complete;
 wire getrandom_pending=getrandom_busy_reg && !getrandom_complete;
 wire timeout_fault=(keygen_pending && elapsed_reg>=OPERATION_LIMIT) || (getrandom_pending && getrandom_elapsed_reg>=OPERATION_LIMIT);
 wire operation_running=reset_n_i && release_reg[1] && operation_reset_n_reg && !abort_i;
 assign operation_reset_n_o=operation_running;
 assign request_ready_o=k_request_ready && !recovery_reg && !timeout_fault;
 assign recovery_valid_o=recovery_reg;
 assign recovery_id_o=recovery_id_reg;
 assign recovery_owned_o=recovery_owned_reg;
 assign recovery_keygen_o=recovery_keygen_reg;
 assign recovery_getrandom_o=recovery_getrandom_reg;
 always @(posedge clock_i or negedge reset_n_i) begin
  if(!reset_n_i) begin
   release_reg<=0;reset_count_reg<=0;keygen_busy_reg<=0;getrandom_busy_reg<=0;owned_reg<=0;active_id_reg<=0;elapsed_reg<=0;getrandom_elapsed_reg<=0;
   recovery_reg<=0;recovery_id_reg<=0;recovery_owned_reg<=0;recovery_keygen_reg<=0;recovery_getrandom_reg<=0;operation_reset_n_reg<=0;
  end else begin
   release_reg<={release_reg[0],1'b1};
   if(recovery_reg && recovery_ready_i) recovery_reg<=0;
   if(reset_count_reg!=0) begin reset_count_reg<=reset_count_reg-1'b1;elapsed_reg<=0;getrandom_elapsed_reg<=0;operation_reset_n_reg<=reset_count_reg==1;end
   else if(abort_i || timeout_fault) begin
    reset_count_reg<=4;elapsed_reg<=0;getrandom_elapsed_reg<=0;operation_reset_n_reg<=0;
    if(!recovery_reg && (keygen_pending || getrandom_pending)) begin
     recovery_reg<=1;recovery_id_reg<=active_id_reg;
     recovery_owned_reg<=owned_reg || (ownership_valid_i && ownership_ready_o && ownership_accept_i);
     recovery_keygen_reg<=keygen_pending;recovery_getrandom_reg<=getrandom_pending;
    end
    keygen_busy_reg<=0;getrandom_busy_reg<=0;owned_reg<=0;
   end else begin
    operation_reset_n_reg<=1;
    if(keygen_busy_reg) elapsed_reg<=elapsed_reg+1'b1;else elapsed_reg<=0;
    if(getrandom_busy_reg) getrandom_elapsed_reg<=getrandom_elapsed_reg+1'b1;else getrandom_elapsed_reg<=0;
    if(cmd_valid_i && cmd_ready_o && !getrandom_busy_reg) begin getrandom_busy_reg<=1;getrandom_elapsed_reg<=0;end
    if(rsp_valid_o && rsp_ready_i && rsp_last_o) getrandom_busy_reg<=0;
    if(request_valid_i && request_ready_o) begin keygen_busy_reg<=1;owned_reg<=0;active_id_reg<=request_id_i;end
    if(ownership_valid_i && ownership_ready_o && ownership_accept_i) owned_reg<=1;
    if(status_valid_o && status_ready_i && !teardown_failed_o) begin keygen_busy_reg<=0;owned_reg<=0;end
   end
  end
 end
 always @(posedge clock_i or negedge operation_reset_n_o) begin
  if(!operation_reset_n_o) last_owner_reg<=1;
  else if(open_ready && (k_open || g_open)) last_owner_reg<=choose_g;
 end
 keygen_rng_coordinator #(.RSA_SOFTCORE(RSA_SOFTCORE),.ROM_FILE(ROM_FILE)) keygen(
  .clock_i(clock_i),.reset_n_i(operation_reset_n_o),
  .request_valid_i(request_valid_i && !recovery_reg && !timeout_fault),.request_ready_o(k_request_ready),.request_profile_i(request_profile_i),.request_mode_i(request_mode_i),.request_id_i(request_id_i),
  .receiver_ready_i(receiver_ready_i),.receiver_scrub_done_i(receiver_scrub_done_i),
  .result_valid_o(result_valid_o),.result_ready_i(result_ready_i),.result_data_o(result_data_o),.result_component_o(result_component_o),
  .result_index_o(result_index_o),.result_component_last_o(result_component_last_o),.result_last_o(result_last_o),.result_id_o(result_id_o),
  .ownership_valid_i(ownership_valid_i),.ownership_accept_i(ownership_accept_i),.ownership_ready_o(ownership_ready_o),.result_discard_o(result_discard_o),
  .status_valid_o(status_valid_o),.status_ready_i(status_ready_i),.status_code_o(status_code_o),.status_id_o(status_id_o),
  .ownership_committed_o(ownership_committed_o),.teardown_failed_o(teardown_failed_o),.source_fault_after_commit_o(source_fault_after_commit_o),
  .open_valid_o(k_open),.open_ready_i(open_ready && !choose_g),.open_id_o(k_id),.open_mode_o(k_mode),.open_profile_o(k_profile),
  .open_rsp_valid_i(open_rsp && !owner),.open_rsp_ready_o(k_open_rsp_ready),.open_status_i(open_status),
  .word_valid_i(word_valid && !owner),.word_ready_o(k_word_ready),.word_data_i(owner ? 32'b0 : word_data),.context_fault_i(context_fault && !owner),
  .close_valid_o(k_close),.close_ready_i(close_ready && !owner),.close_rsp_valid_i(close_rsp && !owner),.close_rsp_ready_o(k_close_rsp_ready),.close_fault_i(close_fault));
 rng_getrandom getrandom(.clock_i(clock_i),.reset_n_i(operation_reset_n_o),.tpm_initialized_i(tpm_initialized_i),
  .cmd_data_i(cmd_data_i),.cmd_valid_i(cmd_valid_i && !recovery_reg && !timeout_fault),.cmd_last_i(cmd_last_i),.cmd_ready_o(cmd_ready_internal),
  .rsp_data_o(rsp_data_o),.rsp_valid_o(rsp_valid_o),.rsp_last_o(rsp_last_o),.rsp_ready_i(rsp_ready_i),
  .open_valid_o(g_open),.open_ready_i(open_ready && choose_g),.open_rsp_valid_i(open_rsp && owner),.open_rsp_ready_o(g_open_rsp_ready),.open_status_i(open_status),
  .word_valid_i(word_valid && owner),.word_ready_o(g_word_ready),.word_data_i(owner ? word_data : 32'b0),.context_fault_i(context_fault && owner),
  .close_valid_o(g_close),.close_ready_i(close_ready && owner),.close_rsp_valid_i(close_rsp && owner),.close_rsp_ready_o(g_close_rsp_ready),.close_fault_i(close_fault),.busy_o(g_busy));
 wire cmd_ready_internal;
 assign cmd_ready_o=cmd_ready_internal && !recovery_reg && !timeout_fault;
 rng_service #(.TEST_BUILD(TEST_BUILD),.SETUP_LIMIT(SETUP_LIMIT)) service(
  .clock_i(clock_i),.reset_n_i(operation_reset_n_o),.open_valid_i(open_ready && (k_open || g_open)),.open_ready_o(open_ready),
  .client_i(choose_g),.operation_id_i(choose_g ? 32'b0 : k_id),.mode_i(choose_g ? 2'b0 : k_mode),.profile_i(choose_g ? 2'b0 : k_profile),
  .procedure_version_i(choose_g ? 16'd0 : 16'd1),.context_handle_i(32'b0),.test_seed_i(test_seed_i),
  .open_rsp_valid_o(open_rsp),.open_rsp_ready_i(owner ? g_open_rsp_ready : k_open_rsp_ready),.open_status_o(open_status),.client_o(owner),.operation_id_o(),
  .seed_valid_i(seed_valid_i),.seed_ready_o(seed_ready_o),.seed_i(seed_i),.health_fault_i(health_fault_i),
  .word_valid_o(word_valid),.word_ready_i(owner ? g_word_ready : k_word_ready),.word_data_o(word_data),.context_fault_o(context_fault),
  .close_valid_i(owner ? g_close : k_close),.close_ready_o(close_ready),.close_rsp_valid_o(close_rsp),
  .close_rsp_ready_i(owner ? g_close_rsp_ready : k_close_rsp_ready),.close_fault_o(close_fault));
endmodule
