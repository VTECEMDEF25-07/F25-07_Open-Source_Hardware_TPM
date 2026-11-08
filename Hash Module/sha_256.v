// SHA-256 Top Level Module
// Pulse start_en_i while !busy_o, then wait for data_ready_o before sending bytes.
// Bytes transfer on rising edges when data_valid_i && data_ready_o.
// message_end_i is accepted only while data_ready_o and may accompany the last
// byte or be sent alone (also used for an empty message).
// Hold unaccepted inputs until ready. hash_valid_o pulses for one clock;
// hash_out_reg_o stays stable until the next completed message. reset_n_i aborts.

module sha_256 (
    input  wire         clk_i,
    input  wire         reset_n_i,
    input  wire         start_en_i,
    input  wire [7:0]   data_in_i,
    input  wire         data_valid_i,
    input  wire         message_end_i,
    output wire         data_ready_o,
    output wire         busy_o,
    output reg  [255:0] hash_out_reg_o,
    output wire         hash_valid_o
);
    wire child_reset_n, buffer_data_valid, buffer_message_end, launch_en;
    wire capture_full_en, capture_padding_en, capture_second_en, select_second_en;
    wire capture_hash_en;
    wire [511:0] full_block, partial_data, padded_block;
    wire [6:0] partial_bytes;
    wire [63:0] message_length;
    wire full_valid, partial_valid, padded_valid, padding_busy;
    wire [31:0] schedule_word;
    wire [6:0] schedule_index;
    wire schedule_valid, schedule_done, schedule_busy;
    wire [255:0] round_hash;
    wire round_valid, round_busy;
    reg [511:0] active_block_reg, second_block_reg;

    sha256_controller u_controller (
        .clk_i(clk_i), .reset_n_i(reset_n_i), .start_en_i(start_en_i),
        .data_valid_i(data_valid_i), .message_end_i(message_end_i),
        .full_valid_i(full_valid), .padded_valid_i(padded_valid),
        .padding_busy_i(padding_busy), .round_valid_i(round_valid),
        .data_ready_o(data_ready_o), .busy_o(busy_o),
        .child_reset_n_o(child_reset_n), .buffer_data_valid_o(buffer_data_valid),
        .buffer_message_end_o(buffer_message_end), .launch_en_o(launch_en),
        .capture_full_en_o(capture_full_en), .capture_padding_en_o(capture_padding_en),
        .capture_second_en_o(capture_second_en), .select_second_en_o(select_second_en),
        .capture_hash_en_o(capture_hash_en), .hash_valid_reg_o(hash_valid_o)
    );
    input_buffer u_input_buffer (
        .clk(clk_i), .reset_n(child_reset_n), .data_in(data_in_i),
        .data_valid(buffer_data_valid), .message_end(buffer_message_end),
        .block_out(full_block), .block_valid(full_valid),
        .partial_data(partial_data), .partial_bytes(partial_bytes),
        .partial_valid(partial_valid), .message_length(message_length)
    );
    padding u_padding (
        .clk(clk_i), .reset_n(child_reset_n),
        .partial_data(partial_data), .partial_bytes(partial_bytes),
        .partial_valid(partial_valid), .message_length(message_length),
        .block_out(padded_block), .block_valid(padded_valid),
        .busy(padding_busy)
    );
    message_schedule u_message_schedule (
        .clk(clk_i), .reset_n(child_reset_n), .block_in(active_block_reg),
        .block_valid(launch_en), .word_out(schedule_word),
        .word_index(schedule_index), .word_valid(schedule_valid),
        .schedule_done(schedule_done), .busy(schedule_busy)
    );
    round_operations u_round_operations (
        .clk(clk_i), .reset_n(child_reset_n), .word_in(schedule_word),
        .word_valid(schedule_valid), .start(launch_en),
        .hash_out(round_hash), .hash_valid(round_valid), .busy(round_busy)
    );

    // Save both padding blocks because padding has no backpressure input.
    // Keep the published digest separate from intermediate block hashes.
    always @(posedge clk_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            active_block_reg <= 512'b0;
            second_block_reg <= 512'b0;
            hash_out_reg_o <= 256'b0;
        end else begin
            if (capture_full_en) active_block_reg <= full_block;
            else if (capture_padding_en) active_block_reg <= padded_block;
            else if (select_second_en) active_block_reg <= second_block_reg;
            if (capture_second_en) second_block_reg <= padded_block;
            if (capture_hash_en) hash_out_reg_o <= round_hash;
        end
    end
endmodule
