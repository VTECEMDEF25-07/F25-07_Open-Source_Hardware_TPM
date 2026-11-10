`timescale 1ns/1ps
module tb_demo_generation;
parameter MODE=1;
reg clk=0;always #10 clk=~clk;
reg rst=0,ov=0,orr=0,wr=0,cv=0,crr=0,failed=0;
reg [1:0] profile=1,mode=MODE;
reg [31:0] id=42,close_id=42;
wire ordy,orv,wv,cf,crdy,crv,ready,scrub;
wire [3:0] oe,ce,fc;wire [31:0] wd;
reg [255:0] expected[0:3],entropy_fixture[0:6];
`include "demo_vectors.vh"
demo_generation_service #(.DEMO_PROVIDER_MODE(MODE),.RESEED_INTERVAL(48'd2)) dut(
 .clock_i(clk),.reset_n_i(rst),.open_valid_i(ov),.open_ready_o(ordy),
 .open_profile_i(profile),.open_id_i(id),.open_mode_i(mode),
 .open_rsp_valid_o(orv),.open_rsp_ready_i(orr),.open_rsp_error_o(oe),
 .word_valid_o(wv),.word_ready_i(wr),.word_data_o(wd),.context_fault_o(cf),.context_fault_code_o(fc),
 .close_valid_i(cv),.close_ready_o(crdy),.close_id_i(close_id),.close_failed_i(failed),
 .close_rsp_valid_o(crv),.close_rsp_ready_i(crr),.close_rsp_error_o(ce),.service_ready_o(ready),.scrub_done_o(scrub));
integer entropy_index=0,hash_stalls=0;
reg [255:0] entropy_drive;reg entropy_valid_drive=0;
generate if(MODE==0) begin : g_feed
 initial begin
  force dut.g_fresh.entropy=entropy_drive;
  force dut.g_fresh.entropy_valid=entropy_valid_drive;
 end
 always @(negedge clk) begin
  entropy_valid_drive=0;
  if(!dut.provider_running) entropy_index=0;
  else if(dut.g_fresh.entropy_needed) begin
   if(entropy_index>6)$fatal(1,"unexpected entropy budget");
   entropy_drive=entropy_fixture[entropy_index];entropy_valid_drive=1;entropy_index=entropy_index+1;
  end
 end
 always @(posedge clk) if(dut.g_fresh.hash_valid && !dut.g_fresh.hash_ready)hash_stalls=hash_stalls+1;
end endgenerate
task reset_all;
 begin
  @(negedge clk);rst=0;ov=0;orr=0;wr=0;cv=0;crr=0;
  #1;if(wv||orv||crv||ready)$fatal(1,"reset did not suppress transfers");
  repeat(4)@(negedge clk);rst=1;wait(ready);@(negedge clk);
 end
endtask
task open_context(input [3:0] error);
 begin
  wait(ordy);@(negedge clk);ov=1;@(posedge clk);@(negedge clk);ov=0;
  wait(orv);@(negedge clk);
  if(oe!==error)$fatal(1,"open error got %0d expected %0d",oe,error);
  repeat(4)begin @(negedge clk);if(!orv||oe!==error)$fatal(1,"open response not held");end
  orr=1;@(posedge clk);@(negedge clk);orr=0;
 end
endtask
task check_scrub;
 integer i;
 begin
  if(!scrub || wd!==0)$fatal(1,"scrub/read latch not clear");
  if(MODE==1)begin
   // Compiled only test-mode hierarchy is checked below in a generate block.
  end
 end
endtask
task close_context(input [3:0] error);
 begin
  @(negedge clk);cv=1;wait(crdy);@(posedge clk);@(negedge clk);cv=0;
  wait(crv);@(negedge clk);if(ce!==error)$fatal(1,"close error");check_scrub;
  repeat(5)begin @(negedge clk);if(!crv||!scrub)$fatal(1,"close response/scrub not held");end
  crr=1;@(posedge clk);@(negedge clk);crr=0;wait(ready);
 end
endtask
generate if(MODE==1)begin
 always @(negedge clk)if(scrub)begin
  if(dut.g_test.u_source.seed_reg!==0 || dut.g_test.u_source.digest_reg!==0 ||
     dut.g_test.u_source.a_reg!==0)$fatal(1,"test secret state retained");
  for(integer j=0;j<16;j=j+1)if(dut.g_test.u_source.schedule_reg[j]!==0)$fatal(1,"test schedule retained");
 end
end else begin
 always @(negedge clk)if(scrub)begin
  if(dut.g_fresh.block_reg!==0 || dut.g_fresh.u_drbg.V!==0 || dut.g_fresh.u_drbg.C!==0 ||
     dut.g_fresh.u_drbg.ent_buf!==0 || dut.g_fresh.u_entropy.sipo_shift_register!==0 ||
     dut.g_fresh.u_sha.u_engine.u_sha_256.hash_out_reg_o!==0 ||
     dut.g_fresh.u_sha.u_engine.u_arbiter.digest_out_reg_o!==0 ||
     dut.g_fresh.u_sha.u_engine.u_sha_256.active_block_reg!==0)$fatal(1,"fresh SHA/DRBG secrets retained");
  for(integer j=0;j<64;j=j+1)
   if(dut.g_fresh.u_sha.u_engine.u_sha_256.u_message_schedule.W[j]!==0)$fatal(1,"SHA schedule retained");
 end
end endgenerate
integer k,s;reg [31:0] held;
initial begin
 reset_all;
 mode=MODE^1;open_context(1);if(!scrub)$fatal(1,"failed open not scrubbed");mode=MODE;
 profile=3;open_context(1);profile=1;
 open_context(0);
 for(k=0;k<32;k=k+1)begin
  wait(wv);@(negedge clk);held=wd;
  if(wd!==expected[k/8][255-(k%8)*32 -:32])$fatal(1,"reference mismatch mode%0d word%0d got%h",MODE,k,wd);
  for(s=0;s<(k%5)+1;s=s+1)begin @(negedge clk);if(!wv||wd!==held)$fatal(1,"stalled word changed");end
  wr=1;@(posedge clk);@(negedge clk);wr=0;
 end
 close_context(0);
 if(MODE==0 && hash_stalls==0)$fatal(1,"real SHA never exercised byte backpressure");
 // Fault is visible while consumer stalls and persists until close.
 open_context(0);wait(wv);@(negedge clk);force dut.provider_failed=1;
 #1;if(!cf||wv)$fatal(1,"source fault hidden as stall");
 @(posedge clk);@(negedge clk);release dut.provider_failed;
 if(!cf)$fatal(1,"source fault not sticky");failed=1;close_context(0);failed=0;
 open_context(0);close_id=43;close_context(1);close_id=42;
 // Reset during a retained word, held open response, and held close response.
 open_context(0);wait(wv);reset_all;
 @(negedge clk);ov=1;@(posedge clk);@(negedge clk);ov=0;wait(orv);reset_all;
 open_context(0);@(negedge clk);cv=1;@(posedge clk);@(negedge clk);cv=0;wait(crv);reset_all;
 open_context(0);wait(wv);@(negedge clk);
 if(wd!==expected[0][255:224])$fatal(1,"reset/consecutive context stream changed");
 close_context(0);
 $display("DEMO_GENERATION_PASS mode=%0d words=32 real_sha_stall_cycles=%0d",MODE,hash_stalls);$finish;
end
initial begin #20000000;$fatal(1,"generation global timeout");end
endmodule
