// Demo-only public control. No key/result-word buses enter this module.
// Codex assisted implementation of frozen DE25 demo v0.1.
`default_nettype none
module demo_aes_coordinator #(
    parameter WIDTH=2048, parameter DEMO_PROVIDER_MODE=1,
    parameter [63:0] GENERATION_DEADLINE=64'd9000000000,
    parameter [63:0] PUBLIC_DEADLINE=64'd50010000
)(
    input wire clock_i, reset_n_i,
    input wire request_valid_i, output wire request_ready_o,
    input wire [7:0] request_opcode_i,
    input wire [31:0] request_id_i, request_handle_i,
    input wire input_valid_i, output wire input_ready_o, input wire [7:0] input_data_i,
    output wire output_valid_o, input wire output_ready_i, output wire [7:0] output_data_o,
    output wire response_valid_o, input wire response_ready_i,
    output reg [31:0] response_code_o, response_id_o, response_handle_o,
    output reg [15:0] response_flags_o,
    output reg [31:0] response_operation_o, response_cleanup_o,
    output reg [7:0] response_state_o,
    output wire busy_o, output reg recovery_required_o,
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
    localparam IDLE=0, GEN_SEND=1, GEN_WAIT=2, FLUSH_SEND=3, FLUSH_WAIT=4,
        CLEAR_SEND=5, CLEAR_WAIT=6, INPUT_BYTE=7, WRITE_WAIT=8,
        MX_SEND=9, MX_WAIT=10, READ_SEND=11, READ_WAIT=12, OUTPUT_BYTE=13,
        FINAL_CLEAR_SEND=14, FINAL_CLEAR_WAIT=15, RESPONSE=16, RECOVERY=17;
    reg [4:0] state;
    reg [31:0] id, handle;
    reg [7:0] opcode;
    reg [11:0] offset;
    reg [7:0] result_byte;
    reg use_allowed;
    reg [31:0] use_handle;
    reg [63:0] deadline_count;
    reg [31:0] last_id, last_handle, last_operation, last_cleanup;
    reg [15:0] last_flags;
    wire [15:0] mode_flags = DEMO_PROVIDER_MODE == 1 ? 16'h0002 : 16'h0000;
    wire gen_ok = gen_done_id_i == id && gen_done_profile_i == 1 &&
        gen_done_mode_i == DEMO_PROVIDER_MODE && gen_done_core_status_i == 0 &&
        gen_done_setup_error_i == 0 && gen_done_teardown_error_i == 0 &&
        gen_done_ownership_committed_i && gen_done_handle_i != 0 &&
        gen_scrub_done_i && !gen_recovery_required_i;
    wire mx_memory_owner = state == MX_SEND || state == MX_WAIT;
    wire local_io = state == INPUT_BYTE || state == READ_SEND;
    wire deadline_hit = deadline_count >= (state == GEN_SEND || state == GEN_WAIT ?
        GENERATION_DEADLINE : PUBLIC_DEADLINE);
    assign request_ready_o = reset_n_i && state == IDLE && !aes_client_active_i &&
        !recovery_required_o && ram_scrub_done_i;
    assign busy_o = reset_n_i && state != IDLE;
    assign store_use_allowed_o = reset_n_i && use_allowed && !recovery_required_o;
    assign response_valid_o = reset_n_i && state == RESPONSE;
    assign gen_job_valid_o = reset_n_i && state == GEN_SEND;
    assign gen_job_profile_o = 2'd1;
    assign gen_job_mode_o = DEMO_PROVIDER_MODE;
    assign gen_job_id_o = id;
    assign gen_done_ready_o = reset_n_i && state == GEN_WAIT;
    assign release_valid_o = reset_n_i && state == FLUSH_SEND && !aes_client_active_i;
    assign release_handle_o = handle;
    assign release_rsp_ready_o = reset_n_i && state == FLUSH_WAIT;
    assign modexp_job_valid_o = reset_n_i && state == MX_SEND;
    assign modexp_job_id_o = id;
    assign modexp_base_addr_o = 12'd0;
    assign modexp_exponent_addr_o = B;
    assign modexp_modulus_addr_o = 2*B;
    assign modexp_result_addr_o = 3*B;
    assign modexp_operand_bytes_o = B;
    assign modexp_status_ready_o = reset_n_i && state == MX_WAIT;
    assign ram_clear_valid_o = reset_n_i && (state == CLEAR_SEND || state == FINAL_CLEAR_SEND);
    assign ram_clear_done_ready_o = reset_n_i && (state == CLEAR_WAIT || state == FINAL_CLEAR_WAIT);
    assign input_ready_o = reset_n_i && state == INPUT_BYTE && ram_req_ready_i;
    assign output_valid_o = reset_n_i && state == OUTPUT_BYTE;
    assign output_data_o = result_byte;
    assign ram_req_valid_o = reset_n_i && (mx_memory_owner ? modexp_ram_req_valid_i :
        local_io && (state == READ_SEND || input_valid_i));
    assign ram_req_write_o = mx_memory_owner ? modexp_ram_req_write_i : state == INPUT_BYTE;
    assign ram_req_addr_o = mx_memory_owner ? modexp_ram_req_addr_i :
        state == INPUT_BYTE ? offset : 3*B + offset;
    assign ram_req_wdata_o = mx_memory_owner ? modexp_ram_req_wdata_i : input_data_i;
    assign ram_rsp_ready_o = reset_n_i && (mx_memory_owner ? modexp_ram_rsp_ready_i :
        state == WRITE_WAIT || state == READ_WAIT);
    assign modexp_ram_req_ready_o = reset_n_i && mx_memory_owner && ram_req_ready_i;
    assign modexp_ram_rsp_valid_o = reset_n_i && mx_memory_owner && ram_rsp_valid_i;
    assign modexp_ram_rsp_rdata_o = mx_memory_owner ? ram_rsp_rdata_i : 8'd0;
    assign modexp_ram_rsp_error_o = mx_memory_owner && ram_rsp_error_i;

    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            state <= IDLE; id <= 0; handle <= 0; opcode <= 0; offset <= 0; result_byte <= 0;
            response_code_o <= 0; response_id_o <= 0; response_handle_o <= 0;
            response_flags_o <= 0; response_operation_o <= 0; response_cleanup_o <= 0;
            response_state_o <= 0; use_allowed <= 0; use_handle <= 0;
            recovery_required_o <= 0; deadline_count <= 0;
            last_id <= 0; last_handle <= 0; last_operation <= 0; last_cleanup <= 0; last_flags <= 0;
        end else begin
            if (state != IDLE && state != RESPONSE && state != RECOVERY)
                deadline_count <= deadline_count + 1'b1;
            // Recovery latches: an incomplete transaction cannot be made reusable by a packet reset.
            if (state != IDLE && state != RESPONSE && state != RECOVERY &&
                (deadline_hit || modexp_recovery_required_i || gen_recovery_required_i)) begin
                recovery_required_o <= 1; use_allowed <= 0; state <= RECOVERY;
                last_id <= id; last_operation <= 32'h60; last_cleanup <= 4;
                last_flags <= mode_flags | 16'h8;
            end else case (state)
                IDLE: if (request_valid_i && request_ready_o) begin
                    id <= request_id_i; handle <= request_handle_i; opcode <= request_opcode_i; offset <= 0;
                    deadline_count <= 0; response_id_o <= request_id_i;
                    response_handle_o <= 0; response_flags_o <= mode_flags;
                    response_operation_o <= 0; response_cleanup_o <= 0;
                    response_code_o <= 0; response_state_o <= 0;
                    case (request_opcode_i)
                        0: begin
                            response_id_o <= last_id; response_handle_o <= last_handle;
                            response_flags_o <= last_flags | mode_flags;
                            response_operation_o <= last_operation; response_cleanup_o <= last_cleanup;
                            response_state_o <= gen_available_i ? 0 : 4;
                            state <= RESPONSE;
                        end
                        1: if (gen_available_i) state <= GEN_SEND;
                        else begin response_code_o <= 32'h922; response_operation_o <= 32'h30; state <= RESPONSE; end
                        2: state <= FLUSH_SEND;
                        3: if (WIDTH > 2048 || WIDTH < 8 || WIDTH % 8 != 0) begin
                            response_code_o <= 32'h095; state <= RESPONSE;
                        end else state <= CLEAR_SEND;
                        default: begin response_code_o <= 32'h12f; state <= RESPONSE; end
                    endcase
                end
                GEN_SEND: if (gen_job_ready_i) state <= GEN_WAIT;
                GEN_WAIT: if (gen_done_valid_i) begin
                    response_handle_o <= gen_done_handle_i;
                    response_flags_o <= mode_flags | (gen_done_ownership_committed_i ? 16'h1 : 16'h0);
                    response_operation_o <= {24'd0,gen_done_setup_error_i,gen_done_core_status_i};
                    response_cleanup_o <= {28'd0,gen_done_teardown_error_i};
                    if (gen_ok) begin use_allowed <= 1; use_handle <= gen_done_handle_i; end
                    else begin
                        if (gen_done_ownership_committed_i) use_allowed <= 0;
                        response_code_o <= gen_done_setup_error_i == 2 || gen_done_setup_error_i == 3 ?
                            32'h922 : gen_done_setup_error_i == 1 ? 32'h12f : 32'h101;
                        if (gen_done_id_i != id || gen_done_profile_i != 1 ||
                            gen_done_mode_i != DEMO_PROVIDER_MODE) response_operation_o <= 32'h70;
                    end
                    state <= RESPONSE;
                end
                FLUSH_SEND: if (release_ready_i && !aes_client_active_i) begin
                    if (handle == use_handle) use_allowed <= 0;
                    state <= FLUSH_WAIT;
                end
                FLUSH_WAIT: if (release_rsp_valid_i) begin
                    response_code_o <= release_rsp_code_i;
                    response_handle_o <= handle;
                    if (release_rsp_code_i != 0) response_operation_o <= 32'h20;
                    state <= RESPONSE;
                end
                CLEAR_SEND: if (ram_clear_ready_i) state <= CLEAR_WAIT;
                CLEAR_WAIT: if (ram_clear_done_valid_i) begin offset <= 0; state <= INPUT_BYTE; end
                INPUT_BYTE: if (input_valid_i && ram_req_ready_i) state <= WRITE_WAIT;
                WRITE_WAIT: if (ram_rsp_valid_i) begin
                    if (ram_rsp_error_i) begin
                        response_code_o <= 32'h101; response_operation_o <= 32'h70;
                        state <= FINAL_CLEAR_SEND;
                    end else if (offset == 3*B-1) begin offset <= 0; state <= MX_SEND; end
                    else begin offset <= offset + 1'b1; state <= INPUT_BYTE; end
                end
                MX_SEND: if (modexp_job_ready_i) state <= MX_WAIT;
                MX_WAIT: if (modexp_status_valid_i) begin
                    if (modexp_status_id_i != id || modexp_status_code_i != 0 ||
                        modexp_status_result_bytes_i != B) begin
                        response_code_o <= modexp_status_code_i == 1 || modexp_status_code_i == 2 ?
                            32'h095 : 32'h101;
                        response_operation_o <= 32'h70; state <= FINAL_CLEAR_SEND;
                    end else begin offset <= 0; state <= READ_SEND; end
                end
                READ_SEND: if (ram_req_ready_i) state <= READ_WAIT;
                READ_WAIT: if (ram_rsp_valid_i) begin
                    if (ram_rsp_error_i) begin
                        response_code_o <= 32'h101; response_operation_o <= 32'h70;
                        state <= FINAL_CLEAR_SEND;
                    end else begin result_byte <= ram_rsp_rdata_i; state <= OUTPUT_BYTE; end
                end
                OUTPUT_BYTE: if (output_ready_i) begin
                    result_byte <= 0;
                    if (offset == B-1) state <= FINAL_CLEAR_SEND;
                    else begin offset <= offset + 1'b1; state <= READ_SEND; end
                end
                FINAL_CLEAR_SEND: if (ram_clear_ready_i) state <= FINAL_CLEAR_WAIT;
                FINAL_CLEAR_WAIT: if (ram_clear_done_valid_i) state <= RESPONSE;
                RESPONSE: if (response_ready_i) begin
                    // CAPS is observational: retain the last executed operation separately.
                    if (opcode != 0) begin
                        last_id <= response_id_o; last_handle <= response_handle_o;
                        last_flags <= response_flags_o; last_operation <= response_operation_o;
                        last_cleanup <= response_cleanup_o;
                    end
                    state <= IDLE;
                end
                RECOVERY: begin end
                default: begin recovery_required_o <= 1; state <= RECOVERY; use_allowed <= 0; end
            endcase
        end
    end
endmodule
`default_nettype wire
