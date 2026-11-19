`timescale 1ns/1ps
// AES128 is a private decoded-worker configuration, never a packet profile.
module tb_aes128_generated_slot;
    reg clk=0; always #5 clk=~clk;
    reg rst=0, generate_key=0, generation_ack=0, destroy=0;
    wire generation_ready, generation_done, slot_valid, reserved;
    wire [3:0] generation_code;
    wire random_request;
    reg random_valid=0;
    localparam [255:0] RNG=256'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f;
    localparam [127:0] IV=128'h101112131415161718191a1b1c1d1e1f;
    reg [7:0] oracle[0:1023], memory[0:127]; reg [1023:0] oracle_path;
    integer cycles=0, scenarios=0, reads=0, writes=0, stalls=0;
    wire request_key, request_ready, reply_key, reply_ready;
    reg finish=0;
    wire [31:0] key_handle, key_code;
    wire [255:0] key_data;
    execution_engine #(.ENABLE_INTERNAL_KEYGEN(1), .ENABLE_AES_SLOT_CONSUMER(1), .AES_SLOT_KEY_BITS(128)) engine (
        .clock_i(clk), .reset_n_i(rst), .command_ready_i(1'b0), .command_done_i(1'b1),
        .command_tag_i(16'h8001), .command_code_i(32'd0), .command_size_i(32'd0), .op_state_i(3'd3),
        .response_addr_i(12'd0), .random_i(RNG), .random_valid_i(random_valid), .random_request_o(random_request),
        .rng_fault_i(1'b0), .hash_grant_i(1'b0), .hash_ready_i(1'b0), .hash_digest_i(256'd0), .hash_digest_valid_i(1'b0),
        .keygen_request_i(generate_key), .keygen_ready_o(generation_ready), .keygen_profile_i(2'd0),
        .keygen_id_i(32'd128), .keygen_allow_i(1'b1), .keygen_completion_o(generation_done),
        .keygen_completion_ready_i(generation_ack), .keygen_code_o(generation_code), .keygen_release_i(destroy),
        .keygen_slot_valid_o(slot_valid), .keygen_private_address_i(8'd0),
        .keygen_result_enable_i(1'b1), .keygen_ownership_enable_i(1'b1), .keygen_terminal_enable_i(1'b1),
        .aes_slot_request_i(request_key), .aes_slot_request_ready_o(request_ready),
        .aes_slot_handle_i(key_handle), .aes_slot_allow_i(1'b1),
        .aes_slot_reply_o(reply_key), .aes_slot_reply_ready_i(reply_ready), .aes_slot_key_o(key_data),
        .aes_slot_code_o(key_code), .aes_slot_release_i(finish), .aes_slot_reserved_o(reserved));
    always @(posedge clk) begin cycles<=cycles+1; random_valid<=rst && random_request && cycles%7==0; end
    reg start=0, decrypt=0;
    reg [31:0] length=40;
    wire aes_start, aes_busy, aes_done, done, busy, direction;
    wire [255:0] aes_key; wire [127:0] aes_iv, aes_final_iv, response_iv;
    wire [31:0] aes_length, completed, response_code, response_length;
    wire [11:0] aes_rc; wire [2:0] mode;
    wire [6:0] input_base, output_base;
    execution_engine_encryptdecrypt2 #(.RAM_ADDR_WIDTH(7)) job (
        .clock_i(clk), .reset_n_i(rst), .start_i(start), .key_handle_i(32'h80000000), .data_length_i(length),
        .input_base_i(7'd0), .output_base_i(7'd64), .iv_i(IV), .decrypt_i(decrypt), .mode_i(3'd1),
        .key_request_o(request_key), .key_request_ready_i(request_ready), .key_handle_o(key_handle),
        .key_reply_valid_i(reply_key), .key_reply_ready_o(reply_ready), .resolved_key_i(key_data), .key_reply_code_i(key_code),
        .aes_start_o(aes_start), .aes_key_o(aes_key), .aes_iv_o(aes_iv), .aes_decrypt_o(direction),
        .aes_mode_o(mode), .aes_input_base_o(input_base), .aes_output_base_o(output_base), .aes_length_o(aes_length),
        .aes_busy_i(aes_busy), .aes_done_i(aes_done), .aes_rc_i(aes_rc), .aes_final_iv_i(aes_final_iv),
        .aes_completed_length_i(completed), .busy_o(busy), .done_o(done),
        .response_code_o(response_code), .response_length_o(response_length), .response_iv_o(response_iv));
    wire req, ready, write, rsp_ready;
    wire [6:0] address; wire [7:0] write_data;
    reg rsp_valid=0; reg [7:0] read_data=0;
    symm_top #(.RAM_ADDR_WIDTH(7), .AES_KEY_BITS(128), .MAX_SYM_DATA_BYTES(64), .MAX_SECRET_BYTES(32), .MAX_NONCE_BYTES(32)) aes (
        .clock_i(clk), .reset_n_i(rst), .start_i(aes_start), .command_code_i(16'h0193), .key_valid_i(1'b1),
        .session_protect_i(1'b0), .session_valid_i(1'b0), .session_decrypt_i(1'b0), .session_encrypt_i(1'b0),
        .session_use_xor_i(1'b0), .mode_i(mode), .session_value_i(256'd0), .session_value_bytes_i(16'd0),
        .nonce_newer_i(256'd0), .nonce_older_i(256'd0), .nonce_newer_bytes_i(16'd0), .nonce_older_bytes_i(16'd0),
        .hmac_key_ready_i(1'b0), .hmac_message_ready_i(1'b0), .hmac_busy_i(1'b0), .hmac_digest_i(256'd0), .hmac_digest_valid_i(1'b0),
        .key_i(aes_key), .iv_i(aes_iv), .decrypt_i(direction), .input_base_i(input_base), .output_base_i(output_base),
        .data_length_i(aes_length), .busy_o(aes_busy), .done_o(aes_done), .tpm_rc_o(aes_rc),
        .final_iv_o(aes_final_iv), .completed_length_o(completed),
        .ram_req_valid_o(req), .ram_req_ready_i(ready), .ram_req_write_o(write), .ram_req_addr_o(address),
        .ram_req_data_o(write_data), .ram_rsp_valid_i(rsp_valid), .ram_rsp_ready_o(rsp_ready),
        .ram_rsp_data_i(read_data), .ram_rsp_error_i(1'b0));
    assign ready=rst && !rsp_valid && cycles%5!=0;
    always @(posedge clk) begin
        if(!rst) begin rsp_valid<=0; read_data<=0; end
        else begin
            if(rsp_valid && rsp_ready) begin rsp_valid<=0; read_data<=0; end
            if(req && !ready) stalls<=stalls+1;
            if(req && ready) begin
                rsp_valid<=1;
                if(write) begin memory[address]<=write_data; writes<=writes+1; end
                else begin read_data<=memory[address]; reads<=reads+1; end
            end
        end
    end
    initial begin
        if(!$value$plusargs("ORACLE=%s",oracle_path)) $fatal(1,"oracle missing");
        $readmemh(oracle_path,oracle);
        repeat(3)@(negedge clk); rst=1; wait(generation_ready); @(negedge clk);
        generate_key=1; @(negedge clk); generate_key=0;
        wait(generation_done); if(generation_code || !slot_valid) $fatal(1,"AES128 generation");
        @(negedge clk); generation_ack=1; @(negedge clk); generation_ack=0;
        for(integer t=0;t<8;t++) begin
            reg [127:0] expected_iv;
            integer n, base, bytes;
            case(t/2) 0:n=0;1:n=1;2:n=16;3:n=40;endcase
            wait(!busy && request_ready && !reserved); @(negedge clk);
            length=n; decrypt=t%2;
            for(integer j=0;j<128;j++) memory[j]=8'ha5;
            for(integer j=0;j<n;j++) memory[j]=decrypt ? oracle[j] : j;
            start=1; @(negedge clk); start=0;
            wait(done); #1;
            if(response_code || response_length!=n || !reserved) $fatal(1,"decoded AES128 status");
            expected_iv=IV;
            if(n!=0) begin expected_iv=0; base=((n-1)/16)*16; bytes=n-base;
                for(integer j=0;j<bytes;j++) expected_iv[127-j*8 -:8]=oracle[base+j]; end
            if(response_iv!==expected_iv) $fatal(1,"AES128 IV oracle");
            for(integer j=0;j<64;j++)
                if(memory[64+j]!==(j<n ? (decrypt ? (j & 255) : oracle[j]) : 8'ha5)) $fatal(1,"AES128 output/guard");
            repeat(10)@(negedge clk);
            if(aes_key!==0 || key_data!==0 || aes.CONTROLLER.cfb_key_o!==0 || aes.WORKER.aes_key_r!==0)
                $fatal(1,"AES128 key copy erasure");
            // The private decoded caller owns these two disjoint RAM spans.
            // Clear its spans before relinquishing; untouched guards stay a5.
            for(integer j=0;j<n;j++) begin memory[j]=0; memory[64+j]=0; end
            finish=1; @(negedge clk); finish=0; wait(!reserved);
            scenarios=scenarios+1;
        end
        wait(request_ready); @(negedge clk); destroy=1; @(negedge clk); destroy=0; wait(generation_ready);
        for(integer j=0;j<129;j++) if(engine.keygen_enabled.protected_keygen.slot[j]!==0) $fatal(1,"AES128 slot erase");
        $display("AES128_GENERATED_SLOT_PASS scenarios=%0d reads=%0d writes=%0d stalls=%0d cycles=%0d",scenarios,reads,writes,stalls,cycles);
        $finish;
    end
    initial begin #2000000; $fatal(1,"AES128 cycle deadline"); end
endmodule
