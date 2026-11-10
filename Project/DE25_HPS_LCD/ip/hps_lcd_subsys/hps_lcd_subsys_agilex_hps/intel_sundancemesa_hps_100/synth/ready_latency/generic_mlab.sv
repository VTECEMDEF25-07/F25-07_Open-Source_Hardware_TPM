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


// Copyright 2021 Intel Corporation. 
//
// This reference design file is subject licensed to you by the terms and 
// conditions of the applicable License Terms and Conditions for Hardware 
// Reference Designs and/or Design Examples (either as signed by you or 
// found at https://www.altera.com/common/legal/leg-license_agreement.html ).  
//
// As stated in the license, you agree to only use this reference design 
// solely in conjunction with Intel FPGAs or Intel CPLDs.  
//
// THE REFERENCE DESIGN IS PROVIDED "AS IS" WITHOUT ANY EXPRESS OR IMPLIED
// WARRANTY OF ANY KIND INCLUDING WARRANTIES OF MERCHANTABILITY, 
// NONINFRINGEMENT, OR FITNESS FOR A PARTICULAR PURPOSE. Intel does not 
// warrant or assume responsibility for the accuracy or completeness of any
// information, links or other items within the Reference Design and any 
// accompanying materials.
//
// In the event that you do not agree with such terms and conditions, do not
// use the reference design file.
/////////////////////////////////////////////////////////////////////////////

(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION OFF" *)
module generic_mlab #(
    parameter WIDTH = 8,
    parameter ADDR_WIDTH = 5
)(
    input clk,
    input [WIDTH-1:0] din,
    input [ADDR_WIDTH-1:0] waddr,
    input we,
    input re,
    input [ADDR_WIDTH-1:0] raddr,
    output [WIDTH-1:0] dout
);

localparam DEPTH = 1 << ADDR_WIDTH;
(* ramstyle = "mlab" *) reg [WIDTH-1:0] mem[0:DEPTH-1];

reg [WIDTH-1:0] dout_r;
always @(posedge clk) begin
    if (we)
        mem[waddr] <= din;
    if (re)
        dout_r <= mem[raddr];
end

assign dout = dout_r;

endmodule
`ifdef QUESTA_INTEL_OEM
`pragma questa_oem_00 "HKE1A/xPv2xENkX8yp9xoqkNge46lbMcPP7BkxII5uVAESNhbSQ48MxyKbstHt+Z73pjaLnv4JZL7VIg1Zl08sUjb+a/DJUEwISomi4A5vL/9xMR86jPaYlbfbvTGJyK0dtsE3CZllK6Orkctae64nBtq574elgMyKlt1SuCin3Dz1hwF/fuGJz1pzcKZ2XKUwAVd2517c5HdE1spdswJCP157Z27/3eHr0YYHHsZ+ATZEL6f6XftEFdSUg7tCHOAgqH7nJ473IGboUU1CBsgXrLzthVtZU+X2229QuNANW3fvO5pjNejdaCt8pQzkZNF89vdlulWRZ/83NxhaxEwq5GyGAkJt6QTzwlyHLZNQXBljlCWnK374C0flNcBz6Y+c/pBujp2iQQRSJtvMwU8ttMYnzqKbpQ+n2B6DiWyh38yGZ98cZHQg/OVk5pgzCUQ/ElnEmWePUZFpnheWbboO09Qn2A0X4/HQpbWSlDj34XBSLbfUNfZEUubaO+gbu6NeB4DVlHJZYJtbuQyGKKvRbCtRH3V8zzZb9sFdlbVzLn/NxpTrJDHrhJc0tOV0eXWpYOOIREYeBjqkh7DibYWaHXjdHWximuKQEGblb7FEMw3WAnwLb4EdHeokLNqInFXD/GRCpS1ZCCYGKOJca6FEWxuZ9IViqUyTGc0rZydn+ZCXZ5RcTxQ1akJRCOCTCeeYYjpTO9FZwOo34hQNezt388z7YSHabJ0nhnUTwwt4KAwLZ30+g998u+W0WTkQVHtDAVQwX914YXL6n4P/E0EwfKGQ6R0GbYnaDW0S5QSGSklBzZS2oy2+dDILc/4gQmtKMsMv9c1YM84thD7hY1ngk3HP54Gr2DvKsS1Rq08sBxSjVaA74lzP5+BWVJISSav7SCrcQ6IduN5OqLvOUhVok1QyFD9hpyIgPQG3OGV6hyZJ3l0Zzr9M5hep3Z1OL35+r8ZC28ULqf8m2dwsRWcv2vf06Hk2AAsKDASctJ3J9aGA68ezNCR+k2Xgh5sE8t"
`endif