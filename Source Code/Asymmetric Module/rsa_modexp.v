////////////////////////////////////////////////////////////////////////////////
// Filename:    rsa_modexp.v
// Author:      Sam McCrowell
// Date:        11/09/2026
// Version:     1.0
// Description: RSA modular exponentiation using one shared Montgomery core.
//
// Modification History:
// Date        By   Version  Change Description
// 11/09/2026  SMC  1.0      Added interface and register naming conventions.
// 11/09/2026  AG/Codex 1.1  Reused precompute subtraction sign for selection.
////////////////////////////////////////////////////////////////////////////////

`timescale 1ns/1ps

// Functional RSA modular-exponentiation prototype using one shared
// Montgomery multiplier.
//
// Computes result_o = base_i^exponent_i mod n_i. WIDTH >= 2; n_i must be odd
// and greater than 1; base_i must be less than n_i. Invalid inputs are rejected
// with a one-cycle done_o and error_o pulse. The exponent is unsigned.
//
// start_i is sampled only in IDLE, where the inputs are latched. A start_i while
// busy_o is high is ignored. done_o pulses when result_o is valid. result_o
// remains stable until the next completed request or reset. Callers should
// pulse start_i rather than hold it high.
//
// This implementation uses fixed-schedule square-and-multiply: every exponent
// bit performs both a square and a multiply, then selects the next accumulator.
// This avoids exponent-dependent latency, but is not a complete side-channel
// countermeasure and is not a production-security claim.
module rsa_modexp #(parameter WIDTH = 2048)(
    input wire clk_i,
    input wire reset_n_i,
    input wire start_i,

    input wire [WIDTH-1:0] base_i,
    input wire [WIDTH-1:0] exponent_i,
    input wire [WIDTH-1:0] n_i,

    output reg [WIDTH-1:0] result_o,
    output reg done_o,
    output reg busy_o,
    output reg error_o
);

    localparam [3:0]
        IDLE          = 4'd0,
        PRECOMPUTE    = 4'd1,
        CONVERT_START = 4'd2,
        CONVERT_WAIT  = 4'd3,
        SQUARE_START  = 4'd4,
        SQUARE_WAIT   = 4'd5,
        MULT_START    = 4'd6,
        MULT_WAIT     = 4'd7,
        FINAL_START   = 4'd8,
        FINAL_WAIT    = 4'd9;

    reg [3:0] state_reg;

    reg [WIDTH-1:0] base_reg;
    reg [WIDTH-1:0] exponent_reg;
    reg [WIDTH-1:0] n_reg;

    reg [WIDTH-1:0] precompute_reg;
    reg [WIDTH-1:0] r_mod_n_reg;
    reg [WIDTH-1:0] r_squared_mod_n_reg;
    reg [WIDTH-1:0] base_mont_reg;
    reg [WIDTH-1:0] accumulator_reg;
    reg [WIDTH-1:0] square_reg;

    reg [31:0] precompute_count_reg;
    reg [31:0] exponent_index_reg;

    reg mont_start;
    reg [WIDTH-1:0] mont_a;
    reg [WIDTH-1:0] mont_b;
    wire [WIDTH-1:0] mont_result;
    wire mont_done;

    wire [WIDTH:0] precompute_doubled;
    wire [WIDTH:0] modulus_extended;
    wire [WIDTH:0] precompute_subtracted;
    wire [WIDTH:0] precompute_next;

    assign precompute_doubled = {1'b0, precompute_reg} << 1;
    assign modulus_extended = {1'b0, n_reg};
    // In PRECOMPUTE, 0 <= precompute_reg < n_reg < 2^WIDTH. Thus
    // -2^WIDTH < (2*precompute_reg - n_reg) < 2^WIDTH, so the WIDTH+1
    // subtraction's top bit is the exact negative-result test. Reuse this
    // subtraction instead of a separate wide comparator and subtractor.
    // This is range-dependent, not a general unsigned-subtraction borrow rule.
    assign precompute_subtracted = precompute_doubled - modulus_extended;
    assign precompute_next = precompute_subtracted[WIDTH]
                           ? precompute_doubled : precompute_subtracted;

    // Build R mod n and R^2 mod n by repeated doubling from 1. For a value
    // already below n, doubling is below 2*n, so one subtraction is sufficient.
    // R = 2^WIDTH, matching the Montgomery multiplier's configured width.
    always @* begin
        mont_start = 1'b0;
        mont_a = {WIDTH{1'b0}};
        mont_b = {WIDTH{1'b0}};

        case (state_reg)
            CONVERT_START: begin
                mont_start = 1'b1;
                mont_a = base_reg;
                mont_b = r_squared_mod_n_reg;
            end

            SQUARE_START: begin
                mont_start = 1'b1;
                mont_a = accumulator_reg;
                mont_b = accumulator_reg;
            end

            MULT_START: begin
                mont_start = 1'b1;
                mont_a = square_reg;
                mont_b = base_mont_reg;
            end

            FINAL_START: begin
                mont_start = 1'b1;
                mont_a = accumulator_reg;
                mont_b = {{(WIDTH-1){1'b0}}, 1'b1};
            end

            default: begin
                mont_start = 1'b0;
            end
        endcase
    end

    montgomery_mult #(
        .WIDTH(WIDTH)
    ) montgomery_core (
        .clk_i(clk_i),
        .reset_n_i(reset_n_i),
        .start_i(mont_start),
        .a_i(mont_a),
        .b_i(mont_b),
        .n_i(n_reg),
        .result_o(mont_result),
        .done_o(mont_done),
        .busy_o()
    );

    always @(posedge clk_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            state_reg             <= IDLE;
            base_reg              <= {WIDTH{1'b0}};
            exponent_reg          <= {WIDTH{1'b0}};
            n_reg                 <= {WIDTH{1'b0}};
            precompute_reg        <= {WIDTH{1'b0}};
            r_mod_n_reg           <= {WIDTH{1'b0}};
            r_squared_mod_n_reg   <= {WIDTH{1'b0}};
            base_mont_reg         <= {WIDTH{1'b0}};
            accumulator_reg       <= {WIDTH{1'b0}};
            square_reg            <= {WIDTH{1'b0}};
            precompute_count_reg  <= 32'd0;
            exponent_index_reg    <= 32'd0;
            result_o              <= {WIDTH{1'b0}};
            done_o                <= 1'b0;
            busy_o                <= 1'b0;
            error_o               <= 1'b0;
        end else begin
            done_o  <= 1'b0;
            error_o <= 1'b0;

            case (state_reg)
                IDLE: begin
                    busy_o <= 1'b0;

                    if (start_i) begin
                        // Reject n_i <= 1, an even modulus, or base_i >= n_i.
                        if ((n_i <= {{(WIDTH-1){1'b0}}, 1'b1}) ||
                            (n_i[0] == 1'b0) || (base_i >= n_i)) begin
                            result_o <= {WIDTH{1'b0}};
                            done_o   <= 1'b1;
                            error_o  <= 1'b1;
                        end else begin
                            base_reg         <= base_i;
                            exponent_reg     <= exponent_i;
                            n_reg            <= n_i;
                            precompute_reg   <= {{(WIDTH-1){1'b0}}, 1'b1};
                            r_mod_n_reg      <= {WIDTH{1'b0}};
                            r_squared_mod_n_reg <= {WIDTH{1'b0}};
                            base_mont_reg    <= {WIDTH{1'b0}};
                            accumulator_reg  <= {WIDTH{1'b0}};
                            square_reg        <= {WIDTH{1'b0}};
                            precompute_count_reg <= 32'd0;
                            busy_o                <= 1'b1;
                            state_reg             <= PRECOMPUTE;
                        end
                    end
                end

                PRECOMPUTE: begin
                    precompute_reg <= precompute_next[WIDTH-1:0];

                    if (precompute_count_reg == WIDTH-1)
                        r_mod_n_reg <= precompute_next[WIDTH-1:0];

                    if (precompute_count_reg == (2*WIDTH)-1) begin
                        r_squared_mod_n_reg <= precompute_next[WIDTH-1:0];
                        accumulator_reg     <= r_mod_n_reg;
                        exponent_index_reg  <= WIDTH-1;
                        state_reg           <= CONVERT_START;
                    end else begin
                        precompute_count_reg <= precompute_count_reg + 1'b1;
                    end
                end

                CONVERT_START: begin
                    state_reg <= CONVERT_WAIT;
                end

                CONVERT_WAIT: begin
                    if (mont_done) begin
                        base_mont_reg <= mont_result;
                        state_reg     <= SQUARE_START;
                    end
                end

                SQUARE_START: begin
                    state_reg <= SQUARE_WAIT;
                end

                SQUARE_WAIT: begin
                    if (mont_done) begin
                        square_reg <= mont_result;
                        state_reg  <= MULT_START;
                    end
                end

                MULT_START: begin
                    state_reg <= MULT_WAIT;
                end

                MULT_WAIT: begin
                    if (mont_done) begin
                        if (exponent_reg[exponent_index_reg])
                            accumulator_reg <= mont_result;
                        else
                            accumulator_reg <= square_reg;

                        if (exponent_index_reg == 0) begin
                            state_reg <= FINAL_START;
                        end else begin
                            exponent_index_reg <= exponent_index_reg - 1'b1;
                            state_reg          <= SQUARE_START;
                        end
                    end
                end

                FINAL_START: begin
                    state_reg <= FINAL_WAIT;
                end

                FINAL_WAIT: begin
                    if (mont_done) begin
                        result_o         <= mont_result;
                        exponent_reg    <= {WIDTH{1'b0}};
                        base_reg        <= {WIDTH{1'b0}};
                        n_reg           <= {WIDTH{1'b0}};
                        precompute_reg  <= {WIDTH{1'b0}};
                        r_mod_n_reg     <= {WIDTH{1'b0}};
                        r_squared_mod_n_reg <= {WIDTH{1'b0}};
                        base_mont_reg   <= {WIDTH{1'b0}};
                        accumulator_reg <= {WIDTH{1'b0}};
                        square_reg       <= {WIDTH{1'b0}};
                        busy_o          <= 1'b0;
                        done_o          <= 1'b1;
                        state_reg       <= IDLE;
                    end
                end

                default: begin
                    state_reg <= IDLE;
                    busy_o    <= 1'b0;
                end
            endcase
        end
    end

endmodule
