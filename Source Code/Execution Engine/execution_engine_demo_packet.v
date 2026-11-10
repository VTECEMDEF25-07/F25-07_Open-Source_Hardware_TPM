// Demo-only SPI packet decoder, frozen v0.1. Codex assisted.
`default_nettype none
module execution_engine_demo_packet #(
    parameter WIDTH=2048, parameter DEMO_PROVIDER_MODE=1
)(
    input wire clock_i, reset_n_i, start_i, operational_i,
    input wire [15:0] command_tag_i,
    input wire [31:0] command_size_i,
    output reg [11:0] command_addr_o, input wire [7:0] command_byte_i,
    output reg response_valid_o, output reg [31:0] response_code_o,
    output wire [11:0] response_length_o,
    input wire [11:0] response_addr_i, output reg [7:0] response_byte_o,
    input wire response_consumed_i,
    input wire supervisor_recovered_i, supervisor_last_committed_i,
    input wire [31:0] supervisor_last_id_i, supervisor_last_handle_i,
    input wire [3:0] supervisor_last_reason_i,
    output wire busy_o, scrub_done_o, output wire recovery_required_o,
    input wire aes_client_active_i, output wire store_use_allowed_o,
    output wire gen_job_valid_o, input wire gen_job_ready_i,
    output wire [1:0] gen_job_profile_o, gen_job_mode_o,
    output wire [31:0] gen_job_id_o,
    input wire gen_done_valid_i, output wire gen_done_ready_o,
    input wire [31:0] gen_done_id_i, gen_done_handle_i,
    input wire [1:0] gen_done_profile_i, gen_done_mode_i,
    input wire [3:0] gen_done_core_status_i, gen_done_setup_error_i, gen_done_teardown_error_i,
    input wire gen_done_ownership_committed_i,
    input wire gen_busy_i, gen_available_i, gen_recovery_required_i, gen_scrub_done_i,
    output wire release_valid_o, input wire release_ready_i,
    output wire [31:0] release_handle_o,
    input wire release_rsp_valid_i, output wire release_rsp_ready_o,
    input wire [31:0] release_rsp_code_i,
    output wire modexp_job_valid_o, input wire modexp_job_ready_i,
    output wire [31:0] modexp_job_id_o,
    output wire [11:0] modexp_base_addr_o, modexp_exponent_addr_o,
    output wire [11:0] modexp_modulus_addr_o, modexp_result_addr_o,
    output wire [15:0] modexp_operand_bytes_o,
    input wire modexp_status_valid_i, output wire modexp_status_ready_o,
    input wire [31:0] modexp_status_id_i, modexp_status_cycles_i,
    input wire [3:0] modexp_status_code_i,
    input wire [15:0] modexp_status_result_bytes_i,
    input wire modexp_recovery_required_i,
    input wire modexp_ram_req_valid_i, output wire modexp_ram_req_ready_o,
    input wire modexp_ram_req_write_i, input wire [11:0] modexp_ram_req_addr_i,
    input wire [7:0] modexp_ram_req_wdata_i,
    output wire modexp_ram_rsp_valid_o, input wire modexp_ram_rsp_ready_i,
    output wire [7:0] modexp_ram_rsp_rdata_o, output wire modexp_ram_rsp_error_o,
    output wire ram_req_valid_o, input wire ram_req_ready_i,
    output wire ram_req_write_o, output wire [11:0] ram_req_addr_o,
    output wire [7:0] ram_req_wdata_o,
    input wire ram_rsp_valid_i, output wire ram_rsp_ready_o,
    input wire [7:0] ram_rsp_rdata_i, input wire ram_rsp_error_i,
    output wire ram_clear_valid_o, input wire ram_clear_ready_i,
    input wire ram_clear_done_valid_i, output wire ram_clear_done_ready_o,
    input wire ram_scrub_done_i
);
    localparam B=WIDTH/8;
    localparam SCRUB=0, IDLE=1, PREFIX_WAIT=2, PREFIX_READ=3, SUBMIT=4,
        INPUT_WAIT=5, INPUT_SEND=6, TERMINAL=7, PUBLISH=8, HOLD=9, FAILED=10;
    reg [3:0] state;
    reg scrub_for_reply;
    reg [127:0] prefix;
    wire [127:0] next_prefix = {prefix[119:0],command_byte_i};
    reg [7:0] opcode;
    reg [31:0] request_id, handle;
    reg [11:0] input_count;
    reg [15:0] output_count, scrub_index;
    reg [7:0] result [0:B-1];
    reg [31:0] reply_id, reply_handle, reply_operation, reply_cleanup;
    reg [15:0] reply_flags;
    reg [7:0] reply_state;
    reg [11:0] reply_length;
    wire c_request_ready, c_input_ready, c_output_valid, c_response_valid, c_busy, c_recovery;
    wire [7:0] c_output_data, c_response_state;
    wire [31:0] c_response_code, c_response_id, c_response_handle,
        c_response_operation, c_response_cleanup;
    wire [15:0] c_response_flags;
    wire c_output_ready = state == TERMINAL && output_count < B;
    assign busy_o = reset_n_i && (state != IDLE || c_busy || !ram_scrub_done_i);
    assign scrub_done_o = reset_n_i && state == IDLE && !c_busy && ram_scrub_done_i;
    assign recovery_required_o = c_recovery || state == FAILED;
    assign response_length_o = reply_length;

    // Read data is indexed by payload offset; CRB supplies the ten-byte header.
    always @* begin
        response_byte_o = 0;
        if (state == HOLD || state == PUBLISH) begin
            case (response_addr_i)
                0: response_byte_o = 1;
                1: response_byte_o = opcode;
                2: response_byte_o = DEMO_PROVIDER_MODE;
                3: response_byte_o = reply_state;
                4: response_byte_o = reply_id[31:24];
                5: response_byte_o = reply_id[23:16];
                6: response_byte_o = reply_id[15:8];
                7: response_byte_o = reply_id[7:0];
                8: response_byte_o = reply_handle[31:24];
                9: response_byte_o = reply_handle[23:16];
                10: response_byte_o = reply_handle[15:8];
                11: response_byte_o = reply_handle[7:0];
                12: response_byte_o = 4;
                13: response_byte_o = 0;
                14: response_byte_o = reply_flags[15:8];
                15: response_byte_o = reply_flags[7:0];
                16: response_byte_o = reply_operation[31:24];
                17: response_byte_o = reply_operation[23:16];
                18: response_byte_o = reply_operation[15:8];
                19: response_byte_o = reply_operation[7:0];
                20: response_byte_o = reply_cleanup[31:24];
                21: response_byte_o = reply_cleanup[23:16];
                22: response_byte_o = reply_cleanup[15:8];
                23: response_byte_o = reply_cleanup[7:0];
                24: response_byte_o = 0;
                25: response_byte_o = 0;
                26: response_byte_o = opcode == 0 || opcode == 3 ? (WIDTH >> 8) : 0;
                27: response_byte_o = opcode == 0 || opcode == 3 ? (WIDTH & 255) : 0;
                default: if (response_code_o == 0 && opcode == 3 &&
                    response_addr_i >= 28 && response_addr_i < 28+B)
                    response_byte_o = result[response_addr_i-28];
            endcase
            if (response_code_o != 0) response_byte_o = 0;
        end
    end
    always @(posedge clock_i) begin
        if (reset_n_i && state == SCRUB) result[scrub_index] <= 0;
        else if (reset_n_i && c_output_valid && c_output_ready)
            result[output_count] <= c_output_data;
    end
    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            state <= SCRUB; scrub_index <= 0; scrub_for_reply <= 0; prefix <= 0; opcode <= 0;
            request_id <= 0; handle <= 0; command_addr_o <= 0;
            response_valid_o <= 0; response_code_o <= 0;
            input_count <= 0; output_count <= 0;
            reply_id <= 0; reply_handle <= 0; reply_operation <= 0;
            reply_cleanup <= 0; reply_flags <= 0; reply_state <= 0; reply_length <= 10;
        end else begin
            response_valid_o <= 0;
            if (c_output_valid && c_output_ready) output_count <= output_count + 1'b1;
            if (c_recovery) state <= FAILED;
            else if (c_response_valid && (state == TERMINAL || state == INPUT_WAIT || state == INPUT_SEND)) begin
                    response_code_o <= c_response_code; reply_id <= c_response_id;
                    reply_handle <= c_response_handle; reply_flags <= c_response_flags;
                    reply_operation <= c_response_operation; reply_cleanup <= c_response_cleanup;
                    reply_state <= c_response_state;
                    if (opcode == 0 && supervisor_recovered_i) begin
                        reply_id <= supervisor_last_id_i; reply_handle <= supervisor_last_handle_i;
                        reply_flags <= (c_response_flags & 16'hfffe) | 16'h0008 | (supervisor_last_committed_i ? 16'h0001 : 16'h0000);
                        reply_operation <= 32'h60; reply_cleanup <= 32'h4;
                    end
                    if (c_response_code == 0 && (opcode != 3 || output_count == B))
                        reply_length <= opcode == 3 ? 38+B : 38;
                    else begin
                        reply_length <= 10;
                        if (c_response_code == 0) response_code_o <= 32'h101;
                    end
                    if (c_response_code != 0 || (opcode == 3 && output_count != B)) begin
                        scrub_index <= 0; scrub_for_reply <= 1; state <= SCRUB;
                    end else state <= PUBLISH;
            end else case (state)
                SCRUB: if (scrub_index == B-1) begin scrub_index <= 0; state <= scrub_for_reply ? PUBLISH : IDLE; end
                    else scrub_index <= scrub_index + 1'b1;
                IDLE: if (start_i && !busy_o) begin
                    prefix <= 0; opcode <= 0; handle <= 0; request_id <= 0;
                    reply_id <= 0; reply_handle <= 0; reply_operation <= 0;
                    reply_cleanup <= 0; reply_flags <= 0; reply_state <= 0;
                    response_code_o <= 0; reply_length <= 10;
                    input_count <= 0; output_count <= 0; command_addr_o <= 10;
                    if (command_tag_i != 16'h8001) begin
                        response_code_o <= command_tag_i == 16'h8002 ? 32'h12f : 32'h01e;
                        state <= PUBLISH;
                    end else if (!operational_i) begin response_code_o <= 32'h100; state <= PUBLISH; end
                    else if (command_size_i < 26 || command_size_i > 26+3*B) begin
                        response_code_o <= 32'h095; state <= PUBLISH;
                    end else state <= PREFIX_WAIT;
                end
                PREFIX_WAIT: state <= PREFIX_READ;
                PREFIX_READ: begin
                    prefix <= next_prefix; command_addr_o <= command_addr_o + 1'b1;
                    if (command_addr_o == 25) begin
                        opcode <= next_prefix[119:112]; request_id <= next_prefix[95:64];
                        handle <= next_prefix[63:32];
                        if (next_prefix[127:120] != 1 || next_prefix[111:96] != 0 ||
                            next_prefix[31:0] != 0 || next_prefix[119:112] > 3 ||
                            (next_prefix[119:112] != 2 && next_prefix[63:32] != 0) ||
                            command_size_i != (next_prefix[119:112] == 3 ? 26+3*B : 26)) begin
                            response_code_o <= 32'h095; state <= PUBLISH;
                        end else state <= SUBMIT;
                    end else state <= PREFIX_WAIT;
                end
                SUBMIT: if (c_request_ready) state <= opcode == 3 ? INPUT_WAIT : TERMINAL;
                INPUT_WAIT: state <= INPUT_SEND;
                INPUT_SEND: if (c_input_ready) begin
                    input_count <= input_count + 1'b1;
                    command_addr_o <= command_addr_o + 1'b1;
                    state <= input_count == 3*B-1 ? TERMINAL : INPUT_WAIT;
                end
                TERMINAL: begin end
                PUBLISH: begin response_valid_o <= 1; state <= HOLD; end
                HOLD: if (response_consumed_i) begin
                    scrub_index <= 0; scrub_for_reply <= 0; prefix <= 0; state <= SCRUB;
                end
                FAILED: begin end
                default: state <= FAILED;
            endcase
        end
    end
    demo_aes_coordinator #(.WIDTH(WIDTH), .DEMO_PROVIDER_MODE(DEMO_PROVIDER_MODE)) coordinator (
        .clock_i(clock_i), .reset_n_i(reset_n_i),
        .request_valid_i(state == SUBMIT), .request_ready_o(c_request_ready),
        .request_opcode_i(opcode), .request_id_i(request_id), .request_handle_i(handle),
        .input_valid_i(state == INPUT_SEND), .input_ready_o(c_input_ready), .input_data_i(command_byte_i),
        .output_valid_o(c_output_valid), .output_ready_i(c_output_ready), .output_data_o(c_output_data),
        .response_valid_o(c_response_valid), .response_ready_i(state == TERMINAL || state == INPUT_WAIT || state == INPUT_SEND),
        .response_code_o(c_response_code), .response_id_o(c_response_id), .response_handle_o(c_response_handle),
        .response_flags_o(c_response_flags), .response_operation_o(c_response_operation),
        .response_cleanup_o(c_response_cleanup), .response_state_o(c_response_state),
        .busy_o(c_busy), .recovery_required_o(c_recovery),
        .aes_client_active_i(aes_client_active_i),
        .store_use_allowed_o(store_use_allowed_o),
        .gen_job_valid_o(gen_job_valid_o),
        .gen_job_ready_i(gen_job_ready_i),
        .gen_job_profile_o(gen_job_profile_o),
        .gen_job_mode_o(gen_job_mode_o),
        .gen_job_id_o(gen_job_id_o),
        .gen_done_valid_i(gen_done_valid_i),
        .gen_done_ready_o(gen_done_ready_o),
        .gen_done_id_i(gen_done_id_i),
        .gen_done_handle_i(gen_done_handle_i),
        .gen_done_profile_i(gen_done_profile_i),
        .gen_done_mode_i(gen_done_mode_i),
        .gen_done_core_status_i(gen_done_core_status_i),
        .gen_done_setup_error_i(gen_done_setup_error_i),
        .gen_done_teardown_error_i(gen_done_teardown_error_i),
        .gen_done_ownership_committed_i(gen_done_ownership_committed_i),
        .gen_busy_i(gen_busy_i),
        .gen_available_i(gen_available_i),
        .gen_recovery_required_i(gen_recovery_required_i),
        .gen_scrub_done_i(gen_scrub_done_i),
        .release_valid_o(release_valid_o),
        .release_ready_i(release_ready_i),
        .release_handle_o(release_handle_o),
        .release_rsp_valid_i(release_rsp_valid_i),
        .release_rsp_ready_o(release_rsp_ready_o),
        .release_rsp_code_i(release_rsp_code_i),
        .modexp_job_valid_o(modexp_job_valid_o),
        .modexp_job_ready_i(modexp_job_ready_i),
        .modexp_job_id_o(modexp_job_id_o),
        .modexp_base_addr_o(modexp_base_addr_o),
        .modexp_exponent_addr_o(modexp_exponent_addr_o),
        .modexp_modulus_addr_o(modexp_modulus_addr_o),
        .modexp_result_addr_o(modexp_result_addr_o),
        .modexp_operand_bytes_o(modexp_operand_bytes_o),
        .modexp_status_valid_i(modexp_status_valid_i),
        .modexp_status_ready_o(modexp_status_ready_o),
        .modexp_status_id_i(modexp_status_id_i),
        .modexp_status_cycles_i(modexp_status_cycles_i),
        .modexp_status_code_i(modexp_status_code_i),
        .modexp_status_result_bytes_i(modexp_status_result_bytes_i),
        .modexp_recovery_required_i(modexp_recovery_required_i),
        .modexp_ram_req_valid_i(modexp_ram_req_valid_i),
        .modexp_ram_req_ready_o(modexp_ram_req_ready_o),
        .modexp_ram_req_write_i(modexp_ram_req_write_i),
        .modexp_ram_req_addr_i(modexp_ram_req_addr_i),
        .modexp_ram_req_wdata_i(modexp_ram_req_wdata_i),
        .modexp_ram_rsp_valid_o(modexp_ram_rsp_valid_o),
        .modexp_ram_rsp_ready_i(modexp_ram_rsp_ready_i),
        .modexp_ram_rsp_rdata_o(modexp_ram_rsp_rdata_o),
        .modexp_ram_rsp_error_o(modexp_ram_rsp_error_o),
        .ram_req_valid_o(ram_req_valid_o),
        .ram_req_ready_i(ram_req_ready_i),
        .ram_req_write_o(ram_req_write_o),
        .ram_req_addr_o(ram_req_addr_o),
        .ram_req_wdata_o(ram_req_wdata_o),
        .ram_rsp_valid_i(ram_rsp_valid_i),
        .ram_rsp_ready_o(ram_rsp_ready_o),
        .ram_rsp_rdata_i(ram_rsp_rdata_i),
        .ram_rsp_error_i(ram_rsp_error_i),
        .ram_clear_valid_o(ram_clear_valid_o),
        .ram_clear_ready_i(ram_clear_ready_i),
        .ram_clear_done_valid_i(ram_clear_done_valid_i),
        .ram_clear_done_ready_o(ram_clear_done_ready_o),
        .ram_scrub_done_i(ram_scrub_done_i)
    );
endmodule
`default_nettype wire
