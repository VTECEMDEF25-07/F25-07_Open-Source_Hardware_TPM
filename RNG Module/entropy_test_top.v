// ===========================================================================
// entropy_test_top.v
//
// Top level for SP 800-90B data collection. Build this INSTEAD of RNG.v
// (set it as the top-level entity) when you want to capture raw samples.
//
// Connects entropy_source's raw-sample tap to entropy_capture, which stores
// samples in on-chip RAM and sends them to a PC over UART.
//
// Set CLK_HZ to your board's clock and BAUD to match capture_90b.py.
//
// Written by Jungyeon Won with the help of generative AI
// ===========================================================================
`timescale 1ns/1ps
 
module entropy_test_top #(
    parameter integer CLK_HZ = 100_000_000,   // <-- your board's clock
    parameter integer BAUD   = 115_200
) (
    input  wire clk,
    input  wire rst_n,      // active-low reset (push button)
    input  wire uart_rx,    // from the PC's USB-UART adapter TX
    output wire uart_tx,    // to the PC's USB-UART adapter RX
    output wire led_busy    // on while capturing / sending
);
 
    wire source_enable;
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
        .busy            (led_busy)
    );
 
endmodule
 