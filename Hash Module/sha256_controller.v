// SHA 256 Controller Module
// Control-only FSM. sha_256 owns the datapath instances and storage.
// Capture/select outputs are clock enables for registers in sha_256.

module sha256_controller (
    input  wire         clk,
    input  wire         reset_n,
    input  wire         start,
    input  wire         data_valid,
    input  wire         message_end,
    input  wire         full_valid,
    input  wire         padded_valid,
    input  wire         padding_busy,
    input  wire         round_valid,
    output wire         data_ready,
    output wire         busy,
    output wire         child_reset_n,
    output wire         buffer_data_valid,
    output wire         buffer_message_end,
    output wire         launch,
    output wire         capture_full,
    output wire         capture_padding,
    output wire         capture_second,
    output wire         select_second,
    output wire         capture_hash,
    output reg          hash_valid
);
    localparam [3:0] IDLE = 4'd0, INIT = 4'd1, RECEIVE = 4'd2,
        FULL_CAPTURE = 4'd3, END_SIGNAL = 4'd4, PAD_WAIT = 4'd5,
        PAD_SECOND = 4'd6, LAUNCH = 4'd7, HASH_WAIT = 4'd8;

    reg [3:0] state;
    reg [5:0] byte_count;
    reg end_pending;
    reg final_block;
    reg second_pending;

    // round_operations retains its chaining state between blocks. INIT
    // resets all children for one full cycle at the start of each message.
    assign child_reset_n = reset_n && (state != INIT);
    assign data_ready = reset_n && (state == RECEIVE);
    assign busy = (state != IDLE);

    assign buffer_data_valid = data_valid && data_ready;
    assign buffer_message_end = (state == END_SIGNAL);
    assign launch = (state == LAUNCH);
    assign capture_full = (state == FULL_CAPTURE) && full_valid;
    assign capture_padding = (state == PAD_WAIT) && padded_valid;
    assign capture_second = (state == PAD_SECOND) && padded_valid;
    assign select_second = (state == HASH_WAIT) && round_valid && second_pending;
    assign capture_hash = (state == HASH_WAIT) && round_valid &&
                          !second_pending && final_block;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= IDLE;
            byte_count <= 0;
            end_pending <= 0;
            final_block <= 0;
            second_pending <= 0;
            hash_valid <= 0;
        end else begin
            hash_valid <= 1'b0;
            case (state)
                IDLE: if (start) state <= INIT;
                INIT: begin
                    byte_count <= 0;
                    end_pending <= 0;
                    final_block <= 0;
                    second_pending <= 0;
                    state <= RECEIVE;
                end
                RECEIVE: begin
                    if (data_valid) begin
                        byte_count <= byte_count + 1'b1;
                        if (byte_count == 6'd63) begin
                            end_pending <= message_end;
                            state <= FULL_CAPTURE;
                        end else if (message_end) begin
                            state <= END_SIGNAL;
                        end
                    end else if (message_end) begin
                        state <= END_SIGNAL;
                    end
                end
                FULL_CAPTURE: if (full_valid) begin
                    final_block <= 1'b0;
                    state <= LAUNCH;
                end
                // Delay end by a cycle so the buffer includes the last byte.
                END_SIGNAL: state <= PAD_WAIT;
                PAD_WAIT: if (padded_valid) begin
                    final_block <= !padding_busy;
                    if (padding_busy) state <= PAD_SECOND;
                    else state <= LAUNCH;
                end
                // padding cannot be stalled: save its consecutive second block.
                PAD_SECOND: if (padded_valid) begin
                    second_pending <= 1'b1;
                    state <= LAUNCH;
                end
                // Both engines accept the pulse here. The scheduler expands
                // the block before emitting words, allowing rounds to start.
                LAUNCH: state <= HASH_WAIT;
                HASH_WAIT: if (round_valid) begin
                    if (second_pending) begin
                        second_pending <= 1'b0;
                        final_block <= 1'b1;
                        state <= LAUNCH;
                    end else if (final_block) begin
                        hash_valid <= 1'b1;
                        state <= IDLE;
                    end else if (end_pending) begin
                        end_pending <= 1'b0;
                        state <= END_SIGNAL;
                    end else begin
                        state <= RECEIVE;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
