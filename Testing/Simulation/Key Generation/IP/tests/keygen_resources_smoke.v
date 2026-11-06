// Filename: keygen_resources_smoke.v
// Modules: keygen_resources_smoke
// Authors: Project contributors; see Git history.
// Date: 2026-10-13
// General Description: Provides keygen resources smoke support for the key-generation implementation and verification.
// AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

// Compile-only resource top; no physical board programming.
module keygen_resources_smoke (
    input clock_i, input reset_n_i, input clock_en_i,
    input valid_i, input [31:0] left_i, input [31:0] right_i,
    input write_en_i, input read_en_i,
    input [7:0] write_address_i, input [7:0] read_address_i,
    input [31:0] write_data_i,
    output valid_o, output [63:0] product_o,
    output read_valid_o, output [31:0] read_data_o
);
    keygen_mult32 multiply (
        .clock_i(clock_i), .reset_n_i(reset_n_i), .clock_en_i(clock_en_i),
        .valid_i(valid_i), .left_i(left_i), .right_i(right_i),
        .valid_o(valid_o), .product_o(product_o)
    );
    keygen_ram32 #(.ADDRESS_WIDTH(8)) memory (
        .clock_i(clock_i), .reset_n_i(reset_n_i), .clock_en_i(clock_en_i),
        .write_en_i(write_en_i), .write_address_i(write_address_i),
        .write_data_i(write_data_i), .read_en_i(read_en_i),
        .read_address_i(read_address_i), .read_valid_o(read_valid_o),
        .read_data_o(read_data_o)
    );
endmodule
