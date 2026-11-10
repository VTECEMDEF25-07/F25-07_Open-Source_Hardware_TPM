////////////////////////////////////////////////////////////////////////////////
// Filename:    montgomery_mult.v
// Author:      Sam McCrowell
// Date:        11/09/2026
// Version:     1.0
// Description: Iterative radix-2 Montgomery multiplication datapath.
//
// Modification History:
// Date        By   Version  Change Description
// 11/09/2026  SMC  1.0      Registered the two add stages and standardized names.
////////////////////////////////////////////////////////////////////////////////

`timescale 1ns/1ps

// Radix-2 iterative Montgomery multiplier.
//
// Preconditions: WIDTH >= 2, n_i is odd and greater than 1, and
// 0 <= a_i,b_i < n_i.
// The result is (a * b * (2^WIDTH)^-1) mod n. This module has no error
// output, so callers must enforce the preconditions before asserting start.
//
// The width-sized operands are internal datapath buses, not FPGA package I/O.
// The two adder stages take two cycles per multiplier bit, followed by one
// reduction cycle. start_i is sampled only in IDLE; busy_o is high while active.
// done_o pulses for one cycle; result_o remains stable until the next result or
// reset. A held-high start_i can be accepted again after returning to IDLE.
module montgomery_mult #(parameter WIDTH = 2048)(
    input wire clk_i,
    input wire reset_n_i,
    input wire start_i,

    input wire [WIDTH-1:0] a_i,
    input wire [WIDTH-1:0] b_i,
    input wire [WIDTH-1:0] n_i,

    output reg [WIDTH-1:0] result_o,
    output reg done_o,
    output reg busy_o
);

    localparam IDLE       = 2'd0;
    localparam CALC_ADD_B = 2'd1;
    localparam CALC_ADD_N = 2'd2;
    localparam REDUCE     = 2'd3;

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

    reg [1:0] state_reg;
    reg [WIDTH-1:0] a_reg;
    reg [WIDTH-1:0] b_reg;
    reg [WIDTH-1:0] n_reg;
    reg [WIDTH+1:0] t_reg;
    reg [WIDTH+1:0] intermediate_reg;
    reg [COUNT_WIDTH-1:0] iteration_count_reg;

    wire [WIDTH+1:0] add_b;
    wire [WIDTH+1:0] add_n;
    wire [WIDTH+1:0] t_next;
    wire [WIDTH+1:0] reduced_t;

    // First stage: U = T + (a[0] ? B : 0). WIDTH+2 bits retain the carry.
    assign add_b = a_reg[0]
                 ? t_reg + {{2{1'b0}}, b_reg}
                 : t_reg;

    // Second stage: T' = (U + (U[0] ? n : 0)) / 2.
    assign add_n = intermediate_reg[0]
                 ? intermediate_reg + {{2{1'b0}}, n_reg}
                 : intermediate_reg;

    assign t_next = add_n >> 1;
    assign reduced_t = t_reg - {2'b00, n_reg};

    always @(posedge clk_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            state_reg          <= IDLE;
            a_reg          <= {WIDTH{1'b0}};
            b_reg          <= {WIDTH{1'b0}};
            n_reg          <= {WIDTH{1'b0}};
            t_reg          <= {(WIDTH+2){1'b0}};
            intermediate_reg <= {(WIDTH+2){1'b0}};
            iteration_count_reg <= {COUNT_WIDTH{1'b0}};
            result_o       <= {WIDTH{1'b0}};
            done_o         <= 1'b0;
            busy_o         <= 1'b0;
        end else begin
            // done_o defaults low, making completion a one-cycle pulse.
            done_o <= 1'b0;

            case (state_reg)
                IDLE: begin
                    busy_o <= 1'b0;

                    if (start_i) begin
                        a_reg           <= a_i;
                        b_reg           <= b_i;
                        n_reg           <= n_i;
                        t_reg           <= {(WIDTH+2){1'b0}};
                        iteration_count_reg <= {COUNT_WIDTH{1'b0}};
                        busy_o          <= 1'b1;
                        state_reg       <= CALC_ADD_B;
                    end
                end

                CALC_ADD_B: begin
                    intermediate_reg <= add_b;
                    state_reg         <= CALC_ADD_N;
                end

                CALC_ADD_N: begin
                    t_reg <= t_next;
                    a_reg <= a_reg >> 1;

                    if (iteration_count_reg == LAST_ITERATION[COUNT_WIDTH-1:0]) begin
                        state_reg <= REDUCE;
                    end else begin
                        iteration_count_reg <= iteration_count_reg + 1'b1;
                        state_reg <= CALC_ADD_B;
                    end
                end

                REDUCE: begin
                    // For the stated input range, the loop leaves T < 2*n,
                    // so one conditional subtraction canonicalizes the result.
                    if (t_reg >= {2'b00, n_reg})
                        result_o <= reduced_t[WIDTH-1:0];
                    else
                        result_o <= t_reg[WIDTH-1:0];

                    busy_o    <= 1'b0;
                    done_o    <= 1'b1;
                    state_reg <= IDLE;
                end

                default: begin
                    state_reg <= IDLE;
                    busy_o    <= 1'b0;
                end
            endcase
        end
    end

endmodule
