// Filename: primitive_controller.v
// Author: Makeda Solomon; refactor assisted by Codex
// Date: October 13, 2026
// Description: Validate a decoded EncryptDecrypt2 job and process it through
// shared AES-256/CFB. Upstream resolves the key handle, authorization and mode.
`default_nettype none
module primitive_controller #(
    parameter MAX_SYM_DATA_BYTES = 1024,
    parameter RAM_ADDR_WIDTH = 12
)(
    input wire clock_i, reset_n_i, start_i,

    // Caller supplies decoded command inputs and an already resolved object key.
    input wire [15:0] command_code_i,
    input wire key_valid_i,
    input wire [2:0] mode_i,
    input wire [255:0] key_i,
    input wire [127:0] iv_i,
    input wire decrypt_i,
    input wire [RAM_ADDR_WIDTH-1:0] input_base_i, output_base_i,
    input wire [31:0] data_length_i,

    // Response returned to symm_top. Output bytes are written to the buffer.
    output wire busy_o,
    output reg done_o, error_o,
    output reg [11:0] tpm_rc_o,
    output reg [127:0] final_iv_o,
    output reg [31:0] completed_length_o,

    output wire ram_req_valid_o,
    input wire ram_req_ready_i,
    output wire ram_req_write_o,
    output wire [RAM_ADDR_WIDTH-1:0] ram_req_addr_o,
    output wire [7:0] ram_req_data_o,
    input wire ram_rsp_valid_i,
    output wire ram_rsp_ready_o,
    input wire [7:0] ram_rsp_data_i,
    input wire ram_rsp_error_i,


    // Prepared request sent to the shared CFB worker.
    output wire cfb_start_o,
    output reg [255:0] cfb_key_o,
    output reg [127:0] cfb_iv_o, cfb_data_o,
    output reg [4:0] cfb_bytes_o,
    output reg cfb_decrypt_o,

    // Response from the shared CFB worker.
    input wire cfb_done_i,
    input wire [11:0] cfb_rc_i,
    input wire [127:0] cfb_data_i, cfb_iv_i
);
    // Verilog-2001 constant function: represent zero through the full capacity.
    function integer count_width;
        input integer maximum;
        integer value;
        begin
            count_width = 1;
            value = maximum;
            while (value > 1) begin
                count_width = count_width + 1;
                value = value >> 1;
            end
        end
    endfunction
    // Invalid build parameters fail elaboration rather than silently changing bounds.
    generate
        if (MAX_SYM_DATA_BYTES < 1 || MAX_SYM_DATA_BYTES > 65535 ||
            RAM_ADDR_WIDTH < 1 || RAM_ADDR_WIDTH > 32) begin : INVALID_CONFIGURATION
            invalid_symmetric_ram_parameters invalid_parameters();
        end
    endgenerate
    localparam COUNT_WIDTH = count_width(MAX_SYM_DATA_BYTES);
    localparam BOUND_WIDTH = RAM_ADDR_WIDTH + 33;
    localparam IDLE = 0, PREPARE = 1, READ_REQ = 2, READ_WAIT = 3,
        ISSUE = 4, WAIT_CFB = 5, WRITE_REQ = 6, WRITE_WAIT = 7,
        FINISH = 8, RELEASE = 9;
    reg [3:0] state_reg;
    reg [RAM_ADDR_WIDTH-1:0] input_base_reg, output_base_reg;
    reg [COUNT_WIDTH-1:0] length_reg, offset_reg;
    reg [4:0] byte_index_reg;
    reg [127:0] result_reg, next_iv_reg;

    // Exclusive ends can equal 2**RAM_ADDR_WIDTH; no truncated arithmetic.
    wire [BOUND_WIDTH-1:0] input_end_w =
        {{33{1'b0}}, input_base_i} + {{(BOUND_WIDTH-32){1'b0}}, data_length_i};
    wire [BOUND_WIDTH-1:0] output_end_w =
        {{33{1'b0}}, output_base_i} + {{(BOUND_WIDTH-32){1'b0}}, data_length_i};
    wire [BOUND_WIDTH-1:0] ram_limit_w = {{(BOUND_WIDTH-1){1'b0}}, 1'b1} << RAM_ADDR_WIDTH;
    wire [31:0] remaining_bytes_w = length_reg - offset_reg;
    wire invalid_range_w = input_end_w > ram_limit_w || output_end_w > ram_limit_w ||
        (data_length_i != 0 && input_base_i != output_base_i &&
         input_base_i < output_end_w && output_base_i < input_end_w);

    assign busy_o = reset_n_i && state_reg != IDLE;
    assign ram_req_valid_o = reset_n_i && (state_reg == READ_REQ || state_reg == WRITE_REQ);
    assign ram_req_write_o = state_reg == WRITE_REQ;
    assign ram_req_addr_o = (ram_req_write_o ? output_base_reg : input_base_reg) +
        offset_reg + byte_index_reg;
    assign ram_req_data_o = result_reg[127 - byte_index_reg * 8 -: 8];
    assign ram_rsp_ready_o = reset_n_i && (state_reg == READ_WAIT || state_reg == WRITE_WAIT);
    assign cfb_start_o = reset_n_i && state_reg == ISSUE;

    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            state_reg <= IDLE;
            input_base_reg <= 0;
            output_base_reg <= 0;
            length_reg <= 0;
            offset_reg <= 0;
            byte_index_reg <= 0;
            result_reg <= 0;
            next_iv_reg <= 0;
            cfb_key_o <= 0;
            cfb_iv_o <= 0;
            cfb_data_o <= 0;
            cfb_bytes_o <= 0;
            cfb_decrypt_o <= 0;
            done_o <= 0;
            error_o <= 0;
            tpm_rc_o <= 0;
            final_iv_o <= 0;
            completed_length_o <= 0;
        end else begin
            done_o <= 0;
            case (state_reg)
                // Capture inputs. Only valid AES-256/CFB jobs proceed to the worker.
                IDLE: if (start_i) begin
                    // Validate before narrowing the length or touching RAM.
                    error_o <= 0;
                    tpm_rc_o <= 0;
                    final_iv_o <= iv_i;
                    completed_length_o <= 0;
                    offset_reg <= 0;
                    if (command_code_i != 16'h0193) begin
                        error_o <= 1;
                        tpm_rc_o <= 12'h143;
                        state_reg <= FINISH;
                    end else if (!key_valid_i) begin
                        error_o <= 1;
                        tpm_rc_o <= 12'h09c;
                        state_reg <= FINISH;
                    end else if (mode_i != 3'd1) begin
                        error_o <= 1;
                        tpm_rc_o <= 12'h089;
                        state_reg <= FINISH;
                    end else if (data_length_i > MAX_SYM_DATA_BYTES || invalid_range_w) begin
                        error_o <= 1;
                        tpm_rc_o <= 12'h095; // TPM_RC_SIZE: invalid local descriptor
                        state_reg <= FINISH;
                    end else if (data_length_i == 0) begin
                        state_reg <= FINISH;
                    end else begin
                        input_base_reg <= input_base_i;
                        output_base_reg <= output_base_i;
                        length_reg <= data_length_i[COUNT_WIDTH-1:0];
                        cfb_key_o <= key_i;
                        cfb_iv_o <= iv_i;
                        cfb_decrypt_o <= decrypt_i;
                        state_reg <= PREPARE;
                    end
                end
                PREPARE: begin
                    // Only the final chunk can be partial. Read all of it before writing.
                    cfb_bytes_o <= (remaining_bytes_w > 16) ? 5'd16 : remaining_bytes_w[4:0];
                    cfb_data_o <= 0;
                    byte_index_reg <= 0;
                    state_reg <= READ_REQ;
                end
                READ_REQ: if (ram_req_ready_i) state_reg <= READ_WAIT;
                READ_WAIT: if (ram_rsp_valid_i) begin
                    if (ram_rsp_error_i) begin
                        error_o <= 1;
                        tpm_rc_o <= 12'h101; // TPM_RC_FAILURE: RAM adapter failed
                        state_reg <= FINISH;
                    end else begin
                        cfb_data_o[127 - byte_index_reg * 8 -: 8] <= ram_rsp_data_i;
                        if (byte_index_reg + 1 == cfb_bytes_o) begin
                            byte_index_reg <= 0;
                            state_reg <= ISSUE;
                        end else begin
                            byte_index_reg <= byte_index_reg + 1'b1;
                            state_reg <= READ_REQ;
                        end
                    end
                end
                // Pulse worker start for one cycle. No KDFa is needed for this path.
                ISSUE: state_reg <= WAIT_CFB;
                // Wait for the worker before writing the chunk back.
                WAIT_CFB: if (cfb_done_i) begin
                    if (cfb_rc_i != 0) begin
                        error_o <= 1;
                        tpm_rc_o <= cfb_rc_i;
                        state_reg <= FINISH;
                    end else begin
                        result_reg <= cfb_data_i;
                        next_iv_reg <= cfb_iv_i;
                        state_reg <= WRITE_REQ;
                    end
                end
                WRITE_REQ: if (ram_req_ready_i) state_reg <= WRITE_WAIT;
                WRITE_WAIT: if (ram_rsp_valid_i) begin
                    if (ram_rsp_error_i) begin
                        error_o <= 1;
                        tpm_rc_o <= 12'h101;
                        state_reg <= FINISH;
                    end else begin
                        // Count acknowledged bytes only, including a partial failed chunk.
                        completed_length_o <= completed_length_o + 1'b1;
                        if (byte_index_reg + 1 == cfb_bytes_o) begin
                            final_iv_o <= next_iv_reg;
                            cfb_iv_o <= next_iv_reg;
                            offset_reg <= offset_reg + cfb_bytes_o;
                            if (offset_reg + cfb_bytes_o == length_reg)
                                state_reg <= FINISH;
                            else state_reg <= PREPARE;
                        end else begin
                            byte_index_reg <= byte_index_reg + 1'b1;
                            state_reg <= WRITE_REQ;
                        end
                    end
                end
                FINISH: begin
                    // Publish done for one clock and erase this controller's key copy.
                    // Retain result metadata for the caller.
                    cfb_key_o <= 0;
                    cfb_iv_o <= 0;
                    cfb_data_o <= 0;
                    cfb_bytes_o <= 0;
                    cfb_decrypt_o <= 0;
                    result_reg <= 0;
                    next_iv_reg <= 0;
                    input_base_reg <= 0;
                    output_base_reg <= 0;
                    length_reg <= 0;
                    offset_reg <= 0;
                    byte_index_reg <= 0;
                    done_o <= 1;
                    state_reg <= RELEASE;
                end
                // Wait for start to fall before accepting another job.
                RELEASE: if (!start_i) state_reg <= IDLE;
                default: begin
                    error_o <= 1;
                    tpm_rc_o <= 12'h101;
                    state_reg <= FINISH;
                end
            endcase
        end
    end
endmodule
`default_nettype wire
