`timescale 1ns/1ps
module tb_keygen_rsa_services;
reg clock_i=0;always #10 clock_i=~clock_i;
reg reset_n_i=0,cmd_valid_i=0,rsp_ready_i=0;
wire cmd_ready_o,rsp_valid_o;wire[7:0]rsp_status_o;
reg[7:0]cmd_op_i=0;reg[31:0]cmd_arg0_i=0,cmd_arg1_i=0,cmd_arg2_i=0,cmd_arg3_i=0;
reg generation_valid_i=0,generation_failed_i=0;reg[31:0]generation_data_i=0;wire generation_ready_o;
wire mem_write_en_o,mem_read_en_o;wire[11:0]mem_address_o;wire[31:0]mem_write_data_o;
reg mem_ready_i=1,mem_read_valid_i=0;reg[31:0]mem_read_data_i=0;
wire pair_start_valid_o;reg pair_start_ready_i=1;wire[1023:0]pair_p_o,pair_q_o;
reg pair_result_valid_i=0;wire pair_result_ready_o;reg[2047:0]pair_n_i=0;reg[3:0]pair_status_i=0;
reg[31:0]memory[0:4095];
localparam[1023:0]P=1024'hf71ccdb1c7544608b1eea2307f4dd112e1ea90ffa89a11a67aa87aced1a654a64b04a412eb1e4ed1cb0fc7b7e2271e94917e2f93f6f9058138975ee5515196e2a6717fdff1e2a6c8fa5e8daa16ee856f4d278b7a55744bab2b1fdeaf4d4ae93540527c08717acb9839a1cffee7dd6163cc2181697fed4e6ffbdf34c1f735bf3b;
localparam[1023:0]COMPOSITE=1024'hb504f333f9de6484597d89b3754abe9f1d6f60ba893ba84ced17ac85833399154afc83043ab8a2c3a8b1fe6fdc83db390f74a85e439c7b4a780487363dfa2768d2202e8742af1f4e53059c6011bc337bcab1bc911688458a460abc722f7c4e33c6d5a8a38bb7e9dccb2a634331f3c84df52f120f836e582eeaa4a0899040ca4d;
reg[1023:0]m;integer a,j,tests=0;
localparam[1023:0]P_MANY_TWOS=1024'he67e32dc59b08879cea8f8efd6af2b127f5ee41c57a1bf564ab13a17c37f82cdab5938fab4b8581f7e7ce6bbbe9fc13743fb96b92ad76dc5b952b1798238e78a372409326feea71798251d438bcb0fb638bf51d72bf4c99857104a786efb0167ea79fa9b63c05e506c31d1762ff2fd3f859d70305f7b2a1d35a481cdaf8c7e01;
keygen_rsa_services dut(.*);
always @(posedge clock_i) begin
 mem_read_valid_i<=mem_read_en_o&&mem_ready_i;
 if(mem_read_en_o&&mem_ready_i)mem_read_data_i<=memory[mem_address_o];
 if(mem_write_en_o&&mem_ready_i)memory[mem_address_o]<=mem_write_data_o;
end
task tick;@(posedge clock_i);#1;endtask
task put(input integer address,input[1023:0]v);
 for(integer k=0;k<32;k++)memory[address+k]=v[k*32+:32];
endtask
task command(input[7:0]op,input[31:0]a0,a1,a2,a3);
 wait(cmd_ready_o);@(negedge clock_i);cmd_op_i=op;cmd_arg0_i=a0;cmd_arg1_i=a1;cmd_arg2_i=a2;cmd_arg3_i=a3;cmd_valid_i=1;
 tick();@(negedge clock_i);cmd_valid_i=0;
endtask
task response(input[7:0]s);
 wait(rsp_valid_o);#1;if(rsp_status_o!==s)$fatal(1,"service op%h status%h expected%h",cmd_op_i,rsp_status_o,s);
 repeat(3)begin tick();if(!rsp_valid_o||rsp_status_o!==s)$fatal(1,"response not held");end
 @(negedge clock_i);rsp_ready_i=1;tick();@(negedge clock_i);rsp_ready_i=0;tests++;
endtask
initial begin
 for(j=0;j<4096;j++)memory[j]=0;
 tick();@(negedge clock_i);reset_n_i=1;
 // Malformed descriptors must return a held error without touching scratch.
 memory[0]=32'hdeadcafe;
 command(8'h30,4065,32,0,0);response(1);
 command(8'h30,0,31,0,0);response(1);
 command(8'h30,0,32,2,0);response(1);
 command(8'h30,0,32,0,1);response(1);
 command(8'h31,1,32,64,0);response(1);
 command(8'h31,0,32,64,2);response(1);
 command(8'h32,95,0,0,0);response(1);
 command(8'h32,96,0,0,1);response(1);
 command(8'h33,2,0,0,0);response(1);
 command(8'h33,0,1,0,0);response(1);
 command(8'h34,0,0,1,0);response(1);
 command(8'hff,0,0,0,0);response(1);
 if(memory[0]!==32'hdeadcafe)$fatal(1,"invalid descriptor mutated scratch");
 command(8'h30,0,32,1,0);
 for(j=0;j<32;j++)begin
  @(negedge clock_i);generation_valid_i=1;generation_data_i=32'h10203040+j;
  if(j==3)begin mem_ready_i=0;repeat(3)begin tick();if(generation_ready_o)$fatal(1,"source consumed on memory stall");end @(negedge clock_i);mem_ready_i=1;end
  tick();@(negedge clock_i);generation_valid_i=0;repeat(j%3)tick();
 end
 response(0);
 for(j=0;j<32;j++)if(memory[31-j]!==((32'h10203040+j)|((j==31)?1:0)))$fatal(1,"draw ordering");
 put(0,0);command(8'h31,0,32,64,0);response(8'h10);
 put(0,COMPOSITE);command(8'h31,0,32,64,0);response(8'h12);
 put(0,P);command(8'h31,0,32,64,0);response(0);
 m=P-1;a=0;while(!m[0])begin m=m>>1;a++;end
 for(j=0;j<32;j++)begin
  if(memory[32+j]!==((P-1)>>(j*32)&32'hffffffff))$fatal(1,"minusone");
  if(memory[64+j]!==m[j*32+:32])$fatal(1,"oddpart");
 end
 if(dut.twos_reg!==a||memory[288]!==1||memory[320]!==2)$fatal(1,"prime preparation");
 put(96,1);command(8'h32,96,0,0,0);response(8'h10);
 put(96,P-1);command(8'h32,96,0,0,0);response(8'h10);
 put(96,2);command(8'h32,96,0,0,0);response(0);
 put(128,1);command(8'h33,1,0,0,0);response(0);
 put(128,P-1);command(8'h33,1,0,0,0);response(0);
 put(128,0);command(8'h33,1,0,0,0);response((a<=1)?8'h11:8'h10);
 put(160,P);put(0,P);command(8'h31,0,32,64,1);response(8'h11);
 command(8'h30,0,32,0,0);@(negedge clock_i);generation_failed_i=1;response(2);generation_failed_i=0;
 // Pair interface only: arithmetic is independently tested in its own suite.
 put(160,P);put(192,P-2);command(8'h34,0,0,0,0);
 wait(pair_start_valid_o);#1;if(pair_p_o!==P||pair_q_o!==(P-2))$fatal(1,"pair operands");
 tick();@(negedge clock_i);pair_status_i=2;pair_result_valid_i=1;
 tick();@(negedge clock_i);pair_result_valid_i=0;response(8'h10);
 // Seed-5 q has nine factors of two in W-1: exactly eight squares allowed.
 put(0,P_MANY_TWOS);command(8'h31,0,32,64,0);response(0);
 if(dut.twos_reg!==9)$fatal(1,"factor count for repeated squares");
 put(96,P_MANY_TWOS-2);command(8'h32,96,0,0,0);response(0);
 put(128,2);command(8'h33,1,0,0,0);response(8'h10);
 for(j=0;j<7;j++)begin command(8'h33,0,0,0,0);response(8'h10);end
 command(8'h33,0,0,0,0);response(8'h11);
 put(128,2);command(8'h33,1,0,0,0);response(8'h10);
 for(j=0;j<7;j++)begin command(8'h33,0,0,0,0);response(8'h10);end
 put(128,P_MANY_TWOS-1);command(8'h33,0,0,0,0);response(0);
 put(128,1);command(8'h33,0,0,0,0);response(8'h11);
 // Exact separation is rejected; two greater is legal for odd candidates.
 put(160,P_MANY_TWOS-(1024'd1<<924));command(8'h31,0,32,64,1);response(8'h11);
 put(160,P_MANY_TWOS-(1024'd1<<924)-2);command(8'h31,0,32,64,1);response(0);
 // Failure coincident with the last word must suppress that memory write.
 memory[0]=32'hfacecafe;command(8'h30,0,32,0,0);
 for(j=0;j<31;j++)begin
  @(negedge clock_i);generation_valid_i=1;generation_data_i=j;tick();
 end
 @(negedge clock_i);generation_failed_i=1;generation_data_i=32'hbadbad;#1;
 if(generation_ready_o)$fatal(1,"failure did not suppress final handshake");
 tick();@(negedge clock_i);generation_valid_i=0;response(2);generation_failed_i=0;
 if(memory[0]!==32'hfacecafe)$fatal(1,"failed last word written");
 // Reset wipes cached candidate, witness, factor and predicate state.
 @(negedge clock_i);reset_n_i=0;#1;
 if(dut.candidate_reg!==0||dut.minus_one_reg!==0||dut.odd_part_reg!==0||dut.value_reg!==0||dut.peer_reg!==0)$fatal(1,"secret reset");
 $display("PASS RSA_SERVICES checks=%0d draw/filter/factor/witness/predicate/separation/reset",tests);$finish;
end
initial begin #10000000;$fatal(1,"services timeout");end
endmodule
