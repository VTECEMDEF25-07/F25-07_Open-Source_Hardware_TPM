// Filename: keygen_mult32.v
// Modules: keygen_mult32
// Authors: Project contributors; see Git history.
// Date: 2026-10-13
// General Description: Selects the generic or Altera 32-bit multiplier resource with a common interface.
// AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

module keygen_mult32 (
    input clock_i,
    input reset_n_i,
    input clock_en_i,
    input valid_i,
    input [31:0] left_i,
    input [31:0] right_i,
    output valid_o,
    output [63:0] product_o
);
`ifdef KEYGEN_ALTERA
    keygen_mult32_altera implementation (
`else
    keygen_mult32_generic implementation (
`endif
        .clock_i(clock_i), .reset_n_i(reset_n_i), .clock_en_i(clock_en_i),
        .valid_i(valid_i), .left_i(left_i), .right_i(right_i),
        .valid_o(valid_o), .product_o(product_o)
    );
endmodule
