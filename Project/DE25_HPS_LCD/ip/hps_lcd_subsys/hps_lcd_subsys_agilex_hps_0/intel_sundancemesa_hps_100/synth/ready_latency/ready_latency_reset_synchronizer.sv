// (C) 2001-2026 Altera Corporation. All rights reserved.
// Your use of Altera Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files from any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Altera Program License Subscription 
// Agreement, Altera IP License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Altera and sold by 
// Altera or its authorized distributors.  Please refer to the applicable 
// agreement for further details.


//
// Module : ready_latency_reset_synchronizer
// Description :
//     2-stage reset synchronizer used for ready latency reset. Takes an
//     asynchronous, active high reset input (rst_async) and synchronizes it
//     to the rising edge of the clock (clk). The output (rst_sync) is active
//     high and safe for use in the clk domain. 
//     This module is intended to be used for Agilex 5 HPS ready latency
//     adapters for the fabric-facing bridges. HPS IP generation should
//     automatically instantiate and connect the HPS reset output (h2f_reset)
//     to the synchronizer input and synchronizer output to each bridge ready
//     latency adapter. This ensures HPS reset and the bridge soft-logic
//     resets are synchronized to the bridge clocks.
//
module ready_latency_reset_synchronizer (
    input logic clk,
    input logic rst_async,    // asynchronous active high input reset
    output logic rst_sync     // synchronized active high output reset 
);

    // 2-stage synchronizer register
    logic [1:0] sync_reg;

    // asynchronous assertion, synchronous deassertion of reset
    always_ff @(posedge clk or posedge rst_async) begin
        if (rst_async) begin
            sync_reg <= 2'b11;    // assert reset synchronously
        end else begin
            sync_reg <= {sync_reg[0], 1'b0}; // Shift in '0' to release reset
        end
    end

    // Output is the last stage of the synchronizer
    assign rst_sync = sync_reg[1];

endmodule
`ifdef QUESTA_INTEL_OEM
`pragma questa_oem_00 "HKE1A/xPv2xENkX8yp9xoqkNge46lbMcPP7BkxII5uVAESNhbSQ48MxyKbstHt+Z73pjaLnv4JZL7VIg1Zl08sUjb+a/DJUEwISomi4A5vL/9xMR86jPaYlbfbvTGJyK0dtsE3CZllK6Orkctae64nBtq574elgMyKlt1SuCin3Dz1hwF/fuGJz1pzcKZ2XKUwAVd2517c5HdE1spdswJCP157Z27/3eHr0YYHHsZ+AXDB6oNWmRK9LEAhJQnpK8ycfr1yMWEjlBMx+lcVBwRTFBPISWnQ0llyD+KgbKK29NM1dCdq2o5QrnUsD6HGpFUmJHDhhBFPGTUVjpY7wneVViHRuMIClBOiyXAXouvsIDtaIIoMKQP1eC8LV8D/KKr3mlqymNokhE2LReRAdhJ7GNEHVt/1ClV00Se38IXCTYM5yQ8d1NZnO4gWT3zqWIlrtCIRPb1BXsKtv/Vs/j6/0wUw0KU3wx2Jr66HF0a8Ubf6h+1ABUjNv2uPhL8w9Ulqfqbc2CZ/1LAsx2ZHP4p/DG+3HlPyV5FpkKUJXDSqhyAStoEmOESdhhXMOUx2kPbVXvyrjglxb0xOrezWCUzXygluWgx9K1120NvNN2zpBeVIxQWmCruwx2n5iI3TTU+snRrGgjLWtwpVAvXzDtG5Ch2YiAtBRniPxseAxAzq/57j7xYQp8OZCmXEADfb0AzvT4s0SVqc1fJHQXB76oyGvyG5YVA6Ss+v3AeuJvFizYSmVdi5fvNX97T3bOn/MBgKKaST7nbjkc4Ov2xcRkMsZ4iK0V8QkjjcWaWpWLRX9VN2Vw2iq2NBUIQDxe9qi+UIw4HVL8b2sTyudpYuKbmfNLexp3jwsh+Di1JoCKv8CqOwoQyr1ygiAdLEXDo767Fr4PZaInTbJHYhfRPESYUWyQDMajrW4Ythro5DqS7oZCcYiITJrQjfYstFDLTxkvnlyg0QmoptkZlQcRyFvSLEWSRDm3cr8sBVzB+2B1BkkTbl34HDRJMIq2BZomyhIz"
`endif