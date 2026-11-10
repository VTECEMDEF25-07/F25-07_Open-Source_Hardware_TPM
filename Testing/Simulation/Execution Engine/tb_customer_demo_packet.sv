
`timescale 1ns/1ps
module tb_customer_demo_packet #(parameter EXPORT_ENABLED=1, parameter WATCHDOG_TEST=0,
 parameter BAD_TERMINAL_TEST=0);
reg  clock_i;
reg  reset_n_i;
reg  start_i;
reg  operational_i;
reg [15:0] command_tag_i;
reg [31:0] command_size_i;
wire [11:0] command_addr_o;
reg [7:0] command_byte_i;
wire  response_valid_o;
wire [31:0] response_code_o;
wire [11:0] response_length_o;
reg [11:0] response_addr_i;
wire [7:0] response_byte_o;
reg  response_consumed_i;
wire  busy_o;
wire  scrub_done_o;
wire  recovery_required_o;
reg [31:0] snapshot_status_word_i;
reg [31:0] snapshot_operation_id_i;
reg [31:0] snapshot_sequence_i;
wire  gen_job_valid_o;
reg  gen_job_ready_i;
wire [1:0] gen_job_profile_o;
wire [1:0] gen_job_mode_o;
wire [31:0] gen_job_id_o;
reg  gen_done_valid_i;
wire  gen_done_ready_o;
reg [31:0] gen_done_id_i;
reg [31:0] gen_done_handle_i;
reg [1:0] gen_done_profile_i;
reg [1:0] gen_done_mode_i;
reg [3:0] gen_done_core_status_i;
reg [3:0] gen_done_setup_error_i;
reg [3:0] gen_done_teardown_error_i;
reg  gen_done_ownership_committed_i;
reg [63:0] gen_done_cycles_i;
reg [3:0] gen_phase_i;
reg  gen_available_i;
reg  gen_busy_i;
reg  gen_recovery_required_i;
reg  gen_scrub_done_i;
wire  release_valid_o;
reg  release_ready_i;
wire [31:0] release_handle_o;
reg  release_rsp_valid_i;
wire  release_rsp_ready_o;
reg [31:0] release_rsp_code_i;
wire  key_request_o;
reg  key_request_ready_i;
wire [31:0] key_handle_o;
reg  key_reply_valid_i;
wire  key_reply_ready_o;
reg [255:0] resolved_key_i;
reg [31:0] key_reply_code_i;
wire  aes_use_allowed_o;
wire  rsa_use_allowed_o;
wire  aes_client_active_o;
wire  public_request_o;
reg  public_request_ready_i;
wire [31:0] public_handle_o;
wire  public_component_o;
wire [5:0] public_index_o;
reg  public_reply_valid_i;
wire  public_reply_ready_o;
reg [31:0] public_data_i;
reg [31:0] public_reply_code_i;
wire  aes_job_valid_o;
reg  aes_job_ready_i;
wire [255:0] aes_job_key_o;
wire [127:0] aes_job_iv_o;
wire [15:0] aes_job_bytes_o;
wire  aes_input_valid_o;
reg  aes_input_ready_i;
wire [7:0] aes_input_data_o;
reg  aes_output_valid_i;
wire  aes_output_ready_o;
reg [7:0] aes_output_data_i;
reg  aes_status_valid_i;
wire  aes_status_ready_o;
reg [31:0] aes_status_code_i;
reg [15:0] aes_status_result_bytes_i;
reg [127:0] aes_status_iv_i;
reg [63:0] aes_status_cycles_i;
reg  aes_busy_i;
reg  aes_scrub_done_i;
reg  aes_recovery_required_i;
wire  rsa_job_valid_o;
reg  rsa_job_ready_i;
wire [31:0] rsa_job_id_o;
wire [31:0] rsa_key_handle_o;
wire [15:0] rsa_ciphertext_bytes_o;
wire  rsa_input_valid_o;
reg  rsa_input_ready_i;
wire [7:0] rsa_input_data_o;
reg  rsa_output_valid_i;
wire  rsa_output_ready_o;
reg [7:0] rsa_output_data_i;
reg  rsa_status_valid_i;
wire  rsa_status_ready_o;
reg [31:0] rsa_status_id_i;
reg [31:0] rsa_status_code_i;
reg [15:0] rsa_status_result_bytes_i;
reg [63:0] rsa_status_cycles_i;
reg  rsa_busy_i;
reg  rsa_recovery_required_i;
reg [3:0] rsa_phase_i;
reg [7:0] rsa_progress_i;
wire  status_valid_o;
wire [3:0] status_code_o;
wire [7:0] status_detail_o;
wire [31:0] status_operation_id_o;
wire  job_accept_o;
wire [31:0] job_id_o;
reg [7:0] packet[0:1099],aes_buffer[0:1023],rsa_frame[0:255];
localparam [255:0] KEY=256'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f;
localparam [127:0] FINAL_IV=128'hffeeddccbbaa99887766554433221100;
integer cycle=0,checks=0,gens=0,releases=0,public_reads=0,aes_jobs=0,rsa_jobs=0;
integer gen_delay=0,cleanup_delay=0,aes_in=0,aes_out=0,aes_n=0,aes_finish=0;
integer rsa_in=0,rsa_out=0,rsa_finish=0,cycles;
reg [31:0] model_handle=0,next_handle=32'h80000001,model_gen_id=0;
reg [1:0] model_profile=0,model_gen_profile=0;
reg [3:0] inject_gen_error=0;
reg early_gen=0,inject_aes_error=0,inject_bad_status_id=0;
reg inject_aes_early=0,inject_rsa_early=0;
reg aes_active=0,aes_outputting=0,rsa_active=0,rsa_outputting=0;
reg [7:0] got;
reg passed=0;
initial clock_i=0; always #10 clock_i=~clock_i;
customer_demo_packet #(.DEMO_PROVIDER_MODE(0),.DEMO_AES_EXPORT_ENABLE(EXPORT_ENABLED),
 .DEADLINE_CYCLES(WATCHDOG_TEST ? 64'd150 : 64'd9000000000)) dut(.*);
always @(posedge clock_i) begin cycle<=cycle+1; command_byte_i<=packet[command_addr_o]; end
function [31:0] nword(input [5:0] index);
 begin nword=index==0 ? 32'hc0000000 : index==63 ? 32'h00001235 : 32'ha5000000+index; end
endfunction
always @* begin
 gen_job_ready_i=!WATCHDOG_TEST; gen_available_i=1;
 release_ready_i=1; key_request_ready_i=cycle%3!=0; public_request_ready_i=cycle%3!=0;
 resolved_key_i=key_reply_valid_i && key_reply_code_i==0 ? KEY : 0;
 aes_job_ready_i=!aes_active && !aes_status_valid_i;
 aes_input_ready_i=aes_active && !inject_aes_early && !aes_outputting && aes_in<aes_n && cycle%3!=0;
 aes_output_valid_i=aes_outputting && aes_out<(inject_aes_error ? aes_n/2 : aes_n);
 aes_output_data_i=aes_buffer[aes_out]^8'h5a;
 rsa_job_ready_i=!rsa_active && !rsa_status_valid_i;
 rsa_input_ready_i=rsa_active && !inject_rsa_early && !rsa_outputting && rsa_in<256 && cycle%3!=0;
 rsa_output_valid_i=rsa_outputting && rsa_out<256;
 rsa_output_data_i=rsa_frame[rsa_out];
 rsa_phase_i=rsa_outputting ? 4'd9 : 4'd3; rsa_progress_i=rsa_outputting ? rsa_out : rsa_in;
end
always @(posedge clock_i) begin
 if(!reset_n_i) begin
  gen_done_valid_i<=0; gen_scrub_done_i<=1; gen_phase_i<=0; gen_delay<=0; cleanup_delay<=0;
  release_rsp_valid_i<=0; key_reply_valid_i<=0; public_reply_valid_i<=0;
  aes_status_valid_i<=0; aes_scrub_done_i<=1; aes_active<=0; aes_outputting<=0; aes_finish<=0;
  rsa_status_valid_i<=0; rsa_active<=0; rsa_outputting<=0; rsa_finish<=0;
  model_handle<=0; model_profile<=0; next_handle<=32'h80000001;
 end else begin
  if(gen_job_valid_o && gen_job_ready_i) begin
   gens<=gens+1; gen_delay<=4; model_gen_id<=gen_job_id_o;
   model_gen_profile<=gen_job_profile_o; gen_phase_i<=4;
  end
  if(gen_delay>0) begin
   gen_delay<=gen_delay-1;
   if(gen_delay==1) begin
    gen_done_valid_i<=1; gen_done_id_i<=model_gen_id; gen_done_profile_i<=model_gen_profile;
    gen_done_mode_i<=0; gen_done_core_status_i<=0; gen_done_setup_error_i<=inject_gen_error;
    gen_done_teardown_error_i<=0; gen_done_ownership_committed_i<=inject_gen_error==0;
    gen_done_handle_i<=inject_gen_error==0 ? next_handle : 0; gen_done_cycles_i<=12345;
    gen_phase_i<=6;
    if(inject_gen_error==0) begin model_handle<=next_handle;model_profile<=model_gen_profile;next_handle<=next_handle+1; end
    if(early_gen) begin gen_scrub_done_i<=0; cleanup_delay<=7; end
   end
  end
  if(cleanup_delay>0) begin cleanup_delay<=cleanup_delay-1; if(cleanup_delay==1) gen_scrub_done_i<=1; end
  if(gen_done_valid_i && gen_done_ready_o) gen_done_valid_i<=0;
  if(release_valid_o && release_ready_i) begin
   if(aes_client_active_o)$fatal(1,"release raced AES lease");
   releases<=releases+1; release_rsp_valid_i<=1;
   release_rsp_code_i<=release_handle_o==model_handle ? 0 : 32'h18b;
   if(release_handle_o==model_handle) begin model_handle<=0;model_profile<=0; end
  end
  if(release_rsp_valid_i && release_rsp_ready_o)release_rsp_valid_i<=0;
  if(key_request_o && key_request_ready_i) begin
   key_reply_valid_i<=1;
   key_reply_code_i<=key_handle_o!=model_handle ? 32'h18b :
                     model_profile!=1 || !aes_use_allowed_o ? 32'h12f : 0;
  end
  if(key_reply_valid_i && key_reply_ready_o)key_reply_valid_i<=0;
  if(public_request_o && public_request_ready_i) begin
   public_reads<=public_reads+1; public_reply_valid_i<=1;
   public_reply_code_i<=public_handle_o!=model_handle || model_profile!=2 ? 32'h18b : 0;
   public_data_i<=public_component_o ? 32'h10001 : nword(public_index_o);
  end
  if(public_reply_valid_i && public_reply_ready_o)public_reply_valid_i<=0;
  if(aes_job_valid_o && aes_job_ready_i) begin
   if(aes_job_key_o!==KEY)$fatal(1,"wrong AES key/byte order");
   aes_jobs<=aes_jobs+1; aes_n<=aes_job_bytes_o; aes_in<=0; aes_out<=0;
   aes_active<=1; aes_outputting<=aes_job_bytes_o==0; aes_scrub_done_i<=0;
   if(inject_aes_early)begin
    aes_status_valid_i<=1;aes_status_code_i<='h095;aes_status_result_bytes_i<=0;
    aes_status_iv_i<=0;aes_status_cycles_i<=19;aes_finish<=7;aes_outputting<=0;
   end
  end
  if(aes_input_valid_o && aes_input_ready_i) begin
   if(aes_input_data_o!==(aes_in%256))$fatal(1,"AES input byte%0d got%h",aes_in,aes_input_data_o);
   aes_buffer[aes_in]<=aes_input_data_o; aes_in<=aes_in+1;
   if(aes_in+1==aes_n)aes_outputting<=1;
  end
  if(aes_output_valid_i && aes_output_ready_o)aes_out<=aes_out+1;
  if(aes_outputting && aes_out==(inject_aes_error ? aes_n/2 : aes_n)) begin
   aes_outputting<=0; aes_finish<=7; aes_status_valid_i<=1;
   aes_status_code_i<=inject_aes_error ? 32'h101 : 0;
   aes_status_result_bytes_i<=inject_aes_error ? 0 : aes_n;
   aes_status_iv_i<=FINAL_IV; aes_status_cycles_i<=5678;
  end
  if(aes_finish>0) begin aes_finish<=aes_finish-1; if(aes_finish==1)aes_scrub_done_i<=1; end
  if(aes_status_valid_i && aes_status_ready_o) begin aes_status_valid_i<=0;aes_active<=0; end
  if(rsa_job_valid_o && rsa_job_ready_i) begin
   if(rsa_key_handle_o!==model_handle || !rsa_use_allowed_o || rsa_ciphertext_bytes_o!=256)$fatal(1,"RSA descriptor/permission");
   rsa_jobs<=rsa_jobs+1; rsa_active<=1;rsa_in<=0;rsa_out<=0;rsa_outputting<=0;
   rsa_status_id_i<=rsa_job_id_o+(inject_bad_status_id ? 1 : 0);
   if(inject_rsa_early)begin
    rsa_finish<=7;rsa_status_code_i<='h18b;rsa_status_result_bytes_i<=0;
   end
  end
  if(rsa_input_valid_o && rsa_input_ready_i) begin
   if(rsa_input_data_o!==(rsa_in%256))$fatal(1,"RSA input byte%0d",rsa_in);
   rsa_in<=rsa_in+1;if(rsa_in==255)rsa_outputting<=1;
  end
  if(rsa_output_valid_i && rsa_output_ready_o)rsa_out<=rsa_out+1;
  if(rsa_outputting && rsa_out==256)begin rsa_outputting<=0;rsa_finish<=7; end
  if(rsa_finish>0) begin
   rsa_finish<=rsa_finish-1;
   if(rsa_finish==1)begin
    rsa_status_valid_i<=1;rsa_status_code_i<=inject_rsa_early && BAD_TERMINAL_TEST!=1 ? 'h18b : 0;
    rsa_status_result_bytes_i<=inject_rsa_early ? 0 : 256;rsa_status_cycles_i<=2468;
   end
  end
  if(rsa_status_valid_i && rsa_status_ready_o)begin rsa_status_valid_i<=0;rsa_active<=0; end
  if(response_valid_o && (cleanup_delay>0 || aes_finish>0 || rsa_finish>0))$fatal(1,"published before cleanup");
 end
end
task tick;begin @(posedge clock_i);#1;end endtask
task getbyte(input integer addr,output reg[7:0] value);
 begin @(negedge clock_i);response_addr_i=addr;tick;value=response_byte_o;end
endtask
task equalbyte(input integer addr,input [7:0] expected);
 begin getbyte(addr,got);if(got!==expected)$fatal(1,"response byte%0d expected%h got%h op%0d",addr,expected,got,dut.opcode);checks=checks+1;end
endtask
task word(input integer addr,input[31:0] expected);
 begin for(integer k=0;k<4;k=k+1)equalbyte(addr+k,expected[31-k*8 -:8]);end
endtask
task prepare(input integer op,input integer ident,input [31:0] handle,input integer flags,input integer size);
 begin
  for(integer k=0;k<1100;k=k+1)packet[k]=0;
  {packet[0],packet[1]}=16'h8001;{packet[2],packet[3],packet[4],packet[5]}=size;
  {packet[6],packet[7],packet[8],packet[9]}=32'h20000101;
  packet[10]=2;packet[11]=op;{packet[12],packet[13]}=flags;
  {packet[14],packet[15],packet[16],packet[17]}=ident;
  {packet[18],packet[19],packet[20],packet[21]}=handle;
  command_size_i=size;command_tag_i=16'h8001;
 end
endtask
task launch;
 begin
  cycles=0;while(busy_o)begin tick;cycles++;if(cycles>2000)$fatal(1,"scrub/idle timeout");end
  @(negedge clock_i);start_i=1;tick;@(negedge clock_i);start_i=0;
 end
endtask
task response(input[31:0] code,input integer payload_len,input integer op,input integer ident);
 begin
  cycles=0;while(!response_valid_o)begin tick;cycles++;if(cycles>40000)$fatal(1,"response timeout state%0d op%0d",dut.state,dut.opcode);end
  if(response_code_o!==code || response_length_o!==payload_len)$fatal(1,"response RC/len %h/%0d expected%h/%0d",response_code_o,response_length_o,code,payload_len);
  if(code==0)begin equalbyte(0,2);equalbyte(1,op);equalbyte(2,0);word(4,ident);word(24,payload_len-28);end
  else begin equalbyte(0,0);equalbyte(30,0);for(integer k=0;k<1024;k=k+1)if(dut.payload[k]!==0)$fatal(1,"error secret data retained");end
  repeat(3)tick;if(!busy_o)$fatal(1,"response released before consumed");
 end
endtask
task consume;
 begin
  @(negedge clock_i);response_consumed_i=1;tick;@(negedge clock_i);response_consumed_i=0;
  cycles=0;while(busy_o)begin tick;cycles++;if(cycles>1100)$fatal(1,"cleanup timeout");end
  if(dut.aes_key!==0 || dut.internal_read_data!==0 || dut.response_ram_data!==0)$fatal(1,"key/read latch retained");
  for(integer k=0;k<1024;k=k+1)if(dut.payload[k]!==0)$fatal(1,"payload scrub slot%0d",k);
 end
endtask
task aes_command(input integer n,input integer ident,input integer code);
 begin
  prepare(2,ident,32'h80000001,0,44+n);
  for(integer k=0;k<16;k=k+1)packet[26+k]=k;
  {packet[42],packet[43]}=n;
  for(integer k=0;k<n;k=k+1)packet[44+k]=k%256;
  launch;response(code,code==0 ? 46+n : 0,2,ident);
  if(code==0)begin
   equalbyte(28,n>>8);equalbyte(29,n);
   for(integer k=0;k<n;k=k+1)equalbyte(30+k,(k%256)^8'h5a);
   for(integer k=0;k<16;k=k+1)equalbyte(30+n+k,FINAL_IV[127-k*8 -:8]);
   if(aes_job_key_o!==0)$fatal(1,"AES key retained after worker capture");
  end
  consume;
 end
endtask
task frame(input integer n,input bit bad_magic,input bit bad_tail);
 begin
  for(integer k=0;k<256;k=k+1)rsa_frame[k]=0;
  rsa_frame[1]='h44;rsa_frame[2]='h45;rsa_frame[3]='h32;rsa_frame[4]=bad_magic?'h58:'h35;
  {rsa_frame[5],rsa_frame[6]}=n;
  for(integer k=0;k<n && k<249;k=k+1)rsa_frame[7+k]=8'h41+k%26;
  if(bad_tail)rsa_frame[255]=1;
 end
endtask
task rsa_command(input integer n,input integer ident,input integer code);
 begin
  prepare(4,ident,32'h80000002,0,284);packet[26]=1;packet[27]=0;
  for(integer k=0;k<256;k=k+1)packet[28+k]=k;
  launch;response(code,code==0 ? 30+n : 0,4,ident);
  if(code==0)begin
   equalbyte(28,n>>8);equalbyte(29,n);
   for(integer k=0;k<n;k=k+1)equalbyte(30+k,8'h41+k%26);
   if(status_code_o!=8 || status_detail_o!=4)$fatal(1,"sticky actual RSA DONE detail");
  end
  consume;
 end
endtask
initial begin
 reset_n_i=0;
start_i=0;
operational_i=0;
command_tag_i=0;
command_size_i=0;
command_byte_i=0;
response_addr_i=0;
response_consumed_i=0;
snapshot_status_word_i=0;
snapshot_operation_id_i=0;
snapshot_sequence_i=0;
gen_job_ready_i=0;
gen_done_valid_i=0;
gen_done_id_i=0;
gen_done_handle_i=0;
gen_done_profile_i=0;
gen_done_mode_i=0;
gen_done_core_status_i=0;
gen_done_setup_error_i=0;
gen_done_teardown_error_i=0;
gen_done_ownership_committed_i=0;
gen_done_cycles_i=0;
gen_phase_i=0;
gen_available_i=0;
gen_busy_i=0;
gen_recovery_required_i=0;
gen_scrub_done_i=0;
release_ready_i=0;
release_rsp_valid_i=0;
release_rsp_code_i=0;
key_request_ready_i=0;
key_reply_valid_i=0;
resolved_key_i=0;
key_reply_code_i=0;
public_request_ready_i=0;
public_reply_valid_i=0;
public_data_i=0;
public_reply_code_i=0;
aes_job_ready_i=0;
aes_input_ready_i=0;
aes_output_valid_i=0;
aes_output_data_i=0;
aes_status_valid_i=0;
aes_status_code_i=0;
aes_status_result_bytes_i=0;
aes_status_iv_i=0;
aes_status_cycles_i=0;
aes_busy_i=0;
aes_scrub_done_i=0;
aes_recovery_required_i=0;
rsa_job_ready_i=0;
rsa_input_ready_i=0;
rsa_output_valid_i=0;
rsa_output_data_i=0;
rsa_status_valid_i=0;
rsa_status_id_i=0;
rsa_status_code_i=0;
rsa_status_result_bytes_i=0;
rsa_status_cycles_i=0;
rsa_busy_i=0;
rsa_recovery_required_i=0;
rsa_phase_i=0;
rsa_progress_i=0;
 operational_i=1;snapshot_status_word_i=32'h01070088;snapshot_operation_id_i=123;snapshot_sequence_i=99;
 repeat(4)tick;@(negedge clock_i);reset_n_i=1;repeat(1030)tick;
 prepare(0,1,0,0,26);launch;response(0,52,0,1);
 equalbyte(15,EXPORT_ENABLED?'h30:'h20);word(28,32'h01000800);word(32,32'h040000f0);
 word(36,50000000);word(40,32'h00d40f80);word(44,32'h00d40fa0);word(48,EXPORT_ENABLED?7:6);consume;
 prepare(1,2,0,0,26);launch;response('h095,0,1,2);if(gens!=0)$fatal(1,"unauthorized export side effect");consume;
 if(!EXPORT_ENABLED)begin
  prepare(1,3,0,1,26);launch;response('h12f,0,1,3);if(gens!=0)$fatal(1,"build guard bypass");consume;
  passed=1;$display("CUSTOMER_PACKET_DISABLED_PASS checks=%0d",checks);$finish;
 end
 if(WATCHDOG_TEST)begin
  prepare(1,90,0,1,26);launch;cycles=0;
  while(!recovery_required_o)begin tick;cycles++;if(cycles>300)$fatal(1,"missing packet deadline");end
  if(response_valid_o || gen_job_valid_o || aes_use_allowed_o || rsa_use_allowed_o || !busy_o)
   $fatal(1,"timeout fabricated success/reuse");
  passed=1;$display("CUSTOMER_PACKET_TIMEOUT_PASS");$finish;
 end
 early_gen=1;prepare(1,3,0,1,26);launch;response(0,60,1,3);early_gen=0;
 word(8,32'h80000001);for(integer k=0;k<32;k=k+1)equalbyte(28+k,k);
 if(!aes_use_allowed_o || !aes_client_active_o)$fatal(1,"export permission/lease");consume;
 aes_command(0,10,0);aes_command(1,11,0);aes_command(17,12,0);aes_command(1024,13,0);
 inject_aes_error=1;aes_command(16,14,'h101);inject_aes_error=0;aes_command(2,15,0);
 // Worker terminal errors after cleanup may precede the first input-ready.
 inject_aes_early=1;aes_command(17,17,'h095);
 if(aes_in!=0 || recovery_required_o)$fatal(1,"early AES rejection not consumed cleanly");
 inject_aes_early=0;aes_command(1,18,0);
 prepare(2,16,32'h80000001,0,61);packet[42]=0;packet[43]=16;launch;response('h095,0,2,16);consume;
 prepare(3,50,0,0,26);launch;response(0,292,3,50);word(8,32'h80000002);
 equalbyte(28,1);equalbyte(29,0);
 for(integer k=0;k<64;k=k+1)word(30+k*4,nword(k));
 equalbyte(286,0);equalbyte(287,4);word(288,32'h10001);
 if(releases!=1 || public_reads!=65 || !rsa_use_allowed_o || aes_use_allowed_o)$fatal(1,"replacement/public scope");consume;
 if(BAD_TERMINAL_TEST)begin
  inject_rsa_early=1;inject_bad_status_id=BAD_TERMINAL_TEST==2;
  prepare(4,58,32'h80000002,0,284);packet[26]=1;packet[27]=0;launch;
  cycles=0;while(!recovery_required_o)begin tick;cycles++;if(cycles>1000)$fatal(1,"early success/ID mismatch not locked");end
  if(response_valid_o || rsa_input_valid_o || rsa_use_allowed_o || aes_use_allowed_o || !busy_o)
   $fatal(1,"early malformed terminal fabricated response/reuse");
  passed=1;$display("CUSTOMER_PACKET_BAD_TERMINAL_PASS kind=%0d",BAD_TERMINAL_TEST);$finish;
 end
 inject_rsa_early=1;rsa_command(15,57,'h18b);
 if(rsa_in!=0 || recovery_required_o)$fatal(1,"early RSA rejection not consumed cleanly");
 inject_rsa_early=0;
 frame(15,0,0);rsa_command(15,51,0);
 frame(0,0,0);rsa_command(0,52,0);
 frame(240,0,0);rsa_command(240,53,0);
 frame(15,0,1);rsa_command(15,54,'h095);
 frame(15,1,0);rsa_command(15,55,'h095);
 frame(241,0,0);rsa_command(241,56,'h095);
 prepare(5,60,0,0,26);launch;response(0,40,5,60);
 snapshot_status_word_i=0;snapshot_operation_id_i=0;snapshot_sequence_i=0;
 word(28,32'h01070088);word(32,123);word(36,99);consume;
 prepare(2,61,32'h80000001,0,44);launch;response('h18b,0,2,61);consume;
 // Generation setup failure is error-only, never a dummy successful export.
 inject_gen_error=2;prepare(1,62,0,1,26);launch;response('h922,0,1,62);consume;inject_gen_error=0;
 // Reset aborts an incomplete packet and all local context references.
 prepare(1,63,0,1,26);launch;repeat(5)tick;@(negedge clock_i);reset_n_i=0;tick;
 if(response_valid_o || key_request_o || gen_job_valid_o || aes_job_valid_o || rsa_job_valid_o)$fatal(1,"reset handshake");
 @(negedge clock_i);reset_n_i=1;repeat(1030)tick;
 if(dut.owned_handle!==0 || aes_use_allowed_o || rsa_use_allowed_o || !scrub_done_o)$fatal(1,"reset references");
 for(integer k=0;k<1024;k=k+1)if(dut.payload[k]!==0)$fatal(1,"reset buffer");
 passed=1;$display("CUSTOMER_PACKET_PASS checks=%0d AES=%0d RSA=%0d GEN=%0d release=%0d public=%0d",checks,aes_jobs,rsa_jobs,gens,releases,public_reads);$finish;
end
initial begin #20000000;$fatal(1,"overall watchdog");end
endmodule
