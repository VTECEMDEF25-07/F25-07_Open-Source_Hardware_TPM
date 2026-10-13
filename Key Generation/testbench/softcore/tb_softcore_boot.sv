`timescale 1ns/1ps
module tb_softcore_boot;
    reg clock=0; always #10 clock=~clock;
    reg reset_n=0, command_ready=0, response_valid=0;
    reg [7:0] response_status=0;
    wire ready,trap,command_valid,response_ready;
    wire [7:0] opcode;
    wire [31:0] arg0,arg1,arg2,arg3,report;
    integer i,run_number;
    keygen_softcore_control dut(.clock_i(clock),.reset_n_i(reset_n),.execute_en_i(1'b1),.instruction_progress_o(),
        .ready_o(ready),.trap_o(trap),.command_valid_o(command_valid),
        .command_ready_i(command_ready),.command_opcode_o(opcode),
        .command_arg0_o(arg0),.command_arg1_o(arg1),.command_arg2_o(arg2),.command_arg3_o(arg3),
        .response_valid_i(response_valid),.response_ready_o(response_ready),
        .response_status_i(response_status),.report_o(report));
    initial begin
        #1000000; $fatal(1,"TIMEOUT: boot self-test did not finish");
    end
    task apply_reset;
        begin
            @(negedge clock); reset_n=0; command_ready=0; response_valid=0;
            for (i=0;i<32;i=i+1) dut.cpu.cpuregs[i]=32'ha5000000+i;
            repeat(4) @(negedge clock);
            if (ready || command_valid || response_ready || report !== 0) $fatal(1,"reset interface invalidation");
            for (i=0;i<32;i=i+1) if (dut.cpu.cpuregs[i] !== 0) $fatal(1,"CPU register not cleared %0d",i);
            if (dut.cpu.reg_op1 !== 0 || dut.cpu.reg_op2 !== 0 || dut.cpu.reg_out !== 0 || dut.cpu.mem_rdata_q !== 0 || dut.cpu.mem_wdata !== 0 || dut.cpu.alu_out_q !== 0) $fatal(1,"CPU operand residue");
            for (i=0;i<4096;i=i+1) dut.ram_reg[i]=32'hdeadbeef;
            reset_n=1;
            repeat(4095) begin @(negedge clock); if(ready) $fatal(1,"early ready during scrub"); end
            @(negedge clock); if (!ready) $fatal(1,"scrub never completed");
            for (i=0;i<4096;i=i+1) if(dut.ram_reg[i] !== 0) $fatal(1,"RAM not scrubbed %0d",i);
        end
    endtask
    initial begin
        for(run_number=0;run_number<3;run_number=run_number+1) begin
            apply_reset();
            wait(command_valid); @(negedge clock);
            repeat(20) begin
                if (!command_valid || opcode !== 0 || arg0 !== 32 || arg1 !== 64 || arg2 !== 96 || arg3 !== 32) $fatal(1,"descriptor changed under stall");
                if(trap) $fatal(1,"CPU trapped");
                @(negedge clock);
            end
            command_ready=1; @(negedge clock); command_ready=0;
            if(command_valid) $fatal(1,"duplicate command");
            wait(response_ready);
            repeat(20) @(negedge clock);
            response_status=(run_number==2)?8'd7:8'd0;
            response_valid=1; @(negedge clock); response_valid=0;
            wait(report!=0); @(negedge clock);
            if(trap) $fatal(1,"CPU trap after response");
            if(report !== ((run_number==2)?32'hffffffff:32'h600d0001)) $fatal(1,"firmware report mismatch");
            repeat(40) begin @(negedge clock); if(command_valid) $fatal(1,"reissued command"); end
        end
        // Abort with a command pending: no descriptor survives reset.
        apply_reset(); wait(command_valid); apply_reset();
        $display("PASS softcore: RV32I boot, stalled descriptor, success/error response, RAM/register scrub, restart and pending-command reset");
        $finish;
    end
endmodule
