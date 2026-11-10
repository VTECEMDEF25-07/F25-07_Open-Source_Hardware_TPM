`timescale 1ns/1ps
module tb_demo_operation;
parameter MODE=1;
reg clk=0;always #10 clk=~clk;
reg rst=0,jv=0,dr=0;reg [1:0] jp=1,jm=1;reg [31:0] jid=0;
wire jr,dv,busy,available,recovery,source_scrub,abort;
wire [31:0] did,handle;wire [1:0] dp,dm;wire [3:0] cs,se,te;wire committed;
wire resv,resr;wire [1:0] resp,resm;wire [31:0] resid;wire demo_use;
wire rr,re,rs;wire [3:0] rec;
wire rv,rready;wire [31:0] rd,rid;wire [2:0] component;wire [6:0] idx;wire cl,last,discard;
wire decision,decision_ready,accept,ownv,ownr,owna,commitv,commitr;
wire [31:0] ch,ci;wire [1:0] cm;
wire relv,relr,relrsp,relrspr;wire [31:0] relh,relcode;
reg flushv=0,flushrr=0;reg [31:0] flushh=0;
reg keyreq=0,keyrr=0,use_allowed=0;reg [31:0] keyhandle=0;
wire keyready,keyvalid;wire [255:0] key;wire [31:0] keycode;
reg result_allow=1,ownership_allow=1;
wire store_rready,store_decision_ready;
assign rready=store_rready && result_allow;
assign decision_ready=store_decision_ready && ownership_allow;
demo_keygen_operation #(.DEMO_PROVIDER_MODE(MODE),.DEADLINE_CYCLES(64'd20000)) op(
 .clock_i(clk),.reset_n_i(rst),.job_valid_i(jv),.job_ready_o(jr),.job_profile_i(jp),.job_mode_i(jm),.job_id_i(jid),
 .done_valid_o(dv),.done_ready_i(dr),.done_id_o(did),.done_profile_o(dp),.done_mode_o(dm),
 .done_core_status_o(cs),.done_setup_error_o(se),.done_teardown_error_o(te),
 .done_ownership_committed_o(committed),.done_handle_o(handle),
 .busy_o(busy),.available_o(available),.recovery_required_o(recovery),.scrub_done_o(source_scrub),.abort_o(abort),
 .reserve_valid_o(resv),.reserve_ready_i(resr),.reserve_profile_o(resp),.reserve_mode_o(resm),.reserve_id_o(resid),
 .reserve_demo_use_o(demo_use),.receiver_ready_i(rr),.receiver_error_i(re),.receiver_error_code_i(rec),.receiver_scrub_done_i(rs),
 .result_valid_o(rv),.result_ready_i(rready),.result_data_o(rd),.result_component_o(component),.result_index_o(idx),
 .result_component_last_o(cl),.result_last_o(last),.result_id_o(rid),.result_discard_o(discard),
 .decision_valid_o(decision),.decision_ready_i(decision_ready),.decision_accept_o(accept),
 .ownership_valid_i(ownv),.ownership_ready_o(ownr),.ownership_accept_i(owna),
 .commit_valid_i(commitv),.commit_ready_o(commitr),.commit_handle_i(ch),.commit_id_i(ci),.commit_mode_i(cm),
 .release_valid_o(relv),.release_ready_i(relr),.release_handle_o(relh),
 .release_rsp_valid_i(relrsp),.release_rsp_ready_o(relrspr),.release_rsp_code_i(relcode));
demo_volatile_store store(
 .clock_i(clk),.reset_n_i(rst),.reserve_valid_i(resv),.reserve_ready_o(resr),
 .reserve_profile_i(resp),.reserve_id_i(resid),.reserve_mode_i(resm),.reserve_demo_use_i(demo_use),
 .receiver_ready_o(rr),.receiver_error_o(re),.receiver_error_code_o(rec),.receiver_scrub_done_o(rs),.abort_i(abort),
 .result_valid_i(rv && result_allow),.result_ready_o(store_rready),.result_data_i(rd),.result_component_i(component),
 .result_index_i(idx),.result_component_last_i(cl),.result_last_i(last),.result_id_i(rid),.result_discard_i(discard),
 .decision_valid_i(decision && ownership_allow),.decision_ready_o(store_decision_ready),.decision_accept_i(accept),
 .ownership_valid_o(ownv),.ownership_ready_i(ownr),.ownership_accept_o(owna),
 .commit_valid_o(commitv),.commit_ready_i(commitr),.commit_handle_o(ch),.commit_id_o(ci),.commit_mode_o(cm),
 .release_valid_i(relv || flushv),.release_ready_o(relr),.release_handle_i(relv ? relh : flushh),
 .release_rsp_valid_o(relrsp),.release_rsp_ready_i(relrspr || flushrr),.release_rsp_code_o(relcode),
 .key_request_i(keyreq),.key_request_ready_o(keyready),.key_handle_i(keyhandle),
 .key_reply_valid_o(keyvalid),.key_reply_ready_i(keyrr),.resolved_key_o(key),.key_reply_code_o(keycode),
 .use_allowed_i(use_allowed),.client_active_i(1'b0));
reg [255:0] expected[0:3],entropy_fixture[0:6];
`include "demo_vectors.vh"
wire [255:0] EXPECTED=expected[0];
reg [255:0] entropy_drive;reg entropy_valid_drive=0;integer entropy_index=0;
generate if(MODE==0) begin
 initial begin
  force op.u_source.g_fresh.entropy=entropy_drive;
  force op.u_source.g_fresh.entropy_valid=entropy_valid_drive;
 end
 always @(negedge clk)begin
  entropy_valid_drive=0;
  if(!op.u_source.provider_running)entropy_index=0;
  else if(op.u_source.g_fresh.entropy_needed)begin
   entropy_drive=entropy_fixture[entropy_index];entropy_valid_drive=1;entropy_index=entropy_index+1;
  end
 end
end endgenerate
integer jobs=0,commits=0,done_count=0;
always @(posedge clk)begin
 if(rst && jv&&jr)jobs=jobs+1;
 if(rst && ownv&&ownr&&owna)commits=commits+1;
 if(rst && dv&&dr)done_count=done_count+1;
 if(!rst && (rv||ownr||jv&&jr))$fatal(1,"reset transfer");
 if(recovery && (rv||ownr||decision||jr))$fatal(1,"recovery admitted work");
end
task reset_all;
 begin
  @(negedge clk);rst=0;jv=0;dr=0;flushv=0;flushrr=0;keyreq=0;keyrr=0;use_allowed=0;
  result_allow=1;ownership_allow=1;
  repeat(4)@(negedge clk);rst=1;wait(jr&&resr);@(negedge clk);
 end
endtask
task start_job(input [1:0] p,input [1:0] m);
 begin
  wait(jr);@(negedge clk);jp=p;jm=m;jid=jid+1;jv=1;
  @(posedge clk);@(negedge clk);jv=0;
  // Prove capture, not live input use.
  jp=3;jm=3;
 end
endtask
task check_done(input [3:0] c,input [3:0] s,input bit owned);
 integer i;reg [31:0] saved;
 begin
  wait(dv);@(negedge clk);saved=handle;
  if(cs!==c||se!==s||te!==0||committed!==owned||did!==jid||dm!==MODE && s!=1)
   $fatal(1,"terminal mismatch id%0d cs%0d se%0d te%0d owned%0d",did,cs,se,te,committed);
  if(!source_scrub)$fatal(1,"done before source cleanup");
  for(i=0;i<8;i=i+1)if(op.u_core.aes.key_words_reg[i]!==0)$fatal(1,"AES secret retained at done");
  repeat(9)begin @(negedge clk);if(!dv||jr||handle!==saved)$fatal(1,"terminal not held");end
  dr=1;@(posedge clk);@(negedge clk);dr=0;wait(jr);
 end
endtask
task lookup(input [31:0] h,input [31:0] code,input bit allowed);
 begin
  @(negedge clk);keyhandle=h;use_allowed=allowed;keyreq=1;wait(keyready);
  @(posedge clk);@(negedge clk);keyreq=0;wait(keyvalid);@(negedge clk);
  if(keycode!==code || (code==0 && key!==EXPECTED) || (code!=0 && key!==0))$fatal(1,"lookup data/code mismatch");
  repeat(5)begin @(negedge clk);if(!keyvalid||keycode!==code)$fatal(1,"lookup not held");end
  keyrr=1;@(posedge clk);@(negedge clk);keyrr=0;
  if(key!==0)$fatal(1,"lookup read latch retained");
 end
endtask
task flush(input [31:0] h);
 begin
  @(negedge clk);flushh=h;flushv=1;wait(relr);@(posedge clk);@(negedge clk);flushv=0;
  wait(relrsp);@(negedge clk);if(relcode!==0||!rs)$fatal(1,"flush before scrub");
  flushrr=1;@(posedge clk);@(negedge clk);flushrr=0;wait(resr);
 end
endtask
task pulse_source_fault;
 begin
  force op.u_source.provider_failed=1;#1;
  if(!abort||rv||ownr)$fatal(1,"fault not same-edge qualified");
  @(posedge clk);@(negedge clk);release op.u_source.provider_failed;
 end
endtask
reg [31:0] h;integer prior,i;
initial begin
 reset_all;
 // AES128 exact words; AES256-only client denies lookup.
 start_job(0,MODE);wait(rv);@(negedge clk);result_allow=0;
 repeat(13)@(negedge clk);if(idx!==0||rd!==EXPECTED[255:224])$fatal(1,"result stall mismatch");result_allow=1;
 wait(dv);for(i=0;i<4;i=i+1)if(store.words[i]!==EXPECTED[255-i*32 -:32])$fatal(1,"AES128 independent words");
 h=handle;check_done(0,0,1);lookup(h,32'h12f,1);flush(h);
 // AES256 retains no source/core copies; occupied request must fail promptly.
 start_job(1,MODE);wait(dv);h=handle;check_done(0,0,1);lookup(h,32'h12f,0);lookup(h,0,1);
 start_job(1,MODE);check_done(0,2,0);lookup(h,0,1);flush(h);lookup(h,32'h18b,1);
 start_job(3,MODE);check_done(0,1,0);
 start_job(1,MODE^1);check_done(0,1,0);
 // Preparation failure has no admitted core job and scrubs the reservation.
 start_job(1,MODE);wait(op.u_source.state_reg==2);@(negedge clk);
 force op.u_source.provider_failed=1;
 wait(op.u_source.state_reg==5);@(negedge clk);release op.u_source.provider_failed;
 check_done(0,4,0);if(!rs)$fatal(1,"failed preparation left receiver staging");
 // Failure on the final source word wins before that transfer/ownership.
 start_job(1,MODE);wait(op.word_valid&&op.word_ready&&op.u_core.aes.word_index_reg==7);
 @(negedge clk);pulse_source_fault;check_done(2,4,0);
 // Source failure on final result prevents ownership and cleans staging.
 start_job(1,MODE);wait(rv&&last);@(negedge clk);prior=commits;pulse_source_fault;
 check_done(2,4,0);if(commits!=prior||!rs)$fatal(1,"fault committed partial key");
 // Failure coincident with offered whole-result ownership.
 ownership_allow=0;start_job(1,MODE);wait(ownr);@(negedge clk);prior=commits;
 force op.u_source.provider_failed=1;ownership_allow=1;#1;if(ownr||ownv)$fatal(1,"ownership fault priority");
 @(posedge clk);@(negedge clk);release op.u_source.provider_failed;
 check_done(2,4,0);if(commits!=prior)$fatal(1,"ownership fault commit");
 // Late failure preserves commit fact, explicitly releases object, reports failure.
 start_job(1,MODE);wait(ownv&&ownr);@(posedge clk);@(negedge clk);pulse_source_fault;
 wait(dv);h=handle;check_done(0,4,1);if(!rs)$fatal(1,"failed committed object not scrubbed");lookup(h,32'h18b,1);
 // Provider teardown failure after ownership releases the object, never success.
 start_job(1,MODE);wait(op.state_reg==8);force op.u_source.close_rsp_error_o=4'd1;
 wait(op.source_close_valid);@(posedge clk);@(negedge clk);release op.u_source.close_rsp_error_o;
 wait(dv);h=handle;if(cs!=0||se!=0||te!=1||!committed||!rs)$fatal(1,"failed teardown lost disposition");
 @(negedge clk);dr=1;@(posedge clk);@(negedge clk);dr=0;wait(jr);lookup(h,32'h18b,1);
 // RSA profile is admitted; source failure during draws is scrubbed, not a fake RSA success.
 start_job(2,MODE);wait(op.word_valid&&op.word_ready);@(negedge clk);pulse_source_fault;
 check_done(2,4,0);
 // Reset while source transferring, while ownership is stalled, and while done is held.
 start_job(1,MODE);wait(op.word_valid&&op.word_ready);reset_all;
 ownership_allow=0;start_job(1,MODE);wait(ownr);reset_all;
 start_job(1,MODE);wait(dv);reset_all;lookup(32'h80000001,32'h18b,1);
 // Watchdog is sticky recovery, never a terminal success or an ordinary source stall.
 result_allow=0;start_job(1,MODE);wait(recovery);@(negedge clk);
 if(dv||jr||!abort||te!=4)$fatal(1,"deadline recovery semantics");
 reset_all;start_job(1,MODE);wait(dv);h=handle;check_done(0,0,1);lookup(h,0,1);
 $display("DEMO_OPERATION_PASS mode=%0d accepted_jobs=%0d commits=%0d acknowledged_done=%0d",MODE,jobs,commits,done_count);$finish;
end
initial begin #30000000;$display("state%0d core%0d source%0d abort%b errors%h/%h/%h committed%b handle%h store%0d",
 op.state_reg,op.u_core.state_reg,op.u_source.state_reg,abort,cs,se,te,committed,handle,store.state);
 $fatal(1,"operation global timeout");end
endmodule
