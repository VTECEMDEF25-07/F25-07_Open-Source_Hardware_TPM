`timescale 1ns/1ps
// SHA-256 Hash_DRBG, 440-bit seedlen, 256-bit Generate requests, no additional_input.
// Instantiate: 256-bit entropy + 128-bit nonce. Reseed: 256-bit entropy.
// Inputs are trusted seed material, NOT an assertion about raw sample entropy.
// AI-assisted integration, October 23 2026. Verilog-2001.
module rng_hash_drbg (
 input wire clock_i,reset_n_i,clear_i,
 input wire instantiate_valid_i, output wire instantiate_ready_o,
 input wire [383:0] seed_i,
 input wire reseed_valid_i, output wire reseed_ready_o,
 input wire generate_valid_i, output wire generate_ready_o,
 output wire initialized_o, reseed_required_o,
 output wire block_valid_o,input wire block_ready_i,output wire [255:0] block_o
);
 localparam IDLE=0,ISSUE=1,WAIT_HASH=2,READY=3,OUTPUT_BLOCK=4;
 reg [2:0] state_reg,phase_reg;
 reg [439:0] v_reg,c_reg;
 reg [383:0] seed_reg;
 reg [255:0] first_reg,output_reg;
 reg [48:0] counter_reg;
 reg reseeding_reg;
 reg [887:0] message;
 reg [6:0] length;
 wire hash_ready,hash_valid;
 wire [255:0] digest;
 assign instantiate_ready_o=reset_n_i && !clear_i && state_reg==IDLE;
 assign initialized_o=reset_n_i && !clear_i && (state_reg==READY || state_reg==OUTPUT_BLOCK);
 assign reseed_required_o=counter_reg>49'h1000000000000;
 assign reseed_ready_o=reset_n_i && !clear_i && state_reg==READY;
 assign generate_ready_o=reseed_ready_o && !reseed_valid_i && !reseed_required_o;
 assign block_valid_o=reset_n_i && !clear_i && state_reg==OUTPUT_BLOCK;
 assign block_o=block_valid_o ? output_reg : 256'b0;
 always @* begin
  message=0;length=0;
  case(phase_reg)
   0,1: begin
    message[887:880]=(phase_reg==0) ? 8'd1 : 8'd2;
    message[879:848]=32'd440;
    if(reseeding_reg) begin
     message[847:840]=8'h01;message[839:400]=v_reg;message[399:144]=seed_reg[383:128];length=93;
    end else begin message[847:464]=seed_reg;length=53;end
   end
   2,3: begin
    message[887:880]=(phase_reg==2) ? 8'd1 : 8'd2;
    message[879:848]=32'd440;message[847:840]=8'h00;message[839:400]=v_reg;length=61;
   end
   4: begin message[887:448]=v_reg;length=55;end
   5: begin message[887:880]=8'h03;message[879:440]=v_reg;length=56;end
   default: begin end
  endcase
 end
 rng_sha256 hash(.clock_i(clock_i),.reset_n_i(reset_n_i),.clear_i(clear_i),
  .request_valid_i(state_reg==ISSUE),.request_ready_o(hash_ready),.message_i(message),.length_i(length),
  .response_valid_o(hash_valid),.response_ready_i(state_reg==WAIT_HASH),.digest_o(digest));
 always @(posedge clock_i or negedge reset_n_i) begin
  if(!reset_n_i) begin
   state_reg<=IDLE;phase_reg<=0;v_reg<=0;c_reg<=0;seed_reg<=0;first_reg<=0;output_reg<=0;counter_reg<=0;reseeding_reg<=0;
  end else if(clear_i) begin
   state_reg<=IDLE;phase_reg<=0;v_reg<=0;c_reg<=0;seed_reg<=0;first_reg<=0;output_reg<=0;counter_reg<=0;reseeding_reg<=0;
  end else case(state_reg)
   IDLE: if(instantiate_valid_i) begin seed_reg<=seed_i;reseeding_reg<=0;phase_reg<=0;state_reg<=ISSUE;end
   ISSUE: if(hash_ready) state_reg<=WAIT_HASH;
   WAIT_HASH: if(hash_valid) begin
    case(phase_reg)
     0: begin first_reg<=digest;phase_reg<=1;state_reg<=ISSUE;end
     1: begin v_reg<={first_reg,digest[255:72]};first_reg<=0;seed_reg<=0;phase_reg<=2;state_reg<=ISSUE;end
     2: begin first_reg<=digest;phase_reg<=3;state_reg<=ISSUE;end
     3: begin c_reg<={first_reg,digest[255:72]};first_reg<=0;counter_reg<=1;state_reg<=READY;end
     4: begin output_reg<=digest;phase_reg<=5;state_reg<=ISSUE;end
     5: begin v_reg<=v_reg+{184'b0,digest}+c_reg+{{391{1'b0}},counter_reg};counter_reg<=counter_reg+1'b1;state_reg<=OUTPUT_BLOCK;end
     default: state_reg<=IDLE;
    endcase
   end
   READY: begin
    if(reseed_valid_i) begin seed_reg<=seed_i;reseeding_reg<=1;phase_reg<=0;state_reg<=ISSUE;end
    else if(generate_valid_i && generate_ready_o) begin phase_reg<=4;state_reg<=ISSUE;end
   end
   OUTPUT_BLOCK: if(block_ready_i) begin output_reg<=0;state_reg<=READY;end
   default: state_reg<=IDLE;
  endcase
 end
endmodule
