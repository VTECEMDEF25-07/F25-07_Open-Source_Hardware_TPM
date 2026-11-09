// Filename: de25_clock.v
// Modules: de25_clock
// Author: Aaron Grossman
// Date: 2026-10-14
// General Description: Generates the related 50 MHz and 100 MHz DE25 TPM clocks through the vendor PLL macro.

// Approved vendor PLL internals; project wrapper remains Verilog.
// Our board wrapper is Verilog; no generated IP-catalog source is required.
module de25_clock (
    input clock_i,
    input reset_i,
    output clock_50_o,
    output clock_100_o,
    output locked_o
);
    // 3200 MHz VCO: C0/64 produces 50 MHz; C1/32 produces 100 MHz.
    // Both TPM clocks share the PLL compensation instead of mixing raw and PLL clocks.
    // Normal feedback compensates output0; STA must still include routed skew.
    wire unused_feedback_wire;
    assign unused_feedback_wire = 1'b0;
    ipm_iopll #(
        .REFERENCE_CLOCK_FREQUENCY("50.0 MHz"),
        .N_CNT(1), .M_CNT(32),
        .C0_CNT(30), .C1_CNT(16), .C2_CNT(16), .C3_CNT(16),
        .C4_CNT(16), .C5_CNT(16), .C6_CNT(16),
        .OPERATION_MODE("normal"), .CLOCK_TO_COMPENSATE(1),
        .PHASE_SHIFT0(0)
    ) clock_multiplier (
        .refclk(clock_i), .reset(reset_i),
        .outclk0(clock_50_o), .outclk1(clock_100_o), .outclk2(), .outclk3(),
        .outclk4(), .outclk5(), .outclk6(), .locked(locked_o),
        .fbclk(1'b0), .fbclkout(), .extclk_out(),
        .zdbfbclk(unused_feedback_wire)
    );
endmodule
