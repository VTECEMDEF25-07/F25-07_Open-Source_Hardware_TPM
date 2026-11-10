// Frozen v0.1 integration glue. No protected words enter packet controller.
module demo_crypto_subsystem #(parameter WIDTH=2048, DEMO_PROVIDER_MODE=1, IP_TYPE=0,
 parameter DEVICE_FAMILY="Agilex 5") (
    input wire  clock_i,
    input wire  reset_n_i,
    input wire  start_i,
    input wire  operational_i,
    input wire [15:0] command_tag_i,
    input wire [31:0] command_size_i,
    output wire [11:0] command_addr_o,
    input wire [7:0] command_byte_i,
    output wire  response_valid_o,
    output wire [31:0] response_code_o,
    output wire [11:0] response_length_o,
    input wire [11:0] response_addr_i,
    output wire [7:0] response_byte_o,
    input wire  response_consumed_i,
    output wire  busy_o,
    output wire  scrub_done_o,
    output wire  recovery_required_o,
    input wire  aes_client_active_i,
    input wire  key_request_i,
    output wire  key_request_ready_o,
    input wire [31:0] key_handle_i,
    output wire  key_reply_valid_o,
    input wire  key_reply_ready_i,
    output wire [255:0] resolved_key_o,
    output wire [31:0] key_reply_code_o,
    input wire  supervisor_recovered_i,
    input wire [31:0] supervisor_last_id_i,
    input wire [31:0] supervisor_last_handle_i,
    input wire  supervisor_last_committed_i,
    input wire [3:0] supervisor_last_reason_i,
    output wire  job_accept_o,
    output wire [31:0] job_id_o,
    output wire  commit_o,
    output wire [31:0] commit_handle_o
);
    wire  abort;
    wire [31:0] commit_handle;
    wire [31:0] commit_id;
    wire [1:0] commit_mode;
    wire  commit_ready;
    wire  commit_valid;
    wire  decision_accept;
    wire  decision_ready;
    wire  decision_valid;
    wire [3:0] done_core_status;
    wire [31:0] done_handle;
    wire [31:0] done_id;
    wire [1:0] done_mode;
    wire  done_ownership_committed;
    wire [1:0] done_profile;
    wire  done_ready;
    wire [3:0] done_setup_error;
    wire [3:0] done_teardown_error;
    wire  done_valid;
    wire  gen_available;
    wire  gen_busy;
    wire  gen_recovery_required;
    wire  gen_scrub_done;
    wire [31:0] host_release_handle;
    wire  host_release_ready;
    wire [31:0] host_release_rsp_code;
    wire  host_release_rsp_ready;
    wire  host_release_rsp_valid;
    wire  host_release_valid;
    wire [31:0] job_id;
    wire [1:0] job_mode;
    wire [1:0] job_profile;
    wire  job_ready;
    wire  job_valid;
    wire [11:0] modexp_base_addr;
    wire [11:0] modexp_exponent_addr;
    wire [31:0] modexp_job_id;
    wire  modexp_job_ready;
    wire  modexp_job_valid;
    wire [11:0] modexp_modulus_addr;
    wire [15:0] modexp_operand_bytes;
    wire [11:0] modexp_ram_req_addr;
    wire  modexp_ram_req_ready;
    wire  modexp_ram_req_valid;
    wire [7:0] modexp_ram_req_wdata;
    wire  modexp_ram_req_write;
    wire  modexp_ram_rsp_error;
    wire [7:0] modexp_ram_rsp_rdata;
    wire  modexp_ram_rsp_ready;
    wire  modexp_ram_rsp_valid;
    wire  modexp_recovery_required;
    wire [11:0] modexp_result_addr;
    wire [3:0] modexp_status_code;
    wire [31:0] modexp_status_cycles;
    wire [31:0] modexp_status_id;
    wire  modexp_status_ready;
    wire [15:0] modexp_status_result_bytes;
    wire  modexp_status_valid;
    wire [31:0] op_release_handle;
    wire  op_release_ready;
    wire [31:0] op_release_rsp_code;
    wire  op_release_rsp_ready;
    wire  op_release_rsp_valid;
    wire  op_release_valid;
    wire  ownership_accept;
    wire  ownership_ready;
    wire  ownership_valid;
    wire  ram_clear_done_ready;
    wire  ram_clear_done_valid;
    wire  ram_clear_ready;
    wire  ram_clear_valid;
    wire [11:0] ram_req_addr;
    wire  ram_req_ready;
    wire  ram_req_valid;
    wire [7:0] ram_req_wdata;
    wire  ram_req_write;
    wire  ram_rsp_error;
    wire [7:0] ram_rsp_rdata;
    wire  ram_rsp_ready;
    wire  ram_rsp_valid;
    wire  ram_scrub_done;
    wire  receiver_error;
    wire [3:0] receiver_error_code;
    wire  receiver_ready;
    wire  receiver_scrub_done;
    wire  reserve_demo_use;
    wire [31:0] reserve_id;
    wire [1:0] reserve_mode;
    wire [1:0] reserve_profile;
    wire  reserve_ready;
    wire  reserve_valid;
    wire [2:0] result_component;
    wire  result_component_last;
    wire [31:0] result_data;
    wire  result_discard;
    wire [31:0] result_id;
    wire [6:0] result_index;
    wire  result_last;
    wire  result_ready;
    wire  result_valid;
    wire [31:0] store_release_handle;
    wire  store_release_ready;
    wire [31:0] store_release_rsp_code;
    wire  store_release_rsp_ready;
    wire  store_release_rsp_valid;
    wire  store_release_valid;
    wire  store_use_allowed;

    // Release requests never overlap under global job exclusion; retain response owner.
    reg release_owner_op;
    wire choose_op = op_release_valid;
    assign store_release_valid = op_release_valid || host_release_valid;
    assign store_release_handle = choose_op ? op_release_handle : host_release_handle;
    assign op_release_ready = store_release_ready && choose_op;
    assign host_release_ready = store_release_ready && !choose_op;
    assign op_release_rsp_valid = store_release_rsp_valid && release_owner_op;
    assign host_release_rsp_valid = store_release_rsp_valid && !release_owner_op;
    assign op_release_rsp_code = store_release_rsp_code;
    assign host_release_rsp_code = store_release_rsp_code;
    assign store_release_rsp_ready = release_owner_op ? op_release_rsp_ready : host_release_rsp_ready;
    always @(posedge clock_i or negedge reset_n_i)
        if(!reset_n_i) release_owner_op <= 0;
        else if(store_release_valid && store_release_ready) release_owner_op <= choose_op;
    assign job_accept_o = (job_valid && job_ready) || (modexp_job_valid && modexp_job_ready);
    assign job_id_o = job_valid ? job_id : modexp_job_id;
    assign commit_o = commit_valid && commit_ready;
    assign commit_handle_o = commit_handle;

    demo_keygen_operation #(.DEMO_PROVIDER_MODE(DEMO_PROVIDER_MODE),.IP_TYPE(IP_TYPE),.DEVICE_FAMILY(DEVICE_FAMILY)) u_operation (
        .clock_i(clock_i),
        .reset_n_i(reset_n_i),
        .job_valid_i(job_valid),
        .job_ready_o(job_ready),
        .job_profile_i(job_profile),
        .job_mode_i(job_mode),
        .job_id_i(job_id),
        .done_valid_o(done_valid),
        .done_ready_i(done_ready),
        .done_id_o(done_id),
        .done_profile_o(done_profile),
        .done_mode_o(done_mode),
        .done_core_status_o(done_core_status),
        .done_setup_error_o(done_setup_error),
        .done_teardown_error_o(done_teardown_error),
        .done_ownership_committed_o(done_ownership_committed),
        .done_handle_o(done_handle),
        .busy_o(gen_busy),
        .available_o(gen_available),
        .recovery_required_o(gen_recovery_required),
        .scrub_done_o(gen_scrub_done),
        .abort_o(abort),
        .reserve_valid_o(reserve_valid),
        .reserve_ready_i(reserve_ready),
        .reserve_profile_o(reserve_profile),
        .reserve_mode_o(reserve_mode),
        .reserve_id_o(reserve_id),
        .reserve_demo_use_o(reserve_demo_use),
        .receiver_ready_i(receiver_ready),
        .receiver_error_i(receiver_error),
        .receiver_error_code_i(receiver_error_code),
        .receiver_scrub_done_i(receiver_scrub_done),
        .result_valid_o(result_valid),
        .result_ready_i(result_ready),
        .result_data_o(result_data),
        .result_component_o(result_component),
        .result_index_o(result_index),
        .result_component_last_o(result_component_last),
        .result_last_o(result_last),
        .result_id_o(result_id),
        .result_discard_o(result_discard),
        .decision_valid_o(decision_valid),
        .decision_ready_i(decision_ready),
        .decision_accept_o(decision_accept),
        .ownership_valid_i(ownership_valid),
        .ownership_ready_o(ownership_ready),
        .ownership_accept_i(ownership_accept),
        .commit_valid_i(commit_valid),
        .commit_ready_o(commit_ready),
        .commit_handle_i(commit_handle),
        .commit_id_i(commit_id),
        .commit_mode_i(commit_mode),
        .release_valid_o(op_release_valid),
        .release_ready_i(op_release_ready),
        .release_handle_o(op_release_handle),
        .release_rsp_valid_i(op_release_rsp_valid),
        .release_rsp_ready_o(op_release_rsp_ready),
        .release_rsp_code_i(op_release_rsp_code)
    );
    demo_volatile_store u_store (
        .clock_i(clock_i),
        .reset_n_i(reset_n_i),
        .reserve_valid_i(reserve_valid),
        .reserve_ready_o(reserve_ready),
        .reserve_profile_i(reserve_profile),
        .reserve_id_i(reserve_id),
        .reserve_mode_i(reserve_mode),
        .reserve_demo_use_i(reserve_demo_use),
        .receiver_ready_o(receiver_ready),
        .receiver_error_o(receiver_error),
        .receiver_error_code_o(receiver_error_code),
        .receiver_scrub_done_o(receiver_scrub_done),
        .abort_i(abort),
        .result_valid_i(result_valid),
        .result_ready_o(result_ready),
        .result_data_i(result_data),
        .result_component_i(result_component),
        .result_index_i(result_index),
        .result_component_last_i(result_component_last),
        .result_last_i(result_last),
        .result_id_i(result_id),
        .result_discard_i(result_discard),
        .decision_valid_i(decision_valid),
        .decision_ready_o(decision_ready),
        .decision_accept_i(decision_accept),
        .ownership_valid_o(ownership_valid),
        .ownership_ready_i(ownership_ready),
        .ownership_accept_o(ownership_accept),
        .commit_valid_o(commit_valid),
        .commit_ready_i(commit_ready),
        .commit_handle_o(commit_handle),
        .commit_id_o(commit_id),
        .commit_mode_o(commit_mode),
        .release_valid_i(store_release_valid),
        .release_ready_o(store_release_ready),
        .release_handle_i(store_release_handle),
        .release_rsp_valid_o(store_release_rsp_valid),
        .release_rsp_ready_i(store_release_rsp_ready),
        .release_rsp_code_o(store_release_rsp_code),
        .key_request_i(key_request_i),
        .key_request_ready_o(key_request_ready_o),
        .key_handle_i(key_handle_i),
        .key_reply_valid_o(key_reply_valid_o),
        .key_reply_ready_i(key_reply_ready_i),
        .resolved_key_o(resolved_key_o),
        .key_reply_code_o(key_reply_code_o),
        .use_allowed_i(store_use_allowed),
        .client_active_i(aes_client_active_i)
    );
    demo_byte_ram u_ram (
        .clock_i(clock_i),
        .reset_n_i(reset_n_i),
        .ram_req_valid_i(ram_req_valid),
        .ram_req_ready_o(ram_req_ready),
        .ram_req_write_i(ram_req_write),
        .ram_req_addr_i(ram_req_addr),
        .ram_req_wdata_i(ram_req_wdata),
        .ram_rsp_valid_o(ram_rsp_valid),
        .ram_rsp_ready_i(ram_rsp_ready),
        .ram_rsp_rdata_o(ram_rsp_rdata),
        .ram_rsp_error_o(ram_rsp_error),
        .access_allowed_i(1'b1),
        .clear_valid_i(ram_clear_valid),
        .clear_ready_o(ram_clear_ready),
        .clear_done_valid_o(ram_clear_done_valid),
        .clear_done_ready_i(ram_clear_done_ready),
        .scrub_done_o(ram_scrub_done)
    );
    execution_engine_demo_packet #(.WIDTH(WIDTH),.DEMO_PROVIDER_MODE(DEMO_PROVIDER_MODE)) u_packet (
        .clock_i(clock_i),
        .reset_n_i(reset_n_i),
        .start_i(start_i),
        .operational_i(operational_i),
        .command_tag_i(command_tag_i),
        .command_size_i(command_size_i),
        .command_addr_o(command_addr_o),
        .command_byte_i(command_byte_i),
        .response_valid_o(response_valid_o),
        .response_code_o(response_code_o),
        .response_length_o(response_length_o),
        .response_addr_i(response_addr_i),
        .response_byte_o(response_byte_o),
        .response_consumed_i(response_consumed_i),
        .supervisor_recovered_i(supervisor_recovered_i),
        .supervisor_last_committed_i(supervisor_last_committed_i),
        .supervisor_last_id_i(supervisor_last_id_i),
        .supervisor_last_handle_i(supervisor_last_handle_i),
        .supervisor_last_reason_i(supervisor_last_reason_i),
        .busy_o(busy_o),
        .scrub_done_o(scrub_done_o),
        .recovery_required_o(recovery_required_o),
        .aes_client_active_i(aes_client_active_i),
        .store_use_allowed_o(store_use_allowed),
        .gen_job_valid_o(job_valid),
        .gen_job_ready_i(job_ready),
        .gen_job_profile_o(job_profile),
        .gen_job_mode_o(job_mode),
        .gen_job_id_o(job_id),
        .gen_done_valid_i(done_valid),
        .gen_done_ready_o(done_ready),
        .gen_done_id_i(done_id),
        .gen_done_handle_i(done_handle),
        .gen_done_profile_i(done_profile),
        .gen_done_mode_i(done_mode),
        .gen_done_core_status_i(done_core_status),
        .gen_done_setup_error_i(done_setup_error),
        .gen_done_teardown_error_i(done_teardown_error),
        .gen_done_ownership_committed_i(done_ownership_committed),
        .gen_busy_i(gen_busy),
        .gen_available_i(gen_available),
        .gen_recovery_required_i(gen_recovery_required),
        .gen_scrub_done_i(gen_scrub_done),
        .release_valid_o(host_release_valid),
        .release_ready_i(host_release_ready),
        .release_handle_o(host_release_handle),
        .release_rsp_valid_i(host_release_rsp_valid),
        .release_rsp_ready_o(host_release_rsp_ready),
        .release_rsp_code_i(host_release_rsp_code),
        .modexp_job_valid_o(modexp_job_valid),
        .modexp_job_ready_i(modexp_job_ready),
        .modexp_job_id_o(modexp_job_id),
        .modexp_base_addr_o(modexp_base_addr),
        .modexp_exponent_addr_o(modexp_exponent_addr),
        .modexp_modulus_addr_o(modexp_modulus_addr),
        .modexp_result_addr_o(modexp_result_addr),
        .modexp_operand_bytes_o(modexp_operand_bytes),
        .modexp_status_valid_i(modexp_status_valid),
        .modexp_status_ready_o(modexp_status_ready),
        .modexp_status_id_i(modexp_status_id),
        .modexp_status_cycles_i(modexp_status_cycles),
        .modexp_status_code_i(modexp_status_code),
        .modexp_status_result_bytes_i(modexp_status_result_bytes),
        .modexp_recovery_required_i(modexp_recovery_required),
        .modexp_ram_req_valid_i(modexp_ram_req_valid),
        .modexp_ram_req_ready_o(modexp_ram_req_ready),
        .modexp_ram_req_write_i(modexp_ram_req_write),
        .modexp_ram_req_addr_i(modexp_ram_req_addr),
        .modexp_ram_req_wdata_i(modexp_ram_req_wdata),
        .modexp_ram_rsp_valid_o(modexp_ram_rsp_valid),
        .modexp_ram_rsp_ready_i(modexp_ram_rsp_ready),
        .modexp_ram_rsp_rdata_o(modexp_ram_rsp_rdata),
        .modexp_ram_rsp_error_o(modexp_ram_rsp_error),
        .ram_req_valid_o(ram_req_valid),
        .ram_req_ready_i(ram_req_ready),
        .ram_req_write_o(ram_req_write),
        .ram_req_addr_o(ram_req_addr),
        .ram_req_wdata_o(ram_req_wdata),
        .ram_rsp_valid_i(ram_rsp_valid),
        .ram_rsp_ready_o(ram_rsp_ready),
        .ram_rsp_rdata_i(ram_rsp_rdata),
        .ram_rsp_error_i(ram_rsp_error),
        .ram_clear_valid_o(ram_clear_valid),
        .ram_clear_ready_i(ram_clear_ready),
        .ram_clear_done_valid_i(ram_clear_done_valid),
        .ram_clear_done_ready_o(ram_clear_done_ready),
        .ram_scrub_done_i(ram_scrub_done)
    );
    demo_modexp_adapter #(.WIDTH(WIDTH),.RAM_ADDR_WIDTH(12)) u_modexp (
        .clock_i(clock_i),
        .reset_n_i(reset_n_i),
        .job_valid_i(modexp_job_valid),
        .job_ready_o(modexp_job_ready),
        .job_id_i(modexp_job_id),
        .base_addr_i(modexp_base_addr),
        .exponent_addr_i(modexp_exponent_addr),
        .modulus_addr_i(modexp_modulus_addr),
        .result_addr_i(modexp_result_addr),
        .operand_bytes_i(modexp_operand_bytes),
        .ram_req_valid_o(modexp_ram_req_valid),
        .ram_req_ready_i(modexp_ram_req_ready),
        .ram_req_write_o(modexp_ram_req_write),
        .ram_req_addr_o(modexp_ram_req_addr),
        .ram_req_wdata_o(modexp_ram_req_wdata),
        .ram_rsp_valid_i(modexp_ram_rsp_valid),
        .ram_rsp_ready_o(modexp_ram_rsp_ready),
        .ram_rsp_rdata_i(modexp_ram_rsp_rdata),
        .ram_rsp_error_i(modexp_ram_rsp_error),
        .status_valid_o(modexp_status_valid),
        .status_ready_i(modexp_status_ready),
        .status_id_o(modexp_status_id),
        .status_code_o(modexp_status_code),
        .status_result_bytes_o(modexp_status_result_bytes),
        .status_cycles_o(modexp_status_cycles),
        .recovery_required_o(modexp_recovery_required)
    );
endmodule
