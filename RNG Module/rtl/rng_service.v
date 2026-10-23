`timescale 1ns/1ps
// Exclusive context, held words, explicit open/close. No raw entropy is accepted here.
// TEST_BUILD uses the existing predictable fixture stream; production cannot select it.
// AI-assisted integration, October 23 2026.
module rng_service #(
 parameter TEST_BUILD=0, parameter [63:0] SETUP_LIMIT=64'd500000000
) (
 input wire clock_i,reset_n_i,
 input wire open_valid_i,output wire open_ready_o,input wire client_i,
 input wire [31:0] operation_id_i,input wire [1:0] mode_i,profile_i,
 input wire [15:0] procedure_version_i,input wire [31:0] context_handle_i,
 input wire [255:0] test_seed_i,
 output wire open_rsp_valid_o,input wire open_rsp_ready_i,output wire [3:0] open_status_o,
 output wire client_o,output wire [31:0] operation_id_o,
 input wire seed_valid_i,output wire seed_ready_o,input wire [383:0] seed_i,
 input wire health_fault_i,
 output wire word_valid_o,input wire word_ready_i,output wire [31:0] word_data_o,
 output wire context_fault_o,
 input wire close_valid_i,output wire close_ready_o,
 output wire close_rsp_valid_o,input wire close_rsp_ready_i,output wire close_fault_o
);
 localparam IDLE=0,SEED=1,INSTANTIATE=2,WAIT_INIT=3,OPEN_RESPONSE=4,ACTIVE=5,CLEAR=6,CLOSE_RESPONSE=7,FAIL_CLEAR=8,FAIL_RESPONSE=9;
 reg [3:0] state_reg,status_reg;
 reg client_reg,fault_reg;
 reg [31:0] id_reg;
 reg [383:0] seed_reg;
 reg [255:0] test_seed_reg,buffer_reg;
 reg buffer_valid_reg;
 reg [2:0] index_reg;
 reg [63:0] setup_count_reg;
 wire drbg_init_ready,drbg_initialized,drbg_generate_ready,drbg_valid,drbg_reseed_required;
 wire [255:0] drbg_block;
 wire test_ready,test_valid,test_failed;
 wire [31:0] test_word;
 wire clearing=state_reg==CLEAR || state_reg==FAIL_CLEAR;
 wire bad_fields=(mode_i==1 || mode_i==3 || (!TEST_BUILD && mode_i!=0) || context_handle_i!=0 ||
  (client_i ? (profile_i!=0 || procedure_version_i!=0) : (profile_i==3 || procedure_version_i!=1)));
 wire live_fault=fault_reg || health_fault_i || (TEST_BUILD ? test_failed : drbg_reseed_required);
 assign open_ready_o=reset_n_i && state_reg==IDLE;
 assign open_rsp_valid_o=reset_n_i && (state_reg==OPEN_RESPONSE || state_reg==FAIL_RESPONSE);
 assign open_status_o=status_reg;
 assign client_o=client_reg;assign operation_id_o=id_reg;
 assign seed_ready_o=reset_n_i && state_reg==SEED && !health_fault_i;
 assign context_fault_o=reset_n_i && live_fault && state_reg!=IDLE;
 assign word_valid_o=reset_n_i && state_reg==ACTIVE && !live_fault && !close_valid_i && (TEST_BUILD ? test_valid : buffer_valid_reg);
 assign word_data_o=word_valid_o ? (TEST_BUILD ? test_word : buffer_reg[255-index_reg*32 -:32]) : 32'b0;
 assign close_ready_o=reset_n_i && state_reg==ACTIVE;
 assign close_rsp_valid_o=reset_n_i && state_reg==CLOSE_RESPONSE;
 assign close_fault_o=live_fault;
 rng_hash_drbg drbg(.clock_i(clock_i),.reset_n_i(reset_n_i),.clear_i(clearing || live_fault),
  .instantiate_valid_i(!TEST_BUILD && state_reg==INSTANTIATE),.instantiate_ready_o(drbg_init_ready),.seed_i(seed_reg),
  .reseed_valid_i(1'b0),.reseed_ready_o(),.generate_valid_i(!TEST_BUILD && state_reg==ACTIVE && !buffer_valid_reg && !live_fault && !close_valid_i),
  .generate_ready_o(drbg_generate_ready),.initialized_o(drbg_initialized),.reseed_required_o(drbg_reseed_required),
  .block_valid_o(drbg_valid),.block_ready_i(state_reg==ACTIVE && !buffer_valid_reg && !live_fault && !close_valid_i),.block_o(drbg_block));
 // The test provider reset is registered by the state transition; never decode a
 // multi-bit state into an asynchronous reset pin. Synchronous clear is below.
 reg test_reset_n_reg;
 always @(posedge clock_i or negedge reset_n_i) begin
  if(!reset_n_i) test_reset_n_reg<=0;
  else if(clearing || live_fault || state_reg==IDLE) test_reset_n_reg<=0;
  else test_reset_n_reg<=1;
 end
 keygen_test_source fixture(.clock_i(clock_i),.reset_n_i(reset_n_i && test_reset_n_reg),
  .start_valid_i(TEST_BUILD && state_reg==INSTANTIATE),.start_ready_o(test_ready),.seed_i(test_seed_reg),
  .word_valid_o(test_valid),.word_ready_i(TEST_BUILD && word_valid_o && word_ready_i && !close_valid_i),.data_o(test_word),.failed_o(test_failed));
 always @(posedge clock_i or negedge reset_n_i) begin
  if(!reset_n_i) begin
   state_reg<=IDLE;status_reg<=0;client_reg<=0;id_reg<=0;seed_reg<=0;test_seed_reg<=0;
   buffer_reg<=0;buffer_valid_reg<=0;index_reg<=0;fault_reg<=0;setup_count_reg<=0;
  end else begin
   if(state_reg!=IDLE && live_fault) begin fault_reg<=1;buffer_reg<=0;buffer_valid_reg<=0;end
   if(state_reg==SEED || state_reg==INSTANTIATE || state_reg==WAIT_INIT) setup_count_reg<=setup_count_reg+1'b1;
   if((state_reg==SEED || state_reg==INSTANTIATE || state_reg==WAIT_INIT) && (live_fault || setup_count_reg>=SETUP_LIMIT)) begin
    status_reg<=2;fault_reg<=1;state_reg<=FAIL_CLEAR;
   end else case(state_reg)
    IDLE: if(open_valid_i) begin
     client_reg<=client_i;id_reg<=operation_id_i;test_seed_reg<=test_seed_i;setup_count_reg<=0;fault_reg<=0;status_reg<=0;
     if(bad_fields || health_fault_i) begin status_reg<=bad_fields ? 4'd1 : 4'd2;state_reg<=FAIL_CLEAR;end
     else state_reg<=TEST_BUILD ? INSTANTIATE : SEED;
    end
    SEED: if(seed_valid_i && seed_ready_o) begin seed_reg<=seed_i;state_reg<=INSTANTIATE;end
    INSTANTIATE: if(TEST_BUILD ? test_ready : drbg_init_ready) state_reg<=WAIT_INIT;
    WAIT_INIT: if(TEST_BUILD || drbg_initialized) begin seed_reg<=0;test_seed_reg<=0;state_reg<=OPEN_RESPONSE;end
    OPEN_RESPONSE: if(open_rsp_ready_i) state_reg<=ACTIVE;
    ACTIVE: begin
     if(close_valid_i) state_reg<=CLEAR;
     else if(!live_fault && !TEST_BUILD) begin
      if(drbg_valid && !buffer_valid_reg) begin buffer_reg<=drbg_block;buffer_valid_reg<=1;index_reg<=0;end
      if(word_valid_o && word_ready_i) begin
       if(index_reg==7) begin buffer_reg<=0;buffer_valid_reg<=0;index_reg<=0;end
       else index_reg<=index_reg+1'b1;
      end
     end
    end
    CLEAR: begin seed_reg<=0;test_seed_reg<=0;buffer_reg<=0;buffer_valid_reg<=0;index_reg<=0;state_reg<=CLOSE_RESPONSE;end
    CLOSE_RESPONSE: if(close_rsp_ready_i) begin fault_reg<=0;id_reg<=0;state_reg<=IDLE;end
    FAIL_CLEAR: begin seed_reg<=0;test_seed_reg<=0;buffer_reg<=0;buffer_valid_reg<=0;index_reg<=0;state_reg<=FAIL_RESPONSE;end
    FAIL_RESPONSE: if(open_rsp_ready_i) begin fault_reg<=0;id_reg<=0;state_reg<=IDLE;end
    default: begin fault_reg<=1;status_reg<=2;state_reg<=FAIL_CLEAR;end
   endcase
  end
 end
endmodule
