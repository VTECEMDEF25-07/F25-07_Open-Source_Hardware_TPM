`timescale 1ns/1ps
// Transaction setup/teardown around the unchanged portable core.
// Receiver scrub acknowledgment is distinct from receiver readiness.
// AI-assisted integration, October 23 2026.
module keygen_rng_coordinator #(
 parameter RSA_SOFTCORE=0,parameter ROM_FILE="rsa_control.hex"
) (
 input wire clock_i,reset_n_i,
 input wire request_valid_i,output wire request_ready_o,input wire [1:0] request_profile_i,request_mode_i,
 input wire [31:0] request_id_i,input wire receiver_ready_i,receiver_scrub_done_i,
 output wire result_valid_o,input wire result_ready_i,output wire [31:0] result_data_o,
 output wire [2:0] result_component_o,output wire [6:0] result_index_o,
 output wire result_component_last_o,result_last_o,output wire [31:0] result_id_o,
 input wire ownership_valid_i,ownership_accept_i,output wire ownership_ready_o,output wire result_discard_o,
 output wire status_valid_o,input wire status_ready_i,output wire [3:0] status_code_o,
 output wire [31:0] status_id_o,output wire ownership_committed_o,output wire teardown_failed_o,output wire source_fault_after_commit_o,
 output wire open_valid_o,input wire open_ready_i,output wire [31:0] open_id_o,
 output wire [1:0] open_mode_o,open_profile_o,
 input wire open_rsp_valid_i,output wire open_rsp_ready_o,input wire [3:0] open_status_i,
 input wire word_valid_i,output wire word_ready_o,input wire [31:0] word_data_i,input wire context_fault_i,
 output wire close_valid_o,input wire close_ready_i,input wire close_rsp_valid_i,
 output wire close_rsp_ready_o,input wire close_fault_i
);
 localparam IDLE=0,OPEN=1,OPEN_WAIT=2,ADMIT=3,RUN=4,CLOSE=5,CLOSE_WAIT=6,ACK=7,REPORT=8,SETUP_FAIL=9;
 reg [3:0] state_reg,status_reg;
 reg [31:0] id_reg;
 reg [1:0] profile_reg,mode_reg;
 reg fault_reg,committed_reg,teardown_reg,admitted_reg,late_fault_reg;
 wire core_request_ready,core_generation_ready,core_status_valid,core_discard,core_ownership_ready;
 wire [3:0] core_status;
 wire live_fault=fault_reg || context_fault_i;
 wire core_status_ack=state_reg==ACK && receiver_scrub_done_i;
 assign request_ready_o=reset_n_i && state_reg==IDLE && receiver_ready_i;
 assign open_valid_o=reset_n_i && state_reg==OPEN;
 assign open_id_o=id_reg;assign open_mode_o=mode_reg;assign open_profile_o=profile_reg;
 assign open_rsp_ready_o=reset_n_i && state_reg==OPEN_WAIT;
 assign word_ready_o=reset_n_i && state_reg==RUN && !live_fault && core_generation_ready;
 assign close_valid_o=reset_n_i && state_reg==CLOSE;
 assign close_rsp_ready_o=reset_n_i && state_reg==CLOSE_WAIT;
 assign status_valid_o=reset_n_i && state_reg==REPORT;
 assign status_code_o=status_reg;assign status_id_o=id_reg;
 assign ownership_committed_o=committed_reg;
 assign teardown_failed_o=teardown_reg;
 assign source_fault_after_commit_o=late_fault_reg;
 assign ownership_ready_o=core_ownership_ready && state_reg==RUN && !live_fault;
 assign result_discard_o=reset_n_i && (core_discard || state_reg==SETUP_FAIL || (!admitted_reg && state_reg==ACK));
 keygen_core #(.RSA_SOFTCORE(RSA_SOFTCORE),.ROM_FILE(ROM_FILE)) core(
  .clock_i(clock_i),.reset_n_i(reset_n_i),.peers_ready_i(receiver_ready_i && (state_reg>=ADMIT && state_reg<=ACK)),
  .request_valid_i(state_reg==ADMIT),.request_ready_o(core_request_ready),.request_profile_i(profile_reg),.request_id_i(id_reg),
  .generation_valid_i(word_valid_i && state_reg==RUN && !live_fault),.generation_ready_o(core_generation_ready),
  .generation_data_i(word_data_i),.generation_failed_i(live_fault),
  .result_valid_o(result_valid_o),.result_ready_i(result_ready_i),.result_data_o(result_data_o),
  .result_component_o(result_component_o),.result_index_o(result_index_o),.result_component_last_o(result_component_last_o),
  .result_last_o(result_last_o),.result_id_o(result_id_o),
  .ownership_valid_i(ownership_valid_i && state_reg==RUN && !live_fault),.ownership_ready_o(core_ownership_ready),.ownership_accept_i(ownership_accept_i),
  .result_discard_o(core_discard),.status_valid_o(core_status_valid),.status_ready_i(core_status_ack),.status_code_o(core_status),.status_id_o());
 always @(posedge clock_i or negedge reset_n_i) begin
  if(!reset_n_i) begin state_reg<=IDLE;status_reg<=0;id_reg<=0;profile_reg<=0;mode_reg<=0;fault_reg<=0;committed_reg<=0;teardown_reg<=0;admitted_reg<=0;late_fault_reg<=0;end
  else begin
   if(state_reg>=ADMIT && state_reg<=ACK && context_fault_i) fault_reg<=1;
   if(ownership_valid_i && ownership_ready_o && ownership_accept_i) committed_reg<=1;
   case(state_reg)
    IDLE: if(request_valid_i && request_ready_o) begin
     id_reg<=request_id_i;profile_reg<=request_profile_i;mode_reg<=request_mode_i;
     status_reg<=0;fault_reg<=0;committed_reg<=0;teardown_reg<=0;admitted_reg<=0;late_fault_reg<=0;state_reg<=OPEN;
    end
    OPEN: if(open_ready_i) state_reg<=OPEN_WAIT;
    OPEN_WAIT: if(open_rsp_valid_i) begin
     if(open_status_i!=0) begin status_reg<=open_status_i==1 ? 4'd1 : 4'd2;state_reg<=SETUP_FAIL;end
     else if(context_fault_i) begin fault_reg<=1;status_reg<=2;state_reg<=CLOSE;end
     else state_reg<=ADMIT;
    end
    ADMIT: if(!receiver_ready_i) begin status_reg<=8;state_reg<=CLOSE;end
           else if(core_request_ready) begin admitted_reg<=1;state_reg<=RUN;end
    RUN: if(core_status_valid) begin status_reg<=core_status;state_reg<=CLOSE;end
    CLOSE: if(close_ready_i) state_reg<=CLOSE_WAIT;
    CLOSE_WAIT: if(close_rsp_valid_i) begin
     // A late source fault after ownership is a separate teardown outcome.
     // close_fault reports source validity, not erasure failure. This local
     // service acknowledges close only after erasure; missing ack -> watchdog.
     teardown_reg<=0;
     late_fault_reg<=close_fault_i && committed_reg;
     if(close_fault_i && !committed_reg && status_reg==0) status_reg<=2;
     state_reg<=ACK;
    end
    ACK: if(receiver_scrub_done_i && (!admitted_reg || core_status_valid)) state_reg<=REPORT;
    SETUP_FAIL: if(receiver_scrub_done_i) state_reg<=REPORT;
    REPORT: if(status_ready_i) state_reg<=teardown_reg ? 4'd10 : IDLE;
    10: begin end // Failed teardown locks admission until reset; no repeated completion.
    default: state_reg<=SETUP_FAIL;
   endcase
  end
 end
endmodule
