// Public memory model and independent Python-vector checks. No FPGA access.
`timescale 1ns/1ps
module tb_demo_modexp_adapter #(
    parameter WIDTH=32,
    parameter JOB_LIMIT=50000000,
    parameter CLEAN_LIMIT=4096
);
    localparam B=WIDTH/8;
    reg clock=0;
    always #5 clock=~clock;
    reg reset_n=0, job_valid=0, status_ready=0;
    wire job_ready, status_valid, recovery;
    reg [31:0] job_id=0;
    reg [11:0] base_addr=0, exponent_addr=B, modulus_addr=2*B, result_addr=3*B;
    reg [15:0] operand_bytes=B;
    wire req_valid, req_write, rsp_ready;
    wire [11:0] req_addr;
    wire [7:0] req_wdata;
    reg rsp_valid=0, rsp_error=0;
    reg [7:0] rsp_data=0;
    wire [31:0] status_id, status_cycles;
    wire [3:0] status_code;
    wire [15:0] status_bytes;
    reg [7:0] memory[0:1023];
    reg pending=0, pending_error=0;
    reg [7:0] pending_data=0;
    integer delay_count=0, requests=0, passes=0, mode=0, vector_count=0;
    reg [31:0] random_state=32'hde259031;
    reg stalls=1, block_requests=0, block_responses=0, fail_next=0, fail_all=0;
    reg request_stalled=0;
    reg [20:0] held_request=0;
    wire req_ready=reset_n && !pending && !rsp_valid && !block_requests &&
                   (!stalls || random_state[0]);
    demo_modexp_adapter #(.WIDTH(WIDTH), .JOB_DEADLINE_CYCLES(JOB_LIMIT),
        .CLEANUP_DEADLINE_CYCLES(CLEAN_LIMIT)) dut (
        .clock_i(clock), .reset_n_i(reset_n), .job_valid_i(job_valid),
        .job_ready_o(job_ready), .job_id_i(job_id), .base_addr_i(base_addr),
        .exponent_addr_i(exponent_addr), .modulus_addr_i(modulus_addr),
        .result_addr_i(result_addr), .operand_bytes_i(operand_bytes),
        .ram_req_valid_o(req_valid), .ram_req_ready_i(req_ready),
        .ram_req_write_o(req_write), .ram_req_addr_o(req_addr), .ram_req_wdata_o(req_wdata),
        .ram_rsp_valid_i(rsp_valid), .ram_rsp_ready_o(rsp_ready),
        .ram_rsp_rdata_i(rsp_data), .ram_rsp_error_i(rsp_error),
        .status_valid_o(status_valid), .status_ready_i(status_ready),
        .status_id_o(status_id), .status_code_o(status_code),
        .status_result_bytes_o(status_bytes), .status_cycles_o(status_cycles),
        .recovery_required_o(recovery)
    );

    always @(posedge clock) begin
        if (!reset_n) begin
            pending<=0; rsp_valid<=0; rsp_data<=0; rsp_error<=0;
            delay_count<=0; fail_next<=0;
            request_stalled<=0;
        end else begin
            if (request_stalled && !dut.cleanup_reg && !dut.job_expired && !recovery &&
                (!req_valid || {req_write,req_addr,req_wdata}!==held_request))
                $fatal(1,"RAM request payload changed while stalled");
            request_stalled<=req_valid && !req_ready;
            held_request<={req_write,req_addr,req_wdata};
            random_state<={random_state[30:0],random_state[31]^random_state[21]^random_state[1]^random_state[0]};
            if (req_valid && req_ready) begin
                if (pending || rsp_valid) $fatal(1,"more than one outstanding RAM request");
                pending<=1; delay_count<=stalls ? {30'd0,random_state[3:2]} : 0;
                pending_error<=fail_next || fail_all || req_addr>=1024;
                pending_data<=0;
                if (!(fail_next || fail_all || req_addr>=1024)) begin
                    if (req_write) memory[req_addr]<=req_wdata;
                    else pending_data<=memory[req_addr];
                end
                fail_next<=0; requests<=requests+1;
            end
            if (pending && !block_responses) begin
                if (delay_count==0) begin
                    rsp_valid<=1; rsp_data<=pending_data; rsp_error<=pending_error; pending<=0;
                end else delay_count<=delay_count-1;
            end
            if (rsp_valid && rsp_ready) begin rsp_valid<=0; rsp_data<=0; rsp_error<=0; end
        end
    end

    task automatic reset_job;
        begin
            @(negedge clock); reset_n=0; job_valid=0; status_ready=0;
            block_requests=0; block_responses=0; fail_next=0; fail_all=0;
            repeat(3) @(negedge clock);
            if (job_ready || status_valid || req_valid || rsp_ready) $fatal(1,"transfer during reset");
            reset_n=1;
            repeat(5) @(negedge clock);
            if (!job_ready || recovery || status_valid) $fatal(1,"reset failed to readmit");
            base_addr=0; exponent_addr=B; modulus_addr=2*B; result_addr=3*B; operand_bytes=B;
        end
    endtask

    task automatic fill_operands(input reg [WIDTH-1:0] a,e,n);
        integer j;
        begin
            for (j=0;j<B;j=j+1) begin
                memory[j]=a[WIDTH-1-8*j -:8];
                memory[B+j]=e[WIDTH-1-8*j -:8];
                memory[2*B+j]=n[WIDTH-1-8*j -:8];
                memory[3*B+j]=8'ha5;
            end
        end
    endtask

    task automatic launch;
        begin
            while (!job_ready) @(negedge clock);
            job_id=32'hdead0025; job_valid=1;
            @(negedge clock); job_valid=0;
            // Live inputs deliberately change after admission: descriptor is captured.
            job_id=32'hbadbadba; base_addr=4095; exponent_addr=4094;
            modulus_addr=4093; result_addr=4092; operand_bytes=0;
        end
    endtask

    task automatic assert_local_zero;
        begin
            if (dut.base_reg!==0 || dut.exponent_reg!==0 || dut.modulus_reg!==0 ||
                dut.arithmetic.base_reg!==0 || dut.arithmetic.exponent_reg!==0 ||
                dut.arithmetic.n_reg!==0 || dut.arithmetic.precompute_reg!==0 ||
                dut.arithmetic.r_mod_n_reg!==0 || dut.arithmetic.r_squared_mod_n_reg!==0 ||
                dut.arithmetic.base_mont_reg!==0 || dut.arithmetic.accumulator_reg!==0 ||
                dut.arithmetic.square_reg!==0 || dut.arithmetic.result_o!==0 ||
                dut.arithmetic.montgomery_core.a_reg!==0 || dut.arithmetic.montgomery_core.b_reg!==0 ||
                dut.arithmetic.montgomery_core.n_reg!==0 || dut.arithmetic.montgomery_core.t_reg!==0 ||
                dut.arithmetic.montgomery_core.intermediate_reg!==0 ||
                dut.arithmetic.montgomery_core.result_o!==0)
                $fatal(1,"local arithmetic/assembly storage not cleared");
        end
    endtask

    task automatic finish_check(input integer code, input reg [WIDTH-1:0] expected,
                               input integer need_recovery, input integer check_destination);
        integer j,t;
        reg [31:0] count;
        begin
            t=0;
            while (!status_valid && t<JOB_LIMIT+CLEAN_LIMIT+100) begin
                @(negedge clock); t=t+1;
            end
            if (!status_valid) $fatal(1,"terminal timeout");
            if (status_code!==code || status_id!==32'hdead0025 ||
                status_bytes!==((code==0)?B:0) || recovery!==need_recovery)
                $fatal(1,"status mismatch got code=%0d id=%h bytes=%0d recovery=%0d expected=%0d/%0d",
                    status_code,status_id,status_bytes,recovery,code,need_recovery);
            assert_local_zero();
            if (check_destination) begin
                for(j=0;j<B;j=j+1)
                    if(memory[3*B+j]!==expected[WIDTH-1-8*j -:8])
                        $fatal(1,"destination mismatch byte %0d got %h expected %h",j,
                            memory[3*B+j],expected[WIDTH-1-8*j -:8]);
            end
            count=status_cycles;
            repeat(7) begin
                @(negedge clock);
                if (!status_valid || job_ready || req_valid || status_cycles!==count ||
                    status_id!==32'hdead0025 || status_code!==code)
                    $fatal(1,"held status/readmission violation");
            end
            $display("PASS width=%0d code=%0d cycles=%0d requests=%0d recovery=%0d",WIDTH,code,count,requests,recovery);
            status_ready=1; @(negedge clock); status_ready=0;
            if(status_valid) $fatal(1,"duplicate terminal after acceptance");
            if(need_recovery) begin
                repeat(5) @(negedge clock);
                if(job_ready || status_valid) $fatal(1,"fault readmitted without reset");
            end else if(!job_ready) $fatal(1,"normal completion did not readmit");
            passes=passes+1;
            base_addr=0; exponent_addr=B; modulus_addr=2*B; result_addr=3*B; operand_bytes=B;
        end
    endtask

    integer fd, scan, j, before_count;
    reg [WIDTH-1:0] va,ve,vn,vy;
    initial begin
        if (!$value$plusargs("mode=%d",mode)) mode=0;
        for(j=0;j<1024;j=j+1) memory[j]=8'h77;
        reset_job();
        if(mode==0) begin
            fd=$fopen("vectors.txt","r");
            if(!fd) $fatal(1,"missing independent vectors");
            scan=$fscanf(fd,"%h %h %h %h\n",va,ve,vn,vy);
            while(scan==4) begin
                fill_operands(va,ve,vn); launch();
                if(vector_count==0) begin
                    wait(dut.state_reg==10); @(negedge clock); job_valid=1;
                    repeat(3) @(negedge clock);
                    if(job_ready) $fatal(1,"accepted job while busy");
                    job_valid=0;
                end
                finish_check(0,vy,0,1);
                vector_count=vector_count+1;
                scan=$fscanf(fd,"%h %h %h %h\n",va,ve,vn,vy);
            end
            $fclose(fd);
            if(vector_count<6) $fatal(1,"insufficient independent vectors");
            // Core invalid operands: n=0/1/even and base>=n, followed by repeat.
            fill_operands(2,3,0); launch(); finish_check(2,0,0,1);
            fill_operands(0,3,1); launch(); finish_check(2,0,0,1);
            fill_operands(2,3,18); launch(); finish_check(2,0,0,1);
            fill_operands(19,3,19); launch(); finish_check(2,0,0,1);
            // Descriptor rejection must not even clear a previous destination.
            before_count=requests; operand_bytes=B-1; launch(); finish_check(1,0,0,0);
            if(requests!=before_count) $fatal(1,"invalid size accessed memory");
            before_count=requests; result_addr=1023; launch(); finish_check(1,0,0,0);
            if(requests!=before_count) $fatal(1,"out-of-range descriptor accessed memory");
            before_count=requests; result_addr=B; launch(); finish_check(1,0,0,0);
            if(requests!=before_count) $fatal(1,"overlap descriptor accessed memory");
            // Transient and persistent RAM faults both require coordinated reset.
            fill_operands(2,3,19); fail_next=1; launch(); finish_check(3,0,1,1);
            reset_job(); fill_operands(2,3,19); fail_all=1;
            launch(); finish_check(3,0,1,0); reset_job();
            fill_operands(2,3,19); launch(); wait(dut.state_reg==7);
            @(negedge clock); fail_next=1; finish_check(3,0,1,1); reset_job();
            fill_operands(2,3,19); launch();
            wait(dut.state_reg==11 && dut.byte_index_reg==B-1);
            @(negedge clock); fail_next=1; finish_check(3,0,1,1); reset_job();
            // Reset while load response is pending, during compute and while result
            // writes are pending. Each reset is followed by a complete valid job.
            fill_operands(2,3,19); launch(); wait(dut.state_reg==8); reset_job();
            fill_operands(2,3,19); launch(); wait(dut.state_reg==10); reset_job();
            fill_operands(2,3,19); launch(); wait(dut.state_reg==12); reset_job();
            fill_operands(2,3,19); launch(); wait(dut.state_reg==15); reset_job();
            fill_operands(2,3,19); launch(); finish_check(0,8,0,1);
        end else if(mode==1) begin
            // Real parameterized short deadline expires during computation.
            fill_operands(2,3,19); launch(); finish_check(4,0,0,1);
            reset_job(); fill_operands(2,3,19); launch(); finish_check(4,0,0,1);
        end else if(mode==2) begin
            // Lost accepted response must not be mistaken for scrub acknowledgment.
            fill_operands(2,3,19); block_responses=1; launch();
            finish_check(4,0,1,0); reset_job();
        end else if(mode==3) begin
            // Deadline while request is unaccepted; cleanup also cannot proceed.
            fill_operands(2,3,19); block_requests=1; launch();
            finish_check(4,0,1,0); reset_job();
        end else if(mode==4) begin
            // Deadline with accepted delayed response, then drain and scrub succeed.
            fill_operands(2,3,19); block_responses=1; launch();
            wait(dut.state_reg==14); @(negedge clock); block_responses=0;
            finish_check(4,0,0,1);
        end
        $display("ALL DEMO MODEXP ADAPTER TESTS PASSED width=%0d mode=%0d cases=%0d vectors=%0d",WIDTH,mode,passes,vector_count);
        $finish;
    end
endmodule
