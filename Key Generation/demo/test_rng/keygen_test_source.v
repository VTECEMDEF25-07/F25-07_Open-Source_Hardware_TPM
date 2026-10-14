// Filename: keygen_test_source.v
// Modules: keygen_test_source
// Authors: Project contributors; see Git history.
// Date: 2026-10-13
// General Description: Produces deterministic generation words for test keys; it is not a production entropy source.
// AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

// Predictable public fixture source. This is NOT an approved cryptographic DRBG.
// Each block hashes domain[15] || seed[32] || counter_be[8], exactly 55 bytes.
module keygen_test_source (
    input clock_i,
    input reset_n_i,
    input start_valid_i,
    output start_ready_o,
    input [255:0] seed_i,
    output word_valid_o,
    input word_ready_i,
    output [31:0] data_o,
    output failed_o
);
    localparam IDLE = 0, INITIALIZE = 1, COMPRESS = 2;
    localparam FINALIZE = 3, OUTPUT_WORDS = 4, FAILED = 5;
    localparam [119:0] DOMAIN = 120'h4b455947454e2d544553542d763100;
    localparam [31:0] H0 = 32'h6a09e667, H1 = 32'hbb67ae85;
    localparam [31:0] H2 = 32'h3c6ef372, H3 = 32'ha54ff53a;
    localparam [31:0] H4 = 32'h510e527f, H5 = 32'h9b05688c;
    localparam [31:0] H6 = 32'h1f83d9ab, H7 = 32'h5be0cd19;
    reg [2:0] state_reg;
    reg [255:0] seed_reg, digest_reg;
    reg [63:0] counter_reg;
    reg [5:0] round_reg;
    reg [2:0] word_index_reg;
    reg [31:0] schedule_reg [0:15];
    reg [31:0] a_reg, b_reg, c_reg, d_reg, e_reg, f_reg, g_reg, h_reg;
    integer clear_index;
    wire [511:0] message_block;
    wire [3:0] schedule_index, index_minus_2, index_minus_7, index_minus_15;
    wire [31:0] schedule_word, first_sum, second_sum;

    function [31:0] rotate_right;
        input [31:0] value_i;
        input integer amount_i;
        begin rotate_right = (value_i >> amount_i) | (value_i << (32-amount_i)); end
    endfunction
    function [31:0] small_sigma_0;
        input [31:0] value_i;
        begin small_sigma_0 = rotate_right(value_i,7) ^ rotate_right(value_i,18) ^ (value_i >> 3); end
    endfunction
    function [31:0] small_sigma_1;
        input [31:0] value_i;
        begin small_sigma_1 = rotate_right(value_i,17) ^ rotate_right(value_i,19) ^ (value_i >> 10); end
    endfunction
    function [31:0] big_sigma_0;
        input [31:0] value_i;
        begin big_sigma_0 = rotate_right(value_i,2) ^ rotate_right(value_i,13) ^ rotate_right(value_i,22); end
    endfunction
    function [31:0] big_sigma_1;
        input [31:0] value_i;
        begin big_sigma_1 = rotate_right(value_i,6) ^ rotate_right(value_i,11) ^ rotate_right(value_i,25); end
    endfunction
    function [31:0] round_constant;
        input [5:0] index_i;
        begin
            case (index_i)
                0: round_constant=32'h428a2f98; 1: round_constant=32'h71374491;
                2: round_constant=32'hb5c0fbcf; 3: round_constant=32'he9b5dba5;
                4: round_constant=32'h3956c25b; 5: round_constant=32'h59f111f1;
                6: round_constant=32'h923f82a4; 7: round_constant=32'hab1c5ed5;
                8: round_constant=32'hd807aa98; 9: round_constant=32'h12835b01;
                10: round_constant=32'h243185be; 11: round_constant=32'h550c7dc3;
                12: round_constant=32'h72be5d74; 13: round_constant=32'h80deb1fe;
                14: round_constant=32'h9bdc06a7; 15: round_constant=32'hc19bf174;
                16: round_constant=32'he49b69c1; 17: round_constant=32'hefbe4786;
                18: round_constant=32'h0fc19dc6; 19: round_constant=32'h240ca1cc;
                20: round_constant=32'h2de92c6f; 21: round_constant=32'h4a7484aa;
                22: round_constant=32'h5cb0a9dc; 23: round_constant=32'h76f988da;
                24: round_constant=32'h983e5152; 25: round_constant=32'ha831c66d;
                26: round_constant=32'hb00327c8; 27: round_constant=32'hbf597fc7;
                28: round_constant=32'hc6e00bf3; 29: round_constant=32'hd5a79147;
                30: round_constant=32'h06ca6351; 31: round_constant=32'h14292967;
                32: round_constant=32'h27b70a85; 33: round_constant=32'h2e1b2138;
                34: round_constant=32'h4d2c6dfc; 35: round_constant=32'h53380d13;
                36: round_constant=32'h650a7354; 37: round_constant=32'h766a0abb;
                38: round_constant=32'h81c2c92e; 39: round_constant=32'h92722c85;
                40: round_constant=32'ha2bfe8a1; 41: round_constant=32'ha81a664b;
                42: round_constant=32'hc24b8b70; 43: round_constant=32'hc76c51a3;
                44: round_constant=32'hd192e819; 45: round_constant=32'hd6990624;
                46: round_constant=32'hf40e3585; 47: round_constant=32'h106aa070;
                48: round_constant=32'h19a4c116; 49: round_constant=32'h1e376c08;
                50: round_constant=32'h2748774c; 51: round_constant=32'h34b0bcb5;
                52: round_constant=32'h391c0cb3; 53: round_constant=32'h4ed8aa4a;
                54: round_constant=32'h5b9cca4f; 55: round_constant=32'h682e6ff3;
                56: round_constant=32'h748f82ee; 57: round_constant=32'h78a5636f;
                58: round_constant=32'h84c87814; 59: round_constant=32'h8cc70208;
                60: round_constant=32'h90befffa; 61: round_constant=32'ha4506ceb;
                62: round_constant=32'hbef9a3f7; 63: round_constant=32'hc67178f2;
                default: round_constant=32'b0;
            endcase
        end
    endfunction

    assign start_ready_o = reset_n_i && state_reg == IDLE;
    assign word_valid_o = reset_n_i && state_reg == OUTPUT_WORDS;
    assign data_o = word_valid_o ? digest_reg[255-word_index_reg*32 -: 32] : 32'b0;
    assign failed_o = reset_n_i && state_reg == FAILED;
    assign message_block = {DOMAIN, seed_reg, counter_reg, 8'h80, 64'd440};
    assign schedule_index = round_reg[3:0];
    assign index_minus_2 = schedule_index - 4'd2;
    assign index_minus_7 = schedule_index - 4'd7;
    assign index_minus_15 = schedule_index - 4'd15;
    assign schedule_word = round_reg < 16 ? schedule_reg[schedule_index] :
        small_sigma_1(schedule_reg[index_minus_2]) + schedule_reg[index_minus_7] +
        small_sigma_0(schedule_reg[index_minus_15]) + schedule_reg[schedule_index];
    assign first_sum = h_reg + big_sigma_1(e_reg) + ((e_reg & f_reg) ^ (~e_reg & g_reg)) +
        round_constant(round_reg) + schedule_word;
    assign second_sum = big_sigma_0(a_reg) + ((a_reg & b_reg) ^ (a_reg & c_reg) ^ (b_reg & c_reg));

    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            state_reg <= IDLE; seed_reg <= 0; digest_reg <= 0; counter_reg <= 0;
            round_reg <= 0; word_index_reg <= 0;
            a_reg <= 0; b_reg <= 0; c_reg <= 0; d_reg <= 0;
            e_reg <= 0; f_reg <= 0; g_reg <= 0; h_reg <= 0;
            for (clear_index=0; clear_index<16; clear_index=clear_index+1) schedule_reg[clear_index] <= 0;
        end else begin
            case (state_reg)
                IDLE: if (start_valid_i) begin
                    seed_reg <= seed_i; counter_reg <= 0; state_reg <= INITIALIZE;
                end
                INITIALIZE: begin
                    for (clear_index=0; clear_index<16; clear_index=clear_index+1)
                        schedule_reg[clear_index] <= message_block[511-clear_index*32 -: 32];
                    a_reg <= H0; b_reg <= H1; c_reg <= H2; d_reg <= H3;
                    e_reg <= H4; f_reg <= H5; g_reg <= H6; h_reg <= H7;
                    round_reg <= 0; state_reg <= COMPRESS;
                end
                COMPRESS: begin
                    if (round_reg >= 16) schedule_reg[schedule_index] <= schedule_word;
                    h_reg <= g_reg; g_reg <= f_reg; f_reg <= e_reg; e_reg <= d_reg + first_sum;
                    d_reg <= c_reg; c_reg <= b_reg; b_reg <= a_reg; a_reg <= first_sum + second_sum;
                    if (round_reg == 63) state_reg <= FINALIZE;
                    else round_reg <= round_reg + 1'b1;
                end
                FINALIZE: begin
                    digest_reg[255:224] <= a_reg + H0; digest_reg[223:192] <= b_reg + H1;
                    digest_reg[191:160] <= c_reg + H2; digest_reg[159:128] <= d_reg + H3;
                    digest_reg[127:96] <= e_reg + H4; digest_reg[95:64] <= f_reg + H5;
                    digest_reg[63:32] <= g_reg + H6; digest_reg[31:0] <= h_reg + H7;
                    word_index_reg <= 0; state_reg <= OUTPUT_WORDS;
                end
                OUTPUT_WORDS: if (word_ready_i) begin
                    if (word_index_reg == 7) begin
                        digest_reg <= 0; word_index_reg <= 0;
                        if (counter_reg == 64'hffffffffffffffff) state_reg <= FAILED;
                        else begin counter_reg <= counter_reg + 1'b1; state_reg <= INITIALIZE; end
                    end else word_index_reg <= word_index_reg + 1'b1;
                end
                FAILED: begin
                    seed_reg <= 0; digest_reg <= 0; counter_reg <= 0; round_reg <= 0; word_index_reg <= 0;
                    a_reg <= 0; b_reg <= 0; c_reg <= 0; d_reg <= 0;
                    e_reg <= 0; f_reg <= 0; g_reg <= 0; h_reg <= 0;
                    for (clear_index=0; clear_index<16; clear_index=clear_index+1) schedule_reg[clear_index] <= 0;
                end
                default: state_reg <= FAILED;
            endcase
        end
    end
endmodule
