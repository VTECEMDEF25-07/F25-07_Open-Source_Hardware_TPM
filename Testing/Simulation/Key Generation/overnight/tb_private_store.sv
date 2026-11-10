`timescale 1ns/1ps
// Synthetic public fixture words exercise protected storage, not RSA arithmetic.
module tb_private_store;
reg clk=0;always #10 clk=~clk;reg rst=0;
reg reserve=0,abort=0,rv=0,decision=0,commit_ready=0,release_v=0,release_rr=0;
reg[2:0]comp=0;reg[6:0]index=0;reg[31:0]data=0,rid=32'd7,h=0;
reg last=0,cl=0;
wire reserve_ready,receiver_ready,error,scrub,result_ready,decision_ready,ov,oa,commit,release_ready,release_reply;
wire[3:0]error_code;wire[31:0]ch,release_code;
reg pubv=0,pubrr=0,privv=0,privrr=0,rsa_allow=0,rsa_active=0;
reg[31:0]pubh=0,privh=0;reg pubcomponent=0,privcomponent=0;reg[5:0]pubidx=0,prividx=0;
wire pubready,pubreply,privready,privreply;wire[31:0]pubdata,pubcode,privdata,privcode;
integer checks=0,cases=0,i;
demo_volatile_store #(.PRIVATE_RSA_ENABLE(1)) dut(
 .clock_i(clk),.reset_n_i(rst),.reserve_valid_i(reserve),.reserve_ready_o(reserve_ready),
 .reserve_profile_i(2'd2),.reserve_id_i(32'd7),.reserve_mode_i(2'd0),.reserve_demo_use_i(1'b1),
 .receiver_ready_o(receiver_ready),.receiver_error_o(error),.receiver_error_code_o(error_code),.receiver_scrub_done_o(scrub),.abort_i(abort),
 .result_valid_i(rv),.result_ready_o(result_ready),.result_data_i(data),.result_component_i(comp),.result_index_i(index),
 .result_component_last_i(cl),.result_last_i(last),.result_id_i(rid),.result_discard_i(1'b0),
 .decision_valid_i(decision),.decision_ready_o(decision_ready),.decision_accept_i(1'b1),
 .ownership_valid_o(ov),.ownership_ready_i(1'b1),.ownership_accept_o(oa),
 .commit_valid_o(commit),.commit_ready_i(commit_ready),.commit_handle_o(ch),.commit_id_o(),.commit_mode_o(),
 .release_valid_i(release_v),.release_ready_o(release_ready),.release_handle_i(h),
 .release_rsp_valid_o(release_reply),.release_rsp_ready_i(release_rr),.release_rsp_code_o(release_code),
 .key_request_i(1'b0),.key_request_ready_o(),.key_handle_i(32'd0),.key_reply_valid_o(),.key_reply_ready_i(1'b0),
 .resolved_key_o(),.key_reply_code_o(),.use_allowed_i(1'b0),.client_active_i(1'b0),
 .rsa_use_allowed_i(rsa_allow),.rsa_client_active_i(rsa_active),
 .public_request_i(pubv),.public_request_ready_o(pubready),.public_handle_i(pubh),.public_component_i(pubcomponent),.public_index_i(pubidx),
 .public_reply_valid_o(pubreply),.public_reply_ready_i(pubrr),.public_data_o(pubdata),.public_reply_code_o(pubcode),
 .private_request_i(privv),.private_request_ready_o(privready),.private_handle_i(privh),.private_component_i(privcomponent),.private_index_i(prividx),
 .private_reply_valid_o(privreply),.private_reply_ready_i(privrr),.private_data_o(privdata),.private_reply_code_o(privcode));
function[31:0]fixture(input integer n);
 begin fixture=n==64 ? 32'h00010001 : n<64 ? 32'ha0000000+n : 32'hd0000000+n-65;end
endfunction
task reset_all;
 begin @(negedge clk);rst=0;reserve=0;abort=0;rv=0;decision=0;commit_ready=0;release_v=0;release_rr=0;
  pubv=0;pubrr=0;privv=0;privrr=0;rsa_active=0;rsa_allow=0;
  #1;if(pubreply||privreply||pubdata!==0||privdata!==0)$fatal(1,"reset secret visibility");
  repeat(4)@(negedge clk);rst=1;wait(reserve_ready);cases=cases+1;end
endtask
task stage(input bit legacy_bad);
 begin @(negedge clk);reserve=1;@(posedge clk);@(negedge clk);reserve=0;
  for(i=0;i<129;i=i+1)begin
   wait(result_ready);rv=1;data=fixture(i);comp=i<64?2:i==64?3:(legacy_bad?4:6);
   index=i<64?i:i==64?0:i-65;cl=(i==63||i==64||i==128);last=i==128;
   @(posedge clk);@(negedge clk);rv=0;
   if(legacy_bad && i==65)break;
  end
  cases=cases+1;
 end
endtask
task commit_stage;
 begin decision=1;wait(decision_ready);@(posedge clk);@(negedge clk);decision=0;wait(commit);h=ch;
  repeat(5)begin @(negedge clk);if(pubready||privready||release_ready||!commit)$fatal(1,"commit record ownership ordering");end
  commit_ready=1;@(posedge clk);@(negedge clk);commit_ready=0;cases=cases+1;
 end
endtask
task pubread(input bit c,input[5:0]idx,input[31:0]code,input[31:0]expected);
 begin @(negedge clk);pubh=h;pubcomponent=c;pubidx=idx;pubv=1;wait(pubready);
  @(posedge clk);@(negedge clk);pubv=0;wait(pubreply);
  if(pubcode!==code||pubdata!==expected)$fatal(1,"public type/index/permission response");
  repeat(3)begin @(negedge clk);if(!pubreply||pubdata!==expected||pubcode!==code)$fatal(1,"public stalled reply");end
  pubrr=1;@(posedge clk);@(negedge clk);pubrr=0;if(pubdata!==0)$fatal(1,"public latch not clear");checks=checks+1;
 end
endtask
task privread(input bit c,input[5:0]idx,input[31:0]code,input[31:0]expected);
 begin @(negedge clk);privh=h;privcomponent=c;prividx=idx;privv=1;wait(privready);
  @(posedge clk);@(negedge clk);privv=0;wait(privreply);
  if(privcode!==code||privdata!==expected)$fatal(1,"private type/index/permission response idx%0d",idx);
  repeat(3)begin @(negedge clk);if(!privreply||privdata!==expected||privcode!==code)$fatal(1,"private stalled reply");end
  if(release_ready)$fatal(1,"release during private reply/lease");
  privrr=1;@(posedge clk);@(negedge clk);privrr=0;if(privdata!==0)$fatal(1,"private latch not clear");checks=checks+1;
 end
endtask
initial begin
 reset_all;stage(0);if(pubready||privready)$fatal(1,"unowned key visible");commit_stage;
 pubread(0,0,32'h12f,0);rsa_allow=1;
 for(integer j=0;j<64;j=j+1)pubread(0,j,0,fixture(j));
 pubread(1,0,0,65537);pubread(1,1,32'h095,0);
 privread(1,0,32'h12f,0);rsa_active=1;
 for(integer j=0;j<64;j=j+1)begin privread(0,j,0,fixture(j));privread(1,j,0,fixture(65+j));end
 // Store-owned private context survives source/engine operation resets (not connected here).
 if(release_ready||pubready)$fatal(1,"RSA lease exclusion");rsa_active=0;
 @(negedge clk);release_v=1;wait(release_ready);@(posedge clk);@(negedge clk);release_v=0;
 wait(release_reply);if(!scrub||release_code!==0)$fatal(1,"release before physical zero");
 release_rr=1;@(posedge clk);@(negedge clk);release_rr=0;wait(reserve_ready);
 pubread(0,0,32'h18b,0);rsa_active=1;privread(1,0,32'h18b,0);rsa_active=0;
 stage(1);wait(error);if(error_code!=7)$fatal(1,"private mode accepted p/q component");
 abort=1;wait(scrub);@(negedge clk);abort=0;wait(reserve_ready);cases=cases+1;
 stage(0);@(negedge clk);decision=1;abort=1;#1;if(ov||decision_ready)$fatal(1,"ownership abort priority");
 @(posedge clk);@(negedge clk);decision=0;wait(scrub);abort=0;wait(reserve_ready);
 for(integer j=0;j<129;j=j+1)if(dut.words[j]!==0)$fatal(1,"RSA context not zeroed");
 reset_all;$display("PASS PRIVATE_STORE cases=%0d checked_words=%0d",cases,checks);$finish;
end
initial begin #10000000;$fatal(1,"private store deadline");end
endmodule
