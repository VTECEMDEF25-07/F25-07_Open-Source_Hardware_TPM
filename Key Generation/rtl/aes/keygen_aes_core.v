// Standalone AES128/AES256 assembly under docs/INTERFACE.md.
// Whole-result ownership and terminal status are separate handshakes.
module keygen_aes_core (
    input wire clock_i,
    input wire reset_n_i,
    input wire peers_ready_i,
    input wire request_valid_i,
    output wire request_ready_o,
    input wire [1:0] request_profile_i,
    input wire [31:0] request_id_i,
    input wire generation_valid_i,
    output wire generation_ready_o,
    input wire [31:0] generation_data_i,
    input wire generation_failed_i,
    output wire result_valid_o,
    input wire result_ready_i,
    output wire [31:0] result_data_o,
    output wire [2:0] result_component_o,
    output wire [6:0] result_index_o,
    output wire result_component_last_o,
    output wire result_last_o,
    output wire [31:0] result_id_o,
    input wire ownership_valid_i,
    output wire ownership_ready_o,
    input wire ownership_accept_i,
    output wire result_discard_o,
    output wire status_valid_o,
    input wire status_ready_i,
    output wire [3:0] status_code_o,
    output wire [31:0] status_id_o
);
    localparam [2:0] SCRUB = 3'd0, IDLE = 3'd1, COLLECT = 3'd2,
                     EMIT = 3'd3, OWNERSHIP = 3'd4, STATUS = 3'd5;
    localparam [3:0] SUCCESS = 4'd0, INVALID_PROFILE = 4'd1,
                     GENERATION_FAILURE = 4'd2, RECEIVER_REJECTED = 4'd5,
                     PEER_UNAVAILABLE = 4'd8;
    reg [1:0] reset_release_reg;
    reg [2:0] state_reg;
    reg [3:0] word_count_reg;
    reg [2:0] word_index_reg;
    reg [31:0] operation_id_reg;
    reg [3:0] status_code_reg;
    reg terminal_pending_reg;
    reg discard_reg;
    reg [31:0] key_words_reg [0:7];
    wire running;
    wire unowned_active;
    wire fault;

    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) reset_release_reg <= 2'b00;
        else reset_release_reg <= {reset_release_reg[0], 1'b1};
    end
    assign running = reset_n_i && reset_release_reg[1];
    assign unowned_active = (state_reg == COLLECT) || (state_reg == EMIT) ||
                            (state_reg == OWNERSHIP);
    assign fault = unowned_active && (generation_failed_i || !peers_ready_i);
    assign request_ready_o = running && (state_reg == IDLE) && peers_ready_i;
    assign generation_ready_o = running && (state_reg == COLLECT) && !fault;
    assign result_valid_o = running && (state_reg == EMIT) && !fault;
    assign result_data_o = result_valid_o ? key_words_reg[word_index_reg] : 32'd0;
    assign result_component_o = result_valid_o ? 3'd1 : 3'd0;
    assign result_index_o = result_valid_o ? {4'd0, word_index_reg} : 7'd0;
    assign result_last_o = result_valid_o && ({1'b0, word_index_reg} == word_count_reg - 1'b1);
    assign result_component_last_o = result_last_o;
    assign result_id_o = running ? operation_id_reg : 32'd0;
    assign ownership_ready_o = running && (state_reg == OWNERSHIP) && !fault;
    assign result_discard_o = running && discard_reg;
    assign status_valid_o = running && (state_reg == STATUS);
    assign status_code_o = status_valid_o ? status_code_reg : SUCCESS;
    assign status_id_o = running ? operation_id_reg : 32'd0;

    // No asynchronous reset on the array: sweep every slot after reset and job.
    // Admission and terminal success both wait until this sweep finishes.
    always @(posedge clock_i) begin
        if (running) begin
            if (state_reg == SCRUB) key_words_reg[word_index_reg] <= 32'd0;
            else if (generation_ready_o && generation_valid_i)
                key_words_reg[word_index_reg] <= generation_data_i;
        end
    end

    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            state_reg <= SCRUB;
            word_count_reg <= 4'd0;
            word_index_reg <= 3'd0;
            operation_id_reg <= 32'd0;
            status_code_reg <= SUCCESS;
            terminal_pending_reg <= 1'b0;
            discard_reg <= 1'b0;
        end else if (running) begin
            if (fault) begin
                status_code_reg <= generation_failed_i ? GENERATION_FAILURE : PEER_UNAVAILABLE;
                terminal_pending_reg <= 1'b1;
                discard_reg <= 1'b1;
                word_index_reg <= 3'd0;
                state_reg <= SCRUB;
            end else begin
                case (state_reg)
                    SCRUB: begin
                        if (word_index_reg == 3'd7) begin
                            word_index_reg <= 3'd0;
                            word_count_reg <= 4'd0;
                            state_reg <= terminal_pending_reg ? STATUS : IDLE;
                        end else word_index_reg <= word_index_reg + 1'b1;
                    end
                    IDLE: begin
                        if (request_valid_i && request_ready_o) begin
                            operation_id_reg <= request_id_i;
                            status_code_reg <= SUCCESS;
                            word_index_reg <= 3'd0;
                            discard_reg <= 1'b0;
                            terminal_pending_reg <= 1'b1;
                            if (request_profile_i <= 2'd1) begin
                                word_count_reg <= (request_profile_i == 2'd0) ? 4'd4 : 4'd8;
                                state_reg <= COLLECT;
                            end else begin
                                status_code_reg <= INVALID_PROFILE;
                                state_reg <= SCRUB;
                            end
                        end
                    end
                    COLLECT: begin
                        if (generation_valid_i && generation_ready_o) begin
                            if ({1'b0, word_index_reg} == word_count_reg - 1'b1) begin
                                word_index_reg <= 3'd0;
                                state_reg <= EMIT;
                            end else word_index_reg <= word_index_reg + 1'b1;
                        end
                    end
                    EMIT: begin
                        if (result_valid_o && result_ready_i) begin
                            if (result_last_o) state_reg <= OWNERSHIP;
                            else word_index_reg <= word_index_reg + 1'b1;
                        end
                    end
                    OWNERSHIP: begin
                        if (ownership_valid_i && ownership_ready_o) begin
                            if (!ownership_accept_i) begin
                                status_code_reg <= RECEIVER_REJECTED;
                                discard_reg <= 1'b1;
                            end
                            word_index_reg <= 3'd0;
                            state_reg <= SCRUB;
                        end
                    end
                    STATUS: begin
                        if (status_valid_o && status_ready_i) begin
                            terminal_pending_reg <= 1'b0;
                            discard_reg <= 1'b0;
                            state_reg <= IDLE;
                        end
                    end
                    default: begin
                        state_reg <= SCRUB;
                        word_index_reg <= 3'd0;
                        terminal_pending_reg <= 1'b0;
                    end
                endcase
            end
        end
    end
endmodule
