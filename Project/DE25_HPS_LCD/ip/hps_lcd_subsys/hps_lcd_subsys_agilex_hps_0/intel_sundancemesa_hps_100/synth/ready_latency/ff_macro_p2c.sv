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


module ff_macro_p2c # (
 parameter DATA_WIDTH = 256,
 parameter NUM_FLOPS = 1 // based on number of flops you need in 1 dir 
 ) (
 input logic clk,

 input [DATA_WIDTH -1:0] in_data ,

 output [DATA_WIDTH -1:0] out_data

);


 (* altera_attribute = {"-name FORCE_HYPER_REGISTER_FOR_PERIPHERY_CORE_TRANSFER ON"} *)
    reg [DATA_WIDTH-1:0] in_data_reg [NUM_FLOPS:0];    

    assign in_data_reg[0] = in_data;


    genvar i;
    
    generate 
    for (i=0 ; i<NUM_FLOPS ; i=i+1 ) begin : hps_p2c_ff
      always @(posedge clk) begin
          in_data_reg[i+1] <= in_data_reg[i];
      end
    end
    endgenerate

    assign out_data = in_data_reg[NUM_FLOPS];



    
endmodule
`ifdef QUESTA_INTEL_OEM
`pragma questa_oem_00 "HKE1A/xPv2xENkX8yp9xoqkNge46lbMcPP7BkxII5uVAESNhbSQ48MxyKbstHt+Z73pjaLnv4JZL7VIg1Zl08sUjb+a/DJUEwISomi4A5vL/9xMR86jPaYlbfbvTGJyK0dtsE3CZllK6Orkctae64nBtq574elgMyKlt1SuCin3Dz1hwF/fuGJz1pzcKZ2XKUwAVd2517c5HdE1spdswJCP157Z27/3eHr0YYHHsZ+CG1OqyBrWA2W2j9LlBsZVFEWakVufy/2FaOrsyO+orJVuqFmVjm5FigSjydy2hzhjoV1r0hd078AzN9Eg5gX+vuY9U0ROK7Jnefo/vDy06CKTNj+auvXBqsmDZZJfpOK969gHqIL7YggNQLqQ4b0QW3WXPivEvt2P/m/oRYZzb/hNGpqB1EAnAXDN/5qqAP4BO1/KlAIjjlE+oVExPooPif1ZrlQ/mt8Dwrc3RuwN5Gn3BQOOqxlKoToVUkpEUXbnIs1YBjqUmUL83onWSEYH6lwzAkQNb2Tv4e1qGyRLmP4nVhoyFJfXEPTIsLcO48EcgZCLAPTr4j/V5VP6mF/cpX7I5aXWDk0hDM17yjwsCv72CEOq5/YxMMlAki/KuailZyVbvLMDp9gBB3JfSehTvYmw3JBiRkRmoISMXwQLpWdZfxJCqaAe4vAvlqSj+utg45cVdV8O1YkzYUABRMygCjnMrjbYQJ3I62oJRduIAxOTUjsgXfd6Qgd34y2iHF8ZQZ2QncXHklJ6L13V7RUuK7Ciy8XI6I/uWqtSWWG2/kp6DVDUYucUr+qNAe2o2rhIDP59Kv+FB9NbQnAdPpmE+tagzv+8zTUjelzjn4gS3sNahpAyovOc2HknimHUr8OEcHMBOVPO3NgvOevl6/8B+MjrUjwTG8iUllpjh90v1YZz9w0f6QbUc9+NgVE6W3u5wl9LozPZ3WzUK0NtbPH+quT5KnN6d6TMN6gN05wMKwa9mdYtXJWAofgsJjDowWwGaPbRIxbXmBgIN8vs0920T"
`endif