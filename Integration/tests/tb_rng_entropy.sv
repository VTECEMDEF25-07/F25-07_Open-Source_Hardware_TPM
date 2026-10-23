`timescale 1ns/1ps
module tb_rng_entropy;
 reg clk=0;always #5 clk=~clk;
 reg reset_n=0,clear=0,sample=0,sample_valid=0,ready=0;
 wire valid,fault,disabled_valid;wire [383:0] seed;
 reg [383:0] expected[0:1];
 rng_entropy_seed #(.VALIDATED(1)) dut(.clock_i(clk),.reset_n_i(reset_n),.clear_i(clear),.sample_i(sample),.sample_valid_i(sample_valid),
 .seed_valid_o(valid),.seed_ready_i(ready),.seed_o(seed),.health_fault_o(fault));
 rng_entropy_seed disabled(.clock_i(clk),.reset_n_i(reset_n),.clear_i(clear),.sample_i(sample),.sample_valid_i(sample_valid),
 .seed_valid_o(disabled_valid),.seed_ready_i(ready),.seed_o(),.health_fault_o());
 task tick;@(posedge clk);#1;endtask
 task bit_sample(input bit value);
  @(negedge clk);sample=value;sample_valid=1;tick();@(negedge clk);sample_valid=0;
 endtask
 integer j;
 initial begin
  $readmemh("entropy.hex",expected);repeat(3) tick();@(negedge clk);reset_n=1;
  for(j=0;j<1024;j=j+1) bit_sample(j%2);
  for(j=0;j<768;j=j+1) bit_sample(j%2);
  wait(dut.state_reg==0);
  for(j=0;j<768;j=j+1) bit_sample(j%2);
  wait(valid);#1;if(seed!==expected[0]) $fatal(1,"conditioning mismatch %h %h",seed,expected[0]);
  // Source continues while the consumer stalls; the committed seed is stable.
  for(j=0;j<1024;j=j+1) begin bit_sample(j%2);if(!valid || seed!==expected[0] || disabled_valid) $fatal(1,"seed hold/default gate");end
  @(negedge clk);ready=1;tick();@(negedge clk);ready=0;
  if(dut.seed_reg!==0 || valid) $fatal(1,"seed consumed twice");
  // Distinct second seed. Keep sampling even through both hash operations.
  for(j=0;j<768;j=j+1) bit_sample((j%4)>=2);
  while(dut.state_reg!=0) bit_sample(!sample);
  for(j=0;j<768;j=j+1) bit_sample((j%4)>=2);
  wait(valid);#1;if(seed!==expected[1]) $fatal(1,"second seed");
  // Fault on acceptance suppresses the seed and remains latched.
  bit_sample(0);for(j=0;j<31;j=j+1) bit_sample(1);
  @(negedge clk);sample=1;sample_valid=1;ready=1;#1;
  if(valid) $fatal(1,"fault acceptance priority");tick();@(negedge clk);sample_valid=0;ready=0;
  if(!fault || dut.seed_reg!==0) $fatal(1,"fault erase");
  // A stuck source faults and operation clear cannot erase the health alarm.
  repeat(34) bit_sample(1);if(!fault || valid) $fatal(1,"RCT fault");
  @(negedge clk);clear=1;tick();@(negedge clk);clear=0;tick();if(!fault) $fatal(1,"health cleared by operation abort");
  @(negedge clk);reset_n=0;tick();@(negedge clk);reset_n=1;
  // Biased but not stuck: 3 ones then zero; only APT should trigger.
  for(j=0;j<512;j=j+1) bit_sample(j%4!=0);
  if(!fault) $fatal(1,"APT fault");
  // Abort partial collection and an active hash: no old seed may escape.
  @(negedge clk);reset_n=0;tick();@(negedge clk);reset_n=1;
  for(j=0;j<1024+128;j=j+1) bit_sample(j%2);
  @(negedge clk);clear=1;tick();@(negedge clk);clear=0;
  if(valid || dut.samples_data_reg!==0 || dut.startup_reg!==0) $fatal(1,"partial clear");
  for(j=0;j<1024+768;j=j+1) bit_sample(j%2);
  wait(dut.state_reg==2);@(negedge clk);clear=1;tick();@(negedge clk);clear=0;
  repeat(150) tick();if(valid || dut.seed_reg!==0 || dut.conditioner.chain_reg!==0) $fatal(1,"hash clear");
  $display("PASS tb_rng_entropy: independent two-seed conditioning, continuous stalled sampling, startup, consumed seed erase, default disabled, RCT/APT, fault-at-acceptance, partial/hash clear");$finish;
 end
 initial begin #1000000;$fatal(1,"timeout");end
endmodule
