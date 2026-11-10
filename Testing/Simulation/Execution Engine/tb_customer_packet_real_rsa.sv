`timescale 1ns/1ps
module tb_customer_packet_real_rsa;
    reg clock_i=0,reset_n_i=0;
    always #5 clock_i=~clock_i;
    wire job_valid_i,input_valid_i,output_ready_i,status_ready_i;
    wire job_ready_o,input_ready_o,output_valid_o,status_valid_o,busy_o,rsa_client_active_o;
    wire [31:0] job_id_i,key_handle_i;
    wire [15:0] ciphertext_bytes_i;
    wire [7:0] input_data_i;
    wire [7:0] output_data_o,progress_o;
    wire [31:0] status_id_o,status_code_o;
    wire [15:0] status_result_bytes_o;
    wire [63:0] status_cycles_o;
    wire recovery_required_o;
    wire [3:0] phase_o;
    wire private_open_valid_o,private_cmd_valid_o,private_rsp_ready_o;
    wire private_mem_write_en_o,private_mem_read_en_o;
    wire private_close_valid_o,private_close_rsp_ready_o;
    wire [7:0] private_cmd_op_o;
    wire [31:0] private_cmd_arg0_o,private_cmd_arg1_o,private_cmd_arg2_o,private_cmd_arg3_o;
    wire [11:0] private_mem_address_o;
    wire [31:0] private_mem_write_data_o;
    wire private_request_o,private_reply_ready_o,private_component_o;
    wire [31:0] private_handle_o;
    wire [5:0] private_index_o;
    reg private_active_i=0,private_close_rsp_valid_i=0;
    reg private_reply_valid_i=0;
    reg [31:0] private_data_i=0,private_reply_code_i=0;
    wire private_open_ready_i,private_cmd_ready_i,private_rsp_valid_i;
    wire [7:0] private_rsp_status_i;
    wire private_mem_ready_i,private_mem_read_valid_i;
    wire [31:0] private_mem_read_data_i;
    wire private_close_ready_i,private_request_ready_i;
    demo_rsa_private_worker worker(.*);

    reg [31:0] random_reg=32'h025d6411;
    reg stalls=1,deny_key=0,stall_math=0,stall_output=0;
    reg [2047:0] n_value,d_value,cipher_value,expected_value;
    integer cases=0,outputs=0,opens=0,closes=0,commands=0,mode=0;
    reg [31:0] expected_id;
    reg core_reset_n=0;
    reg [2:0] lease_state=0;
    reg [63:0] close_clocks=0;
    wire math_cmd_ready,math_rsp_valid,math_mem_ready,math_read_valid;
    wire [7:0] math_status;
    wire [31:0] math_read_data;
    wire cmd_gate=!stalls || random_reg[1];
    wire mem_gate=!stalls || random_reg[2];
    wire math_cmd_valid=private_active_i && lease_state==3 && private_cmd_valid_o && cmd_gate;
    wire math_rsp_ready=private_active_i && lease_state==3 && private_rsp_ready_o;
    wire math_write=private_active_i && lease_state==3 && private_mem_write_en_o && mem_gate;
    wire math_read=private_active_i && lease_state==3 && private_mem_read_en_o && mem_gate;
    assign private_open_ready_i=reset_n_i && lease_state==2 && math_cmd_ready && (!stalls || random_reg[0]);
    assign private_cmd_ready_i=private_active_i && lease_state==3 && math_cmd_ready && cmd_gate;
    assign private_rsp_valid_i=private_active_i && lease_state==3 && math_rsp_valid;
    assign private_rsp_status_i=math_status;
    assign private_mem_ready_i=private_active_i && lease_state==3 && math_mem_ready && mem_gate;
    assign private_mem_read_valid_i=private_active_i && lease_state==3 && math_read_valid;
    assign private_mem_read_data_i=private_mem_read_valid_i ? math_read_data : 0;
    assign private_close_ready_i=private_active_i && lease_state==3 && math_cmd_ready && !math_read_valid;

    // Registered local reset and real math's ready-after-scrub establish close.
    always @(posedge clock_i or negedge reset_n_i) begin
        if(!reset_n_i) begin
            core_reset_n<=0;lease_state<=0;private_active_i<=0;
            private_close_rsp_valid_i<=0;close_clocks<=0;
        end else begin
            random_reg<={random_reg[30:0],random_reg[31]^random_reg[21]^random_reg[1]^random_reg[0]};
            if(lease_state>=4 && lease_state<=6) close_clocks<=close_clocks+1'b1;
            case(lease_state)
                0: lease_state<=1;
                1: begin core_reset_n<=1;lease_state<=2;end
                2: if(private_open_valid_o && private_open_ready_i) begin
                    private_active_i<=1;lease_state<=3;opens<=opens+1;
                end
                3: if(private_close_valid_o && private_close_ready_i) begin
                    core_reset_n<=0;lease_state<=4;close_clocks<=0;
                end
                4: lease_state<=5;
                5: begin core_reset_n<=1;lease_state<=6;end
                6: if(math_cmd_ready) begin
                    if(close_clocks<4098 || math_read_data!==0) $fatal(1,"close before actual scrub/read-latch clearing");
                    private_close_rsp_valid_i<=1;lease_state<=7;
                end
                7: if(private_close_rsp_ready_o) begin
                    private_close_rsp_valid_i<=0;private_active_i<=0;
                    closes<=closes+1;lease_state<=2;
                end
                default: $fatal(1,"lease model state");
            endcase
        end
    end

        keygen_math #(.MAX_LIMBS(64),.COMPACT_STORAGE(1),.IP_TYPE(0)) math(

            .clock_i(clock_i),.reset_n_i(core_reset_n),
            .cmd_valid_i(math_cmd_valid),.cmd_ready_o(math_cmd_ready),
            .cmd_op_i(private_cmd_op_o),.cmd_arg0_i(private_cmd_arg0_o),
            .cmd_arg1_i(private_cmd_arg1_o),.cmd_arg2_i(private_cmd_arg2_o),.cmd_arg3_i(private_cmd_arg3_o),
            .rsp_valid_o(math_rsp_valid),.rsp_ready_i(math_rsp_ready),.rsp_status_o(math_status),
            .mem_write_en_i(math_write),.mem_read_en_i(math_read),
            .mem_address_i(private_mem_address_o),.mem_write_data_i(private_mem_write_data_o),
            .mem_ready_o(math_mem_ready),.mem_read_valid_o(math_read_valid),.mem_read_data_o(math_read_data)
        );


    // Explicit test-only protected store: checked public test fixtures, never a
    // customer key source. One registered held reply, no host secret read path.
    reg store_pending=0;
    reg [31:0] store_word=0,store_code=0;
    integer store_delay=0;
    assign private_request_ready_i=reset_n_i && private_active_i && rsa_client_active_o &&
        !store_pending && !private_reply_valid_i && (!stalls || random_reg[3]);
    always @(posedge clock_i or negedge reset_n_i) begin
        if(!reset_n_i) begin
            store_pending<=0;private_reply_valid_i<=0;private_data_i<=0;private_reply_code_i<=0;
        end else begin
            if(private_request_o && private_request_ready_i) begin
                store_pending<=1;store_delay<=stalls?{30'd0,random_reg[5:4]}:0;
                store_code<=private_handle_o!=32'h80000011 ? 32'h18b : deny_key ? 32'h12f : 0;
                store_word<=private_component_o ? d_value[2047-32*private_index_o -:32] : n_value[2047-32*private_index_o -:32];
            end
            if(store_pending) begin
                if(store_delay==0) begin
                    private_reply_valid_i<=1;private_reply_code_i<=store_code;
                    private_data_i<=store_code==0 ? store_word : 0;store_pending<=0;
                end else store_delay<=store_delay-1;
            end
            if(private_reply_valid_i && private_reply_ready_o) begin
                private_reply_valid_i<=0;private_data_i<=0;private_reply_code_i<=0;
            end
        end
    end


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
wire  packet_busy_o;
wire  scrub_done_o;
wire  packet_recovery_required_o;
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
wire  rsa_job_ready_i;
wire [31:0] rsa_job_id_o;
wire [31:0] rsa_key_handle_o;
wire [15:0] rsa_ciphertext_bytes_o;
wire  rsa_input_valid_o;
wire  rsa_input_ready_i;
wire [7:0] rsa_input_data_o;
wire  rsa_output_valid_i;
wire  rsa_output_ready_o;
wire [7:0] rsa_output_data_i;
wire  rsa_status_valid_i;
wire  rsa_status_ready_o;
wire [31:0] rsa_status_id_i;
wire [31:0] rsa_status_code_i;
wire [15:0] rsa_status_result_bytes_i;
wire [63:0] rsa_status_cycles_i;
wire  rsa_busy_i;
wire  rsa_recovery_required_i;
wire [3:0] rsa_phase_i;
wire [7:0] rsa_progress_i;
wire  packet_status_valid_o;
wire [3:0] packet_status_code_o;
wire [7:0] status_detail_o;
wire [31:0] status_operation_id_o;
wire  job_accept_o;
wire [31:0] job_id_o;

reg [7:0] packet[0:1099];
integer cycles=0,checks=0,raw_outputs=0,fd=0,scan=0;
reg passed=0;
customer_demo_packet #(.DEMO_PROVIDER_MODE(1),.DEMO_AES_EXPORT_ENABLE(0)) packet_dut(
 .clock_i(clock_i),
 .reset_n_i(reset_n_i),
 .start_i(start_i),
 .operational_i(operational_i),
 .command_tag_i(command_tag_i),
 .command_size_i(command_size_i),
 .command_addr_o(command_addr_o),
 .command_byte_i(command_byte_i),
 .response_valid_o(response_valid_o),
 .response_code_o(response_code_o),
 .response_length_o(response_length_o),
 .response_addr_i(response_addr_i),
 .response_byte_o(response_byte_o),
 .response_consumed_i(response_consumed_i),
 .busy_o(packet_busy_o),
 .scrub_done_o(scrub_done_o),
 .recovery_required_o(packet_recovery_required_o),
 .snapshot_status_word_i(snapshot_status_word_i),
 .snapshot_operation_id_i(snapshot_operation_id_i),
 .snapshot_sequence_i(snapshot_sequence_i),
 .gen_job_valid_o(gen_job_valid_o),
 .gen_job_ready_i(gen_job_ready_i),
 .gen_job_profile_o(gen_job_profile_o),
 .gen_job_mode_o(gen_job_mode_o),
 .gen_job_id_o(gen_job_id_o),
 .gen_done_valid_i(gen_done_valid_i),
 .gen_done_ready_o(gen_done_ready_o),
 .gen_done_id_i(gen_done_id_i),
 .gen_done_handle_i(gen_done_handle_i),
 .gen_done_profile_i(gen_done_profile_i),
 .gen_done_mode_i(gen_done_mode_i),
 .gen_done_core_status_i(gen_done_core_status_i),
 .gen_done_setup_error_i(gen_done_setup_error_i),
 .gen_done_teardown_error_i(gen_done_teardown_error_i),
 .gen_done_ownership_committed_i(gen_done_ownership_committed_i),
 .gen_done_cycles_i(gen_done_cycles_i),
 .gen_phase_i(gen_phase_i),
 .gen_available_i(gen_available_i),
 .gen_busy_i(gen_busy_i),
 .gen_recovery_required_i(gen_recovery_required_i),
 .gen_scrub_done_i(gen_scrub_done_i),
 .release_valid_o(release_valid_o),
 .release_ready_i(release_ready_i),
 .release_handle_o(release_handle_o),
 .release_rsp_valid_i(release_rsp_valid_i),
 .release_rsp_ready_o(release_rsp_ready_o),
 .release_rsp_code_i(release_rsp_code_i),
 .key_request_o(key_request_o),
 .key_request_ready_i(key_request_ready_i),
 .key_handle_o(key_handle_o),
 .key_reply_valid_i(key_reply_valid_i),
 .key_reply_ready_o(key_reply_ready_o),
 .resolved_key_i(resolved_key_i),
 .key_reply_code_i(key_reply_code_i),
 .aes_use_allowed_o(aes_use_allowed_o),
 .rsa_use_allowed_o(rsa_use_allowed_o),
 .aes_client_active_o(aes_client_active_o),
 .public_request_o(public_request_o),
 .public_request_ready_i(public_request_ready_i),
 .public_handle_o(public_handle_o),
 .public_component_o(public_component_o),
 .public_index_o(public_index_o),
 .public_reply_valid_i(public_reply_valid_i),
 .public_reply_ready_o(public_reply_ready_o),
 .public_data_i(public_data_i),
 .public_reply_code_i(public_reply_code_i),
 .aes_job_valid_o(aes_job_valid_o),
 .aes_job_ready_i(aes_job_ready_i),
 .aes_job_key_o(aes_job_key_o),
 .aes_job_iv_o(aes_job_iv_o),
 .aes_job_bytes_o(aes_job_bytes_o),
 .aes_input_valid_o(aes_input_valid_o),
 .aes_input_ready_i(aes_input_ready_i),
 .aes_input_data_o(aes_input_data_o),
 .aes_output_valid_i(aes_output_valid_i),
 .aes_output_ready_o(aes_output_ready_o),
 .aes_output_data_i(aes_output_data_i),
 .aes_status_valid_i(aes_status_valid_i),
 .aes_status_ready_o(aes_status_ready_o),
 .aes_status_code_i(aes_status_code_i),
 .aes_status_result_bytes_i(aes_status_result_bytes_i),
 .aes_status_iv_i(aes_status_iv_i),
 .aes_status_cycles_i(aes_status_cycles_i),
 .aes_busy_i(aes_busy_i),
 .aes_scrub_done_i(aes_scrub_done_i),
 .aes_recovery_required_i(aes_recovery_required_i),
 .rsa_job_valid_o(rsa_job_valid_o),
 .rsa_job_ready_i(rsa_job_ready_i),
 .rsa_job_id_o(rsa_job_id_o),
 .rsa_key_handle_o(rsa_key_handle_o),
 .rsa_ciphertext_bytes_o(rsa_ciphertext_bytes_o),
 .rsa_input_valid_o(rsa_input_valid_o),
 .rsa_input_ready_i(rsa_input_ready_i),
 .rsa_input_data_o(rsa_input_data_o),
 .rsa_output_valid_i(rsa_output_valid_i),
 .rsa_output_ready_o(rsa_output_ready_o),
 .rsa_output_data_i(rsa_output_data_i),
 .rsa_status_valid_i(rsa_status_valid_i),
 .rsa_status_ready_o(rsa_status_ready_o),
 .rsa_status_id_i(rsa_status_id_i),
 .rsa_status_code_i(rsa_status_code_i),
 .rsa_status_result_bytes_i(rsa_status_result_bytes_i),
 .rsa_status_cycles_i(rsa_status_cycles_i),
 .rsa_busy_i(rsa_busy_i),
 .rsa_recovery_required_i(rsa_recovery_required_i),
 .rsa_phase_i(rsa_phase_i),
 .rsa_progress_i(rsa_progress_i),
 .status_valid_o(packet_status_valid_o),
 .status_code_o(packet_status_code_o),
 .status_detail_o(status_detail_o),
 .status_operation_id_o(status_operation_id_o),
 .job_accept_o(job_accept_o),
 .job_id_o(job_id_o));
assign job_valid_i=rsa_job_valid_o;assign rsa_job_ready_i=job_ready_o;
assign job_id_i=rsa_job_id_o;assign key_handle_i=rsa_key_handle_o;
assign ciphertext_bytes_i=rsa_ciphertext_bytes_o;
assign input_valid_i=rsa_input_valid_o;assign rsa_input_ready_i=input_ready_o;
assign input_data_i=rsa_input_data_o;assign rsa_output_valid_i=output_valid_o;
assign output_ready_i=rsa_output_ready_o;assign rsa_output_data_i=output_data_o;
assign rsa_status_valid_i=status_valid_o;assign status_ready_i=rsa_status_ready_o;
assign rsa_status_id_i=status_id_o;assign rsa_status_code_i=status_code_o;
assign rsa_status_result_bytes_i=status_result_bytes_o;assign rsa_status_cycles_i=status_cycles_o;
assign rsa_busy_i=busy_o;assign rsa_recovery_required_i=recovery_required_o;
assign rsa_phase_i=phase_o;assign rsa_progress_i=progress_o;
always @(posedge clock_i)begin
 command_byte_i<=packet[command_addr_o];
 if(!reset_n_i)begin gen_done_valid_i<=0;public_reply_valid_i<=0;end
 else begin
  if(gen_job_valid_o && gen_job_ready_i)begin
   gen_done_valid_i<=1;gen_done_id_i<=gen_job_id_o;gen_done_handle_i<=32'h80000011;
   gen_done_profile_i<=2;gen_done_mode_i<=1;gen_done_ownership_committed_i<=1;
  end else if(gen_done_valid_i && gen_done_ready_o)gen_done_valid_i<=0;
  if(public_request_o && public_request_ready_i)begin
   public_reply_valid_i<=1;public_reply_code_i<=0;
   public_data_i<=public_component_o ? 32'h10001 : n_value[2047-32*public_index_o -:32];
  end else if(public_reply_valid_i && public_reply_ready_o)public_reply_valid_i<=0;
  if(output_valid_o && output_ready_i)begin
   if(raw_outputs>=256 || output_data_o!==expected_value[2047-8*raw_outputs -:8])
    $fatal(1,"real RSA raw plaintext mismatch at %0d",raw_outputs);
   raw_outputs<=raw_outputs+1;
  end
  if(response_valid_o && packet_dut.opcode==4 &&
     (private_active_i || closes!=1 || raw_outputs!=256 || status_code_o!=0))
   $fatal(1,"packet published before real private close/scrub");
  if(packet_recovery_required_o || recovery_required_o)$fatal(1,"unexpected private recovery");
 end
end
task tick;begin @(posedge clock_i);#1;end endtask
task equalbyte(input integer addr,input[7:0] expected);
 begin
  @(negedge clock_i);response_addr_i=addr;tick;
  if(response_byte_o!==expected)$fatal(1,"packet byte%0d expected%h got%h",addr,expected,response_byte_o);
  checks=checks+1;
 end
endtask
task prepare(input integer opcode,input integer id,input integer size);
 begin
  for(integer k=0;k<1100;k=k+1)packet[k]=0;
  command_tag_i='h8001;command_size_i=size;packet[10]=2;packet[11]=opcode;packet[17]=id;
  if(opcode==4)begin packet[18]='h80;packet[21]='h11;packet[26]=1;end
 end
endtask
task launch;
 begin
  cycles=0;while(packet_busy_o)begin tick;cycles++;if(cycles>2000)$fatal(1,"packet idle timeout");end
  @(negedge clock_i);start_i=1;tick;@(negedge clock_i);start_i=0;
  cycles=0;while(!response_valid_o)begin tick;cycles++;if(cycles>200000000)$fatal(1,"real private timeout");end
  if(response_code_o!=0)$fatal(1,"packet status %h",response_code_o);
 end
endtask
task consume;
 begin
  @(negedge clock_i);response_consumed_i=1;tick;@(negedge clock_i);response_consumed_i=0;
  cycles=0;while(packet_busy_o)begin tick;cycles++;if(cycles>1100)$fatal(1,"packet scrub timeout");end
  for(integer k=0;k<1024;k=k+1)if(packet_dut.payload[k]!==0)$fatal(1,"packet payload retained");
 end
endtask
initial begin
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
 fd=$fopen("real-rsa-vector.txt","r");if(!fd)$fatal(1,"missing TEST fixture vector");
 scan=$fscanf(fd,"%h %h %h %h",n_value,d_value,cipher_value,expected_value);$fclose(fd);
 if(scan!=4)$fatal(1,"malformed TEST vector");
 operational_i=1;gen_job_ready_i=1;gen_available_i=1;gen_scrub_done_i=1;public_request_ready_i=1;
 // The existing test-only lease/store harness adds held-reply/backpressure stalls.
 repeat(4)tick;@(negedge clock_i);reset_n_i=1;
 while(!math_cmd_ready)tick;
 prepare(3,1,26);launch;
 if(response_length_o!=292)$fatal(1,"public response width");
 equalbyte(2,1);equalbyte(28,1);equalbyte(29,0);
 for(integer k=0;k<256;k=k+1)equalbyte(30+k,n_value[2047-k*8 -:8]);
 equalbyte(286,0);equalbyte(287,4);equalbyte(288,0);equalbyte(289,1);equalbyte(290,0);equalbyte(291,1);
 consume;
 prepare(4,2,284);
 for(integer k=0;k<256;k=k+1)packet[28+k]=cipher_value[2047-8*k -:8];
 launch;
 if(response_length_o!=30+expected_value[2007:1992] || packet_status_code_o!=8 || status_detail_o!=4)
  $fatal(1,"private response frame/length/DONE");
 equalbyte(0,2);equalbyte(1,4);equalbyte(2,1);equalbyte(7,2);
 equalbyte(28,expected_value[2007:2000]);equalbyte(29,expected_value[1999:1992]);
 for(integer k=0;k<expected_value[2007:1992];k=k+1)
  equalbyte(30+k,expected_value[1991-8*k -:8]);
 if(raw_outputs!=256 || opens!=1 || closes!=1 || private_active_i || !job_ready_o)
  $fatal(1,"real private lifecycle mismatch");
 consume;passed=1;
 $display("CUSTOMER_PACKET_REAL_RSA_PASS checks=%0d raw_bytes=%0d closes=%0d cycles=%0d",checks,raw_outputs,closes,cycles);$finish;
end
initial begin #3000000000;$fatal(1,"overall watchdog");end
endmodule
