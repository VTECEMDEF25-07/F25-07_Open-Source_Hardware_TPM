// ===========================================================================
// entropy_test_top.v
//
// Top level for SP 800-90B data collection. Build this INSTEAD of RNG.v
// (set it as the top-level entity) when you want to capture raw samples.
//
// Connects entropy_source's raw-sample tap to entropy_capture, which stores
// samples in on-chip RAM and sends them to a PC over UART.
//
// Set up for the Terasic DE25-Standard (Agilex 5 A5ED013BB32A):
//   clk       CLOCK_50 (50 MHz)
//   rst_n     KEY[0]   (pressed = 0 = reset)
//   uart_rx   GPIO[0]  on the 3.3 V DE-GPIO header, from adapter TX
//   uart_tx   GPIO[1]  on the 3.3 V DE-GPIO header, to adapter RX
//   led_busy_n LEDR[0] (the board's LEDs light when driven LOW)
// The board's own USB-UART is wired to the HPS, not the FPGA fabric, so a
// 3.3 V USB-UART adapter on the GPIO header is used instead.
// Pin numbers are in DE25_entropy_test_pins.tcl.
//
// BAUD must match --baud in capture_90b.py.
//
// Written by Jungyeon Won with the help of generative AI
// ===========================================================================
`timescale 1ns/1ps
 
module entropy_test_top #(
    parameter integer CLK_HZ = 50_000_000,    // DE25-Standard CLOCK_50
    parameter integer BAUD   = 115_200
) (
    input  wire clk,
    input  wire rst_n,      // active-low reset (push button)
    input  wire uart_rx,    // from the PC's USB-UART adapter TX
    output wire uart_tx,    // to the PC's USB-UART adapter RX
    output wire led_busy_n  // LED on (low) while capturing / sending
);
 
    wire source_enable;
    wire busy;
    assign led_busy_n = ~busy;   // DE25 LEDs are active-low
    wire raw_sample;
    wire raw_sample_valid;
 
    // The same entropy_source used by RNG.v, so the data reflects the real
    // design. Its 256-bit output isn't needed here.
    entropy_source u_entropy_source (
        .clk             (clk),
        .rst_n           (rst_n),
        .enable          (source_enable),
        .entropy_output  (),
        .entropy_valid   (),
        .raw_sample      (raw_sample),
        .raw_sample_valid(raw_sample_valid)
    );
 
    entropy_capture #(
        .CLKS_PER_BIT(CLK_HZ / BAUD)
    ) u_capture (
        .clk             (clk),
        .rst_n           (rst_n),
        .uart_rx         (uart_rx),
        .uart_tx         (uart_tx),
        .source_enable   (source_enable),
        .raw_sample      (raw_sample),
        .raw_sample_valid(raw_sample_valid),
        .busy            (busy)
    );
 
endmodule
 