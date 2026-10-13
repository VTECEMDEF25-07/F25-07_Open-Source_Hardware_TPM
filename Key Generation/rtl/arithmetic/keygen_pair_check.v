// RSA pair arithmetic only. The caller has already performed primality tests.
// One captured request; private working registers clear before result_valid_o.
module keygen_pair_check (
    input clock_i,
    input reset_n_i,
    input start_valid_i,
    output start_ready_o,
    input [1023:0] p_i,
    input [1023:0] q_i,
    output result_valid_o,
    input result_ready_i,
    output [2047:0] n_o,
    output [3:0] status_o
);
    localparam IDLE = 0, BOUNDS = 1, MULT_ISSUE = 2, MULT_WAIT = 3;
    localparam PHI_P = 4, PHI_Q = 5, GCD = 6, GCD_ALIGN = 7;
    localparam DIVIDE_PHI = 8, FIND_K = 9, BUILD_NUMERATOR = 10;
    localparam DIVIDE_D = 11, CHECK_D = 12, SCRUB = 13, RESULT = 14;
    localparam [3:0] VALID = 0, BAD_PAIR = 1, LOW_D = 2, ARITHMETIC = 3;
    // ceil(sqrt(2)*2^1023); generated with integer square root, not floating point.
    localparam [1023:0] LOWER_BOUND = 1024'hb504f333f9de6484597d89b3754abe9f1d6f60ba893ba84ced17ac85833399154afc83043ab8a2c3a8b1fe6fdc83db390f74a85e439c7b4a780487363dfa2768d2202e8742af1f4e53059c6011bc337bcab1bc911688458a460abc722f7c4e33c6d5a8a38bb7e9dccb2a634331f3c84df52f120f836e582eeaa4a0899040ca4b;
    localparam [1023:0] MIN_SEPARATION = (1024'd1 << 924);

    reg [3:0] state_reg;
    reg [3:0] status_reg;
    reg [1023:0] p_reg, q_reg, gcd_left_reg, gcd_right_reg;
    reg [2047:0] n_reg, quotient_reg, lambda_reg, d_reg;
    reg [1024:0] remainder_reg;
    reg [10:0] common_shift_reg;
    reg [11:0] bit_count_reg;
    reg [5:0] row_reg, column_reg;
    reg [31:0] carry_reg;
    reg [16:0] lambda_residue_reg, k_reg, k_residue_reg;
    reg [2064:0] numerator_reg, lambda_shift_reg;
    reg [16:0] d_remainder_reg;
    reg [4:0] k_bit_reg;
    reg [1:0] scrub_count_reg;
    wire mult_valid;
    wire [63:0] mult_product;
    wire [63:0] product_sum;
    wire [6:0] product_index;
    wire [1023:0] difference;
    wire [1024:0] division_trial;
    wire division_bit;
    wire [1024:0] division_remainder;
    wire [2047:0] division_quotient;
    wire [17:0] residue_trial;
    wire [16:0] residue_next;
    wire [17:0] k_trial;
    wire [16:0] k_next_residue;
    wire [17:0] d_trial;
    wire d_bit;
    wire [16:0] d_next_remainder;
    wire [2064:0] d_next_quotient;

    assign start_ready_o = reset_n_i && (state_reg == IDLE);
    assign result_valid_o = reset_n_i && (state_reg == RESULT);
    assign n_o = result_valid_o && (status_reg == VALID) ? n_reg : 2048'b0;
    assign status_o = result_valid_o ? status_reg : 4'b0;
    assign difference = (p_reg >= q_reg) ? p_reg - q_reg : q_reg - p_reg;
    assign product_index = row_reg + column_reg;
    assign product_sum = mult_product + {32'b0, n_reg[product_index*32 +: 32]} + {32'b0, carry_reg};
    assign division_trial = {remainder_reg[1023:0], quotient_reg[2047]};
    assign division_bit = division_trial >= {1'b0, gcd_left_reg};
    assign division_remainder = division_bit ? division_trial - {1'b0, gcd_left_reg} : division_trial;
    assign division_quotient = {quotient_reg[2046:0], division_bit};
    assign residue_trial = {lambda_residue_reg, division_bit};
    assign residue_next = (residue_trial >= 18'd65537) ? residue_trial - 18'd65537 : residue_trial;
    assign k_trial = {1'b0, k_residue_reg} + {1'b0, lambda_residue_reg};
    assign k_next_residue = (k_trial >= 18'd65537) ? k_trial - 18'd65537 : k_trial;
    assign d_trial = {d_remainder_reg, numerator_reg[2064]};
    assign d_bit = d_trial >= 18'd65537;
    assign d_next_remainder = d_bit ? d_trial - 18'd65537 : d_trial;
    assign d_next_quotient = {numerator_reg[2063:0], d_bit};

    keygen_mult32 multiplier (
        .clock_i(clock_i), .reset_n_i(reset_n_i), .clock_en_i(1'b1),
        .valid_i(state_reg == MULT_ISSUE),
        .left_i(state_reg == MULT_ISSUE ? p_reg[row_reg*32 +: 32] : 32'b0),
        .right_i(state_reg == MULT_ISSUE ? q_reg[column_reg*32 +: 32] : 32'b0),
        .valid_o(mult_valid), .product_o(mult_product)
    );

    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            state_reg <= IDLE;
            status_reg <= VALID;
            p_reg <= 0; q_reg <= 0; gcd_left_reg <= 0; gcd_right_reg <= 0;
            n_reg <= 0; quotient_reg <= 0; lambda_reg <= 0; d_reg <= 0;
            remainder_reg <= 0; common_shift_reg <= 0; bit_count_reg <= 0;
            row_reg <= 0; column_reg <= 0; carry_reg <= 0;
            lambda_residue_reg <= 0; k_reg <= 0; k_residue_reg <= 0;
            numerator_reg <= 0; lambda_shift_reg <= 0; d_remainder_reg <= 0;
            k_bit_reg <= 0; scrub_count_reg <= 0;
        end else begin
            case (state_reg)
                IDLE: if (start_valid_i) begin
                    p_reg <= p_i;
                    q_reg <= q_i;
                    n_reg <= 0;
                    status_reg <= VALID;
                    state_reg <= BOUNDS;
                end
                BOUNDS: begin
                    if (!p_reg[0] || !q_reg[0] || p_reg < LOWER_BOUND ||
                        q_reg < LOWER_BOUND || difference <= MIN_SEPARATION) begin
                        status_reg <= BAD_PAIR;
                        state_reg <= SCRUB;
                    end else begin
                        row_reg <= 0; column_reg <= 0; carry_reg <= 0;
                        state_reg <= MULT_ISSUE;
                    end
                end
                MULT_ISSUE: state_reg <= MULT_WAIT;
                MULT_WAIT: if (mult_valid) begin
                    n_reg[product_index*32 +: 32] <= product_sum[31:0];
                    if (column_reg == 31) begin
                        n_reg[(row_reg+32)*32 +: 32] <= product_sum[63:32];
                        carry_reg <= 0;
                        column_reg <= 0;
                        if (row_reg == 31) state_reg <= PHI_P;
                        else begin row_reg <= row_reg + 1'b1; state_reg <= MULT_ISSUE; end
                    end else begin
                        carry_reg <= product_sum[63:32];
                        column_reg <= column_reg + 1'b1;
                        state_reg <= MULT_ISSUE;
                    end
                end
                PHI_P: begin
                    if (!n_reg[2047]) begin status_reg <= ARITHMETIC; state_reg <= SCRUB; end
                    else begin quotient_reg <= n_reg - {1024'b0, p_reg}; state_reg <= PHI_Q; end
                end
                PHI_Q: begin
                    quotient_reg <= quotient_reg - {1024'b0, q_reg} + 1'b1;
                    gcd_left_reg <= p_reg - 1'b1;
                    gcd_right_reg <= q_reg - 1'b1;
                    common_shift_reg <= 0;
                    state_reg <= GCD;
                end
                GCD: begin
                    if (gcd_left_reg == gcd_right_reg) state_reg <= GCD_ALIGN;
                    else if (!gcd_left_reg[0] && !gcd_right_reg[0]) begin
                        gcd_left_reg <= gcd_left_reg >> 1;
                        gcd_right_reg <= gcd_right_reg >> 1;
                        common_shift_reg <= common_shift_reg + 1'b1;
                    end else if (!gcd_left_reg[0]) gcd_left_reg <= gcd_left_reg >> 1;
                    else if (!gcd_right_reg[0]) gcd_right_reg <= gcd_right_reg >> 1;
                    else if (gcd_left_reg > gcd_right_reg) gcd_left_reg <= (gcd_left_reg - gcd_right_reg) >> 1;
                    else gcd_right_reg <= (gcd_right_reg - gcd_left_reg) >> 1;
                end
                GCD_ALIGN: begin
                    if (common_shift_reg != 0) begin
                        gcd_left_reg <= gcd_left_reg << 1;
                        common_shift_reg <= common_shift_reg - 1'b1;
                    end else begin
                        remainder_reg <= 0; lambda_residue_reg <= 0;
                        bit_count_reg <= 2048; state_reg <= DIVIDE_PHI;
                    end
                end
                DIVIDE_PHI: begin
                    quotient_reg <= division_quotient;
                    remainder_reg <= division_remainder;
                    lambda_residue_reg <= residue_next;
                    bit_count_reg <= bit_count_reg - 1'b1;
                    if (bit_count_reg == 1) begin
                        lambda_reg <= division_quotient;
                        if (division_remainder != 0 || division_quotient == 0) begin
                            status_reg <= ARITHMETIC; state_reg <= SCRUB;
                        end else if (residue_next == 0) begin status_reg <= BAD_PAIR; state_reg <= SCRUB; end
                        else begin k_reg <= 1; k_residue_reg <= residue_next; state_reg <= FIND_K; end
                    end
                end
                FIND_K: begin
                    if (k_residue_reg == 17'd65536) begin
                        numerator_reg <= 1;
                        lambda_shift_reg <= {17'b0, lambda_reg};
                        k_bit_reg <= 0;
                        state_reg <= BUILD_NUMERATOR;
                    end else if (k_reg == 17'd65536) begin status_reg <= ARITHMETIC; state_reg <= SCRUB; end
                    else begin k_reg <= k_reg + 1'b1; k_residue_reg <= k_next_residue; end
                end
                BUILD_NUMERATOR: begin
                    if (k_reg[k_bit_reg]) numerator_reg <= numerator_reg + lambda_shift_reg;
                    lambda_shift_reg <= lambda_shift_reg << 1;
                    if (k_bit_reg == 16) begin
                        bit_count_reg <= 2065; d_remainder_reg <= 0; state_reg <= DIVIDE_D;
                    end else k_bit_reg <= k_bit_reg + 1'b1;
                end
                DIVIDE_D: begin
                    numerator_reg <= d_next_quotient;
                    d_remainder_reg <= d_next_remainder;
                    bit_count_reg <= bit_count_reg - 1'b1;
                    if (bit_count_reg == 1) begin
                        d_reg <= d_next_quotient[2047:0];
                        if (d_next_remainder != 0 || d_next_quotient[2064:2048] != 0) begin
                            status_reg <= ARITHMETIC; state_reg <= SCRUB;
                        end else state_reg <= CHECK_D;
                    end
                end
                CHECK_D: begin
                    if (d_reg >= lambda_reg) status_reg <= ARITHMETIC;
                    else if (d_reg <= (2048'd1 << 1024)) status_reg <= LOW_D;
                    // Exact division established e*d = 1+k*lambda, including remainder check.
                    state_reg <= SCRUB;
                end
                SCRUB: begin
                    p_reg <= 0; q_reg <= 0; gcd_left_reg <= 0; gcd_right_reg <= 0;
                    quotient_reg <= 0; lambda_reg <= 0; d_reg <= 0; remainder_reg <= 0;
                    common_shift_reg <= 0; bit_count_reg <= 0; row_reg <= 0; column_reg <= 0;
                    carry_reg <= 0; lambda_residue_reg <= 0; k_reg <= 0; k_residue_reg <= 0;
                    numerator_reg <= 0; lambda_shift_reg <= 0; d_remainder_reg <= 0; k_bit_reg <= 0;
                    if (status_reg != VALID) n_reg <= 0;
                    if (scrub_count_reg == 2) begin scrub_count_reg <= 0; state_reg <= RESULT; end
                    else scrub_count_reg <= scrub_count_reg + 1'b1;
                end
                RESULT: if (result_ready_i) begin n_reg <= 0; status_reg <= VALID; state_reg <= IDLE; end
                default: begin status_reg <= ARITHMETIC; state_reg <= SCRUB; end
            endcase
        end
    end
endmodule
