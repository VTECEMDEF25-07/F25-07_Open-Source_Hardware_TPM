// Filename: keygen_mult32.v
// Modules: keygen_mult32
// Authors: Aaron Grossman; Project contributors; see Git history.
// Date: 2026-10-13
// General Description: Selects the generic or Altera 32-bit multiplier resource with a common interface.
// AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

`include "ip_types.vh"

module keygen_mult32 #(parameter IP_TYPE = `IP_GENERIC) (
    input clock_i,
    input reset_n_i,
    input clock_en_i,
    input valid_i,
    input [31:0] left_i,
    input [31:0] right_i,
    output valid_o,
    output [63:0] product_o
);
    generate
        if (IP_TYPE == `IP_GENERIC) begin : generic_ip
            keygen_mult32_generic implementation (
                .clock_i(clock_i), .reset_n_i(reset_n_i), .clock_en_i(clock_en_i),
                .valid_i(valid_i), .left_i(left_i), .right_i(right_i),
                .valid_o(valid_o), .product_o(product_o)
            );
        end else if (IP_TYPE == `IP_ALTERA) begin : altera_ip
            keygen_mult32_altera implementation (
                .clock_i(clock_i), .reset_n_i(reset_n_i), .clock_en_i(clock_en_i),
                .valid_i(valid_i), .left_i(left_i), .right_i(right_i),
                .valid_o(valid_o), .product_o(product_o)
            );
        end else begin : invalid_ip
`ifdef VERILATOR
            // The installed Verilator 5.020 resolves unknown cells before pruning branches.
            // Stop before any transfers; runners must require their explicit PASS marker.
            initial begin
                $display("KEYGEN_INVALID_IP_TYPE: use IP_GENERIC or IP_ALTERA"); $stop;
            end
`else
            KEYGEN_INVALID_IP_TYPE__USE_IP_GENERIC_OR_IP_ALTERA invalid_selection ();
`endif
        end
    endgenerate
endmodule
