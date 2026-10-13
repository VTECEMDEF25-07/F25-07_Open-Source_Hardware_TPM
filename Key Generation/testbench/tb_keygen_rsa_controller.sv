`timescale 1ns/1ps
// Scripted service predicates validate control flow, not primality arithmetic.
// Expected descriptors follow docs/RSA_ALGORITHM.md and firmware/rsa_control.c.
// Real production retry/watchdog bounds are exercised; no force or small limits.
module tb_keygen_rsa_controller;
    reg clock_i=0; always #1 clock_i=~clock_i;
    reg reset_n_i=0,work_valid_i=0,completion_ready_i=0;
    wire work_ready_o,completion_valid_o;
    wire [7:0] completion_status_o;
    wire cmd_valid_o; reg cmd_ready_i=0;
    wire [7:0] cmd_op_o; wire [31:0] cmd_arg0_o,cmd_arg1_o,cmd_arg2_o,cmd_arg3_o;
    reg rsp_valid_i=0; wire rsp_ready_o; reg [7:0] rsp_status_i=0;
    integer descriptors=0, jobs=0;
    keygen_rsa_controller dut(.*);
    task automatic tick; @(posedge clock_i); #0.1; endtask
    task automatic reset;
        @(negedge clock_i);reset_n_i=0;work_valid_i=0;cmd_ready_i=0;
        rsp_valid_i=0;completion_ready_i=0;tick();
        if(cmd_valid_o || completion_valid_o || rsp_ready_o || work_ready_o) $fatal(1,"Reset gating");
        @(negedge clock_i);reset_n_i=1;tick();
        if(!work_ready_o) $fatal(1,"Reset readiness");
    endtask
    task automatic start;
        @(negedge clock_i);work_valid_i=1;tick();
        @(negedge clock_i);work_valid_i=0;
        jobs++;
    endtask
    task automatic accept(input [7:0] op,input [31:0] a,b,c,d);
        integer timeout;
        timeout=0;
        while(!cmd_valid_o) begin tick();timeout++;if(timeout>8) $fatal(1,"Missing command %h",op);end
        // Check all fields while backpressured, including simultaneous stray response.
        rsp_valid_i=1;rsp_status_i=8'hff;
        repeat(2) begin
            if({cmd_op_o,cmd_arg0_o,cmd_arg1_o,cmd_arg2_o,cmd_arg3_o} !== {op,a,b,c,d})
                $fatal(1,"Descriptor %0d: got %h %0d %0d %0d %0d expected %h %0d %0d %0d %0d",descriptors,cmd_op_o,cmd_arg0_o,cmd_arg1_o,cmd_arg2_o,cmd_arg3_o,op,a,b,c,d);
            if(rsp_ready_o) $fatal(1,"Response accepted before command");
            tick();
        end
        @(negedge clock_i);rsp_valid_i=0;cmd_ready_i=1;tick();
        @(negedge clock_i);cmd_ready_i=0;descriptors++;
        if(!rsp_ready_o) $fatal(1,"Missing response ready");
    endtask
    task automatic respond(input [7:0] status);
        @(negedge clock_i);rsp_valid_i=1;rsp_status_i=status;tick();
        @(negedge clock_i);rsp_valid_i=0;
    endtask
    task automatic command(input [7:0] op,input [31:0] a,b,c,d,input [7:0] status);
        accept(op,a,b,c,d);respond(status);
    endtask
    task automatic finish(input [7:0] status);
        integer timeout;
        timeout=0;
        while(!completion_valid_o) begin tick();timeout++;if(timeout>4)$fatal(1,"Missing completion");end
        // Fault completion is sticky; subsequent responses and jobs cannot overwrite it.
        rsp_valid_i=1;rsp_status_i=0;work_valid_i=1;
        repeat(4) begin
            if(!completion_valid_o || completion_status_o!==status || cmd_valid_o || work_ready_o || rsp_ready_o)
                $fatal(1,"Completion expected %0d got %0d",status,completion_status_o);
            tick();
        end
        @(negedge clock_i);rsp_valid_i=0;work_valid_i=0;completion_ready_i=1;tick();
        @(negedge clock_i);completion_ready_i=0;
        if(!work_ready_o || completion_valid_o || completion_status_o!=0)$fatal(1,"Completion release");
    endtask
    task automatic prepare(input bit q,input [7:0] status);
        command('h30,0,32,1,0,0);command('h31,0,32,64,{31'd0,q},status);
    endtask
    task automatic witness(input [7:0] check_status);
        command('h30,96,32,0,0,0);command('h32,96,0,0,0,check_status);
    endtask
    task automatic square(input [7:0] check_status);
        command('h13,352,128,320,1,0);command('h01,128,352,0,32,0);
        command('h33,0,0,0,0,check_status);
    endtask
    task automatic prime(input bit q,input bit exercise,input [7:0] copy_status=0);
        prepare(q,0);command('h11,0,512,32,0,0);
        for(integer r=0;r<5;r++) begin
            if(exercise && r==0) witness('h10);
            witness(0);command('h13,128,96,64,32,0);
            command('h33,1,0,0,0,(exercise && r==0)?8'h10:8'h00);
            if(exercise && r==0) begin square('h10);square(0);end
        end
        command('h01,q?192:160,0,0,32,copy_status);
    endtask
    initial begin
        reset();start();
        prepare(0,'h10);prepare(0,'h11); // non-counting redraw predicates
        prime(0,1);prime(1,1);command('h34,0,0,0,0,'h10); // low d restarts both
        prime(0,0);prime(1,0);command('h34,0,0,0,0,0);finish(0);
        $display("PASS sequence: five rounds, witness redraw, square/copy, low-d pair restart");
        // Actual p bound: mix a Miller-Rabin composite with prefilter failures.
        start();prepare(0,0);command('h11,0,512,32,0,0);witness(0);
        command('h13,128,96,64,32,0);command('h33,1,0,0,0,'h10);square('h11);
        for(integer i=1;i<10240;i++) begin
            if(i==10239) begin prepare(0,'h10);prepare(0,'h11);end
            prepare(0,'h12);
        end
        finish(3);$display("PASS actual p retry bound 10240 with non-counting redraws");
        start();
        // A prior p rejection must not reduce q's independent limit.
        prepare(0,'h12);prime(0,0);
        for(integer i=0;i<20480;i++) begin
            if(i==20479) begin prepare(1,'h10);prepare(1,'h11);end
            prepare(1,'h12);
        end
        finish(3);$display("PASS actual q retry bound 20480 independent of p");
        // Source and arithmetic faults retain first terminal status.
        start();command('h30,0,32,1,0,2);finish(2);
        start();prepare(0,4);finish(4);
        start();prepare(0,0);command('h11,0,512,32,0,4);finish(4);
        start();prepare(0,0);command('h11,0,512,32,0,0);command('h30,96,32,0,0,2);finish(2);
        start();prepare(0,0);command('h11,0,512,32,0,0);witness(4);finish(4);
        start();prepare(0,0);command('h11,0,512,32,0,0);witness(0);command('h13,128,96,64,32,4);finish(4);
        start();prepare(0,0);command('h11,0,512,32,0,0);witness(0);command('h13,128,96,64,32,0);command('h33,1,0,0,0,4);finish(4);
        start();prime(0,0);prime(1,0);command('h34,0,0,0,0,4);finish(4);
        start();prepare(0,0);command('h11,0,512,32,0,0);witness(0);
        command('h13,128,96,64,32,0);command('h33,1,0,0,0,'h10);
        command('h13,352,128,320,1,4);finish(4);
        start();prepare(0,0);command('h11,0,512,32,0,0);witness(0);
        command('h13,128,96,64,32,0);command('h33,1,0,0,0,'h10);
        command('h13,352,128,320,1,0);command('h01,128,352,0,32,4);finish(4);
        start();prime(0,0,4);finish(4);
        // Reset aborts both SEND and WAIT_RESPONSE with no stale completion.
        start();reset();start();accept('h30,0,32,1,0);reset();
        start();command('h30,0,32,1,0,0);accept('h31,0,32,64,0);reset();
        $display("PASS source/arithmetic fault mapping, sticky completion, reset, backpressure");
        // DRAW is excluded from internal watchdog even beyond the real bound.
        start();accept('h30,0,32,1,0);
        repeat(50000001) tick();
        if(completion_valid_o || !rsp_ready_o)$fatal(1,"External draw incorrectly timed out");
        respond(0);accept('h31,0,32,64,0);
        repeat(49999999) tick();
        if(completion_valid_o || !rsp_ready_o)$fatal(1,"Watchdog fired early");
        tick();finish(7);
        $display("PASS actual 50000000-cycle watchdog, external DRAW excluded");
        // On the exact expiry edge a valid service response has priority.
        start();command('h30,0,32,1,0,0);accept('h31,0,32,64,0);
        repeat(49999999) tick();respond(4);finish(4);
        $display("PASS response fault priority at watchdog boundary");
        start();command('h30,0,32,1,0,0);
        // PREPARE command is presented but its ready input never rises.
        repeat(49999999) tick();
        if(completion_valid_o || !cmd_valid_o)$fatal(1,"SEND watchdog fired early");
        tick();finish(7);
        $display("PASS actual internal command-ready watchdog");
        $display("PASS RSA controller: %0d descriptors, %0d jobs",descriptors,jobs);$finish;
    end
endmodule
