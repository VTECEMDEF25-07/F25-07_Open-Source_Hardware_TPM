// AI-authored AES-128/256 key assembly from a supplied cryptographic RNG stream.
// Not an RNG, cipher, key expansion, protected store, or TPM object creator.
module aes_key_assembler (
    input wire clock,
    input wire reset_n,
    input wire work_valid,
    output wire work_ready,
    input wire [31:0] work_id,
    input wire [11:0] work_key_bits,
    input wire [31:0] work_public_exponent,
    input wire work_cancel,
    output wire busy,
    input wire [31:0] rng_data,
    input wire rng_valid,
    input wire rng_error,
    output wire rng_ready,
    output wire out_valid,
    input wire out_ready,
    output wire [31:0] out_id,
    output wire [31:0] out_word,
    output wire [3:0] out_component,
    output wire [6:0] out_index,
    output wire [11:0] out_bits,
    output wire out_last,
    output wire done_valid,
    input wire done_ready,
    output reg [31:0] done_id,
    output reg [7:0] done_status
);
    localparam IDLE = 2'd0, COLLECT = 2'd1, EMIT = 2'd2, DONE = 2'd3;
    localparam [7:0] SUCCESS = 8'd0, UNSUPPORTED = 8'd1,
        RNG_FAILURE = 8'd2, CANCELLED = 8'd3, BAD_METADATA = 8'd4;
    reg [1:0] state;
    reg armed;
    reg [255:0] key_material;
    reg [11:0] key_bits;
    reg [3:0] words_required, accepted_words;
    reg [6:0] emit_index;
    wire active = state == COLLECT || state == EMIT;
    wire clear_controls = work_cancel === 1'b0 && rng_error === 1'b0;
    wire [7:0] word_offset = (words_required - 1'b1 - emit_index) * 8'd32;

    assign work_ready = reset_n && state == IDLE && armed && work_cancel === 1'b0;
    assign busy = reset_n && state != IDLE;
    assign rng_ready = reset_n && state == COLLECT && clear_controls;
    assign out_valid = reset_n && state == EMIT && clear_controls;
    // Suppress secret payload whenever invalid, including fault/cancel/reset edges.
    assign out_word = out_valid ? key_material[word_offset +: 32] : 32'd0;
    assign out_id = out_valid ? done_id : 32'd0;
    assign out_component = out_valid ? 4'd1 : 4'd0; // AES secret-key component
    assign out_index = out_valid ? emit_index : 7'd0;
    assign out_bits = out_valid ? key_bits : 12'd0;
    assign out_last = out_valid && emit_index == words_required - 1'b1;
    assign done_valid = reset_n && state == DONE;

    always @(posedge clock or negedge reset_n) begin
        if (!reset_n) begin
            state <= IDLE;
            armed <= 1'b0; // Sample a low work_valid after reset before accepting work.
            key_material <= 0;
            key_bits <= 0; words_required <= 0; accepted_words <= 0; emit_index <= 0;
            done_id <= 0; done_status <= UNSUPPORTED;
        end else begin
            if (work_valid === 1'b0) armed <= 1'b1;
            // Fault dominates cancellation and any final input/output transfer.
            // Unknown fault/cancel controls are also rejected in simulation.
            if (active && rng_error !== 1'b0) begin
                key_material <= 0;
                key_bits <= 0; words_required <= 0; accepted_words <= 0; emit_index <= 0;
                done_status <= RNG_FAILURE;
                state <= DONE;
            end else if (active && work_cancel !== 1'b0) begin
                key_material <= 0;
                key_bits <= 0; words_required <= 0; accepted_words <= 0; emit_index <= 0;
                done_status <= CANCELLED;
                state <= DONE;
            end else case (state)
                IDLE: if (work_valid === 1'b1 && work_ready) begin
                    armed <= 1'b0;
                    key_material <= 0;
                    accepted_words <= 0; emit_index <= 0;
                    done_id <= (^work_id === 1'bx) ? 32'd0 : work_id;
                    if ((^work_id === 1'bx) || work_public_exponent !== 32'd0) begin
                        done_status <= BAD_METADATA;
                        state <= DONE;
                    end else if (!(work_key_bits === 12'd128 || work_key_bits === 12'd256)) begin
                        done_status <= UNSUPPORTED;
                        state <= DONE;
                    end else if (rng_error !== 1'b0) begin
                        done_status <= RNG_FAILURE;
                        state <= DONE;
                    end else begin
                        key_bits <= work_key_bits;
                        words_required <= work_key_bits == 12'd128 ? 4'd4 : 4'd8;
                        done_status <= SUCCESS;
                        state <= COLLECT;
                    end
                end
                COLLECT: if (rng_valid === 1'b1 && rng_ready) begin
                    if (^rng_data === 1'bx) begin
                        key_material <= 0;
                        key_bits <= 0; words_required <= 0; accepted_words <= 0; emit_index <= 0;
                        done_status <= RNG_FAILURE;
                        state <= DONE;
                    end else begin
                        // First accepted word becomes the most significant actual key word.
                        // Four words occupy low 128 bits; upper 128 remain zero for AES-128.
                        key_material <= {key_material[223:0], rng_data};
                        accepted_words <= accepted_words + 1'b1;
                        if (accepted_words + 1'b1 == words_required) state <= EMIT;
                    end
                end
                EMIT: if (out_valid && out_ready === 1'b1) begin
                    // Clear each accepted word; a stalled word remains stable.
                    key_material[word_offset +: 32] <= 0;
                    if (emit_index == words_required - 1'b1) begin
                        key_material <= 0;
                        key_bits <= 0; words_required <= 0; accepted_words <= 0; emit_index <= 0;
                        done_status <= SUCCESS;
                        state <= DONE;
                    end else emit_index <= emit_index + 1'b1;
                end
                DONE: if (done_ready === 1'b1) begin
                    state <= IDLE;
                    key_material <= 0;
                    key_bits <= 0; words_required <= 0; accepted_words <= 0; emit_index <= 0;
                    done_id <= 0;
                end
                default: begin
                    key_material <= 0;
                    key_bits <= 0; words_required <= 0; accepted_words <= 0; emit_index <= 0;
                    done_status <= BAD_METADATA;
                    state <= DONE;
                end
            endcase
        end
    end
endmodule
