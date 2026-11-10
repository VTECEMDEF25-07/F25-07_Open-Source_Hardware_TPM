`timescale 1ns/1ps
module tb_customer_packet_real_aes;
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
wire  aes_job_ready_i;
wire [255:0] aes_job_key_o;
wire [127:0] aes_job_iv_o;
wire [15:0] aes_job_bytes_o;
wire  aes_input_valid_o;
wire  aes_input_ready_i;
wire [7:0] aes_input_data_o;
wire  aes_output_valid_i;
wire  aes_output_ready_o;
wire [7:0] aes_output_data_i;
wire  aes_status_valid_i;
wire  aes_status_ready_o;
wire [31:0] aes_status_code_i;
wire [15:0] aes_status_result_bytes_i;
wire [127:0] aes_status_iv_i;
wire [63:0] aes_status_cycles_i;
wire  aes_busy_i;
wire  aes_scrub_done_i;
wire  aes_recovery_required_i;
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

// Real packet + AES worker + AES RTL + byte RAM. Gen/store are TEST fixtures.
reg [7:0] packet[0:1099],oracle[0:12383];
localparam [255:0] KEY=256'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f;
integer checks=0,jobs=0,terminals=0,cycles=0,n=0,base=0;
reg [7:0] got;
reg passed=0;
initial clock_i=0; always #10 clock_i=~clock_i;
customer_demo_packet #(.DEMO_PROVIDER_MODE(1),.DEMO_AES_EXPORT_ENABLE(1)) dut(.*);
customer_aes_worker aes_worker(
 .clock_i(clock_i),.reset_n_i(reset_n_i),
 .job_valid_i(aes_job_valid_o),.job_ready_o(aes_job_ready_i),
 .job_key_i(aes_job_key_o),.job_iv_i(aes_job_iv_o),.job_bytes_i(aes_job_bytes_o),
 .input_valid_i(aes_input_valid_o),.input_ready_o(aes_input_ready_i),.input_data_i(aes_input_data_o),
 .output_valid_o(aes_output_valid_i),.output_ready_i(aes_output_ready_o),.output_data_o(aes_output_data_i),
 .status_valid_o(aes_status_valid_i),.status_ready_i(aes_status_ready_o),
 .status_code_o(aes_status_code_i),.status_result_bytes_o(aes_status_result_bytes_i),
 .status_iv_o(aes_status_iv_i),.status_cycles_o(aes_status_cycles_i),
 .busy_o(aes_busy_i),.scrub_done_o(aes_scrub_done_i),.recovery_required_o(aes_recovery_required_i));
always @(posedge clock_i) begin
 command_byte_i<=packet[command_addr_o];
 if(!reset_n_i)begin gen_done_valid_i<=0;key_reply_valid_i<=0;end
 else begin
  if(gen_job_valid_o && gen_job_ready_i)begin
   gen_done_valid_i<=1;gen_done_id_i<=gen_job_id_o;gen_done_handle_i<=32'h80000001;
   gen_done_profile_i<=1;gen_done_mode_i<=1;gen_done_ownership_committed_i<=1;
  end else if(gen_done_valid_i && gen_done_ready_o)gen_done_valid_i<=0;
  if(key_request_o && key_request_ready_i)begin
   if(key_handle_o!=32'h80000001 || !aes_use_allowed_o || !aes_client_active_o)
    $fatal(1,"TEST lookup permission/handle");
   key_reply_valid_i<=1;key_reply_code_i<=0;
  end else if(key_reply_valid_i && key_reply_ready_o)key_reply_valid_i<=0;
  if(aes_job_valid_o && aes_job_ready_i)begin
   if(aes_job_key_o!==KEY)$fatal(1,"real worker key order");jobs<=jobs+1;
  end
  if(aes_status_valid_i && aes_status_ready_o)begin
   if(!aes_scrub_done_i || aes_status_code_i!=0 || aes_status_cycles_i==0)
    $fatal(1,"real AES terminal before cleanup/error/cycles");
   terminals<=terminals+1;
  end
  if(response_valid_o && !aes_scrub_done_i)$fatal(1,"packet publish before AES scrub");
  if(recovery_required_o || aes_recovery_required_i)$fatal(1,"unexpected recovery");
 end
end
task tick;begin @(posedge clock_i);#1;end endtask
task equalbyte(input integer address,input [7:0] expected);
 begin
  @(negedge clock_i);response_addr_i=address;tick;got=response_byte_o;
  if(got!==expected)$fatal(1,"byte %0d expected %h got %h N=%0d",address,expected,got,n);
  checks=checks+1;
 end
endtask
task prepare(input integer opcode,input integer id,input integer size);
 begin
  for(integer k=0;k<1100;k=k+1)packet[k]=0;
  command_tag_i=16'h8001;command_size_i=size;
  packet[10]=2;packet[11]=opcode;packet[17]=id;
  if(opcode==1)packet[13]=1;
  else begin packet[18]='h80;packet[21]=1;end
 end
endtask
task launch;
 begin
  cycles=0;while(busy_o || !aes_scrub_done_i)begin tick;cycles++;if(cycles>4000)$fatal(1,"idle timeout");end
  @(negedge clock_i);start_i=1;tick;@(negedge clock_i);start_i=0;
  cycles=0;while(!response_valid_o)begin tick;cycles++;if(cycles>100000)$fatal(1,"response timeout state%0d",dut.state);end
  if(response_code_o!=0)$fatal(1,"packet error %h",response_code_o);
 end
endtask
task consume;
 begin
  @(negedge clock_i);response_consumed_i=1;tick;@(negedge clock_i);response_consumed_i=0;
  cycles=0;while(busy_o)begin tick;cycles++;if(cycles>1100)$fatal(1,"packet scrub timeout");end
  if(dut.aes_key!==0 || dut.response_ram_data!==0 || dut.internal_read_data!==0)
   $fatal(1,"packet key/read latch retained");
  for(integer k=0;k<1024;k=k+1)if(dut.payload[k]!==0)$fatal(1,"packet payload not clear");
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
 operational_i=1;gen_available_i=1;gen_job_ready_i=1;gen_scrub_done_i=1;
 key_request_ready_i=1;resolved_key_i=KEY;
 $readmemh("real-aes-oracle.hex",oracle);
 repeat(4)tick;@(negedge clock_i);reset_n_i=1;
 prepare(1,1,26);launch;
 if(response_length_o!=60)$fatal(1,"export size");
 equalbyte(2,1);for(integer k=0;k<32;k=k+1)equalbyte(28+k,k);consume;
 for(integer v=0;v<6;v=v+1)begin
  case(v)0:n=0;1:n=1;2:n=17;3:n=31;4:n=32;5:n=1024;endcase
  base=v*2064;prepare(2,v+2,44+n);
  for(integer k=0;k<16;k=k+1)packet[26+k]=k;
  {packet[42],packet[43]}=n;
  for(integer k=0;k<n;k=k+1)packet[44+k]=oracle[base+1024+k];
  launch;
  if(response_length_o!=46+n || status_code_o!=8 || status_detail_o!=2)
   $fatal(1,"packet length/DONE");
  equalbyte(0,2);equalbyte(1,2);equalbyte(2,1);equalbyte(7,v+2);
  equalbyte(28,n>>8);equalbyte(29,n);
  for(integer k=0;k<n;k=k+1)equalbyte(30+k,oracle[base+k]);
  for(integer k=0;k<16;k=k+1)equalbyte(30+n+k,oracle[base+2048+k]);
  if(terminals!=v+1 || jobs!=v+1)$fatal(1,"real worker job/terminal mismatch");
  $display("REAL_AES_PACKET_CASE_PASS bytes=%0d",n);consume;
 end
 passed=1;$display("CUSTOMER_PACKET_REAL_AES_PASS checks=%0d jobs=%0d",checks,jobs);$finish;
end
initial begin #1000000000;$fatal(1,"overall watchdog");end
endmodule
