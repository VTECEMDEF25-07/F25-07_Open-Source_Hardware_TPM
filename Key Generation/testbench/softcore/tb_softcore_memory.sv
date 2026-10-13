`timescale 1ns/1ps
// Actual RV32I SB/SH/SW/LBU/LHU/LW instructions exercise the shared RAM adapter.
module tb_softcore_memory;
 reg clock=0;always #10 clock=~clock;
 reg reset_n=0,valid=0,ack=0;
 wire ready,done,cmd;wire [7:0] status;
 keygen_rsa_softcore #(.ROM_FILE("memory_selftest.hex")) dut(
 .clock_i(clock),.reset_n_i(reset_n),.work_valid_i(valid),.work_ready_o(ready),
 .completion_valid_o(done),.completion_ready_i(ack),.completion_status_o(status),
 .command_valid_o(cmd),.command_ready_i(1'b0),.command_opcode_o(),
 .command_arg0_o(),.command_arg1_o(),.command_arg2_o(),.command_arg3_o(),
 .response_valid_i(1'b0),.response_ready_o(),.response_status_i(8'd0));
 initial begin #1000000;$fatal(1,"memory firmware timeout");end
 initial begin
 repeat(4) @(negedge clock);reset_n=1;
 wait(ready);@(negedge clock);valid=1;@(negedge clock);valid=0;
 wait(done);if(status!==0 || cmd) $fatal(1,"memory instruction self-test failed %d",status);
 $display("PASS CPU memory: actual byte/halfword/word stores and loads, all byte lanes, cleanup completion");$finish;
 end
endmodule
