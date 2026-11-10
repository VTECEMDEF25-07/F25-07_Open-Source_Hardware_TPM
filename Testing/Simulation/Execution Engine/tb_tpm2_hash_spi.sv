`timescale 1ns/1ns
module tb_tpm2_hash_spi #(parameter ENABLE_AES_TEST = 0);
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

TPM_TOP #(.ENABLE_ENCRYPTDECRYPT2(ENABLE_AES_TEST)) dut(.CLOCK_50(clk),.CLOCK_100(clk100),.RESET_n(rst),
.SPI_CLOCK(sck),.SPI_CS_n(cs),.SPI_RST_n(rst),.SPI_MOSI(mosi),.SPI_MISO(miso),.SPI_PIRQ_n(irq),
.aes_key_request_o(key_request), .aes_key_request_ready_i(1'b1), .aes_key_handle_o(key_handle),
.aes_key_reply_valid_i(key_reply_valid), .aes_key_reply_ready_o(key_reply_ready),
.aes_resolved_key_i(KEY), .aes_key_reply_code_i(key_reply_code));
reg [7:0] packet[0:89], response[0:89];
reg passed=0;
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
  shift(8'hd4,got); shift(addr[15:8],got); shift(addr[7:0],got);
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
 if(response[0]===8'hff || !response[0][4]) $fatal(1,"No dataAvail sts=%h code=%h size=%h op=%h",response[0],dut.commandCode,dut.commandSize,dut.op_state);
 transfer(1,16'h0024,count > 64 ? 64 : count);
 if (count > 64) transfer(1,16'h0024,count-64,64);
end endtask
localparam [255:0] ABC=256'hba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad;
localparam [319:0] PLAINTEXT = 320'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f2021222324252627;
localparam [319:0] CIPHERTEXT = 320'he9c2ed89b63155e1f87d96dd3aeaa6815992bae8ff869e17a1af95bd78d810cef497f7aca9d80b4f;
localparam [127:0] IV = 128'h101112131415161718191a1b1c1d1e1f;
localparam [127:0] FEEDBACK = 128'hf497f7aca9d80b4f0000000000000000;

task automatic aes_packet(input bit decrypt,input [31:0] handle,
                          input [319:0] data,input bit malformed,input [31:0] rc);
  reg [231:0] prefix;
  reg [167:0] trailer;
  reg [631:0] expected_reply;
  begin
    write_one(16'h0018,8'h40);
    write_one(16'h0018,8'h40);
    prefix = {16'h8002,32'd90,32'h193,handle,32'd9,32'h40000009,16'd0,
              8'd0,16'd0,16'd40};
    trailer = {7'd0,decrypt,16'h0043,16'd16,IV};
    for (integer i=0;i<29;i=i+1) packet[i]=prefix[231-i*8 -:8];
    for (integer i=0;i<40;i=i+1) packet[29+i]=data[319-i*8 -:8];
    for (integer i=0;i<21;i=i+1) packet[69+i]=trailer[167-i*8 -:8];
    if (malformed) packet[17]=8;
    transfer(0,16'h0024,64);
    transfer(0,16'h0024,26,64);
    finish_cmd(rc == 0 ? 79 : 10);
    if (rc == 0) begin
      expected_reply = {16'h8002,32'd79,32'd0,32'd60,16'd40,
                        (decrypt ? PLAINTEXT : CIPHERTEXT),16'd16,FEEDBACK,40'h0000010000};
      for (integer i=0;i<79;i=i+1)
        if (response[i] !== expected_reply[631-i*8 -:8])
          $fatal(1,"AES reply byte %0d expected %h got %h",i,expected_reply[631-i*8 -:8],response[i]);
    end else if ({response[0],response[1],response[2],response[3],response[4],
                  response[5],response[6],response[7],response[8],response[9]} !==
                 {16'h8001,32'd10,rc})
      $fatal(1,"Unexpected AES error response, expected %h got %h",rc,
             {response[6],response[7],response[8],response[9]});
  end
endtask
initial begin
 #3; rst=1; #7; rst=0; #200; rst=1; #1000;
 write_one(16'h0000,8'h02); transfer(1,16'h0000,1);
 if (response[0] !== 8'ha1) $fatal(1,"Locality 0 was not granted");
 repeat (2) begin
 write_one(16'h0018,8'h40);
 write_one(16'h0018,8'h40);
 {packet[0],packet[1],packet[2],packet[3],packet[4],packet[5],packet[6],packet[7],packet[8],packet[9],packet[10],packet[11]}=96'h80010000000c000001440000;
 transfer(0,16'h0024,10); packet[0]=0; packet[1]=0; transfer(0,16'h0024,2);
 finish_cmd(10);
 if({response[6],response[7],response[8],response[9]} !== 0) $fatal(1,"Startup rc %h",{response[6],response[7],response[8],response[9]});
 write_one(16'h0018,8'h40);
 write_one(16'h0018,8'h40);
 {packet[0],packet[1],packet[2],packet[3],packet[4],packet[5],packet[6],packet[7],packet[8],packet[9],packet[10],packet[11],packet[12],packet[13],packet[14],packet[15],packet[16],packet[17],packet[18],packet[19],packet[20]}=168'h8001000000150000017d0003616263000b40000007;
 transfer(0,16'h0024,21);
 finish_cmd(52);
 if({response[0],response[1],response[2],response[3],response[4],response[5],response[6],response[7],response[8],response[9],response[10],response[11]} !== 96'h800100000034000000000020)
 $fatal(1,"Bad hash header %h",{response[0],response[1],response[2],response[3],response[4],response[5],response[6],response[7],response[8],response[9],response[10],response[11]});
 for(integer n=0;n<32;n=n+1) if(response[12+n]!==ABC[255-n*8 -:8]) $fatal(1,"Wrong digest byte %d",n);
 if({response[44],response[45],response[46],response[47],response[48],response[49],response[50],response[51]}!==64'h8024400000070000) $fatal(1,"Bad ticket");
 end
 if (ENABLE_AES_TEST) begin
   aes_packet(0,32'h80000000,PLAINTEXT,0,0);
   aes_packet(1,32'h80000000,CIPHERTEXT,0,0);
   aes_packet(0,32'h80000001,PLAINTEXT,0,32'h18b);
   allow_use=0;
   aes_packet(0,32'h80000000,PLAINTEXT,0,32'h9a2);
   aes_packet(0,32'h80000000,PLAINTEXT,1,32'h144);
   if (lookups != 4) $fatal(1,"Expected four key requests, got %0d",lookups);
   $display("TPM2_ENCRYPTDECRYPT2_SPI_PASS");
 end else begin
   aes_packet(0,32'h80000000,PLAINTEXT,0,32'h143);
   if (lookups != 0) $fatal(1,"Disabled AES command issued key request");
 end
 passed=1;
 $display("TPM2_HASH_SPI_PASS"); $finish;
end
initial begin #5000000; $fatal(1,"SPI global timeout"); end
endmodule
