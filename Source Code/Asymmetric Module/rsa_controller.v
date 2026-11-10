////////////////////////////////////////////////////////////////////////////////
// Filename:    rsa_controller.v
// Author:      Sam McCrowell
// Date:        11/09/2026
// Version:     1.0
// Description: Selects the RSA exponent and sequences modular exponentiation.
//
// Modification History:
// Date        By   Version  Change Description
// 11/09/2026  SMC  1.0      Added registered naming and simplified launch FSM.
////////////////////////////////////////////////////////////////////////////////

`timescale 1ns/1ps

// This is a provisional arithmetic interface, not a TPM command or bus
// interface. The WIDTH-bit vectors are intended to connect to internal key,
// memory, or command-processing logic. Do not connect them directly to FPGA
// package pins; the system-level bus interface is a separate integration task.
//
// start_i is accepted while idle. rsa_modexp samples the request operands on
// that same edge, so the caller must hold them stable through the accepting
// edge. A start_i while busy_o is high is ignored. done_o and error_o pulse
// together when the operation completes.
module rsa_controller #(parameter WIDTH = 2048)(
    input wire clk_i,
    input wire reset_n_i,
    input wire start_i,

    input wire use_private_key_i,
    input wire [WIDTH-1:0] representative_i,
    input wire [WIDTH-1:0] modulus_i,
    input wire [WIDTH-1:0] public_exponent_i,
    input wire [WIDTH-1:0] private_exponent_i,

    output reg [WIDTH-1:0] result_o,
    output reg done_o,
    output reg busy_o,
    output reg error_o
);

    localparam IDLE       = 1'b0;
    localparam WAIT_MODEXP = 1'b1;

    reg state_reg;

    wire modexp_start;
    wire [WIDTH-1:0] selected_exponent;
    wire [WIDTH-1:0] modexp_result;
    wire modexp_done;
    wire modexp_error;

    // Launch the child in the same cycle that this controller accepts start_i.
    // The child captures these same-cycle inputs into its own operand registers.
    assign modexp_start = (state_reg == IDLE) && start_i;
    assign selected_exponent = use_private_key_i
                             ? private_exponent_i
                             : public_exponent_i;

    rsa_modexp #(
        .WIDTH(WIDTH)
    ) modexp_engine (
        .clk_i(clk_i),
        .reset_n_i(reset_n_i),
        .start_i(modexp_start),
        .base_i(representative_i),
        .exponent_i(selected_exponent),
        .n_i(modulus_i),
        .result_o(modexp_result),
        .done_o(modexp_done),
        .busy_o(),
        .error_o(modexp_error)
    );

    always @(posedge clk_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            state_reg <= IDLE;
            result_o  <= {WIDTH{1'b0}};
            done_o    <= 1'b0;
            busy_o    <= 1'b0;
            error_o   <= 1'b0;
        end else begin
            done_o  <= 1'b0;
            error_o <= 1'b0;

            case (state_reg)
                IDLE: begin
                    busy_o <= 1'b0;
                    if (start_i) begin
                        busy_o   <= 1'b1;
                        state_reg <= WAIT_MODEXP;
                    end
                end

                WAIT_MODEXP: begin
                    if (modexp_done) begin
                        result_o  <= modexp_result;
                        busy_o    <= 1'b0;
                        done_o    <= 1'b1;
                        error_o   <= modexp_error;
                        state_reg <= IDLE;
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
