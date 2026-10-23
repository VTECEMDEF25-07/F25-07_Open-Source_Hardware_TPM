`timescale 1ns/1ps
// Health monitoring and two conditioned sample windows -> entropy256 + nonce128.
// VALIDATED defaults OFF: thresholds/sample counts require physical source assessment.
// 768 samples/window is an engineering configuration, NOT 768 bits of entropy.
// AI-assisted integration, October 23 2026.
module rng_entropy_seed #(
 parameter VALIDATED=0,parameter STARTUP_SAMPLES=1024,
 parameter RCT_LIMIT=32,parameter APT_LOW=187,parameter APT_HIGH=325
) (
 input wire clock_i,reset_n_i,clear_i,
 input wire sample_i,sample_valid_i,
 output wire seed_valid_o,input wire seed_ready_i,output wire [383:0] seed_o,
 output wire health_fault_o
);
 localparam COLLECT=0,HASH=1,WAIT_HASH=2,OUTPUT_SEED=3;
 reg [1:0] state_reg;
 reg fault_reg,last_reg,seen_reg,second_reg;
 reg [31:0] startup_reg,run_reg;
 reg [9:0] window_reg,ones_reg;
 reg [9:0] samples_reg;
 reg [767:0] samples_data_reg;
 reg [383:0] seed_reg;
 wire [10:0] next_ones={1'b0,ones_reg}+{10'b0,sample_i};
 wire detected=sample_valid_i && ((seen_reg && sample_i==last_reg && run_reg>=RCT_LIMIT-1) ||
  (window_reg==511 && (next_ones<APT_LOW || next_ones>APT_HIGH)));
 wire hash_ready,hash_valid;
 wire [255:0] digest;
 assign health_fault_o=fault_reg || detected;
 assign seed_valid_o=reset_n_i && !clear_i && VALIDATED && !health_fault_o && state_reg==OUTPUT_SEED;
 assign seed_o=seed_valid_o ? seed_reg : 384'b0;
 rng_sha256 conditioner(.clock_i(clock_i),.reset_n_i(reset_n_i),.clear_i(clear_i || health_fault_o),
  .request_valid_i(state_reg==HASH),.request_ready_o(hash_ready),.message_i({samples_data_reg,120'b0}),.length_i(7'd96),
  .response_valid_o(hash_valid),.response_ready_i(state_reg==WAIT_HASH),.digest_o(digest));
 always @(posedge clock_i or negedge reset_n_i) begin
  if(!reset_n_i) begin
   fault_reg<=0;last_reg<=0;seen_reg<=0;run_reg<=0;window_reg<=0;ones_reg<=0;
  end else if(sample_valid_i && !fault_reg) begin
   if(detected) fault_reg<=1;
   last_reg<=sample_i;seen_reg<=1;
   if(!seen_reg || sample_i!=last_reg) run_reg<=1;else if(run_reg!=32'hffffffff) run_reg<=run_reg+1'b1;
   if(window_reg==511) begin window_reg<=0;ones_reg<=0;end
   else begin window_reg<=window_reg+1'b1;ones_reg<=next_ones[9:0];end
  end
 end
 always @(posedge clock_i or negedge reset_n_i) begin
  if(!reset_n_i) begin state_reg<=COLLECT;startup_reg<=0;samples_reg<=0;samples_data_reg<=0;seed_reg<=0;second_reg<=0;end
  else if(clear_i || health_fault_o) begin state_reg<=COLLECT;startup_reg<=0;samples_reg<=0;samples_data_reg<=0;seed_reg<=0;second_reg<=0;end
  else begin
   if(sample_valid_i && startup_reg<STARTUP_SAMPLES) startup_reg<=startup_reg+1'b1;
   case(state_reg)
    COLLECT: if(sample_valid_i && startup_reg>=STARTUP_SAMPLES) begin
     samples_data_reg<={samples_data_reg[766:0],sample_i};
     if(samples_reg==767) begin samples_reg<=0;state_reg<=HASH;end
     else samples_reg<=samples_reg+1'b1;
    end
    HASH: if(hash_ready) begin samples_data_reg<=0;state_reg<=WAIT_HASH;end
    WAIT_HASH: if(hash_valid) begin
     if(!second_reg) begin seed_reg[383:128]<=digest;second_reg<=1;state_reg<=COLLECT;end
     else begin seed_reg[127:0]<=digest[255:128];state_reg<=OUTPUT_SEED;end
    end
    OUTPUT_SEED: if(seed_valid_o && seed_ready_i) begin seed_reg<=0;second_reg<=0;state_reg<=COLLECT;end
    default: state_reg<=COLLECT;
   endcase
  end
 end
endmodule
