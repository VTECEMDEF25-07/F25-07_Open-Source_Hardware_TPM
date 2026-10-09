`timescale 1ns/1ps

// Radix-2 iterative Montgomery multiplier.
//
// Preconditions: WIDTH >= 2, n is odd and greater than 1, and 0 <= a,b < n.
// The result is (a * b * (2^WIDTH)^-1) mod n. This module has no error
// output, so callers must enforce the preconditions before asserting start.
//
// Handshake: start is sampled only in IDLE. Operands are latched on acceptance;
// start while busy is ignored. busy is high from acceptance through calculation.
// done pulses for one cycle when result becomes valid. result then stays stable
// until the next completed operation or reset. A held-high start is accepted
// again after the module returns to IDLE.
module montgomery_mult #(parameter WIDTH = 2048)(
    input wire clk,
    input wire rst_n,
    input wire start,

    input wire [WIDTH-1:0] a,
    input wire [WIDTH-1:0] b,
    input wire [WIDTH-1:0] n,

    output reg [WIDTH-1:0] result,
    output reg done,
    output reg busy
);

    localparam IDLE   = 2'd0;
    localparam CALC   = 2'd1;
    localparam REDUCE = 2'd2;

    function integer counter_width;
        input integer value;
        integer remaining;
        begin
            remaining = value - 1;
            counter_width = 0;
            while (remaining > 0) begin
                counter_width = counter_width + 1;
                remaining = remaining >> 1;
            end
            if (counter_width == 0)
                counter_width = 1;
        end
    endfunction

    localparam COUNT_WIDTH = counter_width(WIDTH);
    localparam [31:0] LAST_ITERATION = WIDTH - 1;

    reg [1:0] state;
    reg [WIDTH-1:0] a_reg;
    reg [WIDTH-1:0] b_reg;
    reg [WIDTH-1:0] n_reg;
    reg [WIDTH+1:0] t_reg;
    reg [COUNT_WIDTH-1:0] iteration_count;

    wire [WIDTH+1:0] add_b;
    wire [WIDTH+1:0] add_n;
    wire [WIDTH+1:0] t_next;
    wire [WIDTH+1:0] reduced_t;

    // One radix-2 Montgomery step:
    // U = T + (a[0] ? B : 0)
    // T' = (U + (U[0] ? n : 0)) / 2
    // WIDTH+2 bits retain carries from both additions.
    assign add_b = a_reg[0]
                 ? t_reg + {{2{1'b0}}, b_reg}
                 : t_reg;

    assign add_n = add_b[0]
                 ? add_b + {{2{1'b0}}, n_reg}
                 : add_b;

    assign t_next = add_n >> 1;
    assign reduced_t = t_reg - {2'b00, n_reg};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= IDLE;
            a_reg          <= {WIDTH{1'b0}};
            b_reg          <= {WIDTH{1'b0}};
            n_reg          <= {WIDTH{1'b0}};
            t_reg          <= {(WIDTH+2){1'b0}};
            iteration_count <= {COUNT_WIDTH{1'b0}};
            result         <= {WIDTH{1'b0}};
            done           <= 1'b0;
            busy           <= 1'b0;
        end else begin
            // done defaults low, making completion a one-cycle pulse.
            done <= 1'b0;

            case (state)
                IDLE: begin
                    busy <= 1'b0;

                    if (start) begin
                        a_reg           <= a;
                        b_reg           <= b;
                        n_reg           <= n;
                        t_reg           <= {(WIDTH+2){1'b0}};
                        iteration_count <= {COUNT_WIDTH{1'b0}};
                        busy            <= 1'b1;
                        state           <= CALC;
                    end
                end

                CALC: begin
                    t_reg <= t_next;
                    a_reg <= a_reg >> 1;

                    if (iteration_count == LAST_ITERATION[COUNT_WIDTH-1:0]) begin
                        state <= REDUCE;
                    end else begin
                        iteration_count <= iteration_count + 1'b1;
                    end
                end

                REDUCE: begin
                    // For the stated input range, the loop leaves T < 2*n,
                    // so one conditional subtraction canonicalizes the result.
                    if (t_reg >= {2'b00, n_reg})
                        result <= reduced_t[WIDTH-1:0];
                    else
                        result <= t_reg[WIDTH-1:0];

                    busy  <= 1'b0;
                    done  <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    busy  <= 1'b0;
                end
            endcase
        end
    end

endmodule
