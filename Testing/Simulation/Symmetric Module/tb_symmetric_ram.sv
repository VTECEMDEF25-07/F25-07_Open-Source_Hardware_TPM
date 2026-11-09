`timescale 1ns/1ps
module tb_symmetric_ram;
    parameter MAX_SYM_DATA_BYTES = 1024;
    parameter RAM_ADDR_WIDTH = 12;
    localparam DEPTH = 1 << RAM_ADDR_WIDTH;
    reg clock_i = 0;
    always #5 clock_i = ~clock_i;
    reg reset_n_i = 0, start_i = 0, decrypt_i = 0;
    reg [255:0] key_i = 0;
    reg [127:0] iv_i = 0;
    reg [RAM_ADDR_WIDTH-1:0] input_base_i = 0, output_base_i = 0;
    reg [31:0] data_length_i = 0;
    wire busy_o, done_o, error_o;
    wire [11:0] tpm_rc_o;
    wire [127:0] final_iv_o;
    wire [31:0] completed_length_o;
    wire ram_req_valid_o, ram_req_ready_i, ram_req_write_o;
    wire [RAM_ADDR_WIDTH-1:0] ram_req_addr_o;
    wire [7:0] ram_req_data_o, ram_rsp_data_i;
    wire ram_rsp_valid_i, ram_rsp_ready_o, ram_rsp_error_i;
    wire [15:0] command_code_i = 16'h0193;
    wire key_valid_i = 1'b1;
    wire [2:0] mode_i = 3'd1;
    reg session_protect_i = 0;
    wire session_valid_i = 1'b1;
    wire session_decrypt_i = 1'b0, session_encrypt_i = 1'b1, session_use_xor_i = 1'b1;
    wire [1023:0] session_value_i = 0;
    wire [511:0] nonce_newer_i = 0, nonce_older_i = 0;
    wire [15:0] session_value_bytes_i = 0, nonce_newer_bytes_i = 0, nonce_older_bytes_i = 0;
    wire hmac_start_o, hmac_key_valid_o, hmac_key_end_o;
    wire hmac_message_valid_o, hmac_message_end_o, hmac_digest_ready_o;
    wire [7:0] hmac_key_data_o, hmac_message_data_o;
    reg hmac_digest_valid_i = 0;
    wire hmac_key_ready_i = 1'b1, hmac_message_ready_i = 1'b1, hmac_busy_i = 1'b0;
    wire [255:0] hmac_digest_i = {32{8'ha5}};

    // One fixed digest exercises the session path through the shared buffer.
    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) hmac_digest_valid_i <= 0;
        else if (hmac_message_end_o) hmac_digest_valid_i <= 1;
        else if (hmac_digest_ready_o) hmac_digest_valid_i <= 0;
    end

    symm_top #(.MAX_SYM_DATA_BYTES(MAX_SYM_DATA_BYTES), .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH)) dut(.*);
    symmetric_test_ram #(.ADDR_WIDTH(RAM_ADDR_WIDTH)) ram (
        .clock_i(clock_i), .reset_n_i(reset_n_i),
        .req_valid_i(ram_req_valid_o), .req_ready_o(ram_req_ready_i),
        .req_write_i(ram_req_write_o), .req_addr_i(ram_req_addr_o), .req_data_i(ram_req_data_o),
        .rsp_valid_o(ram_rsp_valid_i), .rsp_ready_i(ram_rsp_ready_o),
        .rsp_data_o(ram_rsp_data_i), .rsp_error_o(ram_rsp_error_i)
    );
    bit successfully_completed = 0;
    integer case_count = 0, worker_count = 0, outstanding = 0;
    integer read_count = 0, write_count = 0;
    bit stalled = 0;
    reg [RAM_ADDR_WIDTH+8:0] held_request;
    // Protocol assertions run independently of the descriptor driver.
    always @(posedge clock_i) begin
        if (!reset_n_i) begin
            stalled = 0;
            outstanding = 0;
        end else begin
            if (stalled && (!ram_req_valid_o ||
                {ram_req_write_o,ram_req_addr_o,ram_req_data_o} !== held_request))
                $fatal(1,"request changed under backpressure");
            stalled = ram_req_valid_o && !ram_req_ready_i;
            held_request = {ram_req_write_o,ram_req_addr_o,ram_req_data_o};
            if (ram_req_valid_o && ram_req_ready_i) begin
                if (outstanding != 0) $fatal(1,"request issued while outstanding");
                outstanding = 1;
                if (ram_req_write_o) write_count = write_count + 1;
                else read_count = read_count + 1;
            end
            if (ram_rsp_valid_i && ram_rsp_ready_o) begin
                if (outstanding != 1) $fatal(1,"unsolicited response consumed");
                outstanding = 0;
            end
            if (dut.cfb_start_w) worker_count = worker_count + 1;
            if (done_o && outstanding != 0) $fatal(1,"completion before response");
        end
    end
    reg [7:0] expected_memory [0:DEPTH-1];
    reg [7:0] input_data [0:DEPTH-1], expected_data [0:DEPTH-1];
    reg [127:0] saved_iv;
    reg [31:0] saved_length;
    reg saved_error;
    reg [11:0] saved_rc;
    integer i, ticks;
    task initialize_memory;
        begin
            for (i=0;i<DEPTH;i=i+1) begin
                ram.memory[i] = (i * 13 + 7) % 256;
                expected_memory[i] = ram.memory[i];
            end
            ram.fail_transaction = -1;
            worker_count = 0; read_count = 0; write_count = 0;
        end
    endtask
    task launch(input integer length, input integer source, input integer destination,
                input bit dec, input [255:0] key, input [127:0] iv);
        begin
            while(busy_o) @(negedge clock_i);
            data_length_i = length; input_base_i = source; output_base_i = destination;
            decrypt_i = dec; key_i = key; iv_i = iv; start_i = 1;
            @(negedge clock_i);
            if (!busy_o) $fatal(1,"descriptor not accepted");
            // All descriptor fields must be captured, including bases and length.
            data_length_i = 32'hffffffff; input_base_i = ~source; output_base_i = ~destination;
            decrypt_i = !dec; key_i = ~key; iv_i = ~iv;
            session_protect_i = 0;
        end
    endtask
    task finish_job(input bit failed, input integer completed, input [127:0] feedback);
        begin
            ticks=0;
            while(!done_o && ticks < 1000000) begin @(negedge clock_i);ticks=ticks+1;end
            if (!done_o || error_o !== failed || completed_length_o !== completed ||
                final_iv_o !== feedback || (failed ? tpm_rc_o == 0 : tpm_rc_o != 0))
                $fatal(1,"case %0d result error=%b rc=%h length=%0d expected=%0d iv=%h expected=%h",
                    case_count,error_o,tpm_rc_o,completed_length_o,completed,final_iv_o,feedback);
            if (dut.CONTROLLER.cfb_key_o !== 0 || dut.CONTROLLER.cfb_data_o !== 0 ||
                dut.CONTROLLER.result_reg !== 0 || dut.CONTROLLER.cfb_iv_o !== 0)
                $fatal(1,"temporary data not cleared");
            saved_iv=final_iv_o; saved_length=completed_length_o; saved_error=error_o; saved_rc=tpm_rc_o;
            repeat(8) begin
                @(negedge clock_i);
                if(done_o || !busy_o || final_iv_o !== saved_iv || completed_length_o !== saved_length ||
                    error_o !== saved_error || tpm_rc_o !== saved_rc || ram_req_valid_o)
                    $fatal(1,"held start replayed or result not retained");
            end
            start_i=0;
            while(busy_o) @(negedge clock_i);
            repeat(3) @(negedge clock_i);
            if(final_iv_o !== saved_iv || completed_length_o !== saved_length ||
                error_o !== saved_error || tpm_rc_o !== saved_rc) $fatal(1,"idle result lost");
            case_count=case_count+1;
        end
    endtask
    task check_memory;
        begin
            for(i=0;i<DEPTH;i=i+1)
                if(ram.memory[i] !== expected_memory[i])
                    $fatal(1,"case %0d memory[%0d]=%h expected=%h",case_count,i,ram.memory[i],expected_memory[i]);
        end
    endtask
    task invalid_job(input integer length,input integer source,input integer destination);
        integer transactions;
        begin
            initialize_memory(); transactions=ram.transaction_count;
            launch(length,source,destination,0,0,128'h1234);
            finish_job(1,0,128'h1234);
            if(ram.transaction_count != transactions || worker_count != 0 || tpm_rc_o !== 12'h095)
                $fatal(1,"invalid job touched RAM/AES or wrong status");
            check_memory();
        end
    endtask
    // Reset the controller AND adapter; RAM contents intentionally survive reset.
    task reset_both;
        begin
            reset_n_i=0;start_i=0;
            repeat(3) @(negedge clock_i);
            if(ram_rsp_valid_i || ram_req_valid_o || busy_o || done_o ||
               final_iv_o !== 0 || completed_length_o !== 0) $fatal(1,"reset not flushed");
            reset_n_i=1;
            repeat(3) @(negedge clock_i);
            if(ram_rsp_valid_i || done_o) $fatal(1,"stale completion after reset");
        end
    endtask
    localparam [127:0] ZERO_CIPHER = 128'hdc95c078a2408989ad48a21492842087;
    task failure_job(input integer length,input integer fail_index,input integer completed,
                     input [127:0] feedback);
        begin
            initialize_memory();
            for(i=0;i<length;i=i+1)begin ram.memory[i]=0;expected_memory[i]=0;end
            for(i=0;i<completed;i=i+1)expected_memory[DEPTH/2+i]=ZERO_CIPHER[127-i*8 -: 8];
            ram.fail_transaction=ram.transaction_count+fail_index;
            launch(length,0,DEPTH/2,0,0,0);
            finish_job(1,completed,feedback);
            if(tpm_rc_o !== 12'h101)$fatal(1,"RAM failure status");
            check_memory();
        end
    endtask
    task reuse_job;
        begin
            initialize_memory();ram.memory[0]=0;expected_memory[0]=0;
            expected_memory[DEPTH-1]=8'hdc;
            launch(1,0,DEPTH-1,0,0,0);
            finish_job(0,1,128'hdc000000000000000000000000000000);
            check_memory();
        end
    endtask
    integer fd, scan, n, dec, source, destination, value, vectors=0;
    reg [255:0] vector_key;
    reg [127:0] vector_iv, vector_feedback;
    string vector_path;
    initial begin
        reset_both();
        if(!$value$plusargs("VECTORS=%s",vector_path)) $fatal(1,"missing vectors");
        fd=$fopen(vector_path,"r");if(!fd)$fatal(1,"cannot open vectors");
        while(!$feof(fd)) begin
            scan=$fscanf(fd,"%d %d %d %d %h %h %h\n",n,dec,source,destination,vector_key,vector_iv,vector_feedback);
            if(scan != 7) $fatal(1,"invalid vector header");
            initialize_memory();
            for(i=0;i<n;i=i+1) begin
                scan=$fscanf(fd,"%h %h\n",input_data[i],expected_data[i]);
                if(scan != 2)$fatal(1,"invalid byte vector");
                ram.memory[source+i]=input_data[i];
                expected_memory[source+i]=input_data[i];
            end
            for(i=0;i<n;i=i+1)expected_memory[destination+i]=expected_data[i];
            // Alternate fast service with variable delays and stalled requests.
            ram.latency_max = vectors % 2 ? 7 : 0;
            ram.stall_modulus = vectors % 2 ? 5 : 0;
            launch(n,source,destination,dec,vector_key,vector_iv);
            finish_job(0,n,vector_feedback);
            if(worker_count != (n+15)/16 || read_count != n || write_count != n)
                $fatal(1,"incorrect chunk/transaction count");
            check_memory(); vectors=vectors+1;
        end
        $fclose(fd);
        invalid_job(MAX_SYM_DATA_BYTES+1,0,0);
        invalid_job(32'hffffffff,0,0);
        if(MAX_SYM_DATA_BYTES >= 2) begin
            invalid_job(2,DEPTH-1,0);
            invalid_job(2,0,DEPTH-1);
            invalid_job(2,0,1);
            invalid_job(2,1,0);
        end
        ram.latency_max=7;ram.stall_modulus=5;
        failure_job(1,0,0,0); // failed read: no output
        failure_job(1,1,0,0); // failed write: completion waits for its ACK
        if(MAX_SYM_DATA_BYTES >= 4) failure_job(4,7,3,0);
        if(MAX_SYM_DATA_BYTES >= 17) begin
            failure_job(17,32,16,ZERO_CIPHER); // next block read fails
            failure_job(17,33,16,ZERO_CIPHER); // next block write fails
        end
        // Exercise the controller's worker-error path without changing AES RTL.
        initialize_memory();
        force dut.cfb_rc_w = 12'h101;
        launch(1,0,DEPTH-1,0,0,0);
        finish_job(1,0,0);
        release dut.cfb_rc_w;
        check_memory();
        reuse_job();

        // Reset during request backpressure, pending read, AES, pending write,
        // and a response that has become valid. Joint flush precedes reuse.
        for(value=0;value<5;value=value+1) begin
            initialize_memory();ram.latency_max=30;ram.stall_modulus=5;
            launch(1,0,DEPTH-1,0,0,0);
            case(value)
                0: while(!(ram_req_valid_o && !ram_req_ready_i)) @(negedge clock_i);
                1: while(!(ram.pending_reg && !ram.write_reg)) @(negedge clock_i);
                2: while(dut.CONTROLLER.state_reg != 5) @(negedge clock_i);
                3: while(!(ram.pending_reg && ram.write_reg)) @(negedge clock_i);
                4: while(!ram_rsp_valid_i) @(negedge clock_i);
            endcase
            reset_both();case_count=case_count+1;
            reuse_job();
        end
        // Switch from the primitive path to session XOR, then back again.
        initialize_memory();
        expected_memory[0] = expected_memory[0] ^ 8'ha5;
        session_protect_i = 1;
        launch(1,0,0,0,0,128'h1234);
        finish_job(0,1,128'h1234);
        check_memory();
        if (worker_count != 0 || read_count != 1 || write_count != 1)
            $fatal(1,"Session XOR used the wrong data path");
        reuse_job();

        successfully_completed=1;
        $display("SYMMETRIC_RAM_SUITE_PASS capacity=%0d address_width=%0d vectors=%0d cases=%0d",
            MAX_SYM_DATA_BYTES,RAM_ADDR_WIDTH,vectors,case_count);
        $finish;
    end
    initial begin #100000000; $fatal(1,"global timeout"); end
endmodule
