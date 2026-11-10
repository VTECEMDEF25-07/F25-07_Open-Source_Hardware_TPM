`timescale 1ns/1ps
// Actual unchanged math command/memory interface; no arithmetic-result stub.
module tb_private_lease;
reg clk=0;always #10 clk=~clk;reg rst=0;
reg ov=0,cv=0,cr=0,mw=0,mr=0,cmdv=0,rspr=0;
reg [11:0] addr=0;reg [31:0] data=0,a0=0,a1=0,a2=0,a3=0;reg[7:0]op=0;
wire oready,active,cready,crv,mready,mvalid,cmdr,rspv,corestatus,reqready;
wire[31:0]md;wire[7:0]rspcode;integer cases=0,ticks=0;
keygen_core #(.PRIVATE_RSA_ENABLE(1)) dut(
 .clock_i(clk),.reset_n_i(rst),.peers_ready_i(1'b1),.request_valid_i(1'b0),.request_ready_o(reqready),
 .request_profile_i(2'd3),.request_id_i(32'd0),.generation_valid_i(1'b0),.generation_ready_o(),
 .generation_data_i(32'd0),.generation_failed_i(1'b0),.result_valid_o(),.result_ready_i(1'b0),
 .result_data_o(),.result_component_o(),.result_index_o(),.result_component_last_o(),.result_last_o(),.result_id_o(),
 .ownership_valid_i(1'b0),.ownership_ready_o(),.ownership_accept_i(1'b0),.result_discard_o(),
 .status_valid_o(corestatus),.status_ready_i(1'b0),.status_code_o(),.status_id_o(),
 .private_open_valid_i(ov),.private_open_ready_o(oready),.private_active_o(active),
 .private_cmd_valid_i(cmdv),.private_cmd_ready_o(cmdr),.private_cmd_op_i(op),
 .private_cmd_arg0_i(a0),.private_cmd_arg1_i(a1),.private_cmd_arg2_i(a2),.private_cmd_arg3_i(a3),
 .private_rsp_valid_o(rspv),.private_rsp_ready_i(rspr),.private_rsp_status_o(rspcode),
 .private_mem_write_en_i(mw),.private_mem_read_en_i(mr),.private_mem_address_i(addr),.private_mem_write_data_i(data),
 .private_mem_ready_o(mready),.private_mem_read_valid_o(mvalid),.private_mem_read_data_o(md),
 .private_close_valid_i(cv),.private_close_ready_o(cready),.private_close_rsp_valid_o(crv),.private_close_rsp_ready_i(cr));
task reset_all;
 begin
  @(negedge clk);rst=0;ov=0;cv=0;cr=0;mw=0;mr=0;cmdv=0;rspr=0;
  #1;if(active||mready||mvalid||cmdr||rspv||oready||crv)$fatal(1,"lease reset visibility");
  repeat(4)@(negedge clk);rst=1;wait(oready);@(negedge clk);cases=cases+1;
 end
endtask
task acquire;
 begin ov=1;@(posedge clk);@(negedge clk);ov=0;
  if(!active||reqready||oready)$fatal(1,"lease admission exclusion");cases=cases+1;end
endtask
task write_word(input[11:0]ad,input[31:0]v);
 begin @(negedge clk);wait(mready);addr=ad;data=v;mw=1;@(posedge clk);@(negedge clk);mw=0;data=0;end
endtask
task read_word(input[11:0]ad,input[31:0]expected);
 begin @(negedge clk);wait(mready);addr=ad;mr=1;@(posedge clk);#1;
  if(!mvalid||md!==expected)$fatal(1,"private read address%0d got%h expected%h",ad,md,expected);
  @(negedge clk);mr=0;@(posedge clk);#1;if(mvalid||md!==0)$fatal(1,"private read latch visibility");
  cases=cases+1;end
endtask
task close_lease;
 begin @(negedge clk);wait(cready);cv=1;@(posedge clk);@(negedge clk);cv=0;ticks=0;
  while(!crv)begin @(negedge clk);ticks=ticks+1;
   if(corestatus||mready||cmdr||rspv||oready||reqready||!active)$fatal(1,"close not exclusive");
   if(ticks>9000)$fatal(1,"lease close timeout");end
  if(ticks<4098)$fatal(1,"lease close did not wait full scratch sweep");
  repeat(7)begin @(negedge clk);if(!crv||!active||corestatus)$fatal(1,"lease close reply not held");end
  cr=1;@(posedge clk);@(negedge clk);cr=0;wait(oready);
  if(active||corestatus||md!==0)$fatal(1,"lease close state/latch");cases=cases+1;
 end
endtask
initial begin
 reset_all;acquire;write_word(1088,32'hdeadbeef);write_word(1089,32'h12345678);
 read_word(1088,32'hdeadbeef);read_word(1089,32'h12345678);
 // Actual64-limb ZERO verifies full-length command acceptance.
 @(negedge clk);op=8'h02;a0=1216;a1=0;a2=0;a3=64;cmdv=1;wait(cmdr);
 @(posedge clk);@(negedge clk);cmdv=0;wait(rspv);
 if(rspcode!==0||mready)$fatal(1,"64limb command/status isolation");
 repeat(5)begin @(negedge clk);if(!rspv||rspcode!==0||cready)$fatal(1,"math status not held");end
 rspr=1;@(posedge clk);@(negedge clk);rspr=0;cases=cases+1;
 close_lease;acquire;read_word(1088,0);read_word(1089,0);read_word(1216,0);read_word(1279,0);
 write_word(1088,32'habcdef01);reset_all;acquire;read_word(1088,0);
 close_lease;
 // Reset while native read pulse pending and while close reply held.
 acquire;@(negedge clk);mr=1;addr=1024;@(posedge clk);reset_all;
 acquire;@(negedge clk);cv=1;wait(cready);@(posedge clk);@(negedge clk);cv=0;wait(crv);reset_all;
 $display("PASS PRIVATE_LEASE cases=%0d full_scrub_cycles=%0d",cases,ticks);$finish;
end
initial begin #10000000;$fatal(1,"private lease deadline");end
endmodule
