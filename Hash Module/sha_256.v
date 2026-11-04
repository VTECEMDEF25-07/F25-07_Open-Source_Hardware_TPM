// SHA-256 Top Level Module
// Pulse start while !busy, then wait for data_ready before sending bytes.
// Bytes transfer on rising edges when data_valid && data_ready.
// message_end is accepted only while data_ready and may accompany the last
// byte or be sent alone (also used for an empty message).
// Hold unaccepted inputs until ready. hash_valid pulses for one clock;
// hash_out stays stable until the next completed message. reset_n aborts.

module sha_256 (
    input  wire         clk,
    input  wire         reset_n,
    input  wire         start,
    input  wire [7:0]   data_in,
    input  wire         data_valid,
    input  wire         message_end,
    output wire         data_ready,
    output wire         busy,
    output reg  [255:0] hash_out,
    output wire         hash_valid
);
    wire child_reset_n, buffer_data_valid, buffer_message_end, launch;
    wire capture_full, capture_padding, capture_second, select_second;
    wire capture_hash;
    wire [511:0] full_block, partial_data, padded_block;
    wire [6:0] partial_bytes;
    wire [63:0] message_length;
    wire full_valid, partial_valid, padded_valid, padding_busy;
    wire [31:0] schedule_word;
    wire [6:0] schedule_index;
    wire schedule_valid, schedule_done, schedule_busy;
    wire [255:0] round_hash;
    wire round_valid, round_busy;
    reg [511:0] active_block, second_block;

    sha256_controller u_controller (
        .clk(clk), .reset_n(reset_n), .start(start),
        .data_valid(data_valid), .message_end(message_end),
        .full_valid(full_valid), .padded_valid(padded_valid),
        .padding_busy(padding_busy), .round_valid(round_valid),
        .data_ready(data_ready), .busy(busy),
        .child_reset_n(child_reset_n), .buffer_data_valid(buffer_data_valid),
        .buffer_message_end(buffer_message_end), .launch(launch),
        .capture_full(capture_full), .capture_padding(capture_padding),
        .capture_second(capture_second), .select_second(select_second),
        .capture_hash(capture_hash), .hash_valid(hash_valid)
    );
    input_buffer u_input_buffer (
        .clk(clk), .reset_n(child_reset_n), .data_in(data_in),
        .data_valid(buffer_data_valid), .message_end(buffer_message_end),
        .block_out(full_block), .block_valid(full_valid),
        .partial_data(partial_data), .partial_bytes(partial_bytes),
        .partial_valid(partial_valid), .message_length(message_length)
    );
    padding u_padding (
        .clk(clk), .reset_n(child_reset_n),
        .partial_data(partial_data), .partial_bytes(partial_bytes),
        .partial_valid(partial_valid), .message_length(message_length),
        .block_out(padded_block), .block_valid(padded_valid),
        .busy(padding_busy)
    );
    message_schedule u_message_schedule (
        .clk(clk), .reset_n(child_reset_n), .block_in(active_block),
        .block_valid(launch), .word_out(schedule_word),
        .word_index(schedule_index), .word_valid(schedule_valid),
        .schedule_done(schedule_done), .busy(schedule_busy)
    );
    round_operations u_round_operations (
        .clk(clk), .reset_n(child_reset_n), .word_in(schedule_word),
        .word_valid(schedule_valid), .start(launch),
        .hash_out(round_hash), .hash_valid(round_valid), .busy(round_busy)
    );

    // Save both padding blocks because padding has no backpressure input.
    // Keep the published digest separate from intermediate block hashes.
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            active_block <= 512'b0;
            second_block <= 512'b0;
            hash_out <= 256'b0;
        end else begin
            if (capture_full) active_block <= full_block;
            else if (capture_padding) active_block <= padded_block;
            else if (select_second) active_block <= second_block;
            if (capture_second) second_block <= padded_block;
            if (capture_hash) hash_out <= round_hash;
        end
    end
endmodule
