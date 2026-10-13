`timescale 1ns/1ps
// Fast integration checks use the real engine, CPU and storage. Successful RSA
// arithmetic is covered by tb_keygen_full, not substituted by this test.
module tb_keygen_lifecycle;
`ifdef KEYGEN_SOFTCORE
 localparam SOFTCORE=1;
`else
 localparam SOFTCORE=0;
`endif
 reg clock_i=0;always #10 clock_i=~clock_i;
 reg reset_n_i=0,peers_ready_i=1,request_valid_i=0;
 wire request_ready_o;
 reg [1:0]request_profile_i=0;
 reg [31:0]request_id_i=0;
 reg generation_valid_i=0,generation_failed_i=0;
 reg [31:0]generation_data_i=0;
 wire generation_ready_o,result_valid_o;
 reg result_ready_i=0;
 wire [31:0]result_data_o,result_id_o;
 wire [2:0]result_component_o;
 wire [6:0]result_index_o;
 wire result_component_last_o,result_last_o;
 reg ownership_valid_i=0,ownership_accept_i=1;
 wire ownership_ready_o,result_discard_o,status_valid_o;
 reg status_ready_i=0;
 wire [3:0]status_code_o;
 wire [31:0]status_id_o;
 integer tests=0,j;
 reg [31:0]active_id=0,held_word;
 keygen_core #(.RSA_SOFTCORE(SOFTCORE)) dut(.*);
 task tick;@(posedge clock_i);#1;endtask
 task request(input [1:0]profile);
  wait(request_ready_o);@(negedge clock_i);
  active_id=active_id+1;request_id_i=active_id;request_profile_i=profile;request_valid_i=1;
  tick();@(negedge clock_i);request_valid_i=0;request_profile_i=3;request_id_i=32'hbadbad;
 endtask
 task word(input [31:0]value);
  @(negedge clock_i);generation_data_i=value;generation_valid_i=1;
  do tick();while(!generation_ready_o); // Draw remains ready for these words.
  @(negedge clock_i);generation_valid_i=0;
 endtask
 task terminal(input [3:0]code);
  wait(status_valid_o);#1;
  repeat(4)begin
   if(status_code_o!==code||status_id_o!==active_id||request_ready_o)$fatal(1,"terminal metadata/hold");
   if(result_valid_o||generation_ready_o||ownership_ready_o)$fatal(1,"transfer during terminal");
   tick();
  end
  @(negedge clock_i);status_ready_i=1;tick();@(negedge clock_i);status_ready_i=0;
  wait(request_ready_o);tests++;
 endtask
 task reset_core;
  @(negedge clock_i);reset_n_i=0;#1;
  if(request_ready_o||generation_ready_o||result_valid_o||ownership_ready_o||status_valid_o)
   $fatal(1,"reset did not invalidate transfers");
  generation_valid_i=0;generation_failed_i=0;peers_ready_i=1;
  ownership_valid_i=0;status_ready_i=0;result_ready_i=0;request_valid_i=0;
  repeat(3)tick();@(negedge clock_i);reset_n_i=1;
  repeat(100)begin tick();if(request_ready_o)$fatal(1,"admission before memory scrub");end
  wait(request_ready_o);if(status_valid_o||result_valid_o)$fatal(1,"stale state after reset");tests++;
 endtask
 task aes(input [1:0]profile,input bit accept);
  request(profile);
  for(integer k=0;k<(profile==0?4:8);k++)begin
   repeat(k%3)tick();
   @(negedge clock_i);generation_data_i=32'h11223300+k;generation_valid_i=1;
   // Observe ready before the sampling edge; the final edge can deassert it.
   wait(generation_ready_o);tick();@(negedge clock_i);generation_valid_i=0;
  end
  for(integer k=0;k<(profile==0?4:8);k++)begin
   wait(result_valid_o);#1;held_word=result_data_o;
   if(held_word!==(32'h11223300+k)||result_index_o!==k||result_component_o!==1||result_id_o!==active_id)
    $fatal(1,"AES wrapper ordering/capture");
   if(result_last_o!==(k==(profile==0?3:7)))$fatal(1,"AES last");
   repeat(4)begin tick();if(!result_valid_o||result_data_o!==held_word)$fatal(1,"result stall");end
   @(negedge clock_i);result_ready_i=1;tick();@(negedge clock_i);result_ready_i=0;
  end
  wait(ownership_ready_o);repeat(4)begin tick();if(status_valid_o)$fatal(1,"premature success");end
  @(negedge clock_i);ownership_accept_i=accept;ownership_valid_i=1;
  tick();@(negedge clock_i);ownership_valid_i=0;
  terminal(accept?0:5);
 endtask
 initial begin
  reset_core();aes(0,1);aes(1,1);aes(0,0);
  request(3);terminal(1);
  // No generation words are offered: a legal source stall must not time out.
  request(2);wait(generation_ready_o);repeat(300)tick();
  if(status_valid_o||request_ready_o)$fatal(1,"external stall treated as completion");
  @(negedge clock_i);generation_failed_i=1;
  wait(result_discard_o);@(negedge clock_i);peers_ready_i=0;
  wait(status_valid_o);if(status_code_o!==2)$fatal(1,"first fault overwritten");
  @(negedge clock_i);generation_failed_i=0;peers_ready_i=1;terminal(2);aes(0,1);
  request(2);wait(generation_ready_o);@(negedge clock_i);peers_ready_i=0;
  wait(status_valid_o);if(status_code_o!==8)$fatal(1,"peer fault");
  @(negedge clock_i);peers_ready_i=1;terminal(8);
  // Reset after partially filling the candidate must not preserve its words.
  request(2);wait(generation_ready_o);
  for(j=0;j<7;j++)word(32'hdead0000+j);
  reset_core();aes(1,1);
  // Reset while an AES result is backpressured, during cleanup and at status.
  request(0);
  for(j=0;j<4;j++)begin
   @(negedge clock_i);generation_valid_i=1;generation_data_i=j;
   wait(generation_ready_o);tick();@(negedge clock_i);generation_valid_i=0;
  end
  wait(result_valid_o);reset_core();aes(0,1);
  request(3);wait(dut.state_reg==11);reset_core();
  request(3);wait(status_valid_o);reset_core();aes(0,1);
  $display("PASS CORE_LIFECYCLE softcore=%0d checks=%0d",SOFTCORE,tests);$finish;
 end
 initial begin #20000000;$fatal(1,"lifecycle timeout state=%0d",dut.state_reg);end
endmodule
