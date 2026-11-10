
`timescale 1ns/1ps
module tb_demo_packet;
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
reg  supervisor_recovered_i;
reg  supervisor_last_committed_i;
reg [31:0] supervisor_last_id_i;
reg [31:0] supervisor_last_handle_i;
reg [3:0] supervisor_last_reason_i;
wire  busy_o;
wire  scrub_done_o;
wire  recovery_required_o;
reg  aes_client_active_i;
wire  store_use_allowed_o;
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
reg  gen_busy_i;
reg  gen_available_i;
reg  gen_recovery_required_i;
reg  gen_scrub_done_i;
wire  release_valid_o;
reg  release_ready_i;
wire [31:0] release_handle_o;
reg  release_rsp_valid_i;
wire  release_rsp_ready_o;
reg [31:0] release_rsp_code_i;
wire  modexp_job_valid_o;
reg  modexp_job_ready_i;
wire [31:0] modexp_job_id_o;
wire [11:0] modexp_base_addr_o;
wire [11:0] modexp_exponent_addr_o;
wire [11:0] modexp_modulus_addr_o;
wire [11:0] modexp_result_addr_o;
wire [15:0] modexp_operand_bytes_o;
reg  modexp_status_valid_i;
wire  modexp_status_ready_o;
reg [31:0] modexp_status_id_i;
reg [31:0] modexp_status_cycles_i;
reg [3:0] modexp_status_code_i;
reg [15:0] modexp_status_result_bytes_i;
reg  modexp_recovery_required_i;
reg  modexp_ram_req_valid_i;
wire  modexp_ram_req_ready_o;
reg  modexp_ram_req_write_i;
reg [11:0] modexp_ram_req_addr_i;
reg [7:0] modexp_ram_req_wdata_i;
wire  modexp_ram_rsp_valid_o;
reg  modexp_ram_rsp_ready_i;
wire [7:0] modexp_ram_rsp_rdata_o;
wire  modexp_ram_rsp_error_o;
wire  ram_req_valid_o;
reg  ram_req_ready_i;
wire  ram_req_write_o;
wire [11:0] ram_req_addr_o;
wire [7:0] ram_req_wdata_o;
reg  ram_rsp_valid_i;
wire  ram_rsp_ready_o;
reg [7:0] ram_rsp_rdata_i;
reg  ram_rsp_error_i;
wire  ram_clear_valid_o;
reg  ram_clear_ready_i;
reg  ram_clear_done_valid_i;
wire  ram_clear_done_ready_o;
reg  ram_scrub_done_i;
reg [7:0] packet[0:1023];
reg [7:0] memory[0:1023];
integer i, cycles, gen_count=0, mx_count=0, clear_count=0, release_count=0;
integer gen_delay=0, mx_delay=0, clearing=0;
reg [3:0] inject_setup=0;
reg inject_bad_id=0, inject_write_error=0;
reg [31:0] job_id;
reg passed=0;
initial clock_i=0; always #5 clock_i=~clock_i;
execution_engine_demo_packet #(.WIDTH(32)) dut(.*);
always @(posedge clock_i) command_byte_i <= packet[command_addr_o];
always @(posedge clock_i) begin
 if (!reset_n_i) begin
  ram_rsp_valid_i<=0; ram_clear_done_valid_i<=0; ram_scrub_done_i<=1;
  gen_done_valid_i<=0; modexp_status_valid_i<=0; release_rsp_valid_i<=0;
  gen_delay<=0; mx_delay<=0; clearing<=0;
 end else begin
  if(gen_job_valid_o && gen_job_ready_i) begin
   gen_count<=gen_count+1; job_id<=gen_job_id_o; gen_delay<=3;
  end
  if(gen_delay>0) begin
   gen_delay<=gen_delay-1;
   if(gen_delay==1) begin
    gen_done_valid_i<=1; gen_done_id_i<=job_id+inject_bad_id;
    gen_done_setup_error_i<=inject_setup; gen_done_handle_i<=32'h80000001;
    gen_done_ownership_committed_i<=inject_setup==0;
   end
  end
  if(gen_done_valid_i && gen_done_ready_o) gen_done_valid_i<=0;
  if(release_valid_o && release_ready_i) begin
   release_count<=release_count+1; release_rsp_valid_i<=1;
   release_rsp_code_i<=release_handle_o==32'h80000001 ? 0 : 32'h18b;
  end
  if(release_rsp_valid_i && release_rsp_ready_o) release_rsp_valid_i<=0;
  if(ram_rsp_valid_i && ram_rsp_ready_o) ram_rsp_valid_i<=0;
  if(ram_req_valid_o && ram_req_ready_i) begin
   if(ram_req_addr_o>=1024) $fatal(1,"range");
   ram_rsp_valid_i<=1; ram_rsp_error_i<=inject_write_error && ram_req_write_o;
   ram_rsp_rdata_i<=ram_req_write_o ? 0 : memory[ram_req_addr_o];
   if(ram_req_write_o) memory[ram_req_addr_o]<=ram_req_wdata_o;
  end
  if(ram_clear_valid_o && ram_clear_ready_i) begin
   clear_count<=clear_count+1; clearing<=3; ram_scrub_done_i<=0;
   for(integer j=0;j<1024;j=j+1) memory[j]<=0;
  end
  if(clearing>0) begin
   clearing<=clearing-1;
   if(clearing==1) begin ram_clear_done_valid_i<=1; ram_scrub_done_i<=1; end
  end
  if(ram_clear_done_valid_i && ram_clear_done_ready_o) ram_clear_done_valid_i<=0;
  if(modexp_job_valid_o && modexp_job_ready_i) begin
   mx_count<=mx_count+1; mx_delay<=3;
   if(modexp_base_addr_o!=0 || modexp_exponent_addr_o!=4 ||
      modexp_modulus_addr_o!=8 || modexp_result_addr_o!=12 || modexp_operand_bytes_o!=4)
      $fatal(1,"descriptor");
   for(integer j=0;j<12;j=j+1) if(memory[j]!==j+8'h30) $fatal(1,"staging");
   for(integer j=0;j<4;j=j+1) memory[12+j]<=8'ha0+j;
   modexp_status_id_i<=modexp_job_id_o;
  end
  if(mx_delay>0) begin mx_delay<=mx_delay-1; if(mx_delay==1) modexp_status_valid_i<=1; end
  if(modexp_status_valid_i && modexp_status_ready_o) modexp_status_valid_i<=0;
 end
end
always @* begin
 ram_req_ready_i=!ram_rsp_valid_i && clearing==0 && !ram_clear_done_valid_i;
 ram_clear_ready_i=!ram_rsp_valid_i && clearing==0 && !ram_clear_done_valid_i;
end
task tick; begin @(posedge clock_i); #1; end endtask
task prefix(input integer op,input integer ident,input integer h);
 begin
  for(integer j=0;j<1024;j=j+1) packet[j]=0;
  packet[10]=1; packet[11]=op;
  {packet[14],packet[15],packet[16],packet[17]}=ident;
  {packet[18],packet[19],packet[20],packet[21]}=h;
  for(integer j=0;j<12;j=j+1) packet[26+j]=j+8'h30;
  command_size_i=op==3?38:26;
 end
endtask
task launch;
 begin
  cycles=0; while(busy_o) begin tick; cycles=cycles+1; if(cycles>2000) $fatal(1,"idle timeout"); end
  @(negedge clock_i); start_i=1; tick; @(negedge clock_i); start_i=0;
 end
endtask
task response(input integer code,input integer length);
 begin
  cycles=0; while(!response_valid_o) begin tick; cycles=cycles+1; if(cycles>10000) $fatal(1,"response timeout state %d coord %d",dut.state,dut.coordinator.state); end
  if(response_code_o!==code || response_length_o!==length) $fatal(1,"response code/length %h %d",response_code_o,response_length_o);
  repeat(5) tick;
  if(!busy_o) $fatal(1,"premature reuse");
 end
endtask
task consume;
 begin
  @(negedge clock_i); response_consumed_i=1; tick;
  @(negedge clock_i); response_consumed_i=0;
  cycles=0; while(busy_o) begin tick; cycles=cycles+1; if(cycles>2000) $fatal(1,"scrub timeout"); end
  for(integer j=0;j<4;j=j+1) if(dut.result[j]!==0) $fatal(1,"result scrub");
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
supervisor_recovered_i=0;
supervisor_last_committed_i=0;
supervisor_last_id_i=0;
supervisor_last_handle_i=0;
supervisor_last_reason_i=0;
aes_client_active_i=0;
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
gen_busy_i=0;
gen_available_i=0;
gen_recovery_required_i=0;
gen_scrub_done_i=0;
release_ready_i=0;
release_rsp_valid_i=0;
release_rsp_code_i=0;
modexp_job_ready_i=0;
modexp_status_valid_i=0;
modexp_status_id_i=0;
modexp_status_cycles_i=0;
modexp_status_code_i=0;
modexp_status_result_bytes_i=0;
modexp_recovery_required_i=0;
modexp_ram_req_valid_i=0;
modexp_ram_req_write_i=0;
modexp_ram_req_addr_i=0;
modexp_ram_req_wdata_i=0;
modexp_ram_rsp_ready_i=0;
ram_req_ready_i=0;
ram_rsp_valid_i=0;
ram_rsp_rdata_i=0;
ram_rsp_error_i=0;
ram_clear_ready_i=0;
ram_clear_done_valid_i=0;
ram_scrub_done_i=0;
 operational_i=1; command_tag_i=16'h8001; gen_job_ready_i=1;
 gen_done_profile_i=1; gen_done_mode_i=1; gen_available_i=1; gen_scrub_done_i=1;
 release_ready_i=1; modexp_job_ready_i=1; modexp_status_result_bytes_i=4;
 reset_n_i=0; repeat(4) tick; @(negedge clock_i); reset_n_i=1; repeat(10) tick;
 prefix(1,42,0); launch; response(0,38);
 if(!store_use_allowed_o || gen_count!=1) $fatal(1,"generation");
 response_addr_i=7; #1; if(response_byte_o!=42) $fatal(1,"ID");
 // Mutating live request inputs while response is held cannot change reply.
 command_size_i=999; repeat(4) tick; #1; if(response_byte_o!=42) $fatal(1,"unstable");
 consume;
 prefix(0,900,0); supervisor_recovered_i=1; supervisor_last_id_i=77;
 supervisor_last_handle_i=32'h80000005; supervisor_last_committed_i=1; launch; response(0,38);
 response_addr_i=7; #1; if(response_byte_o!=77) $fatal(1,"supervisor id");
 response_addr_i=15; #1; if(response_byte_o!=11) $fatal(1,"supervisor flags");
 response_addr_i=19; #1; if(response_byte_o!=8'h60) $fatal(1,"supervisor cause");
 consume; supervisor_recovered_i=0;
 prefix(4,44,0); launch; response('h095,10); if(gen_count!=1) $fatal(1,"bad opcode side effect"); consume;
 prefix(2,45,32'h80000002); launch; response('h18b,10);
 if(!store_use_allowed_o) $fatal(1,"invalid flush disturbed key"); consume;
 prefix(2,46,32'h80000001); launch; response(0,38);
 if(store_use_allowed_o) $fatal(1,"flush permission"); consume;
 prefix(1,47,0); inject_setup=2; launch; response('h922,10);
 if(store_use_allowed_o) $fatal(1,"denied gen permission"); consume; inject_setup=0;
 prefix(1,48,0); inject_bad_id=1; launch; response('h101,10);
 if(store_use_allowed_o) $fatal(1,"bad id permission"); consume; inject_bad_id=0;
 prefix(3,49,0); launch; response(0,42);
 for(integer j=0;j<4;j=j+1) begin response_addr_i=28+j; #1; if(response_byte_o!==8'ha0+j) $fatal(1,"public result"); end
 if(mx_count!=1 || clear_count!=2) $fatal(1,"modexp lifecycle");
 for(integer j=0;j<1024;j=j+1) if(memory[j]!==0) $fatal(1,"public scratch cleanup"); consume;
 prefix(3,51,0); inject_write_error=1; launch; response('h101,10); consume; inject_write_error=0;
 prefix(1,50,0); launch; response(0,38); @(negedge clock_i); reset_n_i=0; tick;
 if(response_valid_o || store_use_allowed_o) $fatal(1,"reset isolation");
 @(negedge clock_i); reset_n_i=1; repeat(20) tick;
 if(busy_o || !scrub_done_o) $fatal(1,"reset scrub");
 passed=1; $display("DEMO_PACKET_PASS generation/denial/flush/provenance/modexp-staging/drain/reset"); $finish;
end
initial begin #2000000; $fatal(1,"watchdog"); end
endmodule
