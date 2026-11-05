`timescale 1ns/1ps

// Request sequencer for the RSA modular-exponentiation engine.
//
// This is a provisional arithmetic boundary, not a TPM command-marshalling
// interface. Raw TPM command data can have command- and scheme-dependent
// lengths. Padding/marshalling must convert that data to a WIDTH-bit RSA
// representative before submitting it here. For RSA-2048, representative,
// modulus, result, and both exponent ports are 2048 bits. A short public
// exponent such as 65537 is zero-extended to WIDTH bits by the caller.
//
// use_private_key selects the private exponent for decrypt/sign operations;
// otherwise the public exponent is selected for encrypt/verify. The key
// management/authorization logic must ensure private_exponent is supplied only
// for an authorized request. This module does not define TPM command opcodes.
//
// start is sampled in IDLE and all request operands are latched. A start while
// busy is ignored. done pulses with busy low when result/error is valid. Inputs
// must satisfy the rsa_modexp requirements; its error is forwarded here.
module rsa_controller #(parameter WIDTH = 2048)(
    input wire clk,
    input wire rst_n,
    input wire start,

    input wire use_private_key,
    input wire [WIDTH-1:0] representative,
    input wire [WIDTH-1:0] modulus,
    input wire [WIDTH-1:0] public_exponent,
    input wire [WIDTH-1:0] private_exponent,

    output reg [WIDTH-1:0] result,
    output reg done,
    output reg busy,
    output reg error
);

    localparam [1:0]
        IDLE         = 2'd0,
        START_MODEXP = 2'd1,
        WAIT_MODEXP  = 2'd2;

    reg [1:0] state;
    reg [WIDTH-1:0] representative_reg;
    reg [WIDTH-1:0] modulus_reg;
    reg [WIDTH-1:0] exponent_reg;

    reg modexp_start;
    wire [WIDTH-1:0] modexp_result;
    wire modexp_done;
    wire modexp_error;

    always @* begin
        modexp_start = (state == START_MODEXP);
    end

    rsa_modexp #(
        .WIDTH(WIDTH)
    ) modexp_engine (
        .clk(clk),
        .rst_n(rst_n),
        .start(modexp_start),
        .base(representative_reg),
        .exponent(exponent_reg),
        .n(modulus_reg),
        .result(modexp_result),
        .done(modexp_done),
        .busy(),
        .error(modexp_error)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state              <= IDLE;
            representative_reg <= {WIDTH{1'b0}};
            modulus_reg        <= {WIDTH{1'b0}};
            exponent_reg       <= {WIDTH{1'b0}};
            result             <= {WIDTH{1'b0}};
            done               <= 1'b0;
            busy               <= 1'b0;
            error              <= 1'b0;
        end else begin
            done  <= 1'b0;
            error <= 1'b0;

            case (state)
                IDLE: begin
                    busy <= 1'b0;

                    if (start) begin
                        representative_reg <= representative;
                        modulus_reg        <= modulus;
                        if (use_private_key)
                            exponent_reg <= private_exponent;
                        else
                            exponent_reg <= public_exponent;

                        busy  <= 1'b1;
                        state <= START_MODEXP;
                    end
                end

                START_MODEXP: begin
                    state <= WAIT_MODEXP;
                end

                WAIT_MODEXP: begin
                    if (modexp_done) begin
                        result             <= modexp_result;
                        representative_reg <= {WIDTH{1'b0}};
                        modulus_reg        <= {WIDTH{1'b0}};
                        exponent_reg       <= {WIDTH{1'b0}};
                        busy               <= 1'b0;
                        done               <= 1'b1;
                        error              <= modexp_error;
                        state              <= IDLE;
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
