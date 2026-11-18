`timescale 1ns/1ns
module tb_tpm2_hash_spi #(parameter ENABLE_AES_TEST = 0, parameter DETERMINISTIC_KEY_TEST = 0);
reg clk=0, clk100=0, rst=0, sck=0, cs=1, mosi=0;
wire miso, irq;
always #10 clk=~clk;
always #5 clk100=~clk100;
localparam [255:0] KEY = DETERMINISTIC_KEY_TEST ? 256'h3127189a1a42bcdcf45b4810b24d1c7ddd6c73cd5ea0053d34d5ae80db93bb22 : 256'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f;
wire key_request, key_reply_ready;
wire [31:0] key_handle;
reg key_reply_valid=0, allow_use=1;
reg [31:0] key_reply_code=0;
integer lookups=0;
wire generated_reply_valid, generated_request_ready, generated_key_ready;
wire [255:0] generated_key;
wire [31:0] generated_reply_code;
generate if (DETERMINISTIC_KEY_TEST) begin : generated
  lenovo_aes_key_service service (
    .clock_i(clk), .reset_n_i(rst), .key_request_i(key_request),
    .key_request_ready_o(generated_request_ready), .key_handle_i(key_handle),
    .key_reply_valid_o(generated_reply_valid), .key_reply_ready_i(key_reply_ready),
    .resolved_key_o(generated_key), .key_reply_code_o(generated_reply_code),
    .key_ready_o(generated_key_ready)
  );

end endgenerate
integer engine_aes_starts=0, engine_aes_replies=0;
always @(posedge clk) if (rst) begin
  if (dut.ee.current_state_o == 12) engine_aes_starts <= engine_aes_starts+1;
  if (dut.ee.response_valid_o && dut.ee.aes_active) begin
    if (dut.ee.current_state_o != 9) $fatal(1,"AES bypassed engine completion");
    engine_aes_replies <= engine_aes_replies+1;
  end
end

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
.aes_key_request_o(key_request), .aes_key_request_ready_i(DETERMINISTIC_KEY_TEST ? generated_request_ready : 1'b1), .aes_key_handle_o(key_handle),
.aes_key_reply_valid_i(DETERMINISTIC_KEY_TEST ? generated_reply_valid : key_reply_valid), .aes_key_reply_ready_o(key_reply_ready),
.aes_resolved_key_i(DETERMINISTIC_KEY_TEST ? generated_key : KEY), .aes_key_reply_code_i(DETERMINISTIC_KEY_TEST ? generated_reply_code : key_reply_code));
reg [7:0] packet[0:1073], response[0:1062];
reg passed=0;
integer engine_hash_starts=0, engine_hash_replies=0;
always @(posedge clk) if (rst) begin
  if (dut.ee.current_state_o == 10 && dut.ee.active_code == 32'h17d)
    engine_hash_starts <= engine_hash_starts+1;
  if (dut.hash_request && (!dut.ee.hash_active || dut.ee.current_state_o != 11))
    $fatal(1,"SPI Hash bypassed execution engine");
  if (dut.ee.response_valid_o && dut.ee.hash_active && dut.ee.active_code == 32'h17d) begin
    if (dut.ee.current_state_o != 9) $fatal(1,"Hash reply outside engine completion");
    engine_hash_replies <= engine_hash_replies+1;
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
 for (i=0;i<count;i=i+64) transfer(1,16'h0024,count-i > 64 ? 64 : count-i,i);
end endtask
localparam [255:0] ABC=256'hba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad;
localparam [319:0] PLAINTEXT = 320'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f2021222324252627;
localparam [319:0] CIPHERTEXT = DETERMINISTIC_KEY_TEST ? 320'h2427ffa69302a5bcebc2010f34dc9bd01b72ef0ab3dd2b846bdfe14efe1236302abc43a108e6e9de : 320'he9c2ed89b63155e1f87d96dd3aeaa6815992bae8ff869e17a1af95bd78d810cef497f7aca9d80b4f;
localparam [127:0] IV = 128'h101112131415161718191a1b1c1d1e1f;
localparam [127:0] FEEDBACK = DETERMINISTIC_KEY_TEST ? 128'h2abc43a108e6e9de0000000000000000 : 128'hf497f7aca9d80b4f0000000000000000;

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
// Encrypt and decrypt boundary lengths through the real SPI and engine path.
task automatic boundary_roundtrip(input integer length);
  reg [7:0] encrypted[0:1023];
  reg [231:0] prefix;
  reg [167:0] trailer;
  integer count, expected_byte;
  begin
    count=50+length;
    for (integer direction=0;direction<2;direction=direction+1) begin
      write_one(16'h0018,8'h40);
      write_one(16'h0018,8'h40);
      prefix={16'h8002,32'(count),32'h193,32'h80000000,
              32'd9,32'h40000009,16'd0,8'd0,16'd0,16'(length)};
      trailer={8'(direction),16'h0043,16'd16,IV};
      for (integer i=0;i<29;i=i+1) packet[i]=prefix[231-i*8 -:8];
      for (integer i=0;i<length;i=i+1)
        packet[29+i]=direction ? encrypted[i] : 8'(i);
      for (integer i=0;i<21;i=i+1) packet[29+length+i]=trailer[167-i*8 -:8];
      for (integer i=0;i<count;i=i+64)
        transfer(0,16'h0024,count-i > 64 ? 64 : count-i,i);
      finish_cmd(39+length);
      if ({response[0],response[1]} !== 16'h8002 ||
          {response[6],response[7],response[8],response[9]} !== 32'd0 ||
          {response[14],response[15]} !== 16'(length))
        $fatal(1,"Boundary AES header length=%0d direction=%0d tag=%h rc=%h length=%h",length,direction,{response[0],response[1]},{response[6],response[7],response[8],response[9]},{response[14],response[15]});
      for (integer i=0;i<length;i=i+1)
        if (!direction) encrypted[i]=response[16+i];
        else if (response[16+i] !== 8'(i))
          $fatal(1,"Boundary plaintext mismatch length=%0d byte=%0d",length,i);
      for (integer i=0;i<16;i=i+1) begin
        if (length == 0) expected_byte=IV[127-i*8 -:8];
        else if (i < (length%16 == 0 ? 16 : length%16))
          expected_byte=encrypted[length-(length%16 == 0 ? 16 : length%16)+i];
        else expected_byte=0;
        if (response[18+length+i] !== 8'(expected_byte))
          $fatal(1,"Boundary IV mismatch length=%0d byte=%0d",length,i);
      end
    end
    $display("LENOVO_AES_BOUNDARY_PASS bytes=%0d",length);
  end
endtask
initial begin
 #3; rst=1; #7; rst=0; #200; rst=1; #1000;
 write_one(16'h0000,8'h02); transfer(1,16'h0000,1);
 if (response[0] !== 8'ha1) $fatal(1,"Locality 0 was not granted");
 repeat (4) begin
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
 $display("TPM2_HASH_SPI_ENGINE_ROUTE starts=%0d replies=%0d",engine_hash_starts,engine_hash_replies);
 if (engine_hash_starts != 4 || engine_hash_replies != 4)
   $fatal(1,"Expected four engine-owned SPI Hash commands, starts=%0d replies=%0d",
          engine_hash_starts,engine_hash_replies);
 if (ENABLE_AES_TEST) begin
   aes_packet(0,32'h80000000,PLAINTEXT,0,0);
   aes_packet(1,32'h80000000,CIPHERTEXT,0,0);
   aes_packet(0,32'h80000001,PLAINTEXT,0,32'h18b);
   if (!DETERMINISTIC_KEY_TEST) begin
     allow_use=0;
     aes_packet(0,32'h80000000,PLAINTEXT,0,32'h9a2);
   end
   aes_packet(0,32'h80000000,PLAINTEXT,1,32'h144);
   if (!DETERMINISTIC_KEY_TEST && lookups != 4) $fatal(1,"Expected four key requests, got %0d",lookups);
   if (engine_aes_starts != (DETERMINISTIC_KEY_TEST ? 4 : 5) ||
       engine_aes_replies != engine_aes_starts)
     $fatal(1,"AES engine dispatch/completion counts differ");
   if (DETERMINISTIC_KEY_TEST) begin
     if (!generated_key_ready)
       $fatal(1,"Deterministic key does not match independent SHA-256 oracle");
     boundary_roundtrip(0);
     boundary_roundtrip(1);
     boundary_roundtrip(15);
     boundary_roundtrip(16);
     boundary_roundtrip(17);
     boundary_roundtrip(1024);
     $display("LENOVO_DETERMINISTIC_AES_SPI_PASS");
   end
   $display("TPM2_ENCRYPTDECRYPT2_SPI_PASS");
 end else begin
   aes_packet(0,32'h80000000,PLAINTEXT,0,32'h143);
   if (lookups != 0) $fatal(1,"Disabled AES command issued key request");
 end
 passed=1;
 $display("TPM2_HASH_SPI_PASS"); $finish;
end
initial begin #50000000; $fatal(1,"SPI global timeout"); end
endmodule
