`timescale 1ns/1ps
// Actual RV32I SB/SH/SW/LBU/LHU/LW instructions exercise the shared RAM adapter.
module tb_softcore_memory;
 reg clock=0;always #10 clock=~clock;
 reg reset_n=0,valid=0,ack=0;
 reg saw_nonzero_latch=0;
 always @(posedge clock) if(dut.control.ram_read_valid &&
     (^dut.control.ram_read_data)!==1'bx && dut.control.ram_read_data!=0) saw_nonzero_latch=1;
 wire ready,done,cmd;wire [7:0] status;
 keygen_rsa_softcore #(.ROM_FILE("memory_selftest.hex")) dut(
 .clock_i(clock),.reset_n_i(reset_n),.work_valid_i(valid),.work_ready_o(ready),
 .completion_valid_o(done),.completion_ready_i(ack),.completion_status_o(status),
 .command_valid_o(cmd),.command_ready_i(1'b0),.command_opcode_o(),
 .command_arg0_o(),.command_arg1_o(),.command_arg2_o(),.command_arg3_o(),
 .response_valid_i(1'b0),.response_ready_o(),.response_status_i(8'd0));
 initial begin #1000000;$fatal(1,"memory firmware timeout");end
 task start_job;
 begin wait(ready);@(negedge clock);saw_nonzero_latch=0;valid=1;@(negedge clock);valid=0;end
 endtask
 task check_done;
 begin
 wait(done);#1;
 if(status!==0 || cmd) $fatal(1,"memory instruction self-test failed %d",status);
 if(!saw_nonzero_latch) $fatal(1,"test never created a stale nonzero RAM output");
 if(dut.control.ram_read_data!==0) $fatal(1,"RAM read latch retained data after cleanup");
 end
 endtask
 initial begin
 repeat(4) @(negedge clock);reset_n=1;
 start_job();wait(saw_nonzero_latch);
 // Abort while the macro output holds data, then require initialization to
 // clear that latch as well as the array before accepting another job.
 @(negedge clock);reset_n=0;repeat(4) @(negedge clock);reset_n=1;
 wait(ready);#1;
 if(dut.control.ram_read_data!==0 || done) $fatal(1,"reset recovery retained RAM output or completion");
 start_job();check_done();
 @(negedge clock);ack=1;@(negedge clock);ack=0;
 start_job();check_done();
 $display("PASS CPU memory: actual byte/halfword/word stores and loads, all byte lanes, stale RAM latch cleanup, reset recovery, repeat jobs");$finish;
 end
endmodule
