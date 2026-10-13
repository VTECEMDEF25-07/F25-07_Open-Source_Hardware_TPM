`timescale 1ns/1ps
// Scripted service peer validates CPU control flow only, not RSA arithmetic.
module tb_rsa_firmware;
    reg clock=0; always #10 clock=~clock;
    reg reset_n=0,work_valid=0,completion_ready=0,command_ready=0,response_valid=0;
    reg [7:0] response_status=0;
    wire work_ready,completion_valid,command_valid,response_ready;
    wire [7:0] completion_status,opcode;
    wire [31:0] arg0,arg1,arg2,arg3;
    integer command_count=0,i;
    reg [31:0] saved_instruction;
    keygen_rsa_softcore #(.WATCHDOG_BITS(10)) dut(
        .clock_i(clock),.reset_n_i(reset_n),.work_valid_i(work_valid),.work_ready_o(work_ready),
        .completion_valid_o(completion_valid),.completion_ready_i(completion_ready),.completion_status_o(completion_status),
        .command_valid_o(command_valid),.command_ready_i(command_ready),.command_opcode_o(opcode),
        .command_arg0_o(arg0),.command_arg1_o(arg1),.command_arg2_o(arg2),.command_arg3_o(arg3),
        .response_valid_i(response_valid),.response_ready_o(response_ready),.response_status_i(response_status));
    initial begin #100000000; $fatal(1,"TIMEOUT firmware controller"); end
    task start_job;
        begin
            wait(work_ready); @(negedge clock); work_valid=1;
            @(negedge clock); work_valid=0;
        end
    endtask
    task expect_command(input [7:0] op,input [31:0] a,b,c,d,input [7:0] response);
        begin
            wait(command_valid); @(negedge clock);
            repeat(3) begin
                if(opcode!==op || arg0!==a || arg1!==b || arg2!==c || arg3!==d)
                    $fatal(1,"command %0d actual=%h %d %d %d %d expected=%h %d %d %d %d",command_count,opcode,arg0,arg1,arg2,arg3,op,a,b,c,d);
                @(negedge clock);
            end
            command_ready=1; @(negedge clock); command_ready=0;
            wait(response_ready); repeat(5) @(negedge clock);
            response_status=response;response_valid=1;@(negedge clock);response_valid=0;
            command_count=command_count+1;
        end
    endtask
    task prime(input integer q_mode,input integer inject_rejects);
        integer round;
        begin
            if(inject_rejects) begin
                expect_command('h30,0,32,1,0,0);
                expect_command('h31,0,32,64,q_mode,q_mode ? 'h11 : 'h10);
                if(!q_mode) begin
                    expect_command('h30,0,32,1,0,0);expect_command('h31,0,32,64,0,'h12);
                end
            end
            expect_command('h30,0,32,1,0,0);expect_command('h31,0,32,64,q_mode,0);
            expect_command('h11,0,512,32,0,0);
            for(round=0;round<5;round=round+1) begin
                if(round==0 && inject_rejects) begin
                    expect_command('h30,96,32,0,0,0);expect_command('h32,96,0,0,0,'h10);
                end
                expect_command('h30,96,32,0,0,0);expect_command('h32,96,0,0,0,0);
                expect_command('h13,128,96,64,32,0);
                expect_command('h33,1,0,0,0,(round==0 && inject_rejects)?'h10:0);
                if(round==0 && inject_rejects) begin
                    expect_command('h13,352,128,320,1,0);expect_command('h01,128,352,0,32,0);
                    expect_command('h33,0,0,0,0,0);
                end
            end
            expect_command('h01,q_mode?192:160,0,0,32,0);
        end
    endtask
    task check_completion(input [7:0] expected);
        begin
            wait(completion_valid);@(negedge clock);
            if(completion_status!==expected) $fatal(1,"completion %d expected %d",completion_status,expected);
            for(i=0;i<4096;i=i+1) if(dut.control.ram_reg[i]!==0) $fatal(1,"post-job RAM residue");
            for(i=0;i<32;i=i+1) if(dut.control.cpu.cpuregs[i]!==0) $fatal(1,"post-job CPU residue");
            repeat(20) begin
                @(negedge clock);
                if(!completion_valid || completion_status!==expected || work_ready || command_valid) $fatal(1,"held completion protocol");
            end
            completion_ready=1;@(negedge clock);completion_ready=0;
        end
    endtask
    initial begin
        repeat(4) @(negedge clock);reset_n=1;
        start_job();
        prime(0,1);prime(1,1);expect_command('h34,0,0,0,0,'h10);
        prime(0,0);prime(1,0);expect_command('h34,0,0,0,0,0);
        check_completion(0);
        start_job();expect_command('h30,0,32,1,0,1);check_completion(2);
        start_job();expect_command('h30,0,32,1,0,0);expect_command('h31,0,32,64,0,1);check_completion(4);
        // External response stall must not trip the instruction-progress watchdog.
        start_job();wait(command_valid);repeat(3000) @(negedge clock);
        if(completion_valid) $fatal(1,"watchdog treated service wait as failure");
        reset_n=0;repeat(4) @(negedge clock);reset_n=1;
        wait(work_ready);if(completion_valid || command_valid) $fatal(1,"abort produced stale completion");
        // Real illegal instruction causes CPU trap.
        saved_instruction=dut.control.rom_reg[0];dut.control.rom_reg[0]=32'hffffffff;
        start_job();check_completion(6);dut.control.rom_reg[0]=saved_instruction;
        // Stall instruction fetch, then require watchdog recovery and cleanup.
        start_job();wait(command_valid);force dut.control.memory_valid=0;
        wait(completion_valid);release dut.control.memory_valid;check_completion(7);
        start_job();expect_command('h30,0,32,1,0,1);check_completion(2);
        $display("PASS RSA firmware control: %0d descriptors, reject/retry/square/low-d restart, faults, watchdog, reset, post-job CPU/RAM scrub",command_count);
        $finish;
    end
endmodule
