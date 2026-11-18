// Public deterministic AES-256 demo key, generated once after each reset.
// Uses the Phase Two AES key assembly and ownership interface.
module lenovo_aes_key_service #(
    parameter [255:0] SEED = 256'd0
) (
    input wire clock_i, reset_n_i,
    input wire key_request_i, output wire key_request_ready_o,
    input wire [31:0] key_handle_i,
    output reg key_reply_valid_o, input wire key_reply_ready_i,
    output wire [255:0] resolved_key_o, output reg [31:0] key_reply_code_o,
    output reg key_ready_o
);
    localparam [31:0] HANDLE = 32'h80000000;
    reg started, source_started, failed;
    reg [1:0] reset_release_reg;
    reg [3:0] words_received;
    reg [255:0] candidate_key, stored_key;
    wire source_ready, source_valid, source_failed, generation_ready;
    wire [31:0] source_word, result_word, result_id, status_id;
    wire request_ready, result_valid, result_last, component_last;
    wire ownership_ready, discard, status_valid;
    wire [2:0] component;
    wire [6:0] index;
    wire [3:0] status;
    wire result_matches = component == 1 && index == {3'd0, words_received} &&
        words_received < 8 && result_id == 1 &&
        result_last == (words_received == 7) && component_last == result_last;

    demo_test_source source (
        .clock_i(clock_i), .reset_n_i(reset_n_i && !key_ready_o && !failed),
        .start_valid_i(reset_release_reg[1] && !source_started), .start_ready_o(source_ready), .seed_i(SEED),
        .word_valid_o(source_valid), .word_ready_i(generation_ready),
        .data_o(source_word), .failed_o(source_failed)
    );
    keygen_aes_core keygen (
        .clock_i(clock_i), .reset_n_i(reset_n_i), .peers_ready_i(1'b1),
        .request_valid_i(!started), .request_ready_o(request_ready),
        .request_profile_i(2'd1), .request_id_i(32'd1),
        .generation_valid_i(source_valid), .generation_ready_o(generation_ready),
        .generation_data_i(source_word), .generation_failed_i(source_failed),
        .result_valid_o(result_valid), .result_ready_i(1'b1), .result_data_o(result_word),
        .result_component_o(component), .result_index_o(index),
        .result_component_last_o(component_last), .result_last_o(result_last), .result_id_o(result_id),
        .ownership_valid_i(words_received == 8 || failed), .ownership_ready_o(ownership_ready),
        .ownership_accept_i(!failed && words_received == 8), .result_discard_o(discard),
        .status_valid_o(status_valid), .status_ready_i(1'b1),
        .status_code_o(status), .status_id_o(status_id)
    );
    // A request may wait for key generation, but replies remain held until taken.
    assign key_request_ready_o = !key_reply_valid_o && (key_ready_o || failed);
    assign resolved_key_o = key_reply_valid_o && key_reply_code_o == 0 ? stored_key : 256'd0;

    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            started <= 0;
            reset_release_reg <= 0;
            source_started <= 0;
            failed <= 0;
            words_received <= 0;
            candidate_key <= 0;
            stored_key <= 0;
            key_ready_o <= 0;
            key_reply_valid_o <= 0;
            key_reply_code_o <= 0;
        end else begin
            reset_release_reg <= {reset_release_reg[0], 1'b1};
            if (!started && request_ready) started <= 1;
            if (reset_release_reg[1] && !source_started && source_ready) source_started <= 1;
            if (result_valid) begin
                if (result_matches) begin
                    candidate_key <= {candidate_key[223:0], result_word};
                    words_received <= words_received + 1'b1;
                end else failed <= 1;
            end
            if (ownership_ready && words_received == 8 && !failed) begin
                stored_key <= candidate_key;
                candidate_key <= 0;
            end
            if (status_valid) begin
                if (status == 0 && status_id == 1 && words_received == 8 && !failed)
                    key_ready_o <= 1;
                else begin
                    failed <= 1;
                    candidate_key <= 0;
                    stored_key <= 0;
                end
            end
            if (discard || source_failed) begin
                failed <= 1;
                key_ready_o <= 0;
                candidate_key <= 0;
                stored_key <= 0;
            end
            if (key_request_i && key_request_ready_o) begin
                key_reply_valid_o <= 1;
                key_reply_code_o <= failed ? 32'h101 : key_handle_i == HANDLE ? 32'd0 : 32'h18b;
            end else if (key_reply_valid_o && key_reply_ready_i) begin
                key_reply_valid_o <= 0;
                key_reply_code_o <= 0;
            end
        end
    end
endmodule
