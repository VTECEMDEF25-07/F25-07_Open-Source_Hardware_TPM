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


// (C) 2001-2012 Altera Corporation. All rights reserved.
// Your use of Altera Corporation's design tools, logic functions and other
// software and tools, and its AMPP partner logic functions, and any output
// files any of the foregoing (including device programming or simulation
// files), and any associated documentation or information are expressly subject
// to the terms and conditions of the Altera Program License Subscription
// Agreement, Altera MegaCore Function License Agreement, or other applicable
// license agreement, including, without limitation, that your use is for the
// sole purpose of programming logic devices manufactured by Altera and sold by
// Altera or its authorized distributors.  Please refer to the applicable
// agreement for further details.


// $Id: //acds/main/ip/merlin/altera_merlin_burst_adapter/altera_merlin_burst_adapter.sv#68 $
// $Revision: #68 $
// $Date: 2014/01/23 $

`timescale 1 ns / 1 ns

// -------------------------------------------------------
// Adapter for uncompressed transactions only. This adapter will
// typically be used to adapt burst length for non-bursting 
// wide to narrow Avalon links.
// -------------------------------------------------------
module altera_merlin_burst_adapter_uncompressed_only
#(
    parameter 
    PKT_BYTE_CNT_H  = 5,
    PKT_BYTE_CNT_L  = 0,
    PKT_BYTEEN_H    = 83,
    PKT_BYTEEN_L    = 80,
    ST_DATA_W       = 84,
    ST_CHANNEL_W    = 8
)
(
    input clk,
    input reset,

    // -------------------
    // Command Sink (Input)
    // -------------------
    input                           sink0_valid,
    input  [ST_DATA_W-1 : 0]        sink0_data,
    input  [ST_CHANNEL_W-1 : 0]     sink0_channel,
    input                           sink0_startofpacket,
    input                           sink0_endofpacket,
    output reg                      sink0_ready,

    // -------------------
    // Command Source (Output)
    // -------------------
    output reg                      source0_valid,
    output reg [ST_DATA_W-1    : 0] source0_data,
    output reg [ST_CHANNEL_W-1 : 0] source0_channel,
    output reg                      source0_startofpacket,
    output reg                      source0_endofpacket,
    input                           source0_ready
);
    localparam
        PKT_BYTE_CNT_W = PKT_BYTE_CNT_H - PKT_BYTE_CNT_L + 1,
        NUM_SYMBOLS    = PKT_BYTEEN_H - PKT_BYTEEN_L + 1;

    wire [PKT_BYTE_CNT_W - 1 : 0] num_symbols_sig = NUM_SYMBOLS[PKT_BYTE_CNT_W - 1 : 0];

    always_comb begin : source0_data_assignments
        source0_valid         = sink0_valid;
        source0_channel       = sink0_channel;
        source0_startofpacket = sink0_startofpacket;
        source0_endofpacket   = sink0_endofpacket;

        source0_data          = sink0_data;
        source0_data[PKT_BYTE_CNT_H : PKT_BYTE_CNT_L] = num_symbols_sig;

        sink0_ready = source0_ready;
    end

endmodule



`ifdef QUESTA_INTEL_OEM
`pragma questa_oem_00 "mfufSZOYfNPxmSfS+FkCl32e9bHGnpakqHX1nHXvrhE4J6x8qGVCEAJRqHIBXSp/FcyWPq9/UmljeMey51E9VTMH3OCNEvZdEUSPU4/Vf6DgtU26zIfR3Ws2AtmUBXEHD5yEeHuHpEMedz5PLIdzFsBxJ/9OiyM+8A3UVG3icM2FQlZPfaXli71zX1obNH4Hi4tyLUZvYQoJv7xSQMqW1lxant16XP5C2V2aZfTOCZlEl7U1mwDa2foPMdSqYqEvxrVPv0jMzxA0aRf5GvKemQQYiAUmoPZ/yty49qVq2u4nCWeBwiIOIWm7gDC9G7PUqb6tQOwrlINch7TSLyDBSTQRE9hXc7SldcwRHZbphJdXk8dLtmihOMDJFCjqPdl3yLIyPr7YL6350GrMmyAi0VBnzeb3PXYeJ774WH1+ABTda662GekklRXGy8DtIgPk0IIg3Oj1dwRb3pFTN66nlIPiZBgL8gjO0CYauPX/q9nMQFGeoQZr4+5e98MGAqbEcnhgooJzrOeQs2tRxgUiChvubqPONnP1A1YFtubOn7CcIC2RelzTbXvuG7xBL8BFrgyCRg/DB4902JDspTPYHKTGnATpyW9IaQ1niNwNhdHAEqiIUKBD/YZXcjnXVgHmwCUait0N//YwiEJonwrRzUsNWzXI1Hqd95q5Iyv88LJIqRopX6GB7QDDG42Z8rlNeHcFQnyJKEV5BhNCL8p3A8ygXqZ6pjUDwYOR+Dgarpg9ij6TIXQQHiiEozYHxBY0fcHtNb8FfenfODkF3XaHFzJciEYDrjHK2q3Ns7fTAp+HkmKgxb/S/s3qrHnpl3GVY+nokliANaXmDBgv4PGyFDfOm5ZifW3H7XSXvHNPSnpKxGuEoZt2v0zN2gZIcCaS5smLpTK+Lh0uks2gCvA/v1P41pbHzy/7CM/JZiP8V8q0zQ0ELX/oWMYwC/t43xkpbirj8nuULPIQPAupetsXyCnaz2p2/DdsSsbGj3kyXN8JLoZV990Dl5M4UL/HzKhw"
`endif