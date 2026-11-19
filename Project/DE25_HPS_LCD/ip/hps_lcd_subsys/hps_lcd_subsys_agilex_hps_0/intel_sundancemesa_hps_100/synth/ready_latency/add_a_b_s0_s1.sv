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

module add_a_b_s0_s1 #(
    parameter SIZE = 5
)(
    input [SIZE-1:0] a,
    input [SIZE-1:0] b,
    input s0,
    input s1,
    output [SIZE-1:0] out
);
    wire [SIZE:0] left;
    wire [SIZE:0] right;
    wire temp;
    
    assign left = {a ^ b, s0};
    assign right = {a[SIZE-2:0] & b[SIZE-2:0], s1, s0};
    assign {out, temp} = left + right;
    
endmodule
`ifdef QUESTA_INTEL_OEM
`pragma questa_oem_00 "HKE1A/xPv2xENkX8yp9xoqkNge46lbMcPP7BkxII5uVAESNhbSQ48MxyKbstHt+Z73pjaLnv4JZL7VIg1Zl08sUjb+a/DJUEwISomi4A5vL/9xMR86jPaYlbfbvTGJyK0dtsE3CZllK6Orkctae64nBtq574elgMyKlt1SuCin3Dz1hwF/fuGJz1pzcKZ2XKUwAVd2517c5HdE1spdswJCP157Z27/3eHr0YYHHsZ+Avia+5lTsxBjIw5r4Zt5CeP94UCcJdmYArxMbyeEeu1h1ctq2fH/zoHsNHx5EkF+OpzXq1OpbAn7kLFdwf6+Ey8s7VnyfBjmZQpaPYz69PTBt0ungu3e8ac8bPef3weVLYpRbzR3IOnmC4e8wuZetN7nukuD5jGUhOAJfM85r4MrGhWmpDUPAtNkzs8TQUECuuuigFv+XwoQCQcGAz0yfOFVAKukElCP9HZR0TH7yl9jymG1Ns+6B/619D5EUtPx81GGNAW6y10L7fOLHyV2gih3rD/S/+n6jvrrQ9qpNNdljImeOAgU+/R4GPwA/6huOdBqOvUqc0LgTx2O4iVr+gv2I3urozo/Usa+koQ6xZVOx1qpPJITtwB/PFzrjYdbSS8Z0vb+ebpxHzjFJ+R2xWiWRd3jj9KluiqZvpiTedTsrO905FzQWUoIyRgflOxSNPtvNB3baA6VQM4ZZEegKbMDjph9+91RvEahqfEiNq1zkzoO9UnvIbLiconBiVtwvZT3U73ROT4/mx1CLSbWBrG7ScvBtkyMmHkfnRtZ0eC83V3xvsYbX00mtdMwe4YXUEosV9+d2wDuiaba3p3Xz8sa6sq+JEBTDK+fevJFzcP3fU14HposUqg7htw7RaqDm1DoQM4bmiH/n7uidOQc0Nbmy7S9WmbjAPj4KHuA2RAUi3S0s0po12Rb0kyyi/9yIwTQ5ADyuFY8oT4lKycj8hArjUp2IiVresn7epdUEk8x7h8qFvJVWcF/xOhE6brlfWHuTpg+wQDazxts9fcwSW"
`endif