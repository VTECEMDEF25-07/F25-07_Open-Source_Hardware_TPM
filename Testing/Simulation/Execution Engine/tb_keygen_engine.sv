`timescale 1ns/1ps
// Exercise the actual engine-owned lifecycle and GetRandom reservation wiring.
module tb_keygen_engine;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,kg_request=0,host_start=0,kg_ack=0,kg_release=0;
 reg [7:0] private_address=0;
 wire kg_ready,kg_done,kg_valid;wire [31:0] private_data;wire [3:0] kg_code;
 wire [11:0] command_address;reg [7:0] command_byte;reg [7:0] packet[0:11];
 wire response_valid;wire [31:0] response_code;wire [15:0] response_length;
 reg [11:0] response_address=0;wire [7:0] response_byte;
 wire random_request,timeout;reg random_valid=0,fault=0;
 reg [255:0] random_data=0;integer blocks=0,delay_count=0;
 reg passed=0;reg ownership=0;reg [1:0] kg_profile=0;
 always @(posedge clk) command_byte<=packet[command_address];
 execution_engine #(.ENABLE_HASH_COMMAND(1),.ENABLE_GETRANDOM(1),.ENABLE_INTERNAL_KEYGEN(1),.GETRANDOM_WAIT_LIMIT(200)) dut (
  .clock_i(clk),.reset_n_i(rst),.command_ready_i(host_start),.command_done_i(1'b1),
  .command_tag_i(16'h8001),.command_code_i(32'h17b),.command_size_i(32'd12),.op_state_i(3'd3),
  .command_addr_o(command_address),.command_byte_i(command_byte),
  .response_addr_i(response_address),.response_byte_o(response_byte),
  .response_valid_o(response_valid),.response_code_o(response_code),.response_length_o(response_length),
  .random_i(random_data),.random_valid_i(random_valid),.random_request_o(random_request),.rng_fault_i(fault),.rng_timeout_o(timeout),
  .hash_grant_i(1'b0),.hash_ready_i(1'b0),.hash_digest_i(256'd0),.hash_digest_valid_i(1'b0),
  .keygen_request_i(kg_request),.keygen_ready_o(kg_ready),.keygen_profile_i(kg_profile),.keygen_id_i(32'd42),.keygen_allow_i(1'b1),
  .keygen_completion_o(kg_done),.keygen_completion_ready_i(kg_ack),.keygen_code_o(kg_code),.keygen_release_i(kg_release),
  .keygen_slot_valid_o(kg_valid),.keygen_private_address_i(private_address),.keygen_private_data_o(private_data),
  .keygen_result_enable_i(1'b1),.keygen_ownership_enable_i(ownership),.keygen_terminal_enable_i(1'b1));
 always @(posedge clk) begin
  random_valid<=0;
  if(!rst) begin blocks<=0;delay_count<=0;end
  else if(random_request) begin
   if(delay_count==4) begin
    for(integer j=0;j<8;j=j+1) random_data[255-32*j -:32]<=32'h01020300+blocks*8+j;
    blocks<=blocks+1;random_valid<=1;delay_count<=0;
   end else delay_count<=delay_count+1;
  end else delay_count<=0;
  if(rst && !kg_valid && private_data!==0) $fatal(1,"engine private visibility");
 end
 initial begin
  {packet[0],packet[1],packet[2],packet[3],packet[4],packet[5],packet[6],packet[7],packet[8],packet[9],packet[10],packet[11]}=
   {16'h8001,32'd12,32'h17b,16'd32};
  repeat(3)@(negedge clk);rst=1;wait(kg_ready);@(negedge clk);kg_request=1;@(negedge clk);kg_request=0;
  wait(dut.keygen_enabled.protected_keygen.ownership_ready);
  @(negedge clk);host_start=1;@(negedge clk);host_start=0;
  wait(dut.host_wait);repeat(300)@(negedge clk);
  if(timeout || response_valid || blocks!=1 || kg_valid) $fatal(1,"held host stole reservation or timed out");
  ownership=1;wait(kg_done);#1;
  if(kg_code!=0 || !kg_valid) $fatal(1,"engine failed publication");
  for(integer j=0;j<4;j=j+1) begin private_address=j;#1;if(private_data!==32'h01020300+j) $fatal(1,"engine slot order");end
  wait(response_valid);#1;
  if(response_code!=0 || response_length!=44 || blocks!=2) $fatal(1,"held GetRandom did not resume");
  for(integer j=0;j<32;j=j+1) begin
   response_address=j+2;#1;
   if(response_byte!==((32'h01020308+j/4)>>(24-8*(j%4)) & 255)) $fatal(1,"cross-client residual reuse");
  end
  // A withdrawn busy request must not queue behind the occupied slot.
  @(negedge clk);kg_profile=3;kg_request=1;@(negedge clk);kg_request=0;
  // Release and generate again without reset. The next AES256 must use
  // the third whole block, not AES128 residuals or GetRandom's block.
  @(negedge clk);kg_ack=1;@(negedge clk);kg_ack=0;kg_release=1;
  @(negedge clk);kg_release=0;wait(kg_ready);
  if(kg_valid || private_data!=0) $fatal(1,"first release did not clear visibility");
  repeat(3)@(negedge clk);
  if(!kg_ready || kg_done || kg_valid || blocks!=2) $fatal(1,"withdrawn busy request queued work");
  @(negedge clk);kg_profile=1;kg_request=1;@(negedge clk);kg_request=0;
  wait(kg_done);#1;
  if(kg_code!=0 || !kg_valid || blocks!=3) $fatal(1,"reuse did not complete with a new block");
  for(integer j=0;j<8;j=j+1) begin
   private_address=j;#1;if(private_data!==32'h01020310+j) $fatal(1,"stale residual/context on reuse");
  end
  // The worker's REPLY eligibility edge has passed; future entropy failure
  // must not retroactively rewrite its committed response or a valid slot.
  @(negedge clk);fault=1;repeat(5)@(negedge clk);
  if(response_code!=0 || !kg_valid) $fatal(1,"postcommit fault rewrote committed result");
  kg_ack=1;@(negedge clk);kg_ack=0;kg_release=1;@(negedge clk);kg_release=0;
  wait(kg_ready);if(kg_valid || private_data!=0) $fatal(1,"engine release");
  passed=1;$display("KEYGEN_ENGINE_RESERVATION_HOST_ELIGIBILITY_PASS blocks=%0d",blocks);$finish;
 end
 initial begin #2000000;$fatal(1,"engine test deadline");end
endmodule
