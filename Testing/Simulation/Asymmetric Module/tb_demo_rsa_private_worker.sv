// Test-only lease/store harness. MOCK=0 uses actual keygen_math64 arithmetic;
// MOCK=1 is explicitly a protocol/fault model and makes no crypto claim.
`timescale 1ns/1ps
module tb_demo_rsa_private_worker #(
    parameter MOCK=1,
    parameter [63:0] DEADLINE=64'd9000000000
);
    reg clock_i=0,reset_n_i=0;
    always #5 clock_i=~clock_i;
    reg job_valid_i=0,input_valid_i=0,output_ready_i=0,status_ready_i=0;
    wire job_ready_o,input_ready_o,output_valid_o,status_valid_o,busy_o,rsa_client_active_o;
    reg [31:0] job_id_i=0,key_handle_i=32'h80000011;
    reg [15:0] ciphertext_bytes_i=256;
    reg [7:0] input_data_i=0;
    wire [7:0] output_data_o,progress_o;
    wire [31:0] status_id_o,status_code_o;
    wire [15:0] status_result_bytes_o;
    wire [63:0] status_cycles_o;
    wire recovery_required_o;
    wire [3:0] phase_o;
    wire private_open_valid_o,private_cmd_valid_o,private_rsp_ready_o;
    wire private_mem_write_en_o,private_mem_read_en_o;
    wire private_close_valid_o,private_close_rsp_ready_o;
    wire [7:0] private_cmd_op_o;
    wire [31:0] private_cmd_arg0_o,private_cmd_arg1_o,private_cmd_arg2_o,private_cmd_arg3_o;
    wire [11:0] private_mem_address_o;
    wire [31:0] private_mem_write_data_o;
    wire private_request_o,private_reply_ready_o,private_component_o;
    wire [31:0] private_handle_o;
    wire [5:0] private_index_o;
    reg private_active_i=0,private_close_rsp_valid_i=0;
    reg private_reply_valid_i=0;
    reg [31:0] private_data_i=0,private_reply_code_i=0;
    wire private_open_ready_i,private_cmd_ready_i,private_rsp_valid_i;
    wire [7:0] private_rsp_status_i;
    wire private_mem_ready_i,private_mem_read_valid_i;
    wire [31:0] private_mem_read_data_i;
    wire private_close_ready_i,private_request_ready_i;
    demo_rsa_private_worker #(.DEADLINE_CYCLES(DEADLINE)) dut(.*);

    reg [31:0] random_reg=32'h025d6411;
    reg stalls=1,deny_key=0,stall_math=0,stall_output=0;
    reg [2047:0] n_value,d_value,cipher_value,expected_value;
    integer cases=0,outputs=0,opens=0,closes=0,commands=0,mode=0;
    reg [31:0] expected_id;
    reg core_reset_n=0;
    reg [2:0] lease_state=0;
    reg [63:0] close_clocks=0;
    wire math_cmd_ready,math_rsp_valid,math_mem_ready,math_read_valid;
    wire [7:0] math_status;
    wire [31:0] math_read_data;
    wire cmd_gate=!stalls || random_reg[1];
    wire mem_gate=!stalls || random_reg[2];
    wire math_cmd_valid=private_active_i && lease_state==3 && private_cmd_valid_o && cmd_gate;
    wire math_rsp_ready=private_active_i && lease_state==3 && private_rsp_ready_o;
    wire math_write=private_active_i && lease_state==3 && private_mem_write_en_o && mem_gate;
    wire math_read=private_active_i && lease_state==3 && private_mem_read_en_o && mem_gate;
    assign private_open_ready_i=reset_n_i && lease_state==2 && math_cmd_ready && (!stalls || random_reg[0]);
    assign private_cmd_ready_i=private_active_i && lease_state==3 && math_cmd_ready && cmd_gate;
    assign private_rsp_valid_i=private_active_i && lease_state==3 && math_rsp_valid;
    assign private_rsp_status_i=math_status;
    assign private_mem_ready_i=private_active_i && lease_state==3 && math_mem_ready && mem_gate;
    assign private_mem_read_valid_i=private_active_i && lease_state==3 && math_read_valid;
    assign private_mem_read_data_i=private_mem_read_valid_i ? math_read_data : 0;
    assign private_close_ready_i=private_active_i && lease_state==3 && math_cmd_ready && !math_read_valid;

    // Registered local reset and real math's ready-after-scrub establish close.
    always @(posedge clock_i or negedge reset_n_i) begin
        if(!reset_n_i) begin
            core_reset_n<=0;lease_state<=0;private_active_i<=0;
            private_close_rsp_valid_i<=0;close_clocks<=0;
        end else begin
            random_reg<={random_reg[30:0],random_reg[31]^random_reg[21]^random_reg[1]^random_reg[0]};
            if(lease_state>=4 && lease_state<=6) close_clocks<=close_clocks+1'b1;
            case(lease_state)
                0: lease_state<=1;
                1: begin core_reset_n<=1;lease_state<=2;end
                2: if(private_open_valid_o && private_open_ready_i) begin
                    private_active_i<=1;lease_state<=3;opens<=opens+1;
                end
                3: if(private_close_valid_o && private_close_ready_i) begin
                    core_reset_n<=0;lease_state<=4;close_clocks<=0;
                end
                4: lease_state<=5;
                5: begin core_reset_n<=1;lease_state<=6;end
                6: if(math_cmd_ready) begin
                    if(close_clocks<4098 || math_read_data!==0) $fatal(1,"close before actual scrub/read-latch clearing");
                    private_close_rsp_valid_i<=1;lease_state<=7;
                end
                7: if(private_close_rsp_ready_o) begin
                    private_close_rsp_valid_i<=0;private_active_i<=0;
                    closes<=closes+1;lease_state<=2;
                end
                default: $fatal(1,"lease model state");
            endcase
        end
    end

    generate if(MOCK==0) begin:g_real
`ifdef TEST_COMPACT_MATH
        keygen_math #(.MAX_LIMBS(64),.COMPACT_STORAGE(1),.IP_TYPE(0)) math(
`else
        keygen_math #(.MAX_LIMBS(64),.IP_TYPE(0)) math(
`endif
            .clock_i(clock_i),.reset_n_i(core_reset_n),
            .cmd_valid_i(math_cmd_valid),.cmd_ready_o(math_cmd_ready),
            .cmd_op_i(private_cmd_op_o),.cmd_arg0_i(private_cmd_arg0_o),
            .cmd_arg1_i(private_cmd_arg1_o),.cmd_arg2_i(private_cmd_arg2_o),.cmd_arg3_i(private_cmd_arg3_o),
            .rsp_valid_o(math_rsp_valid),.rsp_ready_i(math_rsp_ready),.rsp_status_o(math_status),
            .mem_write_en_i(math_write),.mem_read_en_i(math_read),
            .mem_address_i(private_mem_address_o),.mem_write_data_i(private_mem_write_data_o),
            .mem_ready_o(math_mem_ready),.mem_read_valid_o(math_read_valid),.mem_read_data_o(math_read_data)
        );
    end else begin:g_mock
        reg [31:0] ram[0:4095];
        reg [12:0] clear_index=0;
        reg [1:0] state=0;
        reg response_valid=0,read_valid=0;
        reg [7:0] response_status=0;
        reg [31:0] read_data=0;
        integer delay_count=0,j;
        assign math_cmd_ready=core_reset_n && state==1 && !response_valid;
        assign math_mem_ready=math_cmd_ready && !math_cmd_valid;
        assign math_rsp_valid=core_reset_n && response_valid;
        assign math_status=response_status;
        assign math_read_valid=core_reset_n && read_valid;
        assign math_read_data=read_data;
        always @(posedge clock_i or negedge core_reset_n) begin
            if(!core_reset_n) begin
                clear_index<=0;state<=0;response_valid<=0;read_valid<=0;
                read_data<=0;response_status<=0;delay_count<=0;
            end else begin
                read_valid<=0;
                if(state==0) begin
                    if(clear_index<4096) ram[clear_index[11:0]]<=0;
                    if(clear_index==4096) read_data<=ram[4095];
                    if(clear_index==4097) state<=1;
                    else clear_index<=clear_index+1'b1;
                end else if(state==1) begin
                    if(math_write && math_mem_ready) ram[private_mem_address_o]<=private_mem_write_data_o;
                    if(math_read && math_mem_ready) begin read_valid<=1;read_data<=ram[private_mem_address_o];end
                    if(math_cmd_valid && math_cmd_ready) begin
                        response_status<=0;delay_count<=stalls?4:1;state<=2;
                        if(private_cmd_op_o==8'h11) begin
                            if({private_cmd_arg0_o,private_cmd_arg1_o,private_cmd_arg2_o,private_cmd_arg3_o}!==
                                {32'd1024,32'd1536,32'd64,32'd0}) $fatal(1,"MOD_SETUP descriptor mismatch");
                        end else if(private_cmd_op_o==8'h13) begin
                            if({private_cmd_arg0_o,private_cmd_arg1_o,private_cmd_arg2_o,private_cmd_arg3_o}!==
                                {32'd1216,32'd1152,32'd1088,32'd64}) $fatal(1,"MODEXP descriptor mismatch");
                            for(j=0;j<64;j=j+1) begin
                                if(ram[1024+j]!==n_value[32*j +:32] || ram[1088+j]!==d_value[32*j +:32] ||
                                   ram[1152+j]!==cipher_value[32*j +:32]) $fatal(1,"BE/private-LE restoration mismatch limb%0d",j);
                                if(cipher_value<n_value) ram[1216+j]<=expected_value[32*j +:32];
                            end
                            if(cipher_value>=n_value) response_status<=4;
                        end else $fatal(1,"unexpected math opcode");
                    end
                end else if(state==2 && !stall_math) begin
                    if(delay_count==0) begin response_valid<=1;state<=3;end
                    else delay_count<=delay_count-1;
                end else if(state==3 && response_valid && math_rsp_ready) begin response_valid<=0;state<=1;end
            end
        end
    end endgenerate

    // Explicit test-only protected store: checked public test fixtures, never a
    // customer key source. One registered held reply, no host secret read path.
    reg store_pending=0;
    reg [31:0] store_word=0,store_code=0;
    integer store_delay=0;
    assign private_request_ready_i=reset_n_i && private_active_i && rsa_client_active_o &&
        !store_pending && !private_reply_valid_i && (!stalls || random_reg[3]);
    always @(posedge clock_i or negedge reset_n_i) begin
        if(!reset_n_i) begin
            store_pending<=0;private_reply_valid_i<=0;private_data_i<=0;private_reply_code_i<=0;
        end else begin
            if(private_request_o && private_request_ready_i) begin
                store_pending<=1;store_delay<=stalls?{30'd0,random_reg[5:4]}:0;
                store_code<=private_handle_o!=32'h80000011 ? 32'h18b : deny_key ? 32'h12f : 0;
                store_word<=private_component_o ? d_value[2047-32*private_index_o -:32] : n_value[2047-32*private_index_o -:32];
            end
            if(store_pending) begin
                if(store_delay==0) begin
                    private_reply_valid_i<=1;private_reply_code_i<=store_code;
                    private_data_i<=store_code==0 ? store_word : 0;store_pending<=0;
                end else store_delay<=store_delay-1;
            end
            if(private_reply_valid_i && private_reply_ready_o) begin
                private_reply_valid_i<=0;private_data_i<=0;private_reply_code_i<=0;
            end
        end
    end

    reg output_stalled=0,request_stalled=0,cmd_stalled=0;
    reg [7:0] held_output;
    reg [38:0] held_request;
    reg [135:0] held_command;
    always @(posedge clock_i) begin
        if(!reset_n_i) begin output_stalled<=0;request_stalled<=0;cmd_stalled<=0;end
        else begin
            if(output_stalled && !recovery_required_o && (!output_valid_o || output_data_o!==held_output))
                $fatal(1,"output changed under backpressure");
            if(request_stalled && !recovery_required_o && (!private_request_o ||
                {private_handle_o,private_component_o,private_index_o}!==held_request)) $fatal(1,"key request changed under stall");
            if(cmd_stalled && !recovery_required_o && (!private_cmd_valid_o ||
                {private_cmd_op_o,private_cmd_arg0_o,private_cmd_arg1_o,private_cmd_arg2_o,private_cmd_arg3_o}!==held_command))
                $fatal(1,"math command changed under stall");
            output_stalled<=output_valid_o && !output_ready_i;held_output<=output_data_o;
            request_stalled<=private_request_o && !private_request_ready_i;
            held_request<={private_handle_o,private_component_o,private_index_o};
            cmd_stalled<=private_cmd_valid_o && !private_cmd_ready_i;
            held_command<={private_cmd_op_o,private_cmd_arg0_o,private_cmd_arg1_o,private_cmd_arg2_o,private_cmd_arg3_o};
            if(private_cmd_valid_o && private_cmd_ready_i) commands<=commands+1;
            if(output_valid_o && output_ready_i) begin
                if(outputs>=256 || output_data_o!==expected_value[2047-8*outputs -:8])
                    $fatal(1,"actual private result mismatch byte%0d got%h",outputs,output_data_o);
                outputs<=outputs+1;
            end
        end
    end
    always @(negedge clock_i) output_ready_i=reset_n_i && !stall_output && (!stalls || random_reg[6]);

    task automatic reset_all;
        begin
            @(negedge clock_i);reset_n_i=0;job_valid_i=0;input_valid_i=0;status_ready_i=0;
            stall_math=0;stall_output=0;deny_key=0;outputs=0;
            repeat(3)@(negedge clock_i);
            if(job_ready_o || output_valid_o || status_valid_o || private_request_o || private_cmd_valid_o)
                $fatal(1,"handshake during reset");
            reset_n_i=1;repeat(5)@(negedge clock_i);
            while(!math_cmd_ready)@(negedge clock_i);
            if(!job_ready_o || recovery_required_o) $fatal(1,"not reusable after reset");
            key_handle_i=32'h80000011;ciphertext_bytes_i=256;
        end
    endtask
    task automatic start_job;
        begin
            while(!job_ready_o)@(negedge clock_i);
            expected_id=32'h6a250000+cases;job_id_i=expected_id;job_valid_i=1;outputs=0;
            @(negedge clock_i);job_valid_i=0;
            job_id_i=32'hdeadbeef;key_handle_i=32'hbadbadba;ciphertext_bytes_i=0;
        end
    endtask
    task automatic feed_cipher;
        integer i;
        begin
            i=0;
            while(i<256 && !status_valid_o && !recovery_required_o) begin
                @(negedge clock_i);
                if(input_ready_o && (!stalls || random_reg[7])) begin
                    input_data_i=cipher_value[2047-8*i -:8];input_valid_i=1;
                    @(negedge clock_i);input_valid_i=0;i=i+1;
                end
            end
        end
    endtask
    task automatic check_terminal(input [31:0] code,input integer output_bytes);
        reg [63:0] waited,measured;
        begin
            waited=0;
            while(!status_valid_o && !recovery_required_o && waited<64'd500000000) begin
                @(negedge clock_i);waited=waited+1;
            end
            if(recovery_required_o || !status_valid_o) $fatal(1,"private job failed/timeout before terminal");
            if(status_id_o!==expected_id || status_code_o!==code ||
                status_result_bytes_o!==output_bytes || outputs!=output_bytes || dut.word_reg!==0 || private_active_i)
                $fatal(1,"terminal id/code/bytes/cleanup mismatch code=%h bytes=%d outputs=%d active=%b",status_code_o,status_result_bytes_o,outputs,private_active_i);
            measured=status_cycles_o;
            repeat(5)begin @(negedge clock_i);
                if(!status_valid_o || status_cycles_o!==measured || job_ready_o || output_valid_o)
                    $fatal(1,"terminal unstable/readmission");
            end
            $display("PRIVATE_WORKER_CASE_PASS mock=%0d code=%h cycles=%0d bytes=%0d",MOCK,code,measured,outputs);
            status_ready_i=1;@(negedge clock_i);status_ready_i=0;
            if(status_valid_o || !job_ready_o) $fatal(1,"terminal duplicate/no readmission");
            cases=cases+1;key_handle_i=32'h80000011;ciphertext_bytes_i=256;
        end
    endtask

    integer fd,total,scan,v,old_opens;
    reg [2047:0] saved_n,saved_d;
    initial begin
        if(!$value$plusargs("mode=%d",mode))mode=0;
        reset_all();
        fd=$fopen("private_vectors.txt","r");if(!fd)$fatal(1,"missing independent RSA vectors");
        scan=$fscanf(fd,"%d\n",total);if(scan!=1 || total<2)$fatal(1,"bad vector count");
        for(v=0;v<total;v=v+1)begin
            scan=$fscanf(fd,"%h %h %h %h\n",n_value,d_value,cipher_value,expected_value);
            if(scan!=4)$fatal(1,"bad vector row");
            if(mode==0) begin start_job();feed_cipher();check_terminal(0,256);end
            if(v==0)begin saved_n=n_value;saved_d=d_value;end
        end
        $fclose(fd);
        if(mode==0)begin
            n_value=saved_n;d_value=saved_d;cipher_value=n_value;expected_value=0;
            start_job();feed_cipher();check_terminal(32'h095,0);
            old_opens=opens;ciphertext_bytes_i=255;start_job();check_terminal(32'h095,0);
            if(opens!=old_opens)$fatal(1,"bad size opened lease");
            key_handle_i=32'h12345678;start_job();feed_cipher();check_terminal(32'h18b,0);
            deny_key=1;start_job();feed_cipher();check_terminal(32'h12f,0);deny_key=0;
            n_value[2047]=0;start_job();feed_cipher();check_terminal(32'h095,0);n_value=saved_n;
            n_value[0]=0;start_job();feed_cipher();check_terminal(32'h095,0);n_value=saved_n;
            d_value=0;start_job();feed_cipher();check_terminal(32'h095,0);d_value=saved_d;
            if(MOCK)begin
                // Bounded explicit control model tests; no arithmetic claim.
                cipher_value=0;expected_value=0;
                start_job();wait(dut.state_reg==3);reset_all();
                start_job();fork feed_cipher();begin wait(dut.state_reg==10);reset_all();end join
                cipher_value=0;expected_value=0;start_job();feed_cipher();
                wait(dut.state_reg==13);reset_all();
                start_job();feed_cipher();check_terminal(0,256);
            end
            $display("ALL RSA PRIVATE WORKER TESTS PASSED mock=%0d cases=%0d independent_vectors=%0d",MOCK,cases,total);
        end else begin
            stall_math=1;cipher_value=0;expected_value=0;start_job();feed_cipher();
            wait(recovery_required_o);repeat(5)@(negedge clock_i);
            if(status_valid_o || job_ready_o || output_valid_o || dut.word_reg!==0)
                $fatal(1,"unsafe timeout invented reusable terminal");
            reset_all();
            $display("RSA_PRIVATE_TIMEOUT_CONTROL_PASS mock=%0d",MOCK);
        end
        $finish;
    end
endmodule
