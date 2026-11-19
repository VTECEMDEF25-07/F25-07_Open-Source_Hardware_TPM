`timescale 1ns/1ps
// Public deterministic RNG fixture; actual engine/keygen/slot/packet/AES RTL.
module tb_aes_generated_slot;
    reg clk=0; always #5 clk=~clk;
    reg rst=0, generate_key=0, generation_ack=0, destroy=0, allow_use=1;
    reg [1:0] profile=1;
    wire generation_ready, generation_done, slot_valid, reserved;
    wire [3:0] generation_code;
    wire [31:0] private_data;
    wire random_request, random_timeout;
    reg random_valid=0;
    localparam [255:0] KEY=256'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f;
    localparam [127:0] IV=128'h101112131415161718191a1b1c1d1e1f;
    reg [7:0] oracle[0:1023];
    reg [1023:0] oracle_path;
    integer cycles=0, source_delay=0, aes_launches=0, scenarios=0;
    integer previous_launches=0;
    reg result_enable=1, ownership_enable=1, terminal_enable=1;
    reg lookup_enable=1, reply_enable=1;
    wire request_key, request_ready, reply_key, reply_ready, key_release;
    wire [31:0] key_handle, key_code;
    wire [255:0] key_data;
    execution_engine #(.ENABLE_INTERNAL_KEYGEN(1), .ENABLE_AES_SLOT_CONSUMER(1),
        .GETRANDOM_WAIT_LIMIT(2000)) engine (
        .clock_i(clk), .reset_n_i(rst), .command_ready_i(1'b0),
        .command_done_i(1'b1), .command_tag_i(16'h8001), .command_code_i(32'd0),
        .command_size_i(32'd0), .op_state_i(3'd3), .response_addr_i(12'd0),
        .random_i(KEY), .random_valid_i(random_valid), .random_request_o(random_request),
        .rng_fault_i(1'b0), .rng_timeout_o(random_timeout),
        .hash_grant_i(1'b0), .hash_ready_i(1'b0), .hash_digest_i(256'd0), .hash_digest_valid_i(1'b0),
        .keygen_request_i(generate_key), .keygen_ready_o(generation_ready),
        .keygen_profile_i(profile), .keygen_id_i(32'd42), .keygen_allow_i(1'b1),
        .keygen_completion_o(generation_done), .keygen_completion_ready_i(generation_ack),
        .keygen_code_o(generation_code), .keygen_release_i(destroy),
        .keygen_slot_valid_o(slot_valid), .keygen_private_address_i(8'd0), .keygen_private_data_o(private_data),
        .keygen_result_enable_i(result_enable), .keygen_ownership_enable_i(ownership_enable),
        .keygen_terminal_enable_i(terminal_enable),
        .aes_slot_request_i(request_key && lookup_enable), .aes_slot_request_ready_o(request_ready),
        .aes_slot_handle_i(key_handle), .aes_slot_allow_i(allow_use),
        .aes_slot_reply_o(reply_key), .aes_slot_reply_ready_i(reply_ready && reply_enable),
        .aes_slot_key_o(key_data), .aes_slot_code_o(key_code),
        .aes_slot_release_i(key_release), .aes_slot_reserved_o(reserved));
    reg start=0, consumed=0;
    reg [31:0] command_size=90;
    reg [15:0] tag=16'h8002;
    reg [7:0] command_byte;
    reg [7:0] command[0:1073];
    wire [11:0] command_address, response_length;
    reg [11:0] response_address=0;
    wire [7:0] response_byte;
    wire response_valid, busy;
    wire [31:0] response_code;
    execution_engine_aes_packet packet (
        .clock_i(clk), .reset_n_i(rst), .start_i(start), .operational_i(1'b1),
        .response_consumed_i(consumed), .busy_o(busy), .key_release_o(key_release),
        .command_tag_i(tag), .command_size_i(command_size),
        .command_addr_o(command_address), .command_byte_i(command_byte),
        .response_valid_o(response_valid), .response_code_o(response_code),
        .response_length_o(response_length), .response_addr_i(response_address), .response_byte_o(response_byte),
        .key_request_o(request_key), .key_request_ready_i(request_ready && lookup_enable),
        .key_handle_o(key_handle), .key_reply_valid_i(reply_key && reply_enable),
        .key_reply_ready_o(reply_ready), .resolved_key_i(key_data), .key_reply_code_i(key_code));
    always @(posedge clk) begin
        cycles<=cycles+1;
        command_byte<=command[command_address];
        random_valid<=0;
        if(!rst || !random_request) source_delay<=0;
        else if(source_delay==13) begin random_valid<=1; source_delay<=0; end
        else source_delay<=source_delay+1;
        if(rst && packet.aes_start) aes_launches<=aes_launches+1;
        if(rst && reserved && (private_data!==0 || generation_ready)) $fatal(1,"private mux/admission while reserved");
        if(random_timeout) $fatal(1,"unexpected source deadline");
    end
    task automatic reset_all;
        begin
            @(negedge clk); rst=0; start=0; generate_key=0; consumed=0; destroy=0;
            #1; if(slot_valid || reserved || reply_key || key_data!==0 || response_valid)
                $fatal(1,"reset did not mask transfers");
            repeat(3)@(negedge clk); rst=1;
            wait(generation_ready && !busy); @(negedge clk);
        end
    endtask
    task automatic generate_slot(input [1:0] kind);
        begin
            wait(generation_ready); @(negedge clk); profile=kind; generate_key=1;
            result_enable=0; ownership_enable=0; terminal_enable=0;
            @(negedge clk); generate_key=0;
            repeat(35)@(negedge clk); result_enable=1;
            repeat(35)@(negedge clk); ownership_enable=1;
            repeat(35)@(negedge clk); terminal_enable=1;
            wait(generation_done); #1;
            if(generation_code!=0 || !slot_valid) $fatal(1,"generation failed");
            repeat(7)@(negedge clk);
            generation_ack=1; @(negedge clk); generation_ack=0;
            scenarios=scenarios+1;
        end
    endtask
    task automatic clear_slot;
        begin
            @(negedge clk); destroy=1; #1;
            if(slot_valid || private_data!==0) $fatal(1,"destroy visibility");
            @(negedge clk); destroy=0; wait(generation_ready);
            for(integer j=0;j<129;j++)
                if(engine.keygen_enabled.protected_keygen.slot[j]!==0) $fatal(1,"slot erase");
        end
    endtask
    task automatic build_command(input integer n, input bit decrypt, input integer malformed=0);
        begin
            wait(!busy); @(negedge clk);
            previous_launches=aes_launches;
            for(integer j=0;j<1024;j++) packet.payload[j]=8'ha5;
            for(integer j=0;j<1074;j++) command[j]=0;
            command_size=n+50; tag=16'h8002;
            {command[10],command[11],command[12],command[13]}=32'h80000000;
            {command[14],command[15],command[16],command[17]}=32'd9;
            {command[18],command[19],command[20],command[21]}=32'h40000009;
            command[27]=n>>8; command[28]=n;
            for(integer j=0;j<n;j++) command[29+j]=decrypt ? oracle[j] : j;
            command[29+n]=decrypt;
            command[31+n]=8'h43; command[33+n]=16;
            for(integer j=0;j<16;j++) command[34+n+j]=IV[127-j*8 -:8];
            case(malformed)
                1: command[21]=8'h08;
                2: command[31+n]=0;
                3: command[13]=1;
                4: command[17]=8;
                5: command[29+n]=2;
                6: command[33+n]=15;
                7: tag=16'h8001;
                8: command_size=49;
            endcase
        end
    endtask
    task automatic launch;
        begin start=1; @(negedge clk); start=0; end
    endtask
    task automatic finish_and_check(input integer n, input bit decrypt,
        input [31:0] expected_code=0, input integer owned=-1, input bit launched_error=0);
        reg [127:0] expected_iv;
        integer base, bytes, count_before;
        begin
            wait(response_valid); #1;
            if(response_code!==expected_code) $fatal(1,"response code %h expected %h",response_code,expected_code);
            if(aes_launches!=previous_launches+((expected_code==0 || launched_error) ? 1 : 0))
                $fatal(1,"denied/malformed job launched AES or success did not launch");
            if(expected_code==0) begin
                if(!reserved || response_length!=n+39) $fatal(1,"lost terminal ownership/length");
                for(integer j=0;j<n;j++) begin
                    response_address=j+6; #1;
                    if(response_byte!==(decrypt ? (j & 255) : oracle[j])) $fatal(1,"oracle data byte%0d got%h",j,response_byte);
                end
                expected_iv=IV;
                if(n!=0) begin
                    expected_iv=0; base=((n-1)/16)*16; bytes=n-base;
                    for(integer j=0;j<bytes;j++) expected_iv[127-j*8 -:8]=oracle[base+j];
                end
                for(integer j=0;j<16;j++) begin
                    response_address=n+8+j; #1;
                    if(response_byte!==expected_iv[127-j*8 -:8]) $fatal(1,"oracle IV byte%0d",j);
                end
                // Completion stays coherent and protected under consumer stall.
                @(negedge clk); destroy=1; generate_key=1;
                repeat(20)@(negedge clk);
                if(!reserved || !slot_valid || generation_ready || key_data!==0 ||
                    packet.job.aes_key_o!==0 || packet.aes.CONTROLLER.cfb_key_o!==0 ||
                    packet.aes.WORKER.aes_key_r!==0) $fatal(1,"terminal/key ownership");
                destroy=0; generate_key=0;
            end else if(response_length!=10) $fatal(1,"failure reply size");
            @(negedge clk); consumed=1; @(negedge clk); consumed=0;
            wait(!busy && !reserved && engine.aes_slot_request_ready_o); @(negedge clk);
            count_before=owned<0 ? n : owned;
            for(integer j=0;j<1024;j++)
                if(packet.payload[j]!==(j<count_before ? 8'd0 : 8'ha5)) $fatal(1,"scratch/guard byte%0d n%0d owned%0d",j,n,count_before);
            if(packet.ram_read_data!==0 || engine.aes_slot_enabled.consumer.key_reg!==0)
                $fatal(1,"retained private copy");
            scenarios=scenarios+1;
        end
    endtask
    initial begin
        if(!$value$plusargs("ORACLE=%s",oracle_path)) $fatal(1,"oracle missing");
        $readmemh(oracle_path,oracle);
        reset_all();
        build_command(40,0); launch(); finish_and_check(40,0,32'h18b);
        generate_slot(1);
        for(integer test=0;test<7;test++) begin
            integer n;
            case(test) 0:n=0;1:n=1;2:n=16;3:n=17;4:n=40;5:n=64;6:n=1024;endcase
            build_command(n,0); launch(); finish_and_check(n,0);
            build_command(n,1); launch(); finish_and_check(n,1);
        end
        allow_use=0; build_command(40,0); launch(); finish_and_check(40,0,32'h9a2); allow_use=1;
        for(integer bad=1;bad<=8;bad++) begin
            reg [31:0] code;
            case(bad) 1:code='h101;2:code='h3c9;3:code='h18b;4:code='h144;
                5:code='h2c4;6:code='h4d5;7:code='h125;8:code='h142;endcase
            build_command(40,0,bad); launch();
            finish_and_check(40,0,code,(bad==1 || bad==4 || bad==7 || bad==8) ? 0 : 40);
        end
        // Wrong type rejects before AES; wrong size is separately injected below.
        clear_slot(); generate_slot(0);
        build_command(40,0); launch(); finish_and_check(40,0,32'h18b); clear_slot();
        generate_slot(1);
        force engine.keygen_enabled.protected_keygen.profile=2;
        build_command(40,0); launch(); finish_and_check(40,0,32'h18b);
        release engine.keygen_enabled.protected_keygen.profile;
        clear_slot(); generate_slot(1);
        force engine.keygen_enabled.protected_keygen.expected_words=8'd7;
        build_command(40,0); launch(); finish_and_check(40,0,32'h18b);
        release engine.keygen_enabled.protected_keygen.expected_words;
        // Backpressure on acquisition and held assembled key reply.
        build_command(40,0); lookup_enable=0; reply_enable=0; launch();
        wait(request_key); repeat(15)@(negedge clk);
        if(reserved) $fatal(1,"unaccepted lookup acquired lease");
        lookup_enable=1; wait(reply_key); repeat(15)@(negedge clk);
        if(!reserved || key_data!==KEY) $fatal(1,"held key reply unstable");
        reply_enable=1; finish_and_check(40,0);
        // A CRB submission may overlap the old command's deterministic sweep.
        build_command(40,0); launch(); wait(response_valid);
        @(negedge clk); consumed=1;
        @(negedge clk); consumed=0; previous_launches=aes_launches;
        if(packet.state!=7) $fatal(1,"queued command missed scrub window");
        launch(); finish_and_check(40,0);
        // Computation failure must erase its span, preserve the slot, and
        // return an error rather than publishing a partial successful result.
        for(integer error_phase=0;error_phase<2;error_phase++) begin
            build_command(40,0); launch();
            if(error_phase==0) wait(packet.aes.CONTROLLER.state_reg==3);
            else wait(packet.aes.CONTROLLER.state_reg==7);
            force packet.aes.CONTROLLER.ram_rsp_error_i=1'b1;
            wait(response_valid);
            release packet.aes.CONTROLLER.ram_rsp_error_i;
            finish_and_check(40,0,32'h101,-1,1);
            if(!slot_valid) $fatal(1,"failed computation destroyed committed slot");
        end
        clear_slot();
        // Shared reset at key load, computation, output and terminal.
        for(integer phase=0;phase<4;phase++) begin
            generate_slot(1); build_command(40,0); launch();
            case(phase)
                0: wait(engine.aes_slot_enabled.consumer.state_reg==3 && engine.aes_slot_enabled.consumer.address_reg==3);
                1: wait(packet.aes.WORKER.state_r==5);
                2: wait(packet.ram_req_valid && packet.ram_req_write);
                3: wait(response_valid);
            endcase
            reset_all();
            for(integer j=0;j<1024;j++)
                if(packet.payload[j]!==(j<40 ? 8'd0 : 8'ha5)) $fatal(1,"reset scratch guard");
            repeat(10)@(negedge clk);
            force packet.job.aes_done_i=1'b1;
            repeat(3)@(negedge clk);
            release packet.job.aes_done_i;
            if(response_valid || slot_valid || reserved) $fatal(1,"stale completion after reset");
            scenarios=scenarios+1;
        end
        generate_slot(1); build_command(40,0); launch(); finish_and_check(40,0); clear_slot();
        $display("AES_GENERATED_SLOT_PASS scenarios=%0d launches=%0d cycles=%0d",scenarios,aes_launches,cycles);
        $finish;
    end
    initial begin #10000000; $fatal(1,"AES generated slot cycle deadline cycles=%0d",cycles); end
endmodule
