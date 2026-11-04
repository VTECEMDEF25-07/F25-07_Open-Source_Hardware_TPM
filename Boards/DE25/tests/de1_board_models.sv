`timescale 1ns/1ps
// Test-only ideal PLL interface model; no vendor-model or fit claim.
module altera_pll #(
    parameter fractional_vco_multiplier="false",
    parameter reference_clock_frequency="50.0 MHz",
    parameter operation_mode="normal", parameter number_of_clocks=1,
    parameter output_clock_frequency0="100.0 MHz", parameter phase_shift0="0 ps",
    parameter duty_cycle0=50, parameter pll_type="auto", parameter pll_subtype="General"
)(input refclk,rst,fbclk, output logic [number_of_clocks-1:0] outclk,
   output locked,fboutclk);
    initial outclk=0;
    always #5 outclk = rst ? 0 : ~outclk;
    assign locked=~rst;
    assign fboutclk=0;
endmodule
module test0_top(input CLOCK_50,RESET_N,GPIO_1_2,GPIO_1_3,GPIO_1_5,GPIO_1_6,
                 output GPIO_1_4,GPIO_1_7);
    wire [9:0] leds;
    de1_soc_top dut(.CLOCK_50(CLOCK_50),.RESET_N(RESET_N),.LEDR(leds),
       .GPIO_1_2(GPIO_1_2),.GPIO_1_3(GPIO_1_3),.GPIO_1_4(GPIO_1_4),
       .GPIO_1_5(GPIO_1_5),.GPIO_1_6(GPIO_1_6),.GPIO_1_7(GPIO_1_7));
endmodule
