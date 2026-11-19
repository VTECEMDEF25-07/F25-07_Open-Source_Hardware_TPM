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


module ff_macro_c2p # (
 parameter DATA_WIDTH = 256,
 parameter NUM_FLOPS = 1 // based on number of flops you need in 1 dir 
 ) (
 input logic clk,

 input [DATA_WIDTH -1:0] in_data ,

 output [DATA_WIDTH -1:0] out_data

);


 (* altera_attribute = {"-name FORCE_HYPER_REGISTER_FOR_CORE_PERIPHERY_TRANSFER ON; -name HYPER_REGISTER_DELAY_CHAIN 350"} *)
    reg [DATA_WIDTH-1:0] in_data_reg [NUM_FLOPS:0];    

    assign in_data_reg[0] = in_data;


    genvar i;
    
    generate 
    for (i=0 ; i<NUM_FLOPS ; i=i+1 ) begin : hps_c2p_ff
      always @(posedge clk) begin
          in_data_reg[i+1] <= in_data_reg[i];
      end
    end
    endgenerate

    assign out_data = in_data_reg[NUM_FLOPS];



    
endmodule
`ifdef QUESTA_INTEL_OEM
`pragma questa_oem_00 "HKE1A/xPv2xENkX8yp9xoqkNge46lbMcPP7BkxII5uVAESNhbSQ48MxyKbstHt+Z73pjaLnv4JZL7VIg1Zl08sUjb+a/DJUEwISomi4A5vL/9xMR86jPaYlbfbvTGJyK0dtsE3CZllK6Orkctae64nBtq574elgMyKlt1SuCin3Dz1hwF/fuGJz1pzcKZ2XKUwAVd2517c5HdE1spdswJCP157Z27/3eHr0YYHHsZ+B0Sspkh98iY26EbtBlFajLiNBPJa7Q2f2fcV/QlV3ULildTddYOzmeZMzG1OIBm/P4rzVTGc+Yf/m7+5knT24h9cdLK17YidVC3mwFic6YyRxf/aq/ssgxQkgmSxbxMWctDKUKvTkWe2nlyUwyKKPFqqmAVKMj22U/bT79Y9Dumj1T39KcJGmxofJneSSYE7vRGAfustAFspeL0/ahSa3JFcOcp0Vqhq/lhc81KUoFE7Bt1QI7MCaRYDOvVFAj+UN+AWtHIQLEjjg3QpOs+IEgGgZrF1MLw18mAEGLUXGkG512/BwAA6xydLR8EfOBIks1AgGzowQrIivVTr4FH+WAXEOy06+oHi66Ku1FpygHtJSf2zz+ujEn6FgS1EcACI1kOwMyqObUqQxszZRK4Xol6LxHz4sGnMFWAVF2TdKKkpHxDc8Mr4BkS+NXM58lQu8OJe5jPiXfAP4P+tfZ+xHG1un3I6RBUNTF22f5/uGp8V4NnNSdP0UWBKd8UNTeUFowIvpkoofUOacxcXUl8I3AYM3sFxL76CMaEzPu4pKEUtypGQ7lr2g4ZTq32l3/5ygIU9iwOtkbg7uz6wh8wEmQwDY/b5yNcsikh3xSqBNJXzVhhUfMEKmBNKbOPG34j6NVYlXIHkLfBVEKXsrhgHIQdbN856LlFpcSWPLSHLq3O4oNjnF/p6caBGC6xw60ytrHtafigZJhWOpdPmFv/LWhe8EmoDxznYwq8X9xHgN+n4SxPY/9hVBX4Ds+k2LUgTKYNCr/ltwccKtm8+MPT/pn"
`endif