`timescale 1ns/1ps
// Decoded command/object/session fixtures exercise normal command admission.
// Authorization is a testbench service; command-buffer parsing is outside scope.
module tb_execution_engine_primitive;
    reg clock_i=0;
    always #5 clock_i=~clock_i;
    reg reset_n_i=0, command_ready_i=0;
    reg [31:0] command_code_i=32'h00000193;
    reg allow_launch=0, use_real=0, stale_done=0;
    reg mock_done=0;
    reg [31:0] mock_code=0;
    reg [127:0] mock_data=0, mock_iv=0;
    wire command_start_o, response_valid_o, execution_result_valid_o;
    wire [31:0] response_code_o, execution_result_code_o;
    wire [15:0] response_length_o;
    wire [3:0] current_state_o;
    wire [127:0] execution_data_o, execution_iv_o;
    wire sym_wait, sym_done;
    wire [11:0] sym_rc;
    wire [127:0] sym_data, sym_iv;
    wire execution_ready_i=allow_launch && (!use_real || !sym_wait);
    wire command_done_i=stale_done || (use_real ? sym_done : mock_done);
    wire [31:0] execution_response_code_i=use_real ? {20'd0,sym_rc} : mock_code;
    wire [127:0] execution_data_i=use_real ? sym_data : mock_data;
    wire [127:0] execution_iv_i=use_real ? sym_iv : mock_iv;

    execution_engine dut (
        .clock_i(clock_i), .reset_n_i(reset_n_i), .command_ready_i(command_ready_i),
        .command_tag_i(16'h8002), .command_size_i(32'd64), .command_length_i(16'd64),
        .command_code_i(command_code_i), .handle_0_i(32'h80000001), .handle_1_i(32'd0), .handle_2_i(32'd0),
        .session0_handle_i(32'h01000001), .session1_handle_i(32'h01000002), .session2_handle_i(32'h01000003),
        .session0_attributes_i(8'd1), .session1_attributes_i(8'd0), .session2_attributes_i(8'd0),
        .session0_hmac_size_i(16'd32), .session1_hmac_size_i(16'd32), .session2_hmac_size_i(16'd32),
        .session0_valid_i(1'b1), .session1_valid_i(1'b0), .session2_valid_i(1'b0),
        .authorization_size_i(32'd0), .session_loaded_i(1'b1), .max_session_amount_i(16'd1),
        .auth_session_i(1'b1), .auth_necessary_i(1'b1), .authHandle_i(32'h80000001), .pcrSelect_i(8'd0),
        .auth_done_i(1'b1), .auth_success_i(1'b1), .auth_response_code_i(12'd0),
        .param_decrypt_success_i(1'b1), .param_decrypt_fail_i(1'b0),
        .param_unmarshall_success_i(1'b1), .param_unmarshall_fail_i(1'b0),
        .execution_startup_done_i(1'b0), .execution_response_code_i(execution_response_code_i),
        .execution_ready_i(execution_ready_i), .execution_data_i(execution_data_i), .execution_iv_i(execution_iv_i),
        .nv_phEnableNV_in_i(1'b1), .nv_shEnable_in_i(1'b1), .nv_ehEnable_in_i(1'b1),
        .tpm_nv_index_i(32'd0), .nv_index_attributes_i(32'd0), .nv_object_present_i(1'b1),
        .nv_index_present_i(1'b1), .entity_hierarchy_i(32'h40000001),
        .mem_orderly_i(16'd0), .ram_available_i(1'b1), .loaded_object_present_i(1'b1), .object_attributes_i(32'd0),
        .st_testsRun_i(16'd0), .st_testsPassed_i(16'd0), .st_untested_i(16'd0),
        .op_state_i(3'd3), .startup_type_i(3'd0), .phEnable_i(1'b1), .phEnableNV_i(1'b1),
        .shEnable_i(1'b1), .ehEnable_i(1'b1), .shutdownSave_i(16'd0), .command_done_i(command_done_i),
        .testsPassed_o(), .untested_o(), .nv_phEnableNV_o(), .nv_shEnable_o(), .nv_ehEnable_o(),
        .orderlyInput_o(), .initialized_o(), .testsRun_o(), .authHierarchy_o(),
        .response_valid_o(response_valid_o), .response_code_o(response_code_o), .response_length_o(response_length_o),
        .current_state_o(current_state_o), .command_start_o(command_start_o),
        .execution_result_valid_o(execution_result_valid_o), .execution_result_code_o(execution_result_code_o),
        .execution_data_o(execution_data_o), .execution_iv_o(execution_iv_o)
    );

    localparam [255:0] KEY=256'h603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4;
    localparam [127:0] IV=128'h000102030405060708090a0b0c0d0e0f;
    localparam [127:0] PLAIN=128'h6bc1bee22e409f96e93d7e117393172a;
    localparam [127:0] CIPHER=128'hdc7e84bfda79164b7ecd8486985d3860;
    reg key_valid=1, decrypt=0;
    reg [2:0] mode=1;
    reg [15:0] data_bytes=16;
    reg [127:0] data=PLAIN;
    symm_top #(.MAX_DATA_BYTES(16), .MAX_SECRET_BYTES(32), .MAX_NONCE_BYTES(32)) symmetric (
        .clock_i(clock_i), .reset_n_i(reset_n_i), .start_i(command_start_o && use_real),
        .command_code_i(command_code_i[15:0]), .session_protect_i(1'b0),
        .session_decrypt_i(1'b0), .session_encrypt_i(1'b0), .session_use_xor_i(1'b0),
        .key_valid_i(key_valid), .session_valid_i(1'b0), .mode_i(mode), .decrypt_i(decrypt),
        .data_bytes_i(data_bytes), .key_i(KEY), .iv_i(IV), .data_in_i(data), .session_mask_i(128'd0),
        .session_value_i(256'd0), .session_value_bytes_i(16'd0),
        .nonce_newer_i(256'd0), .nonce_newer_bytes_i(16'd0), .nonce_older_i(256'd0), .nonce_older_bytes_i(16'd0),
        .hmac_start_o(), .hmac_key_data_o(), .hmac_message_data_o(), .hmac_key_valid_o(), .hmac_key_end_o(),
        .hmac_key_ready_i(1'b0), .hmac_message_valid_o(), .hmac_message_end_o(), .hmac_message_ready_i(1'b0),
        .hmac_busy_i(1'b0), .hmac_digest_i(256'd0), .hmac_digest_valid_i(1'b0), .hmac_digest_ready_o(),
        .wait_o(sym_wait), .done_o(sym_done), .tpm_rc_o(sym_rc), .data_out_o(sym_data), .iv_out_o(sym_iv),
        .primitive_path_o(), .session_path_o()
    );
    integer launches=0, cases=0;
    always @(posedge clock_i) if (reset_n_i && command_start_o) begin
        if (!execution_ready_i || launches != 0) $fatal(1,"Repeated or premature primitive launch");
        launches=launches+1;
    end
    task admit;
        integer waited;
        begin
            @(negedge clock_i);
            launches=0;
            if (current_state_o != 0) $fatal(1,"Engine not idle");
            command_ready_i=1;
            @(negedge clock_i); command_ready_i=0;
            if (execution_result_valid_o || execution_data_o !== 0 || execution_iv_o !== 0 || execution_result_code_o !== 0)
                $fatal(1,"Old result survived next command admission");
            waited=0;
            while (current_state_o != 8 && !response_valid_o && waited<100) begin
                @(negedge clock_i); waited++;
            end
            if (current_state_o != 8)
                $fatal(1,"Decoded command did not reach execution: state=%0d rc=%h",current_state_o,response_code_o);
            if (dut.handle_count != 1) $fatal(1,"EncryptDecrypt2 must have one key handle");
        end
    endtask
    task check_result(input [31:0] code, input [127:0] result_data, input [127:0] result_iv);
        integer waited;
        begin
            waited=0;
            while (!response_valid_o && waited<2000) begin
                @(negedge clock_i);
                if (current_state_o==8 && dut.execution_phase==1 && execution_result_valid_o)
                    $fatal(1,"Result marked complete before worker done");
                waited++;
            end
            if (!response_valid_o || launches!=1 || response_code_o !== code ||
                !execution_result_valid_o || execution_result_code_o !== code ||
                execution_data_o !== result_data || execution_iv_o !== result_iv)
                $fatal(1,"Bad captured result rc=%h data=%h iv=%h launches=%0d",response_code_o,execution_data_o,execution_iv_o,launches);
            mock_done=0; mock_code=32'hffffffff; mock_data=~result_data; mock_iv=~result_iv;
            repeat(7) begin
                @(negedge clock_i);
                if (!execution_result_valid_o || execution_result_code_o !== code ||
                    execution_data_o !== result_data || execution_iv_o !== result_iv)
                    $fatal(1,"Captured result changed after completion");
            end
            cases++;
            $display("PASS execution/symmetric case %0d",cases);
        end
    endtask
    task reset_all;
        begin
            @(negedge clock_i); reset_n_i=0; command_ready_i=0; allow_launch=0; stale_done=0; mock_done=0;
            repeat(3) @(negedge clock_i); reset_n_i=1;
            repeat(3) @(negedge clock_i);
            if (command_start_o || execution_result_valid_o || execution_result_code_o !== 0 ||
                execution_data_o !== 0 || execution_iv_o !== 0 || current_state_o != 0)
                $fatal(1,"Stale execution state after reset");
        end
    endtask
    integer delay_cycles;
    initial begin
        reset_all();
        // Busy worker and stale pre-launch done must not advance or capture.
        use_real=0; allow_launch=0; stale_done=1; mock_code=32'h95;
        admit();
        repeat(9) begin
            @(negedge clock_i);
            if (command_start_o || execution_result_valid_o || response_valid_o || current_state_o!=8)
                $fatal(1,"Busy worker or stale completion advanced execution");
        end
        stale_done=0; allow_launch=1;
        @(negedge clock_i); allow_launch=0;
        // Readiness can change after acceptance; only done completes the job.
        for (delay_cycles=0; delay_cycles<11; delay_cycles++) begin
            @(negedge clock_i);
            allow_launch=delay_cycles%2;
            mock_code=delay_cycles;
            if (command_start_o || response_valid_o || execution_result_valid_o || current_state_o!=8)
                $fatal(1,"Did not wait for delayed worker");
        end
        mock_code=0; mock_data=PLAIN; mock_iv=IV; mock_done=1;
        check_result(0,PLAIN,IV);

        // Preserve every bit of the worker error and discard error payloads.
        allow_launch=1; admit();
        @(negedge clock_i); mock_code=32'h095; mock_data=PLAIN; mock_iv=IV; mock_done=1;
        check_result(32'h095,0,0);

        use_real=1; key_valid=1; mode=1; data_bytes=16; decrypt=0; data=PLAIN; admit();
        check_result(0,CIPHER,CIPHER);
        decrypt=1; data=CIPHER; admit(); check_result(0,PLAIN,CIPHER);
        decrypt=0; data=PLAIN; data_bytes=5; admit();
        check_result(0,128'hdc7e84bfda0000000000000000000000,128'hdc7e84bfda0000000000000000000000);
        data_bytes=0; admit(); check_result(0,0,IV);
        data_bytes=17; admit(); check_result(32'h095,0,0);
        data_bytes=16; key_valid=0; admit(); check_result(32'h09c,0,0);
        key_valid=1; mode=0; admit(); check_result(32'h089,0,0);

        // Abort both a pending launch and an in-flight AES operation.
        mode=1; allow_launch=0; admit(); reset_all();
        allow_launch=1; admit();
        wait(symmetric.CFB_BLOCK.aes_next_r);
        reset_all();
        allow_launch=1; admit(); check_result(0,CIPHER,CIPHER);
        reset_all();
        $display("EXECUTION_SYMMETRIC_PASS (%0d cases, busy/wait/capture and reset recovery)",cases);
        $finish;
    end
    initial begin #1000000; $fatal(1,"Execution integration timed out"); end
endmodule
