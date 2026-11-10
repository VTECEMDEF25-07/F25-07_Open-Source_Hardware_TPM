// Customer v2 service hub: one protected generation/private-math fabric.
// Packet owns framing; keys stay in the protected service except explicit demo AES export.
// Codex-assisted implementation, 2026-11-10. response_length_o is PAYLOAD ONLY.
`timescale 1ns/1ps
`default_nettype none
module customer_crypto_subsystem #(parameter WIDTH=2048, DEMO_PROVIDER_MODE=0, IP_TYPE=0,
 parameter DEMO_AES_EXPORT_ENABLE=0,
 parameter DEVICE_FAMILY="Agilex 5") (
    input wire  clock_i,
    input wire  reset_n_i,
    input wire  recovery_pending_i,
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
    output wire [31:0] commit_handle_o,
    output wire [31:0] snapshot_status_word_o,
    output wire [31:0] snapshot_operation_id_o,
    output wire [31:0] snapshot_sequence_o,
    output wire [511:0] metrics_snapshot_o
);
    wire aes_active;
    wire gen_abort;
    wire lease_active;
    wire lease_close_ready;
    wire lease_close_rsp_ready;
    wire lease_close_rsp_valid;
    wire lease_close_valid;
    wire [31:0] lease_cmd_arg0;
    wire [31:0] lease_cmd_arg1;
    wire [31:0] lease_cmd_arg2;
    wire [31:0] lease_cmd_arg3;
    wire [7:0] lease_cmd_op;
    wire lease_cmd_ready;
    wire lease_cmd_valid;
    wire [11:0] lease_mem_address;
    wire [31:0] lease_mem_read_data;
    wire lease_mem_read_en;
    wire lease_mem_read_valid;
    wire lease_mem_ready;
    wire [31:0] lease_mem_write_data;
    wire lease_mem_write_en;
    wire lease_open_ready;
    wire lease_open_valid;
    wire lease_rsp_ready;
    wire [7:0] lease_rsp_status;
    wire lease_rsp_valid;
    wire [31:0] op_release_handle;
    wire op_release_ready;
    wire [31:0] op_release_rsp_code;
    wire op_release_rsp_ready;
    wire op_release_rsp_valid;
    wire op_release_valid;
    wire operation_receiver_error;
    wire packet_busy;
    wire packet_operational;
    wire packet_recovery;
    wire packet_scrub;
    wire packet_start;
    wire pkt_aes_busy;
    wire pkt_aes_client_active;
    wire [7:0] pkt_aes_input_data;
    wire pkt_aes_input_ready;
    wire pkt_aes_input_valid;
    wire [15:0] pkt_aes_job_bytes;
    wire [127:0] pkt_aes_job_iv;
    wire [255:0] pkt_aes_job_key;
    wire pkt_aes_job_ready;
    wire pkt_aes_job_valid;
    wire [7:0] pkt_aes_output_data;
    wire pkt_aes_output_ready;
    wire pkt_aes_output_valid;
    wire pkt_aes_recovery_required;
    wire pkt_aes_scrub_done;
    wire [31:0] pkt_aes_status_code;
    wire [63:0] pkt_aes_status_cycles;
    wire [127:0] pkt_aes_status_iv;
    wire pkt_aes_status_ready;
    wire [15:0] pkt_aes_status_result_bytes;
    wire pkt_aes_status_valid;
    wire pkt_aes_use_allowed;
    wire pkt_gen_available;
    wire pkt_gen_busy;
    wire [3:0] pkt_gen_done_core_status;
    wire [63:0] pkt_gen_done_cycles;
    wire [31:0] pkt_gen_done_handle;
    wire [31:0] pkt_gen_done_id;
    wire [1:0] pkt_gen_done_mode;
    wire pkt_gen_done_ownership_committed;
    wire [1:0] pkt_gen_done_profile;
    wire pkt_gen_done_ready;
    wire [3:0] pkt_gen_done_setup_error;
    wire [3:0] pkt_gen_done_teardown_error;
    wire pkt_gen_done_valid;
    wire [31:0] pkt_gen_job_id;
    wire [1:0] pkt_gen_job_mode;
    wire [1:0] pkt_gen_job_profile;
    wire pkt_gen_job_ready;
    wire pkt_gen_job_valid;
    wire pkt_gen_recovery_required;
    wire pkt_gen_scrub_done;
    wire [31:0] pkt_key_handle;
    wire [31:0] pkt_key_reply_code;
    wire pkt_key_reply_ready;
    wire pkt_key_reply_valid;
    wire pkt_key_request;
    wire pkt_key_request_ready;
    wire pkt_public_component;
    wire [31:0] pkt_public_data;
    wire [31:0] pkt_public_handle;
    wire [5:0] pkt_public_index;
    wire [31:0] pkt_public_reply_code;
    wire pkt_public_reply_ready;
    wire pkt_public_reply_valid;
    wire pkt_public_request;
    wire pkt_public_request_ready;
    wire [31:0] pkt_release_handle;
    wire pkt_release_ready;
    wire [31:0] pkt_release_rsp_code;
    wire pkt_release_rsp_ready;
    wire pkt_release_rsp_valid;
    wire pkt_release_valid;
    wire [255:0] pkt_resolved_key;
    wire pkt_rsa_busy;
    wire [15:0] pkt_rsa_ciphertext_bytes;
    wire [7:0] pkt_rsa_input_data;
    wire pkt_rsa_input_ready;
    wire pkt_rsa_input_valid;
    wire [31:0] pkt_rsa_job_id;
    wire pkt_rsa_job_ready;
    wire pkt_rsa_job_valid;
    wire [31:0] pkt_rsa_key_handle;
    wire [7:0] pkt_rsa_output_data;
    wire pkt_rsa_output_ready;
    wire pkt_rsa_output_valid;
    wire [3:0] pkt_rsa_phase;
    wire [7:0] pkt_rsa_progress;
    wire pkt_rsa_recovery_required;
    wire [31:0] pkt_rsa_status_code;
    wire [63:0] pkt_rsa_status_cycles;
    wire [31:0] pkt_rsa_status_id;
    wire pkt_rsa_status_ready;
    wire [15:0] pkt_rsa_status_result_bytes;
    wire pkt_rsa_status_valid;
    wire pkt_rsa_use_allowed;
    wire [3:0] pkt_status_code;
    wire [7:0] pkt_status_detail;
    wire [31:0] pkt_status_operation_id;
    wire pkt_status_valid;
    wire [1:0] provider_mode;
    wire rsa_client_active;
    wire rsa_store_component;
    wire [31:0] rsa_store_data;
    wire [31:0] rsa_store_handle;
    wire [5:0] rsa_store_index;
    wire [31:0] rsa_store_reply_code;
    wire rsa_store_reply_ready;
    wire rsa_store_reply_valid;
    wire rsa_store_request;
    wire rsa_store_request_ready;
    wire store_abort;
    wire [31:0] store_commit_handle;
    wire [31:0] store_commit_id;
    wire [1:0] store_commit_mode;
    wire store_commit_ready;
    wire store_commit_valid;
    wire store_decision_accept;
    wire store_decision_ready;
    wire store_decision_valid;
    wire store_ownership_accept;
    wire store_ownership_ready;
    wire store_ownership_valid;
    wire store_receiver_error;
    wire [3:0] store_receiver_error_code;
    wire store_receiver_ready;
    wire store_receiver_scrub_done;
    wire [31:0] store_release_handle;
    wire store_release_ready;
    wire [31:0] store_release_rsp_code;
    wire store_release_rsp_ready;
    wire store_release_rsp_valid;
    wire store_release_valid;
    wire store_reserve_demo_use;
    wire [31:0] store_reserve_id;
    wire [1:0] store_reserve_mode;
    wire [1:0] store_reserve_profile;
    wire store_reserve_ready;
    wire store_reserve_valid;
    wire [2:0] store_result_component;
    wire store_result_component_last;
    wire [31:0] store_result_data;
    wire store_result_discard;
    wire [31:0] store_result_id;
    wire [6:0] store_result_index;
    wire store_result_last;
    wire store_result_ready;
    wire store_result_valid;
    reg startup_ready;
    reg release_owner_op;
    wire choose_op = op_release_valid;
    reg [31:0] metric_sequence;
    reg [63:0] metric_aes_cycles,metric_rsa_cycles,metric_gen_cycles;
    reg [31:0] accepted_aes_id,accepted_rsa_id,accepted_gen_id;
    reg [31:0] metric_aes_id,metric_rsa_id,metric_gen_id;
    reg [31:0] metric_aes_status,metric_rsa_status,metric_gen_status;
    wire aes_terminal = pkt_aes_status_valid && pkt_aes_status_ready;
    wire rsa_terminal = pkt_rsa_status_valid && pkt_rsa_status_ready;
    wire gen_terminal = pkt_gen_done_valid && pkt_gen_done_ready;
    wire [31:0] gen_status_packed = {20'd0,pkt_gen_done_teardown_error,pkt_gen_done_setup_error,pkt_gen_done_core_status};
    generate if (WIDTH != 2048) begin : invalid_width
`ifdef VERILATOR
        initial $fatal(1,"CUSTOMER_CRYPTO_REQUIRES_RSA2048");
`else
        CUSTOMER_CRYPTO_REQUIRES_RSA2048 invalid_selection ();
`endif
    end endgenerate

    // All services share the supervisor-controlled crypto reset. A pending
    // recovery blocks admission; the supervisor asserts reset_n_i separately.
    // Do not hold local resets low waiting for an aggregate scrub acknowledgment.
    assign packet_start = start_i && !recovery_pending_i && !recovery_required_o;
    assign packet_operational = operational_i && startup_ready && !recovery_pending_i && !recovery_required_o;
    assign provider_mode = DEMO_PROVIDER_MODE[1:0];
    assign operation_receiver_error = store_receiver_error || recovery_pending_i;
    assign store_abort = gen_abort || recovery_pending_i;
    assign aes_active = pkt_aes_client_active || pkt_aes_busy;
    assign busy_o = packet_busy || pkt_gen_busy || pkt_aes_busy || pkt_rsa_busy || lease_active;
    assign recovery_required_o = packet_recovery || pkt_gen_recovery_required ||
                                 pkt_aes_recovery_required || pkt_rsa_recovery_required;
    // A committed owned context intentionally persists. Generation and worker
    // cleanup flags cover private scratch; store abort/release covers failed or
    // replaced contexts through the existing operation/packet handshakes.
    assign scrub_done_o = startup_ready && packet_scrub && pkt_gen_scrub_done && pkt_aes_scrub_done &&
                          !pkt_rsa_busy && !lease_active;
    assign commit_o = store_commit_valid;
    assign commit_handle_o = store_commit_handle;

    // Legacy external lookup is deliberately unavailable in customer mode.
    assign key_request_ready_o = 1'b0;
    assign key_reply_valid_o = 1'b0;
    assign resolved_key_o = 256'd0;
    assign key_reply_code_o = 32'd0;

    always @(posedge clock_i or negedge reset_n_i)
        if (!reset_n_i) startup_ready <= 1'b0;
        else if (pkt_gen_available && store_receiver_scrub_done && pkt_aes_scrub_done && packet_scrub)
            startup_ready <= 1'b1;

    // One outstanding release reply; operation failure cleanup has priority.
    assign store_release_valid = op_release_valid || pkt_release_valid;
    assign store_release_handle = choose_op ? op_release_handle : pkt_release_handle;
    assign op_release_ready = store_release_ready && choose_op;
    assign pkt_release_ready = store_release_ready && !choose_op;
    assign op_release_rsp_valid = store_release_rsp_valid && release_owner_op;
    assign pkt_release_rsp_valid = store_release_rsp_valid && !release_owner_op;
    assign op_release_rsp_code = store_release_rsp_code;
    assign pkt_release_rsp_code = store_release_rsp_code;
    assign store_release_rsp_ready = release_owner_op ? op_release_rsp_ready : pkt_release_rsp_ready;
    always @(posedge clock_i or negedge reset_n_i)
        if (!reset_n_i) release_owner_op <= 1'b0;
        else if (store_release_valid && store_release_ready) release_owner_op <= choose_op;

    // Latch only actual accepted job IDs and held terminal handshakes after
    // cleanup. All words and both sequence bookends update on the same edge.
    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            metric_sequence<=0;metric_aes_cycles<=0;metric_rsa_cycles<=0;metric_gen_cycles<=0;
            accepted_aes_id<=0;accepted_rsa_id<=0;accepted_gen_id<=0;
            metric_aes_id<=0;metric_rsa_id<=0;metric_gen_id<=0;
            metric_aes_status<=0;metric_rsa_status<=0;metric_gen_status<=0;
        end else begin
            if (pkt_aes_job_valid && pkt_aes_job_ready) accepted_aes_id<=job_id_o;
            if (pkt_rsa_job_valid && pkt_rsa_job_ready) accepted_rsa_id<=pkt_rsa_job_id;
            if (pkt_gen_job_valid && pkt_gen_job_ready) accepted_gen_id<=pkt_gen_job_id;
            if (aes_terminal || rsa_terminal || gen_terminal) metric_sequence<=metric_sequence+1'b1;
            if (aes_terminal) begin
                metric_aes_cycles<=pkt_aes_status_cycles;metric_aes_id<=accepted_aes_id;
                metric_aes_status<=pkt_aes_status_code;
            end
            if (rsa_terminal) begin
                metric_rsa_cycles<=pkt_rsa_status_cycles;metric_rsa_id<=accepted_rsa_id;
                metric_rsa_status<=pkt_rsa_status_code;
            end
            if (gen_terminal) begin
                metric_gen_cycles<=pkt_gen_done_cycles;metric_gen_id<=accepted_gen_id;
                metric_gen_status<=(gen_status_packed==0 && !pkt_gen_done_ownership_committed) ?
                                   32'h101 : gen_status_packed;
            end
        end
    end
    assign metrics_snapshot_o={metric_sequence,32'd0,32'd0,metric_gen_status,metric_gen_id,
        metric_aes_status,metric_aes_id,metric_rsa_status,metric_rsa_id,
        metric_gen_cycles[63:32],metric_gen_cycles[31:0],metric_rsa_cycles[63:32],metric_rsa_cycles[31:0],
        metric_aes_cycles[63:32],metric_aes_cycles[31:0],metric_sequence};

    customer_demo_packet #(.DEMO_PROVIDER_MODE(DEMO_PROVIDER_MODE),.DEMO_AES_EXPORT_ENABLE(DEMO_AES_EXPORT_ENABLE)) u_packet (
        .clock_i(clock_i),
        .reset_n_i(reset_n_i),
        .start_i(packet_start),
        .operational_i(packet_operational),
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
        .busy_o(packet_busy),
        .scrub_done_o(packet_scrub),
        .recovery_required_o(packet_recovery),
        .snapshot_status_word_i(snapshot_status_word_o),
        .snapshot_operation_id_i(snapshot_operation_id_o),
        .snapshot_sequence_i(snapshot_sequence_o),
        .gen_job_valid_o(pkt_gen_job_valid),
        .gen_job_ready_i(pkt_gen_job_ready),
        .gen_job_profile_o(pkt_gen_job_profile),
        .gen_job_mode_o(pkt_gen_job_mode),
        .gen_job_id_o(pkt_gen_job_id),
        .gen_done_valid_i(pkt_gen_done_valid),
        .gen_done_ready_o(pkt_gen_done_ready),
        .gen_done_id_i(pkt_gen_done_id),
        .gen_done_handle_i(pkt_gen_done_handle),
        .gen_done_profile_i(pkt_gen_done_profile),
        .gen_done_mode_i(pkt_gen_done_mode),
        .gen_done_core_status_i(pkt_gen_done_core_status),
        .gen_done_setup_error_i(pkt_gen_done_setup_error),
        .gen_done_teardown_error_i(pkt_gen_done_teardown_error),
        .gen_done_ownership_committed_i(pkt_gen_done_ownership_committed),
        .gen_done_cycles_i(pkt_gen_done_cycles),
        .gen_phase_i(4'd0),
        .gen_available_i(pkt_gen_available),
        .gen_busy_i(pkt_gen_busy),
        .gen_recovery_required_i(pkt_gen_recovery_required),
        .gen_scrub_done_i(pkt_gen_scrub_done),
        .release_valid_o(pkt_release_valid),
        .release_ready_i(pkt_release_ready),
        .release_handle_o(pkt_release_handle),
        .release_rsp_valid_i(pkt_release_rsp_valid),
        .release_rsp_ready_o(pkt_release_rsp_ready),
        .release_rsp_code_i(pkt_release_rsp_code),
        .key_request_o(pkt_key_request),
        .key_request_ready_i(pkt_key_request_ready),
        .key_handle_o(pkt_key_handle),
        .key_reply_valid_i(pkt_key_reply_valid),
        .key_reply_ready_o(pkt_key_reply_ready),
        .resolved_key_i(pkt_resolved_key),
        .key_reply_code_i(pkt_key_reply_code),
        .aes_use_allowed_o(pkt_aes_use_allowed),
        .rsa_use_allowed_o(pkt_rsa_use_allowed),
        .aes_client_active_o(pkt_aes_client_active),
        .public_request_o(pkt_public_request),
        .public_request_ready_i(pkt_public_request_ready),
        .public_handle_o(pkt_public_handle),
        .public_component_o(pkt_public_component),
        .public_index_o(pkt_public_index),
        .public_reply_valid_i(pkt_public_reply_valid),
        .public_reply_ready_o(pkt_public_reply_ready),
        .public_data_i(pkt_public_data),
        .public_reply_code_i(pkt_public_reply_code),
        .aes_job_valid_o(pkt_aes_job_valid),
        .aes_job_ready_i(pkt_aes_job_ready),
        .aes_job_key_o(pkt_aes_job_key),
        .aes_job_iv_o(pkt_aes_job_iv),
        .aes_job_bytes_o(pkt_aes_job_bytes),
        .aes_input_valid_o(pkt_aes_input_valid),
        .aes_input_ready_i(pkt_aes_input_ready),
        .aes_input_data_o(pkt_aes_input_data),
        .aes_output_valid_i(pkt_aes_output_valid),
        .aes_output_ready_o(pkt_aes_output_ready),
        .aes_output_data_i(pkt_aes_output_data),
        .aes_status_valid_i(pkt_aes_status_valid),
        .aes_status_ready_o(pkt_aes_status_ready),
        .aes_status_code_i(pkt_aes_status_code),
        .aes_status_result_bytes_i(pkt_aes_status_result_bytes),
        .aes_status_iv_i(pkt_aes_status_iv),
        .aes_status_cycles_i(pkt_aes_status_cycles),
        .aes_busy_i(pkt_aes_busy),
        .aes_scrub_done_i(pkt_aes_scrub_done),
        .aes_recovery_required_i(pkt_aes_recovery_required),
        .rsa_job_valid_o(pkt_rsa_job_valid),
        .rsa_job_ready_i(pkt_rsa_job_ready),
        .rsa_job_id_o(pkt_rsa_job_id),
        .rsa_key_handle_o(pkt_rsa_key_handle),
        .rsa_ciphertext_bytes_o(pkt_rsa_ciphertext_bytes),
        .rsa_input_valid_o(pkt_rsa_input_valid),
        .rsa_input_ready_i(pkt_rsa_input_ready),
        .rsa_input_data_o(pkt_rsa_input_data),
        .rsa_output_valid_i(pkt_rsa_output_valid),
        .rsa_output_ready_o(pkt_rsa_output_ready),
        .rsa_output_data_i(pkt_rsa_output_data),
        .rsa_status_valid_i(pkt_rsa_status_valid),
        .rsa_status_ready_o(pkt_rsa_status_ready),
        .rsa_status_id_i(pkt_rsa_status_id),
        .rsa_status_code_i(pkt_rsa_status_code),
        .rsa_status_result_bytes_i(pkt_rsa_status_result_bytes),
        .rsa_status_cycles_i(pkt_rsa_status_cycles),
        .rsa_busy_i(pkt_rsa_busy),
        .rsa_recovery_required_i(pkt_rsa_recovery_required),
        .rsa_phase_i(pkt_rsa_phase),
        .rsa_progress_i(pkt_rsa_progress),
        .status_valid_o(pkt_status_valid),
        .status_code_o(pkt_status_code),
        .status_detail_o(pkt_status_detail),
        .status_operation_id_o(pkt_status_operation_id),
        .job_accept_o(job_accept_o),
        .job_id_o(job_id_o)
    );
    demo_keygen_operation #(.DEMO_PROVIDER_MODE(DEMO_PROVIDER_MODE),.IP_TYPE(IP_TYPE),.DEVICE_FAMILY(DEVICE_FAMILY),.PRIVATE_RSA_ENABLE(1),
      .ENTROPY_WARMUP_CYCLES(4096),.ENTROPY_SAMPLE_DIV(1024)) u_operation (
        .clock_i(clock_i),
        .reset_n_i(reset_n_i),
        .job_valid_i(pkt_gen_job_valid),
        .job_ready_o(pkt_gen_job_ready),
        .job_profile_i(pkt_gen_job_profile),
        .job_mode_i(pkt_gen_job_mode),
        .job_id_i(pkt_gen_job_id),
        .done_valid_o(pkt_gen_done_valid),
        .done_ready_i(pkt_gen_done_ready),
        .done_id_o(pkt_gen_done_id),
        .done_profile_o(pkt_gen_done_profile),
        .done_mode_o(pkt_gen_done_mode),
        .done_core_status_o(pkt_gen_done_core_status),
        .done_setup_error_o(pkt_gen_done_setup_error),
        .done_teardown_error_o(pkt_gen_done_teardown_error),
        .done_ownership_committed_o(pkt_gen_done_ownership_committed),
        .done_handle_o(pkt_gen_done_handle),
        .done_cycles_o(pkt_gen_done_cycles),
        .busy_o(pkt_gen_busy),
        .available_o(pkt_gen_available),
        .recovery_required_o(pkt_gen_recovery_required),
        .scrub_done_o(pkt_gen_scrub_done),
        .abort_o(gen_abort),
        .reserve_valid_o(store_reserve_valid),
        .reserve_ready_i(store_reserve_ready),
        .reserve_profile_o(store_reserve_profile),
        .reserve_mode_o(store_reserve_mode),
        .reserve_id_o(store_reserve_id),
        .reserve_demo_use_o(store_reserve_demo_use),
        .receiver_ready_i(store_receiver_ready),
        .receiver_error_i(operation_receiver_error),
        .receiver_error_code_i(store_receiver_error_code),
        .receiver_scrub_done_i(store_receiver_scrub_done),
        .result_valid_o(store_result_valid),
        .result_ready_i(store_result_ready),
        .result_data_o(store_result_data),
        .result_component_o(store_result_component),
        .result_index_o(store_result_index),
        .result_component_last_o(store_result_component_last),
        .result_last_o(store_result_last),
        .result_id_o(store_result_id),
        .result_discard_o(store_result_discard),
        .decision_valid_o(store_decision_valid),
        .decision_ready_i(store_decision_ready),
        .decision_accept_o(store_decision_accept),
        .ownership_valid_i(store_ownership_valid),
        .ownership_ready_o(store_ownership_ready),
        .ownership_accept_i(store_ownership_accept),
        .commit_valid_i(store_commit_valid),
        .commit_ready_o(store_commit_ready),
        .commit_handle_i(store_commit_handle),
        .commit_id_i(store_commit_id),
        .commit_mode_i(store_commit_mode),
        .release_valid_o(op_release_valid),
        .release_ready_i(op_release_ready),
        .release_handle_o(op_release_handle),
        .release_rsp_valid_i(op_release_rsp_valid),
        .release_rsp_ready_o(op_release_rsp_ready),
        .release_rsp_code_i(op_release_rsp_code),
        .private_open_valid_i(lease_open_valid),
        .private_open_ready_o(lease_open_ready),
        .private_active_o(lease_active),
        .private_cmd_valid_i(lease_cmd_valid),
        .private_cmd_ready_o(lease_cmd_ready),
        .private_cmd_op_i(lease_cmd_op),
        .private_cmd_arg0_i(lease_cmd_arg0),
        .private_cmd_arg1_i(lease_cmd_arg1),
        .private_cmd_arg2_i(lease_cmd_arg2),
        .private_cmd_arg3_i(lease_cmd_arg3),
        .private_rsp_valid_o(lease_rsp_valid),
        .private_rsp_ready_i(lease_rsp_ready),
        .private_rsp_status_o(lease_rsp_status),
        .private_mem_write_en_i(lease_mem_write_en),
        .private_mem_read_en_i(lease_mem_read_en),
        .private_mem_address_i(lease_mem_address),
        .private_mem_write_data_i(lease_mem_write_data),
        .private_mem_ready_o(lease_mem_ready),
        .private_mem_read_valid_o(lease_mem_read_valid),
        .private_mem_read_data_o(lease_mem_read_data),
        .private_close_valid_i(lease_close_valid),
        .private_close_ready_o(lease_close_ready),
        .private_close_rsp_valid_o(lease_close_rsp_valid),
        .private_close_rsp_ready_i(lease_close_rsp_ready)
    );
    demo_volatile_store #(.PRIVATE_RSA_ENABLE(1)) u_store (
        .clock_i(clock_i),
        .reset_n_i(reset_n_i),
        .reserve_valid_i(store_reserve_valid),
        .reserve_ready_o(store_reserve_ready),
        .reserve_profile_i(store_reserve_profile),
        .reserve_id_i(store_reserve_id),
        .reserve_mode_i(store_reserve_mode),
        .reserve_demo_use_i(store_reserve_demo_use),
        .receiver_ready_o(store_receiver_ready),
        .receiver_error_o(store_receiver_error),
        .receiver_error_code_o(store_receiver_error_code),
        .receiver_scrub_done_o(store_receiver_scrub_done),
        .abort_i(store_abort),
        .result_valid_i(store_result_valid),
        .result_ready_o(store_result_ready),
        .result_data_i(store_result_data),
        .result_component_i(store_result_component),
        .result_index_i(store_result_index),
        .result_component_last_i(store_result_component_last),
        .result_last_i(store_result_last),
        .result_id_i(store_result_id),
        .result_discard_i(store_result_discard),
        .decision_valid_i(store_decision_valid),
        .decision_ready_o(store_decision_ready),
        .decision_accept_i(store_decision_accept),
        .ownership_valid_o(store_ownership_valid),
        .ownership_ready_i(store_ownership_ready),
        .ownership_accept_o(store_ownership_accept),
        .commit_valid_o(store_commit_valid),
        .commit_ready_i(store_commit_ready),
        .commit_handle_o(store_commit_handle),
        .commit_id_o(store_commit_id),
        .commit_mode_o(store_commit_mode),
        .release_valid_i(store_release_valid),
        .release_ready_o(store_release_ready),
        .release_handle_i(store_release_handle),
        .release_rsp_valid_o(store_release_rsp_valid),
        .release_rsp_ready_i(store_release_rsp_ready),
        .release_rsp_code_o(store_release_rsp_code),
        .key_request_i(pkt_key_request),
        .key_request_ready_o(pkt_key_request_ready),
        .key_handle_i(pkt_key_handle),
        .key_reply_valid_o(pkt_key_reply_valid),
        .key_reply_ready_i(pkt_key_reply_ready),
        .resolved_key_o(pkt_resolved_key),
        .key_reply_code_o(pkt_key_reply_code),
        .use_allowed_i(pkt_aes_use_allowed),
        .client_active_i(aes_active),
        .rsa_use_allowed_i(pkt_rsa_use_allowed),
        .rsa_client_active_i(rsa_client_active),
        .public_request_i(pkt_public_request),
        .public_request_ready_o(pkt_public_request_ready),
        .public_handle_i(pkt_public_handle),
        .public_component_i(pkt_public_component),
        .public_index_i(pkt_public_index),
        .public_reply_valid_o(pkt_public_reply_valid),
        .public_reply_ready_i(pkt_public_reply_ready),
        .public_data_o(pkt_public_data),
        .public_reply_code_o(pkt_public_reply_code),
        .private_request_i(rsa_store_request),
        .private_request_ready_o(rsa_store_request_ready),
        .private_handle_i(rsa_store_handle),
        .private_component_i(rsa_store_component),
        .private_index_i(rsa_store_index),
        .private_reply_valid_o(rsa_store_reply_valid),
        .private_reply_ready_i(rsa_store_reply_ready),
        .private_data_o(rsa_store_data),
        .private_reply_code_o(rsa_store_reply_code)
    );
    customer_aes_worker  u_aes (
        .clock_i(clock_i),
        .reset_n_i(reset_n_i),
        .job_valid_i(pkt_aes_job_valid),
        .job_ready_o(pkt_aes_job_ready),
        .job_key_i(pkt_aes_job_key),
        .job_iv_i(pkt_aes_job_iv),
        .job_bytes_i(pkt_aes_job_bytes),
        .input_valid_i(pkt_aes_input_valid),
        .input_ready_o(pkt_aes_input_ready),
        .input_data_i(pkt_aes_input_data),
        .output_valid_o(pkt_aes_output_valid),
        .output_ready_i(pkt_aes_output_ready),
        .output_data_o(pkt_aes_output_data),
        .status_valid_o(pkt_aes_status_valid),
        .status_ready_i(pkt_aes_status_ready),
        .status_code_o(pkt_aes_status_code),
        .status_result_bytes_o(pkt_aes_status_result_bytes),
        .status_iv_o(pkt_aes_status_iv),
        .status_cycles_o(pkt_aes_status_cycles),
        .busy_o(pkt_aes_busy),
        .scrub_done_o(pkt_aes_scrub_done),
        .recovery_required_o(pkt_aes_recovery_required)
    );
    demo_rsa_private_worker  u_rsa (
        .clock_i(clock_i),
        .reset_n_i(reset_n_i),
        .job_valid_i(pkt_rsa_job_valid),
        .job_ready_o(pkt_rsa_job_ready),
        .job_id_i(pkt_rsa_job_id),
        .key_handle_i(pkt_rsa_key_handle),
        .ciphertext_bytes_i(pkt_rsa_ciphertext_bytes),
        .input_valid_i(pkt_rsa_input_valid),
        .input_ready_o(pkt_rsa_input_ready),
        .input_data_i(pkt_rsa_input_data),
        .output_valid_o(pkt_rsa_output_valid),
        .output_ready_i(pkt_rsa_output_ready),
        .output_data_o(pkt_rsa_output_data),
        .status_valid_o(pkt_rsa_status_valid),
        .status_ready_i(pkt_rsa_status_ready),
        .status_id_o(pkt_rsa_status_id),
        .status_code_o(pkt_rsa_status_code),
        .status_result_bytes_o(pkt_rsa_status_result_bytes),
        .status_cycles_o(pkt_rsa_status_cycles),
        .busy_o(pkt_rsa_busy),
        .rsa_client_active_o(rsa_client_active),
        .recovery_required_o(pkt_rsa_recovery_required),
        .phase_o(pkt_rsa_phase),
        .progress_o(pkt_rsa_progress),
        .private_open_valid_o(lease_open_valid),
        .private_open_ready_i(lease_open_ready),
        .private_active_i(lease_active),
        .private_cmd_valid_o(lease_cmd_valid),
        .private_cmd_ready_i(lease_cmd_ready),
        .private_cmd_op_o(lease_cmd_op),
        .private_cmd_arg0_o(lease_cmd_arg0),
        .private_cmd_arg1_o(lease_cmd_arg1),
        .private_cmd_arg2_o(lease_cmd_arg2),
        .private_cmd_arg3_o(lease_cmd_arg3),
        .private_rsp_valid_i(lease_rsp_valid),
        .private_rsp_ready_o(lease_rsp_ready),
        .private_rsp_status_i(lease_rsp_status),
        .private_mem_write_en_o(lease_mem_write_en),
        .private_mem_read_en_o(lease_mem_read_en),
        .private_mem_address_o(lease_mem_address),
        .private_mem_write_data_o(lease_mem_write_data),
        .private_mem_ready_i(lease_mem_ready),
        .private_mem_read_valid_i(lease_mem_read_valid),
        .private_mem_read_data_i(lease_mem_read_data),
        .private_close_valid_o(lease_close_valid),
        .private_close_ready_i(lease_close_ready),
        .private_close_rsp_valid_i(lease_close_rsp_valid),
        .private_close_rsp_ready_o(lease_close_rsp_ready),
        .private_request_o(rsa_store_request),
        .private_request_ready_i(rsa_store_request_ready),
        .private_handle_o(rsa_store_handle),
        .private_component_o(rsa_store_component),
        .private_index_o(rsa_store_index),
        .private_reply_valid_i(rsa_store_reply_valid),
        .private_reply_ready_o(rsa_store_reply_ready),
        .private_data_i(rsa_store_data),
        .private_reply_code_i(rsa_store_reply_code)
    );
    demo_lcd_status  u_status (
        .clock_i(clock_i),
        .reset_n_i(reset_n_i),
        .status_valid_i(pkt_status_valid),
        .status_code_i(pkt_status_code),
        .status_detail_i(pkt_status_detail),
        .operation_id_i(pkt_status_operation_id),
        .provider_mode_i(provider_mode),
        .status_word_o(snapshot_status_word_o),
        .operation_id_o(snapshot_operation_id_o),
        .sequence_o(snapshot_sequence_o)
    );
endmodule
`default_nettype wire
