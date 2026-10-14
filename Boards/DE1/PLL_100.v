// Supplies the clock module referenced by the original Phase 1 board top.
// Cyclone V ALTERA_PLL macro: 50 MHz reference, one 100 MHz output.
module PLL_100 (
    input refclk,
    input rst,
    output outclk_0
);
    wire [0:0] pll_clock;
    assign outclk_0 = pll_clock[0];
    altera_pll #(
        .fractional_vco_multiplier("false"),
        .reference_clock_frequency("50.0 MHz"),
        .operation_mode("normal"),
        .number_of_clocks(1),
        .output_clock_frequency0("100.0 MHz"),
        .phase_shift0("0 ps"),
        .duty_cycle0(50),
        .pll_type("auto"),
        .pll_subtype("General")
    ) clock_multiplier (
        .refclk(refclk), .rst(rst), .outclk(pll_clock),
        .locked(), .fbclk(1'b0), .fboutclk()
    );
endmodule
