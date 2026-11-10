
`timescale 1ns/1ps
module tb_demo_aes_lifecycle;
reg clock_i=0; always #5 clock_i=~clock_i;
reg reset_n_i=0,start_i=0,operational_i=1,response_consumed_i=0;
reg [15:0] command_tag_i=16'h8002;
reg [31:0] command_size_i;
wire [11:0] command_addr_o, response_length_o;
reg [7:0] command_byte_i;
wire response_valid_o; wire [31:0] response_code_o;
reg [11:0] response_addr_i=0; wire [7:0] response_byte_o;
wire busy_o,scrub_done_o,recovery_required_o,key_request_o,key_reply_ready_o;
reg key_request_ready_i=1,key_reply_valid_i=0;
wire [31:0] key_handle_o;
reg [255:0] resolved_key_i=256'h603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4;
reg [31:0] key_reply_code_i=0;
reg [7:0] packet[0:1200], expected[0:9215];
integer lengths[0:8]; integer cycles,n,case_no,j,starts=0;
reg deny=0, passed=0;
execution_engine_aes_packet #(.ENABLE_DEMO_LIFECYCLE(1)) dut(.*);
always @(posedge clock_i) command_byte_i<=packet[command_addr_o];
always @(posedge clock_i) begin
 if(!reset_n_i) key_reply_valid_i<=0;
 else begin
  if(key_request_o && key_request_ready_i) begin
   key_reply_valid_i<=1; key_reply_code_i<=deny ? 32'h18b : 0;
  end
  if(key_reply_valid_i && key_reply_ready_o) key_reply_valid_i<=0;
  if(dut.aes_start) starts<=starts+1;
 end
end
task tick; begin @(posedge clock_i); #1; end endtask
task make_packet(input integer size,input integer dec,input integer index);
 begin
  for(integer k=0;k<1201;k=k+1) packet[k]=0;
  command_size_i=50+size; packet[13]=1; packet[17]=9;
  packet[18]='h40; packet[21]=9;
  {packet[27],packet[28]}=size;
  for(integer k=0;k<size;k=k+1) packet[29+k]=dec ? expected[index*1024+k] : k%256;
  packet[29+size]=dec; packet[31+size]='h43; packet[33+size]=16;
  for(integer k=0;k<16;k=k+1) packet[34+size+k]=k;
 end
endtask
task launch;
 begin
  cycles=0; while(busy_o) begin tick; cycles++; if(cycles>2000) $fatal(1,"idle scrub"); end
  @(negedge clock_i); start_i=1; tick; @(negedge clock_i); start_i=0;
 end
endtask
task response(input integer rc);
 begin
  cycles=0; while(!response_valid_o) begin tick; cycles++; if(cycles>200000) $fatal(1,"AES timeout state %d",dut.state); end
  if(response_code_o!==rc) $fatal(1,"AES RC %h",response_code_o);
  if(dut.aes.WORKER.aes_key_r!==0 || dut.job.aes_key_o!==0 || dut.aes.CONTROLLER.cfb_key_o!==0)
   $fatal(1,"key copy survived response");
  for(integer k=0;k<15;k=k+1)
   if(dut.aes.WORKER.AES_IMPLEMENT.UNIT_AES_CORE.keymem.key_mem[k]!==0) $fatal(1,"round key survived");
 end
endtask
task consume;
 begin
  repeat(5) tick; if(!busy_o) $fatal(1,"premature AES release");
  @(negedge clock_i); response_consumed_i=1; tick;
  @(negedge clock_i); response_consumed_i=0;
  cycles=0; while(busy_o) begin tick; cycles++; if(cycles>1100) $fatal(1,"AES cleanup"); end
  for(integer k=0;k<1024;k=k+1) if(dut.payload[k]!==0) $fatal(1,"payload survivor %d",k);
  if(dut.ram_read_data!==0) $fatal(1,"read latch survivor");
 end
endtask
initial begin
 $readmemh("aes_ciphertext.hex",expected);
 lengths[0]=0; lengths[1]=1; lengths[2]=15; lengths[3]=16; lengths[4]=17;
 lengths[5]=31; lengths[6]=32; lengths[7]=1023; lengths[8]=1024;
 repeat(4) tick; @(negedge clock_i); reset_n_i=1; repeat(1030) tick;
 for(case_no=0;case_no<9;case_no=case_no+1) begin
  n=lengths[case_no];
  for(integer dec=0;dec<2;dec=dec+1) begin
   make_packet(n,dec,case_no); launch; response(0);
   if(response_length_o!=39+n) $fatal(1,"length");
   for(j=0;j<n;j=j+1) begin
    response_addr_i=6+j; #1;
    if(response_byte_o!==(dec ? j%256 : expected[case_no*1024+j])) $fatal(1,"AES oracle case %d byte %d",case_no,j);
   end
   // Existing worker contract zero-fills partial final feedback; never continue it.
   for(j=0;j<16;j=j+1) begin
    response_addr_i=8+n+j; #1;
    if(n==0) begin if(response_byte_o!==j) $fatal(1,"empty IV"); end
    else if(n%16==0) begin
     if(response_byte_o!==expected[case_no*1024+n-16+j]) $fatal(1,"full IV");
    end else if(j<n%16) begin
     if(response_byte_o!==expected[case_no*1024+n-n%16+j]) $fatal(1,"partial IV");
    end else if(response_byte_o!==0) $fatal(1,"partial IV fill");
   end
   consume;
  end
 end
 deny=1; make_packet(16,0,3); launch; response('h18b);
 if(starts!=18 || response_length_o!=10) $fatal(1,"denied AES launched"); consume;
 deny=0; make_packet(16,0,3); launch;
 repeat(20) tick; @(negedge clock_i); reset_n_i=0; tick;
 if(response_valid_o || key_request_o) $fatal(1,"reset stale transaction");
 @(negedge clock_i); reset_n_i=1; repeat(1030) tick;
 for(j=0;j<1024;j=j+1) if(dut.payload[j]!==0) $fatal(1,"reset clear");
 passed=1; $display("DEMO_AES_LIFECYCLE_PASS 18 independent AES/IV cases, denial, key-schedule/scratch scrub, reset"); $finish;
end
initial begin #10000000; $fatal(1,"watchdog"); end
endmodule
