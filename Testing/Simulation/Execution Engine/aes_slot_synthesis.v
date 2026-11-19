// Enabled composition for synthesis ONLY. No board programming or host key port.
// Inputs retain the worker, reservation and packet datapath through synthesis.
module aes_slot_synthesis #(
    parameter IP_TYPE=1, parameter DEVICE_FAMILY="Cyclone V"
)(
    input wire clock_i, reset_n_i,
    input wire keygen_request_i, keygen_ack_i, keygen_destroy_i, keygen_allow_i,
    input wire [1:0] keygen_profile_i, input wire [31:0] keygen_id_i,
    output wire keygen_ready_o, keygen_completion_o, keygen_slot_valid_o,
    output wire [3:0] keygen_code_o,
    input wire [255:0] random_i, input wire random_valid_i, rng_fault_i,
    output wire random_request_o, rng_timeout_o,
    input wire command_start_i, operational_i, use_allow_i, response_consumed_i,
    input wire [15:0] command_tag_i, input wire [31:0] command_size_i,
    output wire [11:0] command_addr_o, input wire [7:0] command_byte_i,
    output wire response_valid_o, output wire [31:0] response_code_o,
    output wire [11:0] response_length_o, input wire [11:0] response_addr_i,
    output wire [7:0] response_byte_o, output wire busy_o, reserved_o
);
    wire request_key, request_ready, reply_key, reply_ready, finish;
    wire [31:0] handle, code;
    wire [255:0] key;
    execution_engine #(.ENABLE_INTERNAL_KEYGEN(1), .ENABLE_AES_SLOT_CONSUMER(1),
        .IP_TYPE(IP_TYPE), .DEVICE_FAMILY(DEVICE_FAMILY)) engine (
        .clock_i(clock_i), .reset_n_i(reset_n_i), .command_ready_i(1'b0), .command_done_i(1'b1),
        .command_tag_i(16'h8001), .command_code_i(32'd0), .command_size_i(32'd0), .op_state_i(3'd3),
        .response_addr_i(12'd0), .random_i(random_i), .random_valid_i(random_valid_i),
        .random_request_o(random_request_o), .rng_fault_i(rng_fault_i), .rng_timeout_o(rng_timeout_o),
        .hash_grant_i(1'b0), .hash_ready_i(1'b0), .hash_digest_i(256'd0), .hash_digest_valid_i(1'b0),
        .keygen_request_i(keygen_request_i), .keygen_ready_o(keygen_ready_o),
        .keygen_profile_i(keygen_profile_i), .keygen_id_i(keygen_id_i), .keygen_allow_i(keygen_allow_i),
        .keygen_completion_o(keygen_completion_o), .keygen_completion_ready_i(keygen_ack_i),
        .keygen_code_o(keygen_code_o), .keygen_release_i(keygen_destroy_i), .keygen_slot_valid_o(keygen_slot_valid_o),
        .keygen_private_address_i(8'd0), .keygen_result_enable_i(1'b1), .keygen_ownership_enable_i(1'b1), .keygen_terminal_enable_i(1'b1),
        .aes_slot_request_i(request_key), .aes_slot_request_ready_o(request_ready), .aes_slot_handle_i(handle),
        .aes_slot_allow_i(use_allow_i), .aes_slot_reply_o(reply_key), .aes_slot_reply_ready_i(reply_ready),
        .aes_slot_key_o(key), .aes_slot_code_o(code), .aes_slot_release_i(finish), .aes_slot_reserved_o(reserved_o));
    execution_engine_aes_packet packet (
        .clock_i(clock_i), .reset_n_i(reset_n_i), .start_i(command_start_i), .operational_i(operational_i),
        .response_consumed_i(response_consumed_i), .busy_o(busy_o), .key_release_o(finish),
        .command_tag_i(command_tag_i), .command_size_i(command_size_i),
        .command_addr_o(command_addr_o), .command_byte_i(command_byte_i),
        .response_valid_o(response_valid_o), .response_code_o(response_code_o), .response_length_o(response_length_o),
        .response_addr_i(response_addr_i), .response_byte_o(response_byte_o),
        .key_request_o(request_key), .key_request_ready_i(request_ready), .key_handle_o(handle),
        .key_reply_valid_i(reply_key), .key_reply_ready_o(reply_ready), .resolved_key_i(key), .key_reply_code_i(code));
endmodule
