`timescale 1ns/1ps
module tb_customer_aes_worker;
    reg clock_i=0;always #10 clock_i=~clock_i;
    reg reset_n_i=0,job_valid_i=0,input_valid_i=0,output_ready_i=0,status_ready_i=0;
    reg [255:0] job_key_i=0;
    reg [127:0] job_iv_i=0;
    reg [15:0] job_bytes_i=0;
    reg [7:0] input_data_i=0;
    wire job_ready_o,input_ready_o,output_valid_o,status_valid_o,busy_o,scrub_done_o,recovery_required_o;
    wire [7:0] output_data_o;
    wire [31:0] status_code_o;
    wire [15:0] status_result_bytes_o;
    wire [127:0] status_iv_o;
    wire [63:0] status_cycles_o;
    customer_aes_worker #(.JOB_DEADLINE_CYCLES(64'd100000)) dut(.*);
    reg [7:0] ciphertext[0:1023],plaintext[0:1023];
    integer count=0,total_bytes=0,out_count=0,ticks=0,edge_count=0,started=0;
    integer fd,scan,n,i;
    reg [255:0] key;
    reg [127:0] iv,feedback;
    reg [7:0] held_byte;
    bit held=0,successfully_completed=0,checking=0,was_status=0;
    string path;
    always @(posedge clock_i)begin
        edge_count=edge_count+1;
        if(reset_n_i && job_valid_i && job_ready_o)started=edge_count;
        if(reset_n_i && output_valid_o)begin
            if(held && output_data_o!==held_byte)$fatal(1,"plaintext changed under stall");
            if(checking && output_ready_i)begin
                if(out_count>=n || output_data_o!==plaintext[out_count])$fatal(1,"plaintext mismatch case=%0d offset=%0d",count,out_count);
                out_count=out_count+1;
            end
        end
        held=reset_n_i && output_valid_o && !output_ready_i;held_byte=output_data_o;
        if(reset_n_i && status_valid_o)begin
            if(!was_status && status_cycles_o!==edge_count-started-1)
                $fatal(1,"lifecycle cycle mismatch measured=%0d expected=%0d",status_cycles_o,edge_count-started-1);
            if(!scrub_done_o || dut.key!==0 || dut.iv!==0 || dut.core_enable || dut.aes.busy_o)
                $fatal(1,"terminal before key/core cleanup");
            for(integer j=0;j<=1024;j=j+1)if(dut.buffer.bytes[j]!==0)$fatal(1,"terminal before RAM scrub address=%0d",j);
            if(dut.buffer.response_data!==0)$fatal(1,"RAM read latch not zero");
        end
        was_status=reset_n_i && status_valid_o;
    end
    task wait_ready;
        ticks=0;while(!job_ready_o && ticks<120000)begin @(negedge clock_i);ticks=ticks+1;end
        if(!job_ready_o || !scrub_done_o)$fatal(1,"worker not ready/scrubbed");
    endtask
    task begin_job(input integer bytes_count);
        wait_ready();job_bytes_i=bytes_count;job_key_i=key;job_iv_i=iv;job_valid_i=1;
        @(negedge clock_i);job_valid_i=0;
        job_bytes_i=16'hffff;job_key_i=~key;job_iv_i=~iv;
    endtask
    task finish_status(input [31:0] rc,input integer bytes_count,input [127:0] expected_iv);
        reg [63:0] saved_cycles;
        ticks=0;while(!status_valid_o && ticks<120000)begin @(negedge clock_i);ticks=ticks+1;end
        if(!status_valid_o || status_code_o!==rc || status_result_bytes_o!==bytes_count || status_iv_o!==expected_iv)
            $fatal(1,"status mismatch case=%0d rc=%h bytes=%0d iv=%h",count,status_code_o,status_result_bytes_o,status_iv_o);
        saved_cycles=status_cycles_o;
        if(saved_cycles==0)$fatal(1,"missing timing count");
        repeat(7)begin
            @(negedge clock_i);
            if(!status_valid_o || job_ready_o || status_code_o!==rc || status_result_bytes_o!==bytes_count ||
                status_iv_o!==expected_iv || status_cycles_o!==saved_cycles || output_valid_o)
                $fatal(1,"terminal not held stable");
        end
        status_ready_i=1;@(negedge clock_i);status_ready_i=0;
    endtask
    initial begin
        if(!$value$plusargs("VECTORS=%s",path))$fatal(1,"missing vectors");
        fd=$fopen(path,"r");if(!fd)$fatal(1,"missing file");
        repeat(4)@(negedge clock_i);reset_n_i=1;wait_ready();
        while(!$feof(fd))begin
            scan=$fscanf(fd,"%d %h %h %h\n",n,key,iv,feedback);
            if(scan==4)begin
                for(i=0;i<n;i=i+1)begin scan=$fscanf(fd,"%h %h\n",ciphertext[i],plaintext[i]);if(scan!=2)$fatal(1,"bad byte");end
                out_count=0;checking=1;output_ready_i=0;begin_job(n);
                for(i=0;i<n;i=i+1)begin
                    if(i%7==0)repeat(2)@(negedge clock_i);
                    input_data_i=ciphertext[i];input_valid_i=1;
                    do @(posedge clock_i);while(!input_ready_o);
                    @(negedge clock_i);input_valid_i=0;
                end
                ticks=0;
                while(out_count<n && ticks<120000)begin
                    output_ready_i=(ticks%5==0);@(negedge clock_i);ticks=ticks+1;
                end
                output_ready_i=0;
                if(out_count!=n)$fatal(1,"wrong plaintext output count");
                finish_status(0,n,feedback);
                if(recovery_required_o)$fatal(1,"recovery asserted for valid vector");
                total_bytes=total_bytes+n;count=count+1;checking=0;
                $display("CUSTOMER_AES_MATCH vector=%0d bytes=%0d cycles=%0d",count,n,status_cycles_o);
            end else if(!$feof(fd))$fatal(1,"bad header");
        end
        if(count!=52 || total_bytes!=12866)$fatal(1,"wrong independent denominator");
        n=0;out_count=0;begin_job(1025);finish_status(32'h095,0,0);
        if(recovery_required_o)$fatal(1,"invalid descriptor poisoned reusable worker");
        reset_abort();
        ram_error();
        input_timeout();
        cleanup_timeout();
        successfully_completed=1;
        $display("CUSTOMER_AES_WORKER_PASS vectors=52 bytes=12866 invalid_length reset_abort ram_error input_timeout cleanup_timeout cycles");$finish;
    end
    task reset_abort;
        begin_job(16);input_valid_i=1;input_data_i=8'hab;
        do @(posedge clock_i);while(!input_ready_o);
        @(negedge clock_i);input_valid_i=0;reset_n_i=0;
        repeat(4)@(negedge clock_i);
        if(status_valid_o || output_valid_o || input_ready_o || job_ready_o)$fatal(1,"reset admission/output not invalidated");
        reset_n_i=1;wait_ready();
        n=0;begin_job(0);finish_status(0,0,iv);
        $display("CUSTOMER_AES_RESET_PASS");
    endtask
    task ram_error;
        n=0;begin_job(1);
        force dut.ram_rsp_error=1'b1;
        input_data_i=8'h55;input_valid_i=1;
        do @(posedge clock_i);while(!input_ready_o);
        @(negedge clock_i);input_valid_i=0;
        wait(dut.state==9);release dut.ram_rsp_error;
        finish_status(32'h101,0,0);
        if(!recovery_required_o || output_valid_o)$fatal(1,"RAM error did not reject output/latch recovery");
        reset_n_i=0;repeat(4)@(negedge clock_i);reset_n_i=1;wait_ready();
        $display("CUSTOMER_AES_RAM_ERROR_PASS");
    endtask
    task cleanup_timeout;
        n=0;begin_job(0);force dut.clear_done=1'b0;
        ticks=0;while(!recovery_required_o && ticks<20000)begin
            @(negedge clock_i);ticks=ticks+1;
            if(status_valid_o)$fatal(1,"terminal exposed without cleanup ack");
        end
        if(!recovery_required_o || status_valid_o || job_ready_o)$fatal(1,"cleanup timeout not failclosed");
        release dut.clear_done;
        repeat(5)@(negedge clock_i);if(status_valid_o || job_ready_o)$fatal(1,"late cleanup made failed job reusable");
        reset_n_i=0;repeat(4)@(negedge clock_i);reset_n_i=1;wait_ready();
        $display("CUSTOMER_AES_CLEANUP_TIMEOUT_PASS");
    endtask
    task input_timeout;
        n=0;begin_job(1);finish_status(32'h101,0,0);
        if(!recovery_required_o || job_ready_o)$fatal(1,"timeout did not latch recovery");
        repeat(5)@(negedge clock_i);if(job_ready_o || status_valid_o)$fatal(1,"failed worker readmitted/replayed");
        reset_n_i=0;repeat(4)@(negedge clock_i);reset_n_i=1;wait_ready();
        $display("CUSTOMER_AES_TIMEOUT_PASS");
    endtask
    initial begin #1000000000;$fatal(1,"global timeout");end
endmodule
