`timescale 1ns/1ps
module tb_rng_crypto;
 reg clk=0;always #5 clk=~clk;
 reg reset_n=0,clear=0,init=0,reseed=0,gen=0,ready=0;
 reg [383:0] seed=0,seeds[0:3];
 reg [255:0] expected[0:19];
 wire init_ready,reseed_ready,gen_ready,initialized,required,valid;
 wire [255:0] block_data;
 rng_hash_drbg dut(.clock_i(clk),.reset_n_i(reset_n),.clear_i(clear),.instantiate_valid_i(init),.instantiate_ready_o(init_ready),.seed_i(seed),
  .reseed_valid_i(reseed),.reseed_ready_o(reseed_ready),.generate_valid_i(gen),.generate_ready_o(gen_ready),
  .initialized_o(initialized),.reseed_required_o(required),.block_valid_o(valid),.block_ready_i(ready),.block_o(block_data));
 reg hash_request=0,hash_ready=0;
 reg [887:0] message=0,messages[0:5];reg [6:0] length=0;
 wire hash_accept,hash_valid;wire [255:0] digest;
 reg [255:0] digests[0:5];
 integer lengths[0:5];
 rng_sha256 hash(.clock_i(clk),.reset_n_i(reset_n),.clear_i(clear),.request_valid_i(hash_request),.request_ready_o(hash_accept),
  .message_i(message),.length_i(length),.response_valid_o(hash_valid),.response_ready_i(hash_ready),.digest_o(digest));
 task tick; @(posedge clk);#1;endtask
 task generation(input integer index);
  wait(gen_ready);@(negedge clk);gen=1;tick();@(negedge clk);gen=0;
  wait(valid);#1;
  if(block_data!==expected[index]) $fatal(1,"DRBG vector %0d expected %h got %h",index,expected[index],block_data);
  repeat(7) begin tick();if(!valid || block_data!==expected[index]) $fatal(1,"DRBG stall");end
  @(negedge clk);ready=1;tick();@(negedge clk);ready=0;
 endtask
 integer s,j,b;
 initial begin
  $readmemh("seeds.hex",seeds);$readmemh("drbg.hex",expected);$readmemh("messages.hex",messages);$readmemh("digests.hex",digests);
  lengths[0]=0;lengths[1]=3;lengths[2]=55;lengths[3]=56;lengths[4]=64;lengths[5]=111;
  repeat(3) tick();@(negedge clk);reset_n=1;
  for(s=0;s<6;s=s+1) begin
   @(negedge clk);message=messages[s];length=lengths[s];hash_request=1;
   tick();@(negedge clk);hash_request=0;wait(hash_valid);#1;
   repeat(5) begin tick();if(!hash_valid || digest!==digests[s]) $fatal(1,"SHA length %0d",length);end
   @(negedge clk);hash_ready=1;tick();@(negedge clk);hash_ready=0;
  end
  for(s=0;s<4;s=s+1) begin
   @(negedge clk);seed=seeds[s];init=1;tick();@(negedge clk);init=0;wait(initialized);
   for(j=0;j<3;j=j+1) generation(s*5+j);
   @(negedge clk);for(b=0;b<32;b=b+1) seed[383-b*8 -:8]=seeds[s][135+b*8 -:8];
   reseed=1;tick();@(negedge clk);reseed=0;wait(initialized);
   for(j=3;j<5;j=j+1) generation(s*5+j);
   @(negedge clk);clear=1;tick();@(negedge clk);clear=0;
   if(dut.v_reg!==0 || dut.c_reg!==0 || dut.output_reg!==0 || dut.seed_reg!==0) $fatal(1,"DRBG erase");
  end
  // Reset while hashing and clear a pending output, then prove reuse.
  @(negedge clk);seed=seeds[0];init=1;tick();@(negedge clk);init=0;
  repeat(30) tick();@(negedge clk);reset_n=0;tick();@(negedge clk);reset_n=1;
  if(valid || dut.v_reg!==0) $fatal(1,"reset");
  @(negedge clk);init=1;tick();@(negedge clk);init=0;wait(initialized);generation(0);
  $display("PASS tb_rng_crypto: six SHA vectors with stalls; 20 DRBG instantiate/generate/reseed vectors; erase/reset/reuse");$finish;
 end
 initial begin #1000000;$fatal(1,"timeout");end
endmodule
