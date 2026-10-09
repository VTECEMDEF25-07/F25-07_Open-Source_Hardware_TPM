`timescale 1ns/1ps

// Functional RSA modular-exponentiation prototype using one shared
// Montgomery multiplier.
//
// Computes result = base^exponent mod n. WIDTH >= 2; n must be odd and > 1;
// base must be less than n. Invalid modulus/base inputs are rejected with a
// one-cycle done and error pulse. The exponent is an unsigned WIDTH-bit value.
//
// start is sampled only in IDLE, where the inputs are latched. start while busy
// is ignored. done pulses with busy low when result is valid. result remains
// stable until the next completed request or reset. A held-high start can be
// accepted again after the FSM returns to IDLE; callers should pulse start.
//
// This implementation uses fixed-schedule square-and-multiply: every exponent
// bit performs both a square and a multiply, then selects the next accumulator.
// This avoids exponent-dependent latency, but is not a complete side-channel
// countermeasure and is not a production-security claim.
module rsa_modexp #(parameter WIDTH = 2048)(
    input wire clk,
    input wire rst_n,
    input wire start,

    input wire [WIDTH-1:0] base,
    input wire [WIDTH-1:0] exponent,
    input wire [WIDTH-1:0] n,

    output reg [WIDTH-1:0] result,
    output reg done,
    output reg busy,
    output reg error
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

    reg [3:0] state;

    reg [WIDTH-1:0] base_reg;
    reg [WIDTH-1:0] exponent_reg;
    reg [WIDTH-1:0] n_reg;

    reg [WIDTH-1:0] precompute_reg;
    reg [WIDTH-1:0] r_mod_n_reg;
    reg [WIDTH-1:0] r_squared_mod_n_reg;
    reg [WIDTH-1:0] base_mont_reg;
    reg [WIDTH-1:0] accumulator_reg;
    reg [WIDTH-1:0] square_reg;

    reg [31:0] precompute_count;
    reg [31:0] exponent_index;

    reg mont_start;
    reg [WIDTH-1:0] mont_a;
    reg [WIDTH-1:0] mont_b;
    wire [WIDTH-1:0] mont_result;
    wire mont_done;

    wire [WIDTH:0] precompute_doubled;
    wire [WIDTH:0] modulus_extended;
    wire [WIDTH:0] precompute_next;

    assign precompute_doubled = {1'b0, precompute_reg} << 1;
    assign modulus_extended = {1'b0, n_reg};
    assign precompute_next = (precompute_doubled >= modulus_extended)
                           ? precompute_doubled - modulus_extended
                           : precompute_doubled;

    // Build R mod n and R^2 mod n by repeated doubling from 1. For a value
    // already below n, doubling is below 2*n, so one subtraction is sufficient.
    // R = 2^WIDTH, matching the Montgomery multiplier's configured width.
    always @* begin
        mont_start = 1'b0;
        mont_a = {WIDTH{1'b0}};
        mont_b = {WIDTH{1'b0}};

        case (state)
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
        .clk(clk),
        .rst_n(rst_n),
        .start(mont_start),
        .a(mont_a),
        .b(mont_b),
        .n(n_reg),
        .result(mont_result),
        .done(mont_done),
        .busy()
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state                 <= IDLE;
            base_reg              <= {WIDTH{1'b0}};
            exponent_reg          <= {WIDTH{1'b0}};
            n_reg                 <= {WIDTH{1'b0}};
            precompute_reg        <= {WIDTH{1'b0}};
            r_mod_n_reg           <= {WIDTH{1'b0}};
            r_squared_mod_n_reg   <= {WIDTH{1'b0}};
            base_mont_reg         <= {WIDTH{1'b0}};
            accumulator_reg       <= {WIDTH{1'b0}};
            square_reg            <= {WIDTH{1'b0}};
            precompute_count      <= 32'd0;
            exponent_index        <= 32'd0;
            result                <= {WIDTH{1'b0}};
            done                  <= 1'b0;
            busy                  <= 1'b0;
            error                 <= 1'b0;
        end else begin
            done  <= 1'b0;
            error <= 1'b0;

            case (state)
                IDLE: begin
                    busy <= 1'b0;

                    if (start) begin
                        if ((n <= {{(WIDTH-1){1'b0}}, 1'b1}) ||
                            (n[0] == 1'b0) || (base >= n)) begin
                            result <= {WIDTH{1'b0}};
                            done   <= 1'b1;
                            error  <= 1'b1;
                        end else begin
                            base_reg         <= base;
                            exponent_reg     <= exponent;
                            n_reg            <= n;
                            precompute_reg   <= {{(WIDTH-1){1'b0}}, 1'b1};
                            r_mod_n_reg      <= {WIDTH{1'b0}};
                            r_squared_mod_n_reg <= {WIDTH{1'b0}};
                            base_mont_reg    <= {WIDTH{1'b0}};
                            accumulator_reg  <= {WIDTH{1'b0}};
                            square_reg        <= {WIDTH{1'b0}};
                            precompute_count <= 32'd0;
                            busy              <= 1'b1;
                            state             <= PRECOMPUTE;
                        end
                    end
                end

                PRECOMPUTE: begin
                    precompute_reg <= precompute_next[WIDTH-1:0];

                    if (precompute_count == WIDTH-1)
                        r_mod_n_reg <= precompute_next[WIDTH-1:0];

                    if (precompute_count == (2*WIDTH)-1) begin
                        r_squared_mod_n_reg <= precompute_next[WIDTH-1:0];
                        accumulator_reg     <= r_mod_n_reg;
                        exponent_index      <= WIDTH-1;
                        state               <= CONVERT_START;
                    end else begin
                        precompute_count <= precompute_count + 1'b1;
                    end
                end

                CONVERT_START: begin
                    state <= CONVERT_WAIT;
                end

                CONVERT_WAIT: begin
                    if (mont_done) begin
                        base_mont_reg <= mont_result;
                        state         <= SQUARE_START;
                    end
                end

                SQUARE_START: begin
                    state <= SQUARE_WAIT;
                end

                SQUARE_WAIT: begin
                    if (mont_done) begin
                        square_reg <= mont_result;
                        state      <= MULT_START;
                    end
                end

                MULT_START: begin
                    state <= MULT_WAIT;
                end

                MULT_WAIT: begin
                    if (mont_done) begin
                        if (exponent_reg[exponent_index])
                            accumulator_reg <= mont_result;
                        else
                            accumulator_reg <= square_reg;

                        if (exponent_index == 0) begin
                            state <= FINAL_START;
                        end else begin
                            exponent_index <= exponent_index - 1'b1;
                            state          <= SQUARE_START;
                        end
                    end
                end

                FINAL_START: begin
                    state <= FINAL_WAIT;
                end

                FINAL_WAIT: begin
                    if (mont_done) begin
                        result          <= mont_result;
                        exponent_reg    <= {WIDTH{1'b0}};
                        base_reg        <= {WIDTH{1'b0}};
                        n_reg           <= {WIDTH{1'b0}};
                        precompute_reg  <= {WIDTH{1'b0}};
                        r_mod_n_reg     <= {WIDTH{1'b0}};
                        r_squared_mod_n_reg <= {WIDTH{1'b0}};
                        base_mont_reg   <= {WIDTH{1'b0}};
                        accumulator_reg <= {WIDTH{1'b0}};
                        square_reg       <= {WIDTH{1'b0}};
                        busy            <= 1'b0;
                        done            <= 1'b1;
                        state           <= IDLE;
                    end
                end

                default: begin
                    state <= IDLE;
                    busy  <= 1'b0;
                end
            endcase
        end
    end

endmodule
