`timescale 1ns/1ps
module tb_getrandom_engine;
 reg clk=0; always #5 clk=~clk;
 reg reset_n=0, start=0, random_valid=0, fault=0;
 reg [31:0] code=32'h17b, size=12;
 reg [15:0] tag=16'h8001;
 reg [7:0] packet[0:13], command_byte;
 reg [11:0] response_addr=0;
 wire [11:0] command_addr;
 wire [7:0] response_byte;
 wire [31:0] rc;
 wire [15:0] length;
 wire [3:0] state;
 wire ready, request, timeout;
 reg passed=0;
 localparam [255:0] BLOCK=256'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f;
 always @(posedge clk) command_byte<=packet[command_addr];
 execution_engine #(.ENABLE_HASH_COMMAND(1),.ENABLE_GETRANDOM(1),.GETRANDOM_WAIT_LIMIT(100)) dut (
  .clock_i(clk),.reset_n_i(reset_n),.command_ready_i(start),.command_done_i(1'b1),
  .command_tag_i(tag),.command_code_i(code),.command_size_i(size),.op_state_i(3'd3),
  .command_addr_o(command_addr),.command_byte_i(command_byte),
  .response_addr_i(response_addr),.response_byte_o(response_byte),
  .response_valid_o(ready),.response_code_o(rc),.response_length_o(length),.current_state_o(state),
  .random_i(BLOCK),.random_valid_i(random_valid),.random_request_o(request),
  .rng_fault_i(fault),.rng_timeout_o(timeout),.hash_grant_i(1'b0),.hash_ready_i(1'b0),
  .hash_digest_i(256'd0),.hash_digest_valid_i(1'b0));
 task make_packet;
 begin
  tag=16'h8001; code=32'h17b; size=12;
  {packet[0],packet[1],packet[2],packet[3],packet[4],packet[5],packet[6],packet[7],packet[8],packet[9],packet[10],packet[11]}=
   {16'h8001,32'd12,32'h17b,16'd32};
 end endtask
 task launch;
 begin @(negedge clk); start=1; @(negedge clk); start=0; end endtask
 task check(input [31:0] expected,input integer count);
 begin
  wait(ready); @(negedge clk);
  if(rc!==expected || length!==count || state!=9 || !dut.random_active)
   $fatal(1,"Engine reply rc=%h length=%d state=%d",rc,length,state);
  if(expected==0) begin
   response_addr=0; #1; if(response_byte!==0) $fatal(1,"size MSB");
   response_addr=1; #1; if(response_byte!==32) $fatal(1,"size LSB");
   for(integer n=0;n<32;n=n+1) begin
    response_addr=2+n; #1;
    if(response_byte!==BLOCK[255-8*n -:8]) $fatal(1,"payload byte order %d",n);
   end
  end
  repeat(5) @(negedge clk);
 end endtask
 initial begin
  make_packet(); repeat(3) @(negedge clk); reset_n=1;
  launch(); wait(request);
  // A second ready and changed external metadata must not steal ownership.
  @(negedge clk); start=1; code=32'h17d; size=1; tag=0;
  repeat(2) @(negedge clk); start=0; random_valid=1;
  @(negedge clk); random_valid=0;
  check(0,44);
  make_packet(); packet[5]=13; launch(); check(32'h142,10);
  make_packet(); size=14; launch(); check(32'h142,10);
  make_packet(); launch(); check(32'h101,10);
  if(!timeout) $fatal(1,"Missing bounded wait fault");
  reset_n=0; repeat(3) @(negedge clk); reset_n=1;
  make_packet(); launch(); wait(request);
  reset_n=0; repeat(3) @(negedge clk);
  if(ready || request || timeout) $fatal(1,"Reset left stale transaction");
  reset_n=1; make_packet(); launch(); wait(request);
  @(negedge clk); random_valid=1; @(negedge clk); random_valid=0;
  check(0,44);
  // Fault during reply collection must revoke success before publication.
  make_packet(); launch(); wait(request);
  @(negedge clk); random_valid=1; @(negedge clk); random_valid=0;
  wait(dut.random_command.received==15); @(negedge clk); fault=1;
  check(32'h101,10);
  passed=1; $display("GETRANDOM_ENGINE_OWNER_TIMEOUT_RESET_PASS"); $finish;
 end
 initial begin #200000; $fatal(1,"Engine test timeout"); end
endmodule
