`timescale 1ns/1ns
module tb_tpm2_pcr_extend_spi;
reg clk=0, clk100=0, rst=0, sck=0, cs=1, mosi=0;
wire miso, irq;
always #10 clk=~clk;
always #5 clk100=~clk100;
localparam [255:0] KEY = 256'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f;
wire key_request, key_reply_ready;
wire [31:0] key_handle;
reg key_reply_valid=0, allow_use=1;
reg [31:0] key_reply_code=0;
integer lookups=0;

always @(posedge clk) begin
  if (key_request) begin
    lookups <= lookups + 1;
    key_reply_valid <= 1;
    key_reply_code <= key_handle != 32'h80000000 ? 32'h18b : allow_use ? 0 : 32'h9a2;
  end else if (key_reply_ready)
    key_reply_valid <= 0;
end

TPM_TOP #(.ENABLE_ENCRYPTDECRYPT2(0), .ENABLE_PCR_EXTEND(1),
.PCR_EXTEND_EMPTY_AUTH_MASK(24'h810101)) dut(.CLOCK_50(clk),.CLOCK_100(clk100),.RESET_n(rst),
.SPI_CLOCK(sck),.SPI_CS_n(cs),.SPI_RST_n(rst),.SPI_MOSI(mosi),.SPI_MISO(miso),.SPI_PIRQ_n(irq),
.aes_key_request_o(key_request), .aes_key_request_ready_i(1'b1), .aes_key_handle_o(key_handle),
.aes_key_reply_valid_i(key_reply_valid), .aes_key_reply_ready_o(key_reply_ready),
.aes_resolved_key_i(KEY), .aes_key_reply_code_i(key_reply_code));
reg [7:0] packet[0:511], response[0:511];
reg [7:0] expected[0:511];
integer expected_size;
reg [15:0] locality_base=0;
integer backend_commits=0;
always @(posedge clk) if(rst && dut.shared_hash.pcr_write_en) backend_commits<=backend_commits+1;
reg passed=0;
integer engine_starts=0,engine_replies=0;
reg prior_data_avail=0;
always @(posedge clk) begin
 if(!rst) prior_data_avail<=0;
 else prior_data_avail<=dut.io.fifo_register_space.r_dataAvail;
end
always @(posedge clk) if(rst) begin
  if(dut.io.pcr_status_active && dut.io.fifo_register_space.r_dataAvail && !prior_data_avail &&
     (dut.io.fifo_register_space.io_fifo.state==8 ||
      dut.io.fifo_register_space.io_fifo.state==9 ||
      dut.io.fifo_register_space.io_fifo.state==10))
    $fatal(1,"PCR dataAvail preceded complete FIFO transfer");
  if(dut.ee.current_state_o==10 && dut.ee.pcr_active) engine_starts<=engine_starts+1;
  if(dut.ee.pcr_command.start_i && dut.ee.active_locality !== dut.command_locality)
    $fatal(1,"Lost command locality binding");
  if(dut.ee.pcr_command.start_i && (!dut.ee.pcr_active || dut.ee.current_state_o!=10))
    $fatal(1,"SPI PCR bypassed Phase One dispatch");
  if(dut.ee.response_valid_o && dut.ee.pcr_active) begin
    if(dut.ee.current_state_o!=9) $fatal(1,"SPI PCR bypassed post-processing");
    engine_replies<=engine_replies+1;
  end
end
task automatic shift(input [7:0] val,output reg [7:0] got);
  for(integer i=7;i>=0;i=i-1) begin
    mosi=val[i]; #33; sck=1; got[i]=miso; #33; sck=0;
  end
endtask
task automatic transfer(input bit rd,input [15:0] addr,input integer count,input integer offset=0);
reg [7:0] got; integer n, first_data;
begin
  #100; cs=0; #100;
  shift((rd?8'hc0:8'h40)|(count-1),got);
  shift(8'hd4,got); shift((addr[15:8] | locality_base[15:8]),got); shift(addr[7:0],got);
  n=0;
  while(!got[0] && n<40) begin shift(rd ? 8'd0 : packet[offset],got); n=n+1; end
  // The inherited serializer can consume the first write byte while
  // returning the ready indication on MISO.
  first_data = !rd && n != 0 ? 1 : 0;
  if(!got[0]) $fatal(1,"SPI wait timeout addr=%h",addr);
  for(n=first_data;n<count;n=n+1) begin
     shift(rd ? 8'd0 : packet[offset+n],got);
     if(rd) response[offset+n]=got;

  end
  #100; cs=1; #100;
end endtask
task automatic write_one(input [15:0] addr,input [7:0] val);
begin packet[0]=val; transfer(0,addr,1); end
endtask
task automatic finish_cmd(input integer count);
integer i;
begin
 write_one(16'h0018,8'h20);
 i=0;
 do begin transfer(1,16'h0018,1); i=i+1; end while((response[0]===8'hff || !response[0][4]) && i<100);
 if(response[0]===8'hff || !response[0][4]) $display("PCR_DEBUG crb=%0d fifo=%0d sts=%0d done=%b rspdone=%b ack=%b data=%b",dut.io.command_response_buffer.state,dut.io.fifo_register_space.io_fifo.state,dut.io.fifo_register_space.sts_s,dut.io.c_execDone,dut.io.c_rspDone,dut.io.c_execAck,dut.io.fifo_register_space.r_dataAvail);
 if(response[0]===8'hff || !response[0][4]) $fatal(1,"No dataAvail sts=%h code=%h size=%h op=%h",response[0],dut.commandCode,dut.commandSize,dut.op_state);

 for(integer base=0;base<count;base+=64)
   transfer(1,16'h0024,(count-base)>64?64:(count-base),base);
end endtask
localparam [255:0] PCR0=256'h5c85955f709283ecce2b74f1b1552918819f390911816e7bb466805a38ab87f3;
localparam [255:0] PCR8=256'h20a7d6f6e88f212bd7a6d6098a6dcc93b83def3ea1f696fd81e72bae0edcc3cd;
localparam [255:0] PCR16=256'h8878b15a7d6a3a4f464e8f9f42591dbc0cf4bedea0ec309003d2b2ee53655ef8;
localparam [255:0] PCR23=256'hcc067049bf369bb26145c4589915939e098b996626c9b121ba34cba2081642b2;
task automatic startup;
begin
 write_one(16'h0018,8'h40);write_one(16'h0018,8'h40);
 {packet[0],packet[1],packet[2],packet[3],packet[4],packet[5],packet[6],packet[7],packet[8],packet[9],packet[10],packet[11]}=96'h80010000000c000001440000;
 transfer(0,16'h0024,10);packet[0]=0;packet[1]=0;transfer(0,16'h0024,2);
 finish_cmd(10);
 if({response[6],response[7],response[8],response[9]}!==0) $fatal(1,"SPI Startup error");
end endtask
task automatic backend_extend(input [4:0] index, input integer fault=0);
begin
 write_one(16'h0018,8'h40);write_one(16'h0018,8'h40);
 for(integer n=0;n<65;n++) packet[n]=0;
 {packet[0],packet[1]}=16'h8002;packet[5]=65;
 {packet[6],packet[7],packet[8],packet[9]}=32'h182;
 packet[13]=index;packet[17]=9;
 {packet[18],packet[19],packet[20],packet[21]}=32'h40000009;
 packet[30]=1;packet[32]=8'h0b;
 for(integer n=33;n<65;n++) packet[n]=8'(index+1);
 case(fault)
  1:packet[26]=1; // unsupported nonempty password
  2:packet[32]=4; // unsupported SHA-1 bank
  3:packet[13]=24; // bad PCR handle
  4:packet[5]=64; // truncated digest
 endcase
 transfer(0,16'h0024,64);
 if(fault!=4) begin packet[0]=8'(index+1);transfer(0,16'h0024,1);end
 case(fault)
  1,5:expected_header(10,32'h98e);
  2:expected_header(10,32'h1c3);
  3:expected_header(10,32'h18b);
  4:expected_header(10,32'h142);
  6:expected_header(10,32'h907);
  default:begin expected_header(19);expected[1]=2;expected[16]=1;end
 endcase
 check_response();
end endtask
task automatic expected_header(input integer length,input [31:0] rc=0);
begin
 expected_size=length;
 for(integer i=0;i<512;i++) expected[i]=0;
 {expected[0],expected[1],expected[2],expected[3],expected[4],expected[5],expected[6],expected[7],expected[8],expected[9]}={16'h8001,32'(length),rc};
end endtask
task automatic check_response;
begin
 finish_cmd(expected_size);
 for(integer i=0;i<expected_size;i++) if(response[i]!==expected[i])
   $fatal(1,"SPI PCR byte %0d expected %h got %h",i,expected[i],response[i]);
end endtask
task automatic read_bank(input bit initial_bank=0);
reg [255:0] value;
begin
 write_one(16'h0018,8'h40);write_one(16'h0018,8'h40);
 {packet[0],packet[1],packet[2],packet[3],packet[4],packet[5],packet[6],packet[7],packet[8],packet[9],packet[10],packet[11],packet[12],packet[13],packet[14],packet[15],packet[16],packet[17],packet[18],packet[19]}=160'h8001000000140000017e00000001000b03010181;
 transfer(0,16'h0024,20);
 expected_header(164);
 // Independently specified wire prefix: counter, one bank, mask, four digests.
 {expected[10],expected[11],expected[12],expected[13]}=initial_bank?0:4;
 {expected[14],expected[15],expected[16],expected[17],expected[18],expected[19],expected[20],expected[21],expected[22],expected[23],expected[24],expected[25],expected[26],expected[27]}=112'h00000001000b0301018100000004;
 for(integer n=0;n<4;n++) begin
   case(n) 0:value=PCR0;1:value=PCR8;2:value=PCR16;3:value=PCR23;endcase
   expected[28+n*34]=0;expected[29+n*34]=32;
   for(integer j=0;j<32;j++) expected[30+n*34+j]=initial_bank?0:value[255-j*8 -:8];
 end
 check_response();
end endtask
// Full response boundary: eight digests, 300 bytes over five SPI transfers.
task automatic read_page(input bit last_page);
reg [255:0] value;
reg [23:0] input_mask, output_mask;
integer index;
begin
 input_mask=last_page?24'hff0000:24'hffffff;
 output_mask=last_page?24'hff0000:24'h0000ff;
 write_one(16'h0018,8'h40);write_one(16'h0018,8'h40);
 {packet[0],packet[1],packet[2],packet[3],packet[4],packet[5],packet[6],packet[7],packet[8],packet[9],packet[10],packet[11],packet[12],packet[13],packet[14],packet[15],packet[16]}=136'h8001000000140000017e00000001000b03;
 {packet[17],packet[18],packet[19]}={input_mask[7:0],input_mask[15:8],input_mask[23:16]};
 transfer(0,16'h0024,20);
 expected_header(300);
 {expected[10],expected[11],expected[12],expected[13]}=4;
 {expected[14],expected[15],expected[16],expected[17],expected[18],expected[19],expected[20]}=56'h00000001000b03;
 {expected[21],expected[22],expected[23]}={output_mask[7:0],output_mask[15:8],output_mask[23:16]};
 expected[27]=8;
 for(integer n=0;n<8;n++) begin
   index=(last_page?16:0)+n;
   case(index) 0:value=PCR0;16:value=PCR16;23:value=PCR23;default:value=0;endcase
   expected[28+n*34]=0;expected[29+n*34]=32;
   for(integer j=0;j<32;j++) expected[30+n*34+j]=value[255-j*8 -:8];
 end
 check_response();
end endtask
task automatic capability;
begin
 write_one(16'h0018,8'h40);write_one(16'h0018,8'h40);
 {packet[0],packet[1],packet[2],packet[3],packet[4],packet[5],packet[6],packet[7],packet[8],packet[9],packet[10],packet[11],packet[12],packet[13],packet[14],packet[15],packet[16],packet[17],packet[18],packet[19],packet[20],packet[21]}=176'h8001000000160000017a000000050000000000000001;
 transfer(0,16'h0024,22);
 expected_header(25);
 {expected[10],expected[11],expected[12],expected[13],expected[14],expected[15],expected[16],expected[17],expected[18],expected[19],expected[20],expected[21],expected[22],expected[23],expected[24]}=120'h000000000500000001000b03ffffff;
 check_response();
end endtask
initial begin
 #3;rst=1;#7;rst=0;#200;rst=1;#1000;
 write_one(16'h0000,8'h02);transfer(1,16'h0000,1);
 if(response[0]!==8'ha1) $fatal(1,"No locality");
 startup();read_bank(1);capability();
 backend_extend(0);backend_extend(8);backend_extend(16);backend_extend(23);
 read_bank();read_page(0);read_page(1);capability();
 // Rejects travel over actual SPI and CRB, with a full independent PCR snapshot
 // after each. No mutation controls are forced by this host bench.
 for(integer fault=1;fault<=5;fault++) begin
   backend_extend(fault==5?15:0,fault);read_bank();
 end
 // Relinquish locality0 and acquire locality1 through real ACCESS registers.
 write_one(16'h0000,8'h20);locality_base=16'h1000;
 write_one(16'h0000,8'h02);transfer(1,16'h0000,1);
 if(response[0]!==8'ha1 || dut.locality!==2) $fatal(1,"No locality1");
 backend_extend(0,6);read_bank();
 write_one(16'h0000,8'h20);locality_base=0;write_one(16'h0000,8'h02);
 if(backend_commits!=4) $fatal(1,"SPI rejection changed bank/counter");
 // Existing profile: management Startup does not reset or restore PCR RAM.
 startup();read_bank();
 if(dut.shared_hash.pcr_update_counter_o!==4) $fatal(1,"Startup/read changed counter");
 // Hardware reset reinitializes the volatile bank and counter.
 rst=0;#200;rst=1;#1000;
 write_one(16'h0000,8'h02);startup();read_bank(1);capability();
 if(engine_starts!=25 || engine_replies!=25) $fatal(1,"SPI engine route lost commands starts=%0d replies=%0d",engine_starts,engine_replies);
 $display("TPM2_PCR_EXTEND_SPI_ENGINE_ROUTE starts=%0d replies=%0d",engine_starts,engine_replies);
 passed=1;$display("TPM2_PCR_EXTEND_SPI_PASS");$finish;
end
initial begin #10000000;$fatal(1,"SPI PCR timeout");end
endmodule
