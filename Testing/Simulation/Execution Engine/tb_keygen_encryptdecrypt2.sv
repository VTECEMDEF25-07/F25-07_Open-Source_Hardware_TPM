`timescale 1ns/1ps
module tb_keygen_encryptdecrypt2;
    localparam [31:0] TEST_HANDLE = 32'h80000000;
    localparam [255:0] TEST_WORDS = 256'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f;
    localparam [127:0] START_IV = 128'h101112131415161718191a1b1c1d1e1f;
    localparam [319:0] CIPHERTEXT = 320'he9c2ed89b63155e1f87d96dd3aeaa6815992bae8ff869e17a1af95bd78d810cef497f7aca9d80b4f;
    localparam [127:0] FEEDBACK = 128'hf497f7aca9d80b4f0000000000000000;
    reg clock_i=0, reset_n_i=0, passed=0;
    always #5 clock_i=~clock_i;

    reg generate_key=0;
    wire keygen_ready, generation_ready, result_valid, ownership_ready, status_valid;
    wire [31:0] result_data, result_id, status_id;
    wire [6:0] result_index;
    wire [2:0] result_component;
    wire result_last, result_component_last, result_discard;
    wire [3:0] status_code;
    integer words_sent=0, words_received=0;
    reg [255:0] candidate_key=0, stored_key=0;
    reg slot_valid=0;

    keygen_core keygen (
        .clock_i(clock_i), .reset_n_i(reset_n_i), .peers_ready_i(1'b1),
        .request_valid_i(generate_key), .request_ready_o(keygen_ready),
        .request_profile_i(2'd1), .request_id_i(32'd42),
        .generation_valid_i(words_sent < 8), .generation_ready_o(generation_ready),
        .generation_data_i(words_sent < 8 ? TEST_WORDS[255-words_sent*32 -: 32] : 32'd0),
        .generation_failed_i(1'b0),
        .result_valid_o(result_valid), .result_ready_i(1'b1),
        .result_data_o(result_data), .result_component_o(result_component),
        .result_index_o(result_index), .result_component_last_o(result_component_last),
        .result_last_o(result_last), .result_id_o(result_id),
        .ownership_valid_i(words_received == 8), .ownership_ready_o(ownership_ready),
        .ownership_accept_i(1'b1), .result_discard_o(result_discard),
        .status_valid_o(status_valid), .status_ready_i(1'b1),
        .status_code_o(status_code), .status_id_o(status_id)
    );

    // Only the key handed off by keygen is stored in the test slot.
    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            words_sent <= 0;
            words_received <= 0;
            candidate_key <= 0;
            stored_key <= 0;
            slot_valid <= 0;
        end else begin
            if (generation_ready && words_sent < 8) words_sent <= words_sent+1;
            if (result_valid) begin
                if (result_component != 1 || result_index != words_received || result_id != 42 ||
                    result_last !== (words_received == 7) || result_component_last !== result_last)
                    $fatal(1,"Unexpected AES keygen result metadata");
                candidate_key <= {candidate_key[223:0],result_data};
                words_received <= words_received+1;
            end
            if (ownership_ready && words_received == 8) begin
                stored_key <= candidate_key;
                candidate_key <= 0;
            end
            if (result_discard) $fatal(1,"Keygen discarded the result");
            if (status_valid) begin
                if (status_code != 0 || status_id != 42 || stored_key !== TEST_WORDS)
                    $fatal(1,"AES keygen handoff failed");
                slot_valid <= 1;
            end
        end
    end

    reg start=0, decrypt=0, allow_use=0;
    reg [31:0] handle=0;
    reg [6:0] input_base=0, output_base=0;
    wire key_request, key_reply_ready;
    wire [31:0] lookup_handle;
    reg key_reply_valid=0;
    reg [31:0] key_reply_code=0;
    wire [255:0] aes_key;
    wire [127:0] aes_iv, aes_final_iv, response_iv;
    wire aes_start, aes_decrypt, aes_busy, aes_done;
    wire [2:0] aes_mode;
    wire [6:0] aes_input_base, aes_output_base;
    wire [31:0] aes_length, aes_completed_length, response_code, response_length;
    wire [11:0] aes_rc;
    wire busy, done;
    integer aes_jobs=0;

    // Test-only object/authorization service. A matching handle and permission
    // are separate checks. The board's host path has no connection to this slot.
    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            key_reply_valid <= 0;
            key_reply_code <= 0;
            aes_jobs <= 0;
        end else begin
            if (key_request && !key_reply_valid) begin
                key_reply_valid <= 1;
                if (!slot_valid || lookup_handle != TEST_HANDLE)
                    key_reply_code <= 32'h18b;
                else if (!allow_use)
                    key_reply_code <= 32'h9a2;
                else key_reply_code <= 0;
            end else if (key_reply_ready)
                key_reply_valid <= 0;
            if (aes_start) aes_jobs <= aes_jobs+1;
        end
    end

    execution_engine_encryptdecrypt2 #(.RAM_ADDR_WIDTH(7)) engine (
        .clock_i(clock_i), .reset_n_i(reset_n_i), .start_i(start),
        .key_handle_i(handle), .data_length_i(32'd40),
        .input_base_i(input_base), .output_base_i(output_base),
        .iv_i(START_IV), .decrypt_i(decrypt), .mode_i(3'd1),
        .key_request_o(key_request), .key_request_ready_i(!key_reply_valid),
        .key_handle_o(lookup_handle), .key_reply_valid_i(key_reply_valid),
        .key_reply_ready_o(key_reply_ready),
        .resolved_key_i(key_reply_code == 0 ? stored_key : 256'd0),
        .key_reply_code_i(key_reply_code),
        .aes_start_o(aes_start), .aes_key_o(aes_key), .aes_iv_o(aes_iv),
        .aes_decrypt_o(aes_decrypt), .aes_mode_o(aes_mode),
        .aes_input_base_o(aes_input_base), .aes_output_base_o(aes_output_base),
        .aes_length_o(aes_length), .aes_busy_i(aes_busy), .aes_done_i(aes_done),
        .aes_rc_i(aes_rc), .aes_final_iv_i(aes_final_iv),
        .aes_completed_length_i(aes_completed_length),
        .busy_o(busy), .done_o(done), .response_code_o(response_code),
        .response_length_o(response_length), .response_iv_o(response_iv)
    );

    wire ram_req_valid, ram_req_ready, ram_req_write, ram_rsp_valid, ram_rsp_ready, ram_rsp_error;
    wire [6:0] ram_addr;
    wire [7:0] ram_write, ram_read;
    symm_top #(.MAX_SYM_DATA_BYTES(64), .RAM_ADDR_WIDTH(7),
        .MAX_SECRET_BYTES(32), .MAX_NONCE_BYTES(32)) aes (
        .clock_i(clock_i), .reset_n_i(reset_n_i), .start_i(aes_start),
        .command_code_i(16'h0193), .key_valid_i(1'b1), .session_protect_i(1'b0),
        .session_valid_i(1'b0), .session_decrypt_i(1'b0), .session_encrypt_i(1'b0),
        .session_use_xor_i(1'b0), .mode_i(aes_mode),
        .session_value_i(256'd0), .session_value_bytes_i(16'd0),
        .nonce_newer_i(256'd0), .nonce_older_i(256'd0),
        .nonce_newer_bytes_i(16'd0), .nonce_older_bytes_i(16'd0),
        .hmac_start_o(), .hmac_key_data_o(), .hmac_message_data_o(),
        .hmac_key_valid_o(), .hmac_key_end_o(), .hmac_key_ready_i(1'b0),
        .hmac_message_valid_o(), .hmac_message_end_o(), .hmac_message_ready_i(1'b0),
        .hmac_busy_i(1'b0), .hmac_digest_i(256'd0), .hmac_digest_valid_i(1'b0),
        .hmac_digest_ready_o(),
        .key_i(aes_key), .iv_i(aes_iv), .decrypt_i(aes_decrypt),
        .input_base_i(aes_input_base), .output_base_i(aes_output_base),
        .data_length_i(aes_length), .busy_o(aes_busy), .done_o(aes_done),
        .error_o(), .tpm_rc_o(aes_rc), .final_iv_o(aes_final_iv),
        .completed_length_o(aes_completed_length),
        .ram_req_valid_o(ram_req_valid), .ram_req_ready_i(ram_req_ready),
        .ram_req_write_o(ram_req_write), .ram_req_addr_o(ram_addr), .ram_req_data_o(ram_write),
        .ram_rsp_valid_i(ram_rsp_valid), .ram_rsp_ready_o(ram_rsp_ready),
        .ram_rsp_data_i(ram_read), .ram_rsp_error_i(ram_rsp_error)
    );
    symmetric_test_ram #(.ADDR_WIDTH(7)) ram (
        .clock_i(clock_i), .reset_n_i(reset_n_i),
        .req_valid_i(ram_req_valid), .req_ready_o(ram_req_ready),
        .req_write_i(ram_req_write), .req_addr_i(ram_addr), .req_data_i(ram_write),
        .rsp_valid_o(ram_rsp_valid), .rsp_ready_i(ram_rsp_ready),
        .rsp_data_o(ram_read), .rsp_error_o(ram_rsp_error)
    );

    task automatic execute(input [31:0] id, input bit allowed, direction,
                           input [6:0] source, destination, input [31:0] expected_code);
        integer previous_jobs, previous_accesses;
        begin
            while (busy) @(negedge clock_i);
            previous_jobs=aes_jobs;
            previous_accesses=ram.transaction_count;
            handle=id; allow_use=allowed; decrypt=direction;
            input_base=source; output_base=destination;
            start=1;
            @(negedge clock_i);
            start=0; handle=~id; decrypt=!direction;
            input_base=~source; output_base=~destination;
            while (!done) @(negedge clock_i);
            if (response_code !== expected_code || aes_key !== 256'd0)
                $fatal(1,"Wrong engine status or key not cleared");
            if (expected_code != 0) begin
                if (aes_jobs != previous_jobs || ram.transaction_count != previous_accesses ||
                    response_length !== 0 || response_iv !== 0)
                    $fatal(1,"Rejected job reached AES or the buffer");
            end else if (aes_jobs != previous_jobs+1 || response_length !== 40 || response_iv !== FEEDBACK)
                $fatal(1,"Wrong AES completion metadata");
        end
    endtask

    initial begin
        repeat (3) @(negedge clock_i);
        reset_n_i=1;
        execute(TEST_HANDLE,1,0,0,64,32'h18b);
        while (!keygen_ready) @(negedge clock_i);
        generate_key=1;
        @(negedge clock_i); generate_key=0;
        while (!slot_valid) @(negedge clock_i);

        for (integer i=0;i<40;i++) ram.memory[i]=i[7:0];
        execute(TEST_HANDLE+1,1,0,0,64,32'h18b);
        execute(TEST_HANDLE,0,0,0,64,32'h9a2);
        execute(TEST_HANDLE,1,0,0,64,0);
        for (integer i=0;i<40;i++)
            if (ram.memory[64+i] !== CIPHERTEXT[319-i*8 -: 8])
                $fatal(1,"Ciphertext mismatch at byte %0d",i);
        execute(TEST_HANDLE,1,1,64,0,0);
        for (integer i=0;i<40;i++)
            if (ram.memory[i] !== i[7:0]) $fatal(1,"Plaintext mismatch at byte %0d",i);
        passed=1;
        $display("KEYGEN_ENCRYPTDECRYPT2_PASS");
        $finish;
    end

    initial begin #1000000; $fatal(1,"Keygen-to-AES timeout"); end
endmodule
