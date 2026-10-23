`timescale 1ns/1ps
module tb_rng_system;
`ifdef FRESH
 localparam TEST=0;
`else
 localparam TEST=1;
`endif
`ifdef KEYGEN_SOFTCORE
 localparam SOFT=1;
`else
 localparam SOFT=0;
`endif
 reg clock_i=0;always #5 clock_i=~clock_i;
 reg reset_n_i=0,abort_i=0,request_valid_i=0;
 wire request_ready_o;
 reg [1:0] request_profile_i=0,request_mode_i=0;
 reg [31:0] request_id_i=0;reg [255:0] test_seed_i=1;
 reg receiver_ready_i=1,receiver_scrub_done_i=1;
 wire result_valid_o;reg result_ready_i=1;wire [31:0] result_data_o,result_id_o;
 wire [2:0] result_component_o;wire [6:0] result_index_o;
 wire result_component_last_o,result_last_o;
 reg ownership_valid_i=0,ownership_accept_i=1;wire ownership_ready_o,result_discard_o;
 wire status_valid_o;reg status_ready_i=0;wire [3:0] status_code_o;wire [31:0] status_id_o;
 wire ownership_committed_o,teardown_failed_o,source_fault_after_commit_o;
 reg [7:0] cmd_data_i=0;reg cmd_valid_i=0,cmd_last_i=0;wire cmd_ready_o;
 wire [7:0] rsp_data_o;wire rsp_valid_o,rsp_last_o;reg rsp_ready_i=0,tpm_initialized_i=1;
 reg seed_valid_i=1;wire seed_ready_o;reg [383:0] seed_i=384'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f;
 reg health_fault_i=0;wire operation_reset_n_o,recovery_valid_o;reg recovery_ready_i=0;
 wire [31:0] recovery_id_o;wire recovery_owned_o,recovery_keygen_o,recovery_getrandom_o;
`ifdef WATCHDOG_TEST
 rng_keygen_system #(.TEST_BUILD(TEST),.RSA_SOFTCORE(SOFT),.OPERATION_LIMIT(64'd20000),.SETUP_LIMIT(64'd2000)) dut(.*);
`else
 rng_keygen_system #(.TEST_BUILD(TEST),.RSA_SOFTCORE(SOFT)) dut(.*);
`endif
 reg [31:0] fixture[0:7],rsa_words[0:128];reg [255:0] drbg[0:19];
 reg [31:0] expected[0:128];integer received=0,wanted=0,cycles=0;
 reg check_result=0;
 reg [7:0] command[0:11],response[0:43];
 reg bad_tag=0;
 always @(negedge clock_i) begin cycles=cycles+1;result_ready_i=(cycles%7<4);end
 always @(posedge clock_i) if(result_valid_o && result_ready_i && check_result) begin
  if(received>=wanted || result_data_o!==expected[received]) $fatal(1,"result %0d got %h expected %h",received,result_data_o,expected[received]);
  if(result_id_o!==request_id_i) $fatal(1,"result ID");
  received<=received+1;
 end
 task tick;@(posedge clock_i);#1;endtask
 task start_job(input [1:0] profile,input [1:0] mode);
  wait(request_ready_o);@(negedge clock_i);request_id_i=request_id_i+1;request_profile_i=profile;request_mode_i=mode;request_valid_i=1;
  tick();@(negedge clock_i);request_valid_i=0;
 endtask
 task terminal(input [3:0] code,input bit owned);
  wait(status_valid_o);#1;
  if(status_code_o!==code || ownership_committed_o!==owned) $fatal(1,"terminal code=%0d wanted=%0d owned=%b",status_code_o,code,ownership_committed_o);
  if(dut.service.buffer_reg!==0 || dut.service.drbg.v_reg!==0 || dut.service.drbg.c_reg!==0) $fatal(1,"source not erased before terminal");
  repeat(5) begin tick();if(!status_valid_o || request_ready_o) $fatal(1,"held terminal");end
  @(negedge clock_i);status_ready_i=1;tick();@(negedge clock_i);status_ready_i=0;
 endtask
 task accept_key;
  wait(ownership_ready_o);repeat(4) tick();@(negedge clock_i);ownership_valid_i=1;tick();@(negedge clock_i);ownership_valid_i=0;
 endtask
 task aes(input bit wide);
  received=0;wanted=wide?8:4;check_result=1;
  for(integer j=0;j<8;j=j+1) expected[j]=TEST ? fixture[j] : drbg[0][255-j*32 -:32];
  start_job(wide?1:0,0);wait(received==wanted);accept_key();terminal(0,1);check_result=0;
 endtask
 task send_command(input integer count);
  command[0]=bad_tag ? 8'h81 : 8'h80;command[1]=1;command[2]=0;command[3]=0;command[4]=0;command[5]=12;
  command[6]=0;command[7]=0;command[8]=1;command[9]=8'h7b;command[10]=count>>8;command[11]=count;
  for(integer j=0;j<12;j=j+1) begin
   wait(cmd_ready_o);@(negedge clock_i);cmd_data_i=command[j];cmd_valid_i=1;cmd_last_i=j==11;tick();@(negedge clock_i);cmd_valid_i=0;cmd_last_i=0;
  end
 endtask
 task read_response(input integer count,input [31:0] code);
  integer n;
  n=code==0 ? 12+count : 10;
  for(integer j=0;j<n;j=j+1) begin
   wait(rsp_valid_o);#1;response[j]=rsp_data_o;
   repeat(2) begin tick();if(!rsp_valid_o || rsp_data_o!==response[j]) $fatal(1,"GetRandom stalled data");end
   if(rsp_last_o!==(j==n-1)) $fatal(1,"response last");
   @(negedge clock_i);rsp_ready_i=1;tick();@(negedge clock_i);rsp_ready_i=0;
  end
  if({response[6],response[7],response[8],response[9]}!==code) $fatal(1,"GetRandom code");
  if({response[2],response[3],response[4],response[5]}!==n) $fatal(1,"GetRandom size");
  if(code==0) for(integer j=0;j<count;j=j+1) begin
   if(response[12+j] !== (TEST ? fixture[j/4][31-(j%4)*8 -:8] : drbg[0][255-j*8 -:8])) $fatal(1,"GetRandom byte %0d",j);
  end
 endtask
 initial begin
  $readmemh("fixture.hex",fixture);$readmemh("drbg.hex",drbg);$readmemh("rsa.hex",rsa_words);
  repeat(3) tick();@(negedge clock_i);reset_n_i=1;
`ifdef WATCHDOG_TEST
  // Stalled GetRandom response times out with a retained supervisor record.
  send_command(8);wait(rsp_valid_o);wait(recovery_valid_o);
  if(!recovery_getrandom_o || recovery_keygen_o) $fatal(1,"watchdog lost client");
  repeat(8) tick();if(cmd_ready_o) $fatal(1,"recovery not acknowledged");
  @(negedge clock_i);recovery_ready_i=1;tick();@(negedge clock_i);recovery_ready_i=0;
  send_command(1);read_response(1,0);
  seed_valid_i=0;start_job(0,0);terminal(2,0);seed_valid_i=1;aes(0);
  // A completion accepted exactly at its deadline must not also be aborted.
  start_job(0,0);accept_key();wait(status_valid_o);wait(dut.elapsed_reg==20000);
  @(negedge clock_i);status_ready_i=1;tick();@(negedge clock_i);status_ready_i=0;
  repeat(8) tick();if(recovery_valid_o) $fatal(1,"success also reported as timeout");
  send_command(1);wait(rsp_valid_o);
  repeat(12) begin @(negedge clock_i);rsp_ready_i=1;tick();@(negedge clock_i);rsp_ready_i=0;end
  if(!rsp_last_o) $fatal(1,"expected final byte");wait(dut.getrandom_elapsed_reg==20000);
  @(negedge clock_i);rsp_ready_i=1;tick();@(negedge clock_i);rsp_ready_i=0;
  repeat(8) tick();if(recovery_valid_o) $fatal(1,"response also reported as timeout");
  $display("PASS tb_rng_system watchdog: stalled-host reset/retained metadata, admission lock, setup timeout, retry");$finish;
`else
`ifdef RSA_TEST
`ifdef FRESH
  $readmemh("rsa_fresh.hex",rsa_words);
`endif
  test_seed_i=20;
  received=0;wanted=129;check_result=1;
  for(integer j=0;j<129;j=j+1) expected[j]=rsa_words[j];
  start_job(2,0);wait(received==129);accept_key();terminal(0,1);
  $display("PASS tb_rng_system full RSA-2048 shared service softcore=%0d cycles=%0d",SOFT,cycles);$finish;
`else
  aes(0);aes(1);
  // Complete GetRandom source teardown while its host is stalled; then run keygen.
  send_command(31);wait(rsp_valid_o);aes(0);read_response(31,0);
  send_command(0);read_response(0,0);
  send_command(1);read_response(1,0);send_command(3);read_response(3,0);
  send_command(4);read_response(4,0);send_command(32);read_response(32,0);send_command(65535);read_response(32,0);
  tpm_initialized_i=0;send_command(8);read_response(0,32'h100);tpm_initialized_i=1;
  bad_tag=1;send_command(8);read_response(0,32'h01e);bad_tag=0;
  send_command(8);wait(dut.service.state_reg==5);@(negedge clock_i);health_fault_i=1;
  repeat(3) tick();@(negedge clock_i);health_fault_i=0;read_response(0,32'h101);
  send_command(3);wait(rsp_valid_o);health_fault_i=1;read_response(3,0);health_fault_i=0;
  start_job(0,1);terminal(1,0); // Primary must fail, never fall back.
  // Fault wins the ownership edge and survives service-close clearing.
  received=0;wanted=4;check_result=1;
  for(integer j=0;j<8;j=j+1) expected[j]=TEST ? fixture[j] : drbg[0][255-j*32 -:32];
  start_job(0,0);wait(ownership_ready_o);@(negedge clock_i);health_fault_i=1;ownership_valid_i=1;
  tick();if(ownership_ready_o || ownership_committed_o) $fatal(1,"fault ownership precedence");
  @(negedge clock_i);health_fault_i=0;ownership_valid_i=0;receiver_scrub_done_i=0;
  wait(dut.keygen.state_reg==7);repeat(5) tick();if(status_valid_o) $fatal(1,"receiver scrub ignored");
  receiver_scrub_done_i=1;terminal(2,0);check_result=0;aes(0);
  // Abort after whole-result ownership must preserve the ownership record.
  received=0;wanted=4;check_result=1;start_job(0,0);wait(received==4);accept_key();
  @(negedge clock_i);abort_i=1;tick();@(negedge clock_i);abort_i=0;
  wait(recovery_valid_o);if(!recovery_owned_o || recovery_id_o!=request_id_i) $fatal(1,"ownership recovery");
  @(negedge clock_i);recovery_ready_i=1;tick();@(negedge clock_i);recovery_ready_i=0;check_result=0;
  aes(0);
  // GetRandom-only abort retains recovery even though the frontend resets.
  send_command(8);wait(rsp_valid_o);@(negedge clock_i);abort_i=1;tick();@(negedge clock_i);abort_i=0;
  wait(recovery_valid_o);if(recovery_keygen_o) $fatal(1,"GetRandom recovery attribution");
  @(negedge clock_i);recovery_ready_i=1;tick();@(negedge clock_i);recovery_ready_i=0;
  repeat(10) tick();send_command(1);read_response(1,0);
  $display("PASS tb_rng_system fresh=%0d softcore=%0d AES128/256, GetRandom sizes, isolation, primary rejection, stalls, fault ownership, cleanup, reset recovery",!TEST,SOFT);$finish;
`endif
`endif
 end
 initial begin
`ifdef RSA_TEST
  #(64'd90000000000);
`else
  #10000000;
`endif
  $fatal(1,"timeout state=%0d service=%0d core=%0d",dut.keygen.state_reg,dut.service.state_reg,dut.keygen.core.state_reg);
 end
endmodule
