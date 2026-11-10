// Public modular-exponentiation demo adapter, frozen DE25 interface v0.1.
// Author: Aaron Grossman / Codex-assisted implementation, 2026-11-09.
// Reuses the unmodified rsa_modexp arithmetic. No private-key interface.
// All addresses are bytes; integer byte zero is the most significant byte.
// One outstanding RAM request; writes require responses too. Shared reset
// must flush both requester and RAM. recovery_required_o requires that reset.
`timescale 1ns/1ps
module demo_modexp_adapter #(
    parameter WIDTH = 2048,
    parameter RAM_ADDR_WIDTH = 12,
    parameter JOB_DEADLINE_CYCLES = 50000000,
    parameter CLEANUP_DEADLINE_CYCLES = 4096
)(
    input wire clock_i,
    input wire reset_n_i,
    input wire job_valid_i,
    output wire job_ready_o,
    input wire [31:0] job_id_i,
    input wire [RAM_ADDR_WIDTH-1:0] base_addr_i,
    input wire [RAM_ADDR_WIDTH-1:0] exponent_addr_i,
    input wire [RAM_ADDR_WIDTH-1:0] modulus_addr_i,
    input wire [RAM_ADDR_WIDTH-1:0] result_addr_i,
    input wire [15:0] operand_bytes_i,

    output reg ram_req_valid_o,
    input wire ram_req_ready_i,
    output reg ram_req_write_o,
    output reg [RAM_ADDR_WIDTH-1:0] ram_req_addr_o,
    output reg [7:0] ram_req_wdata_o,
    input wire ram_rsp_valid_i,
    output reg ram_rsp_ready_o,
    input wire [7:0] ram_rsp_rdata_i,
    input wire ram_rsp_error_i,

    output wire status_valid_o,
    input wire status_ready_i,
    output reg [31:0] status_id_o,
    output reg [3:0] status_code_o,
    output reg [15:0] status_result_bytes_o,
    output reg [31:0] status_cycles_o,
    output reg recovery_required_o
);
    localparam BYTES = WIDTH/8;
    localparam [15:0] BYTE_COUNT = BYTES[15:0];
    localparam [15:0] LAST_BYTE = BYTE_COUNT-16'd1;
    localparam [4:0] BOOT0=0, BOOT1=1, BOOT2=2, IDLE=3,
        VALIDATE=4, CLEAR_REQ=5, CLEAR_RSP=6, LOAD_REQ=7, LOAD_RSP=8,
        LAUNCH=9, COMPUTE=10, WRITE_REQ=11, WRITE_RSP=12,
        ABORT_RESET=13, DRAIN=14, FINISH_RESET=15, RELEASE0=16,
        RELEASE1=17, RELEASE2=18, PUBLISH=19, TERMINAL=20, UNAVAILABLE=21;
    localparam [3:0] OK=0, BAD_DESCRIPTOR=1, BAD_OPERAND=2,
        MEMORY_ERROR=3, DEADLINE=4, INTERNAL_ERROR=5;
    reg [4:0] state_reg;
    reg [RAM_ADDR_WIDTH-1:0] base_addr_reg, exponent_addr_reg;
    reg [RAM_ADDR_WIDTH-1:0] modulus_addr_reg, result_addr_reg;
    reg [15:0] operand_bytes_reg;
    reg [15:0] byte_index_reg;
    reg [1:0] component_reg;
    reg [WIDTH-1:0] base_reg, exponent_reg, modulus_reg;
    reg core_reset_n_reg;
    reg pending_reg;
    reg cleanup_reg;
    reg [31:0] elapsed_reg, cleanup_cycles_reg;
    reg [31:0] ram_addr_wide;
    wire [WIDTH-1:0] core_result;
    wire core_done, core_error;
    wire request_fire = ram_req_valid_o && ram_req_ready_i;
    wire response_fire = ram_rsp_valid_i && ram_rsp_ready_o;
    wire active = state_reg >= VALIDATE && state_reg <= PUBLISH;
    wire job_expired = active && !cleanup_reg && elapsed_reg >= JOB_DEADLINE_CYCLES;
    wire cleanup_expired = active && cleanup_reg &&
                           cleanup_cycles_reg >= CLEANUP_DEADLINE_CYCLES;

    // All additions are widened before validating the physical 1024-byte RAM.
    wire [31:0] base_wide = {{(32-RAM_ADDR_WIDTH){1'b0}},base_addr_reg};
    wire [31:0] exponent_wide = {{(32-RAM_ADDR_WIDTH){1'b0}},exponent_addr_reg};
    wire [31:0] modulus_wide = {{(32-RAM_ADDR_WIDTH){1'b0}},modulus_addr_reg};
    wire [31:0] result_wide = {{(32-RAM_ADDR_WIDTH){1'b0}},result_addr_reg};
    wire [31:0] byte_index_wide = {16'd0,byte_index_reg};
    wire [31:0] base_end = base_wide + BYTES;
    wire [31:0] exponent_end = exponent_wide + BYTES;
    wire [31:0] modulus_end = modulus_wide + BYTES;
    wire [31:0] result_end = result_wide + BYTES;
    wire descriptor_bad = operand_bytes_reg != BYTE_COUNT ||
        base_end > 1024 || exponent_end > 1024 || modulus_end > 1024 || result_end > 1024 ||
        (base_wide < exponent_end && exponent_wide < base_end) ||
        (base_wide < modulus_end && modulus_wide < base_end) ||
        (base_wide < result_end && result_wide < base_end) ||
        (exponent_wide < modulus_end && modulus_wide < exponent_end) ||
        (exponent_wide < result_end && result_wide < exponent_end) ||
        (modulus_wide < result_end && result_wide < modulus_end);

    assign job_ready_o = reset_n_i && state_reg == IDLE && !recovery_required_o;
    assign status_valid_o = reset_n_i && state_reg == TERMINAL;
    rsa_modexp #(.WIDTH(WIDTH)) arithmetic (
        .clk_i(clock_i), .reset_n_i(core_reset_n_reg),
        .start_i(reset_n_i && state_reg == LAUNCH && !job_expired),
        .base_i(base_reg), .exponent_i(exponent_reg), .n_i(modulus_reg),
        .result_o(core_result), .done_o(core_done), .busy_o(), .error_o(core_error)
    );

    always @* begin
        ram_req_valid_o=1'b0; ram_req_write_o=1'b0;
        ram_req_addr_o={RAM_ADDR_WIDTH{1'b0}}; ram_req_wdata_o=8'd0;
        ram_addr_wide=32'd0;
        ram_rsp_ready_o=1'b0;
        if (reset_n_i) begin
            case (state_reg)
                CLEAR_REQ: begin
                    ram_req_valid_o=1'b1; ram_req_write_o=1'b1;
                    ram_addr_wide=result_wide+byte_index_wide;
                end
                LOAD_REQ: begin
                    ram_req_valid_o=1'b1;
                    case (component_reg)
                        0: ram_addr_wide=base_wide+byte_index_wide;
                        1: ram_addr_wide=exponent_wide+byte_index_wide;
                        default: ram_addr_wide=modulus_wide+byte_index_wide;
                    endcase
                end
                WRITE_REQ: begin
                    ram_req_valid_o=1'b1; ram_req_write_o=1'b1;
                    ram_addr_wide=result_wide+byte_index_wide;
                    ram_req_wdata_o=core_result[WIDTH-1-8*byte_index_reg -: 8];
                end
                CLEAR_RSP, LOAD_RSP, WRITE_RSP: ram_rsp_ready_o=1'b1;
                DRAIN: ram_rsp_ready_o=pending_reg;
                default: begin end
            endcase
        end
        ram_req_addr_o=ram_addr_wide[RAM_ADDR_WIDTH-1:0];
    end

    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            state_reg<=BOOT0; core_reset_n_reg<=1'b0;
            base_addr_reg<=0; exponent_addr_reg<=0; modulus_addr_reg<=0; result_addr_reg<=0;
            operand_bytes_reg<=0; byte_index_reg<=0; component_reg<=0;
            base_reg<=0; exponent_reg<=0; modulus_reg<=0;
            pending_reg<=0; cleanup_reg<=0; elapsed_reg<=0; cleanup_cycles_reg<=0;
            status_id_o<=0; status_code_o<=OK; status_result_bytes_o<=0;
            status_cycles_o<=0; recovery_required_o<=0;
        end else begin
            if (request_fire) pending_reg<=1'b1;
            if (response_fire) pending_reg<=1'b0;
            if (active && elapsed_reg != 32'hffffffff) elapsed_reg<=elapsed_reg+1'b1;
            if (active && cleanup_reg && cleanup_cycles_reg != 32'hffffffff)
                cleanup_cycles_reg<=cleanup_cycles_reg+1'b1;

            // A timeout never reuses an untagged outstanding response. Drain it
            // before issuing cleanup requests, or require coordinated reset.
            if (cleanup_expired) begin
                core_reset_n_reg<=1'b0; base_reg<=0; exponent_reg<=0; modulus_reg<=0;
                status_result_bytes_o<=0; recovery_required_o<=1'b1;
                status_cycles_o<=elapsed_reg;
                state_reg<=TERMINAL;
            end else if (job_expired) begin
                status_code_o<=DEADLINE; status_result_bytes_o<=0;
                core_reset_n_reg<=1'b0; cleanup_reg<=1'b1; cleanup_cycles_reg<=0;
                base_reg<=0; exponent_reg<=0; modulus_reg<=0;
                state_reg<=ABORT_RESET;
            end else begin
                case (state_reg)
                    BOOT0: state_reg<=BOOT1;
                    BOOT1: begin core_reset_n_reg<=1'b1; state_reg<=BOOT2; end
                    BOOT2: state_reg<=IDLE;
                    IDLE: if (job_valid_i && job_ready_o) begin
                        status_id_o<=job_id_i; status_code_o<=OK; status_result_bytes_o<=0;
                        status_cycles_o<=0; elapsed_reg<=0; cleanup_cycles_reg<=0; cleanup_reg<=0;
                        base_addr_reg<=base_addr_i; exponent_addr_reg<=exponent_addr_i;
                        modulus_addr_reg<=modulus_addr_i; result_addr_reg<=result_addr_i;
                        operand_bytes_reg<=operand_bytes_i;
                        byte_index_reg<=0; component_reg<=0;
                        state_reg<=VALIDATE;
                    end
                    VALIDATE: if (descriptor_bad) begin
                        status_code_o<=BAD_DESCRIPTOR; state_reg<=FINISH_RESET;
                    end else state_reg<=CLEAR_REQ;
                    CLEAR_REQ: if (request_fire) state_reg<=CLEAR_RSP;
                    CLEAR_RSP: if (response_fire) begin
                        if (ram_rsp_error_i) begin
                            recovery_required_o<=1'b1;
                            if (cleanup_reg) begin
                                recovery_required_o<=1'b1; state_reg<=FINISH_RESET;
                            end else begin
                                status_code_o<=MEMORY_ERROR; state_reg<=ABORT_RESET;
                            end
                        end else if (byte_index_reg == LAST_BYTE) begin
                            byte_index_reg<=0;
                            state_reg<=cleanup_reg ? FINISH_RESET : LOAD_REQ;
                        end else begin byte_index_reg<=byte_index_reg+1'b1; state_reg<=CLEAR_REQ; end
                    end
                    LOAD_REQ: if (request_fire) state_reg<=LOAD_RSP;
                    LOAD_RSP: if (response_fire) begin
                        if (ram_rsp_error_i) begin
                            recovery_required_o<=1'b1;
                            status_code_o<=MEMORY_ERROR; state_reg<=ABORT_RESET;
                        end else begin
                            case (component_reg)
                                0: base_reg[WIDTH-1-8*byte_index_reg -: 8]<=ram_rsp_rdata_i;
                                1: exponent_reg[WIDTH-1-8*byte_index_reg -: 8]<=ram_rsp_rdata_i;
                                default: modulus_reg[WIDTH-1-8*byte_index_reg -: 8]<=ram_rsp_rdata_i;
                            endcase
                            if (byte_index_reg == LAST_BYTE) begin
                                byte_index_reg<=0;
                                if (component_reg == 2) state_reg<=LAUNCH;
                                else begin component_reg<=component_reg+1'b1; state_reg<=LOAD_REQ; end
                            end else begin byte_index_reg<=byte_index_reg+1'b1; state_reg<=LOAD_REQ; end
                        end
                    end
                    LAUNCH: begin
                        base_reg<=0; exponent_reg<=0; modulus_reg<=0;
                        state_reg<=COMPUTE;
                    end
                    COMPUTE: if (core_done) begin
                        byte_index_reg<=0;
                        if (core_error) begin status_code_o<=BAD_OPERAND; state_reg<=ABORT_RESET; end
                        else state_reg<=WRITE_REQ;
                    end
                    WRITE_REQ: if (request_fire) state_reg<=WRITE_RSP;
                    WRITE_RSP: if (response_fire) begin
                        if (ram_rsp_error_i) begin
                            recovery_required_o<=1'b1;
                            status_code_o<=MEMORY_ERROR; state_reg<=ABORT_RESET;
                        end
                        else if (byte_index_reg == LAST_BYTE) begin
                            status_result_bytes_o<=BYTE_COUNT; state_reg<=FINISH_RESET;
                        end else begin byte_index_reg<=byte_index_reg+1'b1; state_reg<=WRITE_REQ; end
                    end
                    ABORT_RESET: begin
                        core_reset_n_reg<=1'b0; base_reg<=0; exponent_reg<=0; modulus_reg<=0;
                        status_result_bytes_o<=0; cleanup_reg<=1'b1;
                        state_reg<=DRAIN;
                    end
                    DRAIN: if (!pending_reg || response_fire) begin
                        byte_index_reg<=0; state_reg<=CLEAR_REQ;
                    end
                    FINISH_RESET: begin
                        core_reset_n_reg<=1'b0; base_reg<=0; exponent_reg<=0; modulus_reg<=0;
                        state_reg<=RELEASE0;
                    end
                    RELEASE0: state_reg<=RELEASE1;
                    RELEASE1: begin core_reset_n_reg<=1'b1; state_reg<=RELEASE2; end
                    RELEASE2: state_reg<=PUBLISH;
                    PUBLISH: begin status_cycles_o<=elapsed_reg; state_reg<=TERMINAL; end
                    TERMINAL: if (status_ready_i)
                        state_reg<=recovery_required_o ? UNAVAILABLE : IDLE;
                    UNAVAILABLE: begin end
                    default: begin
                        status_code_o<=INTERNAL_ERROR; status_result_bytes_o<=0;
                        recovery_required_o<=1'b1; state_reg<=FINISH_RESET;
                    end
                endcase
            end
        end
    end
endmodule
