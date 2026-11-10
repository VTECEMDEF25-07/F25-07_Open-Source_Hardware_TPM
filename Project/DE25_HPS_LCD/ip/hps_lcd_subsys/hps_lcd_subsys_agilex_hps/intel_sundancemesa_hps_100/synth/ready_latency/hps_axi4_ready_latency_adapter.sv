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



module hps_axi4_ready_latency_adp # (

parameter LOG_DEPTH =3 ,
parameter NUM_PIPELINES =2,
parameter ID_WIDTH = 9,
parameter ADDR_WIDTH =44,
parameter DATA_WIDTH = 256,
parameter STRB_WIDTH = 32,
parameter BUFFER_TYPE = "MLAB"
) (

input logic clk,
input logic reset,

// aw channel

 input  logic awready,
 output logic awvalid_r,
 output logic [ID_WIDTH-1:0] awid_r,
 output logic [ADDR_WIDTH-1:0] awaddr_r,
 output logic [7:0] awlen_r,
 output logic [2:0] awsize_r,
 output logic [1:0] awburst_r,
 output logic awlock_r,
 output logic [3:0] awcache_r,
 output logic [2:0] awprot_r,

 output logic  awready_r,
 input logic awvalid,
 input logic [ID_WIDTH-1:0] awid,
 input logic [ADDR_WIDTH-1:0] awaddr,
 input logic [7:0] awlen,
 input logic [2:0] awsize,
 input logic [1:0] awburst,
 input logic awlock,
 input logic [3:0] awcache,
 input logic [2:0] awprot,


 // ar channel

 input  logic arready,
 output logic arvalid_r,
 output logic [ID_WIDTH-1:0] arid_r,
 output logic [ADDR_WIDTH-1:0] araddr_r,
 output logic [7:0] arlen_r,
 output logic [2:0] arsize_r,
 output logic [1:0] arburst_r,
 output logic arlock_r,
 output logic [3:0] arcache_r,
 output logic [2:0] arprot_r,

 output logic arready_r,
 input logic arvalid,
 input logic [ID_WIDTH-1:0] arid,
 input logic [ADDR_WIDTH-1:0] araddr,
 input logic [7:0] arlen,
 input logic [2:0] arsize,
 input logic [1:0] arburst,
 input logic arlock,
 input logic [3:0] arcache,
 input logic [2:0] arprot,


 //w channel

 input logic wready,
 
 output logic wvalid_r,
 output logic [DATA_WIDTH-1:0] wdata_r,
 output logic wlast_r,
 output logic [STRB_WIDTH-1:0] wstrb_r,


 output logic wready_r,
 
 input logic wvalid,
 input logic [DATA_WIDTH-1:0] wdata,
 input logic wlast,
 input logic [STRB_WIDTH-1:0] wstrb,


 // response channel

  input logic bvalid ,
  input logic [ID_WIDTH-1:0] bid,
  input logic [1:0] bresp,

  input logic  bready,

  output logic  bvalid_r,
  output logic  [ID_WIDTH-1:0] bid_r,
  output logic  [1:0] bresp_r,

  output logic bready_r,


  input logic rvalid,
  input logic [ID_WIDTH-1:0] rid,
  input logic [DATA_WIDTH-1:0] rdata,
  input logic [1:0] rresp,
  input logic rlast,

  output logic rready_r,


  output logic rvalid_r,
  output logic [ID_WIDTH-1:0] rid_r,
  output logic [DATA_WIDTH-1:0] rdata_r,
  output logic [1:0] rresp_r,
  output logic rlast_r,

  input logic rready

 );

 // awlen(8),awsize(3),awburst(2),awlock,awcache(4),awprot(3) -- excludes awvalid & awready
 localparam FIXED_WIDTH_AW =21;
 localparam DATA_WIDTH_AW = ID_WIDTH + ADDR_WIDTH + FIXED_WIDTH_AW;
 // arlen(8),arsize(3),arburst(2),arlock,arcache(4),arprot(3) -- excludes arvalid & arready
 localparam FIXED_WIDTH_AR =21;
 localparam DATA_WIDTH_AR = ID_WIDTH + ADDR_WIDTH + FIXED_WIDTH_AR;
 // 3: bvalid + bresp(2) + bid -- excludes bready
 localparam DATA_WIDTH_B = ID_WIDTH + 3;
 // 1: wlast + wdata + wstrb -- excludes wready & wvalid
 localparam DATA_WIDTH_W = DATA_WIDTH + STRB_WIDTH + 1;
 // 4: rvalid,rlast,rresp(2) + rdata + rid -- excludes rready
 localparam DATA_WIDTH_R = DATA_WIDTH + ID_WIDTH + 4;

 localparam FLOP_DEPTH = NUM_PIPELINES/2; // half flops on cmd, rest on rsp path

  logic bvalid_b, rvalid_b;
  logic [DATA_WIDTH_AW-1:0] indata_aw,tempdata_aw,outdata_aw;
  logic [DATA_WIDTH_AR-1:0] indata_ar,tempdata_ar,outdata_ar;
  logic [DATA_WIDTH_B -1 :0] indata_b,tempdata_b, bdata_f;

  logic [DATA_WIDTH_R -1 :0] indata_r,tempdata_r, rdata_f;


  logic [DATA_WIDTH_W -1 :0] indata_w, outdata_w, tempdata_w;


  generate if ( NUM_PIPELINES == 0 ) begin : no_pipeline

    assign {awready_r,awvalid_r,awid_r,awaddr_r,awlen_r,awsize_r,awburst_r,awlock_r,awcache_r,awprot_r} ={awready,awvalid,awid,awaddr,awlen,awsize,awburst,awlock,awcache,awprot}; 

    assign {arready_r,arvalid_r,arid_r,araddr_r,arlen_r,arsize_r,arburst_r,arlock_r,arcache_r,arprot_r} ={arready,arvalid,arid,araddr,arlen,arsize,arburst,arlock,arcache,arprot};

    assign {wready_r,wvalid_r,wdata_r,wstrb_r,wlast_r} = {wready,wvalid,wdata,wstrb,wlast};

    assign {bready_r,bvalid_r,bid_r,bresp_r} = {bready,bvalid,bid,bresp};
    
    assign {rready_r,rvalid_r,rid_r,rresp_r,rdata_r,rlast_r} = {rready,rvalid,rid,rresp,rdata,rlast}; 

  end
  else begin

//    assign {awready_r,awvalid_r,awid_r,awaddr_r,awlen_r,awsize_r,awburst_r,awlock_r,awcache_r,awprot_r} ={awready,awvalid,awid,awaddr,awlen,awsize,awburst,awlock,awcache,awprot}; 
//
//    assign {arready_r,arvalid_r,arid_r,araddr_r,arlen_r,arsize_r,arburst_r,arlock_r,arcache_r,arprot_r} ={arready,arvalid,arid,araddr,arlen,arsize,arburst,arlock,arcache,arprot};
//
//    assign {wready_r,wvalid_r,wdata_r,wstrb_r,wlast_r} = {wready,wvalid,wdata,wstrb,wlast};



 // aw channel 

  assign indata_aw = {awid,awaddr,awlen,awsize,awburst,awlock,awcache,awprot};


  ff_macro_p2c # (
  .NUM_FLOPS (FLOP_DEPTH),

  .DATA_WIDTH (DATA_WIDTH_AW)

  ) aw_inst (

  .clk (clk),
  .in_data (indata_aw),
  .out_data (tempdata_aw)

  );
   
  ff_macro_p2c # (
  .NUM_FLOPS (FLOP_DEPTH),

  .DATA_WIDTH (1)

  ) awvalid_inst (

  .clk (clk),
  .in_data (awvalid),
  .out_data (awvalid_b)
  );
  ff_macro_c2p # (
  .NUM_FLOPS (FLOP_DEPTH),
  .DATA_WIDTH (1)
  ) awready_inst (
  .clk (clk),
  .in_data (awready_f),
  .out_data (awready_r)

  );

  (* dont_merge *) reg aw_inst_skid_buf__reset_pipe_in;
  always @(posedge clk) begin
    aw_inst_skid_buf__reset_pipe_in <= reset;
  end
  ready_latency_adapter # (
     .READY_LATENCY_OUT (NUM_PIPELINES),
     .PAYLOAD_WIDTH (DATA_WIDTH_AW),
     .LOG_DEPTH (LOG_DEPTH),
     .BUFFER_TYPE (BUFFER_TYPE)
    ) aw_inst_skid_buf (
     .clk (clk),
     .reset (aw_inst_skid_buf__reset_pipe_in),
     .in_ready (awready_f), // noc ready output 
     .in_valid (awvalid_b),
     .in_data (tempdata_aw),

     .out_ready (awready), // axi ready 0 latency
     .out_valid (awvalid_r),
     .out_data (outdata_aw)
 
    );


  assign {awid_r,awaddr_r,awlen_r,awsize_r,awburst_r,awlock_r,awcache_r,awprot_r} = outdata_aw;

 // ar channel 

  assign indata_ar = {arid,araddr,arlen,arsize,arburst,arlock,arcache,arprot};
 

ff_macro_p2c # (
  .NUM_FLOPS (FLOP_DEPTH),

  .DATA_WIDTH (DATA_WIDTH_AR)

  ) ar_inst_data (

  .clk (clk),
  .in_data (indata_ar),
  .out_data (tempdata_ar)

  );

   
  ff_macro_p2c # (
  .NUM_FLOPS (FLOP_DEPTH),

  .DATA_WIDTH (1)

  ) arvalid_inst (

  .clk (clk),
  .in_data (arvalid),
  .out_data (arvalid_b)
  );
  ff_macro_c2p # (
  .NUM_FLOPS (FLOP_DEPTH),
  .DATA_WIDTH (1)
  ) arready_inst (
  .clk (clk),
  .in_data (arready_f),
  .out_data (arready_r)

  );

  (* dont_merge *) reg ar_inst_skid_buf__reset_pipe_in;
  always @(posedge clk) begin
    ar_inst_skid_buf__reset_pipe_in <= reset;
  end
  ready_latency_adapter # (
     .READY_LATENCY_OUT (NUM_PIPELINES),
     .PAYLOAD_WIDTH (DATA_WIDTH_AR),
     .LOG_DEPTH (LOG_DEPTH),
     .BUFFER_TYPE (BUFFER_TYPE)
    ) ar_inst_skid_buf (
     .clk (clk),
     .reset (ar_inst_skid_buf__reset_pipe_in),
     .in_ready (arready_f), // noc ready output 
     .in_valid (arvalid_b),
     .in_data (tempdata_ar),

     .out_ready (arready), // axi ready 0 latency
     .out_valid (arvalid_r),
     .out_data (outdata_ar)
 
    );

  assign {arid_r,araddr_r,arlen_r,arsize_r,arburst_r,arlock_r,arcache_r,arprot_r} = outdata_ar;
 

 // w channel 

 assign indata_w = {wdata,wlast,wstrb};
 

ff_macro_p2c # (
  .NUM_FLOPS (FLOP_DEPTH),

  .DATA_WIDTH (DATA_WIDTH_W)

  ) w_inst_data (

  .clk (clk),
  .in_data (indata_w),
  .out_data (tempdata_w)

  );

   
  ff_macro_p2c # (
  .NUM_FLOPS (FLOP_DEPTH),

  .DATA_WIDTH (1)

  ) wvalid_inst (

  .clk (clk),
  .in_data (wvalid),
  .out_data (wvalid_b)

  );

  ff_macro_c2p # (
  .NUM_FLOPS (FLOP_DEPTH),
  .DATA_WIDTH (1)
  ) wready_inst (
  .clk (clk),
  .in_data (wready_f),
  .out_data (wready_r)
  );

  (* dont_merge *) reg w_inst_skid_buf__reset_pipe_in;
  always @(posedge clk) begin
    w_inst_skid_buf__reset_pipe_in <= reset;
  end
  ready_latency_adapter # (
     .READY_LATENCY_OUT (NUM_PIPELINES),
     .PAYLOAD_WIDTH (DATA_WIDTH_W),
     .LOG_DEPTH (LOG_DEPTH),
     .BUFFER_TYPE (BUFFER_TYPE)
    ) w_inst_skid_buf (
     .clk (clk),
     .reset (w_inst_skid_buf__reset_pipe_in),
     .in_ready (wready_f), // noc ready output 
     .in_valid (wvalid_b),
     .in_data (tempdata_w),

     .out_ready (wready), // axi ready 0 latency
     .out_valid (wvalid_r),
     .out_data (outdata_w)
 
    );

 assign {wdata_r,wlast_r,wstrb_r} = outdata_w;


  // write response channel

  assign indata_b = {bvalid,bid,bresp};

  // data 
  
  ff_macro_c2p # (
  .NUM_FLOPS (FLOP_DEPTH),

  .DATA_WIDTH (DATA_WIDTH_B)

  ) b_inst_data (

  .clk (clk),
  .in_data (indata_b),
  .out_data (tempdata_b)

  );

   
 assign {bvalid_r,bid_r,bresp_r} = tempdata_b;


  ff_macro_p2c # (
  .NUM_FLOPS (FLOP_DEPTH),

  .DATA_WIDTH (1)
  ) bready_inst (
  .clk (clk),
  .in_data (bready),
  .out_data (bready_r)
  );
 // read response channel

 assign indata_r = {rvalid,rid,rresp,rdata,rlast};

  // data 
  
  ff_macro_c2p # (
  .NUM_FLOPS (FLOP_DEPTH),

  .DATA_WIDTH (DATA_WIDTH_R)

  ) r_inst_data (

  .clk (clk),
  .in_data (indata_r),
  .out_data (tempdata_r)

  );

   
 assign {rvalid_r,rid_r,rresp_r,rdata_r,rlast_r} = tempdata_r;

  ff_macro_p2c # (
  .NUM_FLOPS (FLOP_DEPTH),
  .DATA_WIDTH (1)
  ) rready_inst (
  .clk (clk),
  .in_data (rready),
  .out_data (rready_r)
  );
 end
 endgenerate


endmodule 

`ifdef QUESTA_INTEL_OEM
`pragma questa_oem_00 "HKE1A/xPv2xENkX8yp9xoqkNge46lbMcPP7BkxII5uVAESNhbSQ48MxyKbstHt+Z73pjaLnv4JZL7VIg1Zl08sUjb+a/DJUEwISomi4A5vL/9xMR86jPaYlbfbvTGJyK0dtsE3CZllK6Orkctae64nBtq574elgMyKlt1SuCin3Dz1hwF/fuGJz1pzcKZ2XKUwAVd2517c5HdE1spdswJCP157Z27/3eHr0YYHHsZ+Cang607eBVYABILPBx3lgZz/h1T8KzpiWVGLfG4FZ7qJ/LvkVKphh3YrkEDpS3C335VGZeH/lDT/9F8RSX9As0Dyn6RDaUcQlJNWJwq7GhW0quY2VE7E3NlDfO1zmwfDiGnc6g+qUdHp4Gwt1MGcYecNEeYbGEG5C1eESMNzyEFTRQ3eZw7ytylFp0lZudcIwvDq50/RQRpDf6zLFjY3PMaREH0iy2fdnDKdAtIdngd2xSMkTycVQV96O9tkOZd25j/N6mAD7lhPKfHAcqCf/whejViSdnrcDgYj4Ae0mKVlE0VyD0kkKvepbg3eH3LSTGrthDjjUpkm/YfXy9R0BelMcb5/+y2SGQCbrUi6wVSwG2glQIg/b53kcEq3sq8gVg7MRYVtVblZQdw6FKPfqS3Q7DqxHG24gDcyso3ZcyQUg2m1oBH/A2l1GW4ZO+8u8Jt0fKxh6oHdwjBobRGF1vzZF57itPMqpfVhEUxIj9/eyRpRHv6xZ8AkV8EWkV0JBk6+70LWx7drDQtMbytKdWfVLpFieICkepKRT7jKI3vCspFXALoUIwjfGwipqjh8ebYuoVOmu/JqOc1YN5OXx8x79xxu7lpzECkaeofuNiQojs+XsoNYjy52LdP0aEtFhp1C02XijK2DhQjYb5wdKLI8d3oQrt+252FI/QEVWvMcsIuEHxlfxSJ/A3e/awilh7VHJf+xJ+e6I1xOPFBKSanK4e5C0UDpkLMbbSQL2BWJCWLTuWZaofKjs3AhbZZujTKLdEoEBk9mw68CF3DnwK"
`endif