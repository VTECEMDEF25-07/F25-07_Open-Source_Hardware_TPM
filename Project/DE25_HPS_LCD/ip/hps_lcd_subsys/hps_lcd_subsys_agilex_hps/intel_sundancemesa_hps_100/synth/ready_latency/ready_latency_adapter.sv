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


`timescale 1ns / 100ps

// this module has zero ready latency input and non zero latency output


module ready_latency_adapter # (
 parameter READY_LATENCY_OUT = 2,
 parameter PAYLOAD_WIDTH = 256,
 parameter LOG_DEPTH = 3,
 parameter BUFFER_TYPE = "MLAB"
) (  
 output logic         in_ready,
 input  logic            in_valid,
 input  logic   [PAYLOAD_WIDTH-1: 0]  in_data,
 // Interface: out
 input  logic             out_ready,
 output logic          out_valid,
 output logic [PAYLOAD_WIDTH-1: 0] out_data,
  // Interface: clk
 input logic          clk,
 // Interface: reset
 input logic           reset

 /*AUTOARG*/);

   // ---------------------------------------------------------------------
   //| Signal Declarations
   // ---------------------------------------------------------------------
   
   logic [PAYLOAD_WIDTH-1:0]   in_payload;
   logic [PAYLOAD_WIDTH-1:0]   out_payload;
   logic            in_ready_wire;
   logic            out_valid_wire;
   logic [2:0]      fifo_fill;
   logic    rdreq;
   logic empty;   

   logic [READY_LATENCY_OUT-1:0] in_ready_dly_reg;
   logic in_ready_dly;
   assign in_ready_dly = (READY_LATENCY_OUT > 0) ? in_ready_dly_reg[0] : in_ready;

   logic fifo_wr_req;
   assign fifo_wr_req = (in_valid === 1'b1) && (in_ready_dly === 1'b1);
 
   localparam DEPTH = 2 ** LOG_DEPTH -1 ;

   // ---------------------------------------------------------------------
   //| Payload Mapping
   // ---------------------------------------------------------------------
   always @* begin
     in_payload = {in_data};
     {out_data} = out_payload;
   end

   // ---------------------------------------------------------------------
   //| FIFO
   // ---------------------------------------------------------------------                           
    scfifo_s # (
      .LOG_DEPTH (LOG_DEPTH),
      .WIDTH (PAYLOAD_WIDTH),
      .ALMOST_FULL_VALUE (DEPTH-1),
      .SHOW_AHEAD (1),
      .BUFFER_TYPE (BUFFER_TYPE)
    ) fifo_inst ( 
       .clock        (clk),
       .aclr       (1'b0),
       .sclr (reset),
       //.in_ready   (),
       .wrreq  (fifo_wr_req),      
       .data    (in_payload),
      //.out_ready  (out_ready),
       .rdreq      (rdreq),
       .q (out_payload),
       .usedw (fifo_fill),
       .empty (empty),
       .full (full),
       .almost_empty (),
       .almost_full ()
       );

   // ---------------------------------------------------------------------
   //| Ready & valid signals.
   // ---------------------------------------------------------------------
   always @* begin
      in_ready = ( DEPTH- fifo_fill > READY_LATENCY_OUT);
   end

    always @(posedge clk) begin
        in_ready_dly_reg[READY_LATENCY_OUT-1] <= in_ready;
        for (int i = 0; i < READY_LATENCY_OUT - 1; i++) begin
            in_ready_dly_reg[i] <= in_ready_dly_reg[i+1];
        end
    end

    generate
      if (BUFFER_TYPE == "MLAB") begin 
        assign out_valid = !empty;
      end
      else begin
        always @(posedge clk) begin
          out_valid <= !empty;
        end
      end
    endgenerate

   // ---------------------------------------------------------------------
   //| Read logic
   // ---------------------------------------------------------------------
   // read when out ready and fifo not empty

assign rdreq = out_ready && !empty;



endmodule


`ifdef QUESTA_INTEL_OEM
`pragma questa_oem_00 "HKE1A/xPv2xENkX8yp9xoqkNge46lbMcPP7BkxII5uVAESNhbSQ48MxyKbstHt+Z73pjaLnv4JZL7VIg1Zl08sUjb+a/DJUEwISomi4A5vL/9xMR86jPaYlbfbvTGJyK0dtsE3CZllK6Orkctae64nBtq574elgMyKlt1SuCin3Dz1hwF/fuGJz1pzcKZ2XKUwAVd2517c5HdE1spdswJCP157Z27/3eHr0YYHHsZ+AbLMXrL0LPWEjnfWTT+Jt6lEE5ZV90jxXswx56vQuIa8oDO8sBydliK0tWp2+cWwN1hpozejEsEMNfPDsUwufL4zNTfZ4Tky4XdizvIfqJwOpWrd4rU1wnITtZAy29DTbtYSQ5bZef/d/fx8c8mpQ4VBrmqs8kc4coQVyY2nwhu8C5Z0VtmZU+qd37E3t0VS52UMxo6o0QdzuRXKxDe1w+iWgY/WgzGRAfsWSjrYYDvBraTF8gV0y5C02T1aAaeiUEelW8+CULIfGgJLcskor2mBeqVarQzIE8KfjwmCDLEXsNF6Sb38VEgbdPxNopzpl6Ax2eRl9cqF4aavsIMmm+JP1AkDdgym3Mj1vQEHn/HrnsV6sORkBoyMN8L7s9jToJUMIX9yNG0pMt3OJ/lOLSWxNvOT+PbJGl0i3iq90oZYYBaI4OdDCqiyOrqz385GyJNko7Dxqw8dY4u8AyTptGdDWuxgnmqX2z5SLYbJmt1eTl+2KvtgG60xkYDtY5pa8AHiwBe+kz2AM72Ho6sca4pk0wcR2f4q8AXemZ6K5nfC4wznuYxqudvspnbLmQGhfi4y17O1zj+81vkWDbUlOm5pduOXumDyY6RgKOehE/oAuqPNsHtI9mJ251hbROXK5NVW0cixPG9yqpsyAtprSl9tlPJRGWpqKXWwc5OK5m2FlKFCfsTIwwJ4AKW0NxlabOVAd0TSJ4qit4hUXXuz/We5HkzOKWmiAGMx2buCHfD8voT9P3WIrjNPGYK2sRhYLMwKRZhZE/VssPmr5MsIpb"
`endif