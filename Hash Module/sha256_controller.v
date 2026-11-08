// SHA 256 Controller Module
// Control-only FSM. sha_256 owns the datapath instances and storage.
// Capture/select outputs are clock enables for registers in sha_256.

module sha256_controller (
    input  wire         clk_i,
    input  wire         reset_n_i,
    input  wire         start_en_i,
    input  wire         data_valid_i,
    input  wire         message_end_i,
    input  wire         full_valid_i,
    input  wire         padded_valid_i,
    input  wire         padding_busy_i,
    input  wire         round_valid_i,
    output wire         data_ready_o,
    output wire         busy_o,
    output wire         child_reset_n_o,
    output wire         buffer_data_valid_o,
    output wire         buffer_message_end_o,
    output wire         launch_en_o,
    output wire         capture_full_en_o,
    output wire         capture_padding_en_o,
    output wire         capture_second_en_o,
    output wire         select_second_en_o,
    output wire         capture_hash_en_o,
    output reg          hash_valid_reg_o
);
    localparam [3:0] IDLE = 4'd0, INIT = 4'd1, RECEIVE = 4'd2,
        FULL_CAPTURE = 4'd3, END_SIGNAL = 4'd4, PAD_WAIT = 4'd5,
        PAD_SECOND = 4'd6, LAUNCH = 4'd7, HASH_WAIT = 4'd8;

    reg [3:0] state_reg;
    reg [5:0] byte_count_reg;
    reg end_pending_reg;
    reg final_block_reg;
    reg second_pending_reg;

    // round_operations retains its chaining state_reg between blocks. INIT
    // resets all children for one full cycle at the start_en_i of each message.
    assign child_reset_n_o = reset_n_i && (state_reg != INIT);
    assign data_ready_o = reset_n_i && (state_reg == RECEIVE);
    assign busy_o = (state_reg != IDLE);

    assign buffer_data_valid_o = data_valid_i && data_ready_o;
    assign buffer_message_end_o = (state_reg == END_SIGNAL);
    assign launch_en_o = (state_reg == LAUNCH);
    assign capture_full_en_o = (state_reg == FULL_CAPTURE) && full_valid_i;
    assign capture_padding_en_o = (state_reg == PAD_WAIT) && padded_valid_i;
    assign capture_second_en_o = (state_reg == PAD_SECOND) && padded_valid_i;
    assign select_second_en_o = (state_reg == HASH_WAIT) && round_valid_i && second_pending_reg;
    assign capture_hash_en_o = (state_reg == HASH_WAIT) && round_valid_i &&
                          !second_pending_reg && final_block_reg;

    always @(posedge clk_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            state_reg <= IDLE;
            byte_count_reg <= 0;
            end_pending_reg <= 0;
            final_block_reg <= 0;
            second_pending_reg <= 0;
            hash_valid_reg_o <= 0;
        end else begin
            hash_valid_reg_o <= 1'b0;
            case (state_reg)
                IDLE: if (start_en_i) state_reg <= INIT;
                INIT: begin
                    byte_count_reg <= 0;
                    end_pending_reg <= 0;
                    final_block_reg <= 0;
                    second_pending_reg <= 0;
                    state_reg <= RECEIVE;
                end
                RECEIVE: begin
                    if (data_valid_i) begin
                        byte_count_reg <= byte_count_reg + 1'b1;
                        if (byte_count_reg == 6'd63) begin
                            end_pending_reg <= message_end_i;
                            state_reg <= FULL_CAPTURE;
                        end else if (message_end_i) begin
                            state_reg <= END_SIGNAL;
                        end
                    end else if (message_end_i) begin
                        state_reg <= END_SIGNAL;
                    end
                end
                FULL_CAPTURE: if (full_valid_i) begin
                    final_block_reg <= 1'b0;
                    state_reg <= LAUNCH;
                end
                // Delay end by a cycle so the buffer includes the last byte.
                END_SIGNAL: state_reg <= PAD_WAIT;
                PAD_WAIT: if (padded_valid_i) begin
                    final_block_reg <= !padding_busy_i;
                    if (padding_busy_i) state_reg <= PAD_SECOND;
                    else state_reg <= LAUNCH;
                end
                // padding cannot be stalled: save its consecutive second block.
                PAD_SECOND: if (padded_valid_i) begin
                    second_pending_reg <= 1'b1;
                    state_reg <= LAUNCH;
                end
                // Both engines accept the pulse here. The scheduler expands
                // the block before emitting words, allowing rounds to start_en_i.
                LAUNCH: state_reg <= HASH_WAIT;
                HASH_WAIT: if (round_valid_i) begin
                    if (second_pending_reg) begin
                        second_pending_reg <= 1'b0;
                        final_block_reg <= 1'b1;
                        state_reg <= LAUNCH;
                    end else if (final_block_reg) begin
                        hash_valid_reg_o <= 1'b1;
                        state_reg <= IDLE;
                    end else if (end_pending_reg) begin
                        end_pending_reg <= 1'b0;
                        state_reg <= END_SIGNAL;
                    end else begin
                        state_reg <= RECEIVE;
                    end
                end
                default: state_reg <= IDLE;
            endcase
        end
    end
endmodule
