// AI-authored AES-128/256 key assembly from a supplied cryptographic RNG stream.
// Not an RNG, cipher, key expansion, protected store, or TPM object creator.
module aes_key_assembler (
    input wire clock_i,
    input wire reset_n_i,
    input wire work_valid_i,
    output wire work_ready_o,
    input wire [31:0] work_id_i,
    input wire [11:0] work_key_bits_i,
    input wire [31:0] work_public_exponent_i,
    input wire work_cancel_i,
    output wire busy_o,
    input wire [31:0] rng_data_i,
    input wire rng_valid_i,
    input wire rng_error_i,
    output wire rng_ready_o,
    output wire out_valid_o,
    input wire out_ready_i,
    output wire [31:0] out_id_o,
    output wire [31:0] out_word_o,
    output wire [3:0] out_component_o,
    output wire [6:0] out_index_o,
    output wire [11:0] out_bits_o,
    output wire out_last_o,
    output wire done_valid_o,
    input wire done_ready_i,
    output reg [31:0] done_id_reg_o,
    output reg [7:0] done_status_reg_o
);
    localparam IDLE = 2'd0, COLLECT = 2'd1, EMIT = 2'd2, DONE = 2'd3;
    localparam [7:0] SUCCESS = 8'd0, UNSUPPORTED = 8'd1,
        RNG_FAILURE = 8'd2, CANCELLED = 8'd3, BAD_METADATA = 8'd4;
    reg [1:0] state_reg;
    reg armed_reg;
    reg [255:0] key_material_reg;
    reg [11:0] key_bits_reg;
    reg [3:0] words_required_reg, accepted_words_reg;
    reg [6:0] emit_index_reg;
    wire active = state_reg == COLLECT || state_reg == EMIT;
    wire clear_controls = work_cancel_i === 1'b0 && rng_error_i === 1'b0;
    wire [7:0] word_offset = (words_required_reg - 1'b1 - emit_index_reg) * 8'd32;

    assign work_ready_o = reset_n_i && state_reg == IDLE && armed_reg && work_cancel_i === 1'b0;
    assign busy_o = reset_n_i && state_reg != IDLE;
    assign rng_ready_o = reset_n_i && state_reg == COLLECT && clear_controls;
    assign out_valid_o = reset_n_i && state_reg == EMIT && clear_controls;
    // Suppress secret payload whenever invalid, including fault/cancel/reset edges.
    assign out_word_o = out_valid_o ? key_material_reg[word_offset +: 32] : 32'd0;
    assign out_id_o = out_valid_o ? done_id_reg_o : 32'd0;
    assign out_component_o = out_valid_o ? 4'd1 : 4'd0; // AES secret-key component
    assign out_index_o = out_valid_o ? emit_index_reg : 7'd0;
    assign out_bits_o = out_valid_o ? key_bits_reg : 12'd0;
    assign out_last_o = out_valid_o && emit_index_reg == words_required_reg - 1'b1;
    assign done_valid_o = reset_n_i && state_reg == DONE;

    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            state_reg <= IDLE;
            armed_reg <= 1'b0; // Sample a low work_valid after reset before accepting work.
            key_material_reg <= 0;
            key_bits_reg <= 0; words_required_reg <= 0; accepted_words_reg <= 0; emit_index_reg <= 0;
            done_id_reg_o <= 0; done_status_reg_o <= UNSUPPORTED;
        end else begin
            if (work_valid_i === 1'b0) armed_reg <= 1'b1;
            // Fault dominates cancellation and any final input/output transfer.
            // Unknown fault/cancel controls are also rejected in simulation.
            if (active && rng_error_i !== 1'b0) begin
                key_material_reg <= 0;
                key_bits_reg <= 0; words_required_reg <= 0; accepted_words_reg <= 0; emit_index_reg <= 0;
                done_status_reg_o <= RNG_FAILURE;
                state_reg <= DONE;
            end else if (active && work_cancel_i !== 1'b0) begin
                key_material_reg <= 0;
                key_bits_reg <= 0; words_required_reg <= 0; accepted_words_reg <= 0; emit_index_reg <= 0;
                done_status_reg_o <= CANCELLED;
                state_reg <= DONE;
            end else case (state_reg)
                IDLE: if (work_valid_i === 1'b1 && work_ready_o) begin
                    armed_reg <= 1'b0;
                    key_material_reg <= 0;
                    accepted_words_reg <= 0; emit_index_reg <= 0;
                    done_id_reg_o <= (^work_id_i === 1'bx) ? 32'd0 : work_id_i;
                    if ((^work_id_i === 1'bx) || work_public_exponent_i !== 32'd0) begin
                        done_status_reg_o <= BAD_METADATA;
                        state_reg <= DONE;
                    end else if (!(work_key_bits_i === 12'd128 || work_key_bits_i === 12'd256)) begin
                        done_status_reg_o <= UNSUPPORTED;
                        state_reg <= DONE;
                    end else if (rng_error_i !== 1'b0) begin
                        done_status_reg_o <= RNG_FAILURE;
                        state_reg <= DONE;
                    end else begin
                        key_bits_reg <= work_key_bits_i;
                        words_required_reg <= work_key_bits_i == 12'd128 ? 4'd4 : 4'd8;
                        done_status_reg_o <= SUCCESS;
                        state_reg <= COLLECT;
                    end
                end
                COLLECT: if (rng_valid_i === 1'b1 && rng_ready_o) begin
                    if (^rng_data_i === 1'bx) begin
                        key_material_reg <= 0;
                        key_bits_reg <= 0; words_required_reg <= 0; accepted_words_reg <= 0; emit_index_reg <= 0;
                        done_status_reg_o <= RNG_FAILURE;
                        state_reg <= DONE;
                    end else begin
                        // First accepted word becomes the most significant actual key word.
                        // Four words occupy low 128 bits; upper 128 remain zero for AES-128.
                        key_material_reg <= {key_material_reg[223:0], rng_data_i};
                        accepted_words_reg <= accepted_words_reg + 1'b1;
                        if (accepted_words_reg + 1'b1 == words_required_reg) state_reg <= EMIT;
                    end
                end
                EMIT: if (out_valid_o && out_ready_i === 1'b1) begin
                    // Clear each accepted word; a stalled word remains stable.
                    key_material_reg[word_offset +: 32] <= 0;
                    if (emit_index_reg == words_required_reg - 1'b1) begin
                        key_material_reg <= 0;
                        key_bits_reg <= 0; words_required_reg <= 0; accepted_words_reg <= 0; emit_index_reg <= 0;
                        done_status_reg_o <= SUCCESS;
                        state_reg <= DONE;
                    end else emit_index_reg <= emit_index_reg + 1'b1;
                end
                DONE: if (done_ready_i === 1'b1) begin
                    state_reg <= IDLE;
                    key_material_reg <= 0;
                    key_bits_reg <= 0; words_required_reg <= 0; accepted_words_reg <= 0; emit_index_reg <= 0;
                    done_id_reg_o <= 0;
                end
                default: begin
                    key_material_reg <= 0;
                    key_bits_reg <= 0; words_required_reg <= 0; accepted_words_reg <= 0; emit_index_reg <= 0;
                    done_status_reg_o <= BAD_METADATA;
                    state_reg <= DONE;
                end
            endcase
        end
    end
endmodule
