// Filename: keygen_mult32_altera.v
// Modules: keygen_mult32_altera
// Authors: Project contributors; see Git history.
// Date: 2026-10-13
// General Description: Implements the Altera multiplier resource through a hand-instantiated vendor macro.
// AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

// Unsigned product: two enabled rising edges; reset invalidates the pipeline.
module keygen_mult32_altera (
    input clock_i,
    input reset_n_i,
    input clock_en_i,
    input valid_i,
    input [31:0] left_i,
    input [31:0] right_i,
    output valid_o,
    output [63:0] product_o
);
    reg [1:0] valid_reg;
    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) valid_reg <= 2'b00;
        else if (clock_en_i) valid_reg <= {valid_reg[0], valid_i};
    end
    assign valid_o = valid_reg[1];
    // Direct megafunction instantiation: no IP Catalog project required.
    lpm_mult #(
        .lpm_widtha(32), .lpm_widthb(32), .lpm_widthp(64),
        .lpm_widths(1), .lpm_representation("UNSIGNED"), .lpm_pipeline(2),
        .lpm_hint("DEDICATED_MULTIPLIER_CIRCUITRY=YES")
    ) multiply (
        .clock(clock_i), .clken(clock_en_i), .aclr(~reset_n_i), .sclr(1'b0),
        .dataa(left_i), .datab(right_i), .sum(1'b0), .result(product_o)
    );
endmodule
