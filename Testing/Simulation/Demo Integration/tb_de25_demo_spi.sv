`timescale 1ns/1ns
module tb_de25_demo_spi #(parameter WIDTH=32);
reg clk=0,rst=0,sck=0,cs=1,mosi=0;
wire miso,irq; always #10 clk=~clk;
TPM_TOP #(.ENABLE_DEMO_COMMANDS(1),.DEMO_PROVIDER_MODE(1),.DEMO_MODEXP_WIDTH(WIDTH),.IP_TYPE(0)) dut(
 .CLOCK_50(clk),.RESET_n(rst),.SPI_CLOCK(sck),.SPI_CS_n(cs),.SPI_RST_n(rst),.SPI_MOSI(mosi),.SPI_MISO(miso),.SPI_PIRQ_n(irq),
 .aes_key_request_ready_i(1'b0),.aes_key_reply_valid_i(1'b0),.aes_resolved_key_i(256'd0),.aes_key_reply_code_i(32'h101));
reg [7:0] packet[0:1099],response[0:1099];
reg [31:0] handle,old_handle;
localparam B=WIDTH/8;
task automatic shift(input [7:0] val,output reg [7:0] got);
  for(integer i=7;i>=0;i=i-1) begin
    mosi=val[i]; #500; sck=1; got[i]=miso; #500; sck=0;
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
 do begin transfer(1,16'h0018,1); i=i+1; end while((response[0]===8'hff || !response[0][4]) && i<20000);
 if(response[0]===8'hff || !response[0][4]) $fatal(1,"No dataAvail sts=%h code=%h size=%h op=%h",response[0],dut.commandCode,dut.commandSize,dut.op_state);
 for(integer off=0;off<count;off=off+64)
   transfer(1,16'h0024,count-off>64?64:count-off,off);
end endtask

localparam [319:0] PT=320'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f2021222324252627, CT=320'h2427ffa69302a5bcebc2010f34dc9bd01b72ef0ab3dd2b846bdfe14efe1236302abc43a108e6e9de;
localparam [127:0] IV=128'h101112131415161718191a1b1c1d1e1f;
localparam [255:0] DIGEST=256'h5faa4eec3611556812c2d74b437c8c49add3f910f10063d801441f7d75cd5e3b;
reg [7:0] expected_modexp[0:B-1];
task automatic header(input [15:0] tag,input integer size,input [31:0] cc);
 begin
 {packet[0],packet[1]}=tag;
 {packet[2],packet[3],packet[4],packet[5]}=size;
 {packet[6],packet[7],packet[8],packet[9]}=cc;
 end
endtask
task automatic ready_cmd;
 integer tries;
 begin
 write_one(16'h0018,8'h40);write_one(16'h0018,8'h40);
 tries=0;
 do begin transfer(1,16'h0018,1); tries=tries+1; end while(!response[0][6] && tries<100);
 if(!response[0][6]) $fatal(1,"No commandReady");
 end
endtask
task automatic send_cmd(input integer size,input integer replysize,input [31:0] rc);
 begin
 for(integer off=0;off<size;off=off+64) transfer(0,16'h0024,size-off>64?64:size-off,off);
 finish_cmd(replysize);
 if({response[6],response[7],response[8],response[9]} !== rc)
  $fatal(1,"Unexpected command RC expected=%h actual=%h cc=%h",rc,{response[6],response[7],response[8],response[9]},dut.commandCode);
 end
endtask
task automatic control(input [7:0] opcode,input [31:0] h,input [31:0] id,input [31:0] rc);
 begin
 ready_cmd(); header(16'h8001,26,32'h20000100);
 for(integer i=10;i<26;i=i+1)packet[i]=0;
 packet[10]=1;packet[11]=opcode;
 {packet[14],packet[15],packet[16],packet[17]}=id;
 {packet[18],packet[19],packet[20],packet[21]}=h;
 send_cmd(26,rc==0?38:10,rc);
 if(rc==0 && response[12]!==1) $fatal(1,"Missing TEST_DETERMINISTIC label");
 end
endtask
task automatic aes(input bit decrypt,input [31:0] h,input [31:0] rc);
 reg [231:0] prefix;reg[167:0] trailer;reg[319:0] data,expected;
 begin
 ready_cmd();data=decrypt?CT:PT;expected=decrypt?PT:CT;
 prefix={16'h8002,32'd90,32'h193,h,32'd9,32'h40000009,16'd0,8'd0,16'd0,16'd40};
 trailer={7'd0,decrypt,16'h0043,16'd16,IV};
 for(integer i=0;i<29;i=i+1)packet[i]=prefix[231-8*i -:8];
 for(integer i=0;i<40;i=i+1)packet[29+i]=data[319-8*i -:8];
 for(integer i=0;i<21;i=i+1)packet[69+i]=trailer[167-8*i -:8];
 send_cmd(90,rc==0?79:10,rc);
 if(rc==0)for(integer i=0;i<40;i=i+1)
  if(response[16+i]!==expected[319-8*i -:8])$fatal(1,"Independent AES byte%0d expected%h got%h",i,expected[319-8*i -:8],response[16+i]);
 end
endtask
task automatic startup;
 begin
 write_one(16'h0000,8'h02);transfer(1,16'h0000,1);
 if(response[0]!==8'ha1)$fatal(1,"No locality");
 ready_cmd();header(16'h8001,12,32'h144);packet[10]=0;packet[11]=0;send_cmd(12,10,0);
 end
endtask
initial begin
 #3;rst=1;#7;rst=0;#200;rst=1;
 repeat(10000)@(posedge clk);
 startup();control(0,0,1,0);control(1,0,2,0);
 handle={response[18],response[19],response[20],response[21]};
 if(handle==0 || !response[25][0])$fatal(1,"No committed protected handle");
 $display("DEMO_GENERATED handle=%h",handle);
 aes(0,handle,0);aes(1,handle,0);
 ready_cmd();header(16'h8001,58,32'h17d);packet[10]=0;packet[11]=40;
 for(integer i=0;i<40;i=i+1)packet[12+i]=PT[319-8*i -:8];
 {packet[52],packet[53],packet[54],packet[55],packet[56],packet[57]}=48'h000b40000007;
 send_cmd(58,52,0);
 for(integer i=0;i<32;i=i+1)if(response[12+i]!==DIGEST[255-8*i -:8])$fatal(1,"SHA reference mismatch");
 control(2,handle,3,0);aes(0,handle,32'h18b);
 control(1,0,4,0);old_handle=handle;handle={response[18],response[19],response[20],response[21]};
 if(handle==old_handle)$fatal(1,"Handle incarnation reused");aes(0,old_handle,32'h18b);aes(0,handle,0);
 control(2,handle,5,0);
 ready_cmd();header(16'h8001,26+3*B,32'h20000100);
 for(integer i=10;i<26+3*B;i=i+1)packet[i]=0;
 packet[10]=1;packet[11]=3;packet[17]=6;
 // public base=01234567, exponent=65537, modulus=(1<<WIDTH)-189
 {packet[26+B-4],packet[26+B-3],packet[26+B-2],packet[26+B-1]}=32'h01234567;
 packet[26+2*B-3]=1;packet[26+2*B-1]=1;
 for(integer i=0;i<B;i=i+1)packet[26+2*B+i]=8'hff;
 packet[26+3*B-1]=8'h43;
 $readmemh("modexp_expected.hex",expected_modexp);
 send_cmd(26+3*B,38+B,0);
 for(integer i=0;i<B;i=i+1)if(response[38+i]!==expected_modexp[i])$fatal(1,"MODEXP reference byte%0d expected%h got%h",i,expected_modexp[i],response[38+i]);
 $display("DEMO_MODEXP_MATCH WIDTH=%0d",WIDTH);
 // Full reset invalidates cached references; no old key returned.
 rst=0;#200;rst=1;repeat(10000)@(posedge clk);startup();aes(0,handle,32'h18b);
 control(0,0,7,0);
 $display("PASS DE25 REAL SPI DEMO TEST WIDTH=%0d",WIDTH);$finish;
end
initial begin #1000000000;$fatal(1,"Combined SPI deadline state=%d cc=%h",dut.io.command_response_buffer.state,dut.commandCode);end
endmodule
