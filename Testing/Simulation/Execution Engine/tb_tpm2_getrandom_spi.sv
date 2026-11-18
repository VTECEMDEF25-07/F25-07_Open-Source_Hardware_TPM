`timescale 1ns/1ns
module tb_tpm2_getrandom_spi #(parameter ENABLE_RANDOM_TEST = 1);
reg clk=0, clk100=0, rst=0, sck=0, cs=1, mosi=0;
wire miso, irq;
always #10 clk=~clk;
always #5 clk100=~clk100;
TPM_TOP #(.ENABLE_GETRANDOM(ENABLE_RANDOM_TEST)) dut(.CLOCK_50(clk),.CLOCK_100(clk100),.RESET_n(rst),
.SPI_CLOCK(sck),.SPI_CS_n(cs),.SPI_RST_n(rst),.SPI_MOSI(mosi),.SPI_MISO(miso),.SPI_PIRQ_n(irq));
reg [7:0] packet[0:511], response[0:511];
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
 for(integer base=0;base<count;base+=64)
  transfer(1,16'h0024,(count-base)>64?64:count-base,base);
end endtask
localparam [255:0] ABC=256'hba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad;
task automatic hash_abc;
begin
 write_one(16'h0018,8'h40);
 write_one(16'h0018,8'h40);
 {packet[0],packet[1],packet[2],packet[3],packet[4],packet[5],packet[6],packet[7],packet[8],packet[9],packet[10],packet[11],packet[12],packet[13],packet[14],packet[15],packet[16],packet[17],packet[18],packet[19],packet[20]}=168'h8001000000150000017d0003616263000b40000007;
 transfer(0,16'h0024,21);
 finish_cmd(52);
 if({response[0],response[1],response[2],response[3],response[4],response[5],response[6],response[7],response[8],response[9],response[10],response[11]} !== 96'h800100000034000000000020)
 $fatal(1,"Bad hash header %h",{response[0],response[1],response[2],response[3],response[4],response[5],response[6],response[7],response[8],response[9],response[10],response[11]});
 for(integer n=0;n<32;n=n+1) if(response[12+n]!==ABC[255-n*8 -:8]) $fatal(1,"Wrong digest byte %d",n);
 if({response[44],response[45],response[46],response[47],response[48],response[49],response[50],response[51]}!==64'h8024400000070000) $fatal(1,"Bad ticket");
end endtask
reg source_bit=0;
integer source_mode=0, source_index=0, random_starts=0, random_replies=0, rng_hashes=0;
wire [31:0] health_repetition, health_samples;
generate if(ENABLE_RANDOM_TEST) begin
 assign health_repetition=dut.rng.enabled.health.repetition;
 assign health_samples=dut.rng.enabled.health.samples;
 initial force dut.rng.enabled.entropy.sampled_bit = source_bit;
end else begin
 assign health_repetition=0; assign health_samples=0;
end endgenerate
always @(negedge clk) begin
 source_index=source_index+1;
 case(source_mode)
  0: source_bit=source_index[0];
  1: source_bit=0;
  2: source_bit=(source_index % 8 != 0);
 endcase
end
always @(posedge clk) if(rst) begin
 if(dut.ee.current_state_o == 12) random_starts<=random_starts+1;
 if(dut.ee.response_valid_o && dut.ee.random_active) begin
  if(dut.ee.current_state_o != 9) $fatal(1,"GetRandom bypassed engine completion");
  random_replies<=random_replies+1;
 end
 if(dut.shared_hash.grant[3]) rng_hashes<=rng_hashes+1;
 if(dut.random_request && (!dut.ee.random_active || dut.ee.current_state_o != 13))
  $fatal(1,"GetRandom request outside owner wait");
end
reg [255:0] last_random=0, observed_random=0;
integer random_successes=0;
task automatic getrandom(input integer requested,input integer size,input [15:0] tag,input [31:0] rc);
 integer count;
 begin
  write_one(16'h0018,8'h40); write_one(16'h0018,8'h40);
  {packet[0],packet[1]}=tag;
  {packet[2],packet[3],packet[4],packet[5]}=size;
  {packet[6],packet[7],packet[8],packet[9]}=32'h17b;
  {packet[10],packet[11]}=requested[15:0]; packet[12]=0;
  transfer(0,16'h0024,size);
  count=rc==0 ? 12+(requested>32 ? 32:requested) : 10;
  finish_cmd(count);
  if({response[0],response[1]} !== (rc==32'h1e ? 16'h00c4 :16'h8001) ||
     {response[2],response[3],response[4],response[5]} !== count ||
     {response[6],response[7],response[8],response[9]} !== rc)
    $fatal(1,"GetRandom header size=%0d rc=%h expected count=%0d rc=%h",
      {response[2],response[3],response[4],response[5]},
      {response[6],response[7],response[8],response[9]},count,rc);
  if(rc==0) begin
   if({response[10],response[11]} !== count-12) $fatal(1,"randomBytes.size mismatch");
   if(count==44) begin
    for(integer n=0;n<32;n=n+1) observed_random[255-n*8 -:8]=response[12+n];
    if(observed_random==0 || (random_successes>0 && observed_random==last_random))
     $fatal(1,"Missing or reused random output");
    last_random=observed_random; random_successes=random_successes+1;
   end
  end else if(dut.io.command_response_buffer.response_length_hold != 10)
    $fatal(1,"Error published random payload");
 end
endtask

// Read/discovery packets must retain their own address/length/response owner
// when interleaved with GetRandom and raw Hash on this same TPM_TOP instance.
integer mixed_pcr_responses=0;
task automatic pcr_discovery;
reg [199:0] capability_expected;
reg [7:0] expected[0:299];
begin
 write_one(16'h0018,8'h40);write_one(16'h0018,8'h40);
 for(integer i=0;i<22;i++)packet[i]=0;
 {packet[0],packet[1]}=16'h8001;packet[5]=22;packet[8]=1;packet[9]=8'h7a;
 packet[13]=5;packet[21]=1;
 transfer(0,16'h0024,22);finish_cmd(25);
 capability_expected=200'h80010000001900000000000000000500000001000b03ffffff;
 for(integer i=0;i<25;i++)if(response[i]!==capability_expected[199-i*8 -:8])
  $fatal(1,"Mixed GetCapability byte %0d",i);
 mixed_pcr_responses++;
 for(integer page=0;page<3;page++)begin
  write_one(16'h0018,8'h40);write_one(16'h0018,8'h40);
  for(integer i=0;i<20;i++)packet[i]=0;
  {packet[0],packet[1]}=16'h8001;packet[5]=20;packet[8]=1;packet[9]=8'h7e;
  packet[13]=1;packet[15]=8'h0b;packet[16]=3;
  for(integer i=page;i<3;i++)packet[17+i]=8'hff;
  transfer(0,16'h0024,20);finish_cmd(300);
  for(integer i=0;i<300;i++)expected[i]=0;
  {expected[0],expected[1]}=16'h8001;expected[4]=1;expected[5]=8'h2c;
  expected[17]=1;expected[19]=8'h0b;expected[20]=3;expected[21+page]=8'hff;
  expected[27]=8;
  for(integer i=0;i<8;i++)expected[29+i*34]=32;
  for(integer i=0;i<300;i++)if(response[i]!==expected[i])
   $fatal(1,"Mixed PCR_Read page %0d byte %0d expected %h got %h",page,i,expected[i],response[i]);
  mixed_pcr_responses++;
 end
end endtask

initial begin
 #3; rst=1; #7; rst=0; #200; rst=1; #1000;
 write_one(16'h0000,8'h02); transfer(1,16'h0000,1);
 if (response[0] !== 8'ha1) $fatal(1,"Locality 0 was not granted");
 if(ENABLE_RANDOM_TEST) getrandom(32,12,16'h8001,32'h100);
 repeat (4) begin
 write_one(16'h0018,8'h40);
 write_one(16'h0018,8'h40);
 {packet[0],packet[1],packet[2],packet[3],packet[4],packet[5],packet[6],packet[7],packet[8],packet[9],packet[10],packet[11]}=96'h80010000000c000001440000;
 transfer(0,16'h0024,10); packet[0]=0; packet[1]=0; transfer(0,16'h0024,2);
 finish_cmd(10);
 if({response[6],response[7],response[8],response[9]} !== 0) $fatal(1,"Startup rc %h",{response[6],response[7],response[8],response[9]});
 hash_abc();
 if(ENABLE_RANDOM_TEST) begin
  getrandom(32,12,16'h8001,0);
 end
 pcr_discovery();
 end
 if(ENABLE_RANDOM_TEST) begin
  getrandom(0,12,16'h8001,0);
  getrandom(1,12,16'h8001,0);
  getrandom(31,12,16'h8001,0);
  getrandom(33,12,16'h8001,0);
  getrandom(65535,12,16'h8001,0);
  getrandom(32,10,16'h8001,32'h1da);
  getrandom(32,11,16'h8001,32'h1da);
  getrandom(32,13,16'h8001,32'h95);
  getrandom(32,12,16'h8002,32'h1e);
  getrandom(32,12,16'h0000,32'h1e);
  // Real detector observes a stuck sampled source; no forced fault signal.
  fork
   getrandom(32,12,16'h8001,32'h101);
   begin wait(dut.random_request); @(negedge clk); source_mode=1; end
  join
  wait(dut.rng.health_fault); repeat(3) @(negedge clk);
  if(health_repetition < 31) $fatal(1,"No real repetition fault");
  getrandom(32,12,16'h8001,32'h101);
  source_mode=0; repeat(600) @(negedge clk);
  getrandom(32,12,16'h8001,32'h101);
  hash_abc();
  $display("GETRANDOM_REAL_RCT_PROPAGATION_PASS");
 end else getrandom(32,12,16'h8001,32'h143);
 $display("TPM2_HASH_SPI_ENGINE_ROUTE starts=%0d replies=%0d",engine_hash_starts,engine_hash_replies);
 if (engine_hash_starts != (ENABLE_RANDOM_TEST ? 5:4) || engine_hash_replies != (ENABLE_RANDOM_TEST ? 5:4))
   $fatal(1,"Wrong engine-owned SPI Hash count, starts=%0d replies=%0d",
          engine_hash_starts,engine_hash_replies);
 if(ENABLE_RANDOM_TEST) begin
  if(random_starts != random_replies || rng_hashes < 10) $fatal(1,"Owner/shared SHA counts wrong");
  $display("GETRANDOM_MIXED_ENGINE_SHA_PASS starts=%0d replies=%0d rng_hashes=%0d",random_starts,random_replies,rng_hashes);
  // Global reset clears health/DRBG/command ownership and reseeds.
  rst=0; repeat(4) @(negedge clk); source_mode=2; rst=1;
  wait(dut.rng.health_fault);
  if(health_samples != 0) $fatal(1,"APT did not finish window");
  if(health_repetition >= 31) $fatal(1,"Biased source hit RCT instead of APT");
  // Fault propagation also holds for the adaptive proportion detector.
  // Restart the normal host startup after reset before requesting random.
  write_one(16'h0000,8'h02);
  repeat(4) begin
   write_one(16'h0018,8'h40); write_one(16'h0018,8'h40);
   {packet[0],packet[1],packet[2],packet[3],packet[4],packet[5],packet[6],packet[7],packet[8],packet[9],packet[10],packet[11]}=96'h80010000000c000001440000;
   transfer(0,16'h0024,12); finish_cmd(10);
  end
  getrandom(32,12,16'h8001,32'h101);
  $display("GETRANDOM_REAL_APT_PROPAGATION_PASS");
  rst=0; repeat(4) @(negedge clk); source_mode=0; rst=1;
  write_one(16'h0000,8'h02);
  repeat(4) begin
   write_one(16'h0018,8'h40); write_one(16'h0018,8'h40);
   {packet[0],packet[1],packet[2],packet[3],packet[4],packet[5],packet[6],packet[7],packet[8],packet[9],packet[10],packet[11]}=96'h80010000000c000001440000;
   transfer(0,16'h0024,12); finish_cmd(10);
  end
  if(dut.rng.fault_o) $fatal(1,"Global reset did not clear source fault");
  // A reseeded deterministic source can repeat its first value after reset;
  // comparison across a reset is not a freshness requirement.
  random_successes=0;
  getrandom(32,12,16'h8001,0);
  hash_abc();
  $display("GETRANDOM_RESET_HEALTHY_RECOVERY_PASS");
 end
 if(mixed_pcr_responses!=16)$fatal(1,"Mixed PCR discovery did not finish");
 $display("GETRANDOM_PCR_READ_MIXED_PASS replies=%0d",mixed_pcr_responses);
 passed=1;
 $display("TPM2_GETRANDOM_SPI_PASS"); $finish;
end
initial begin #15000000; $fatal(1,"SPI global timeout"); end
endmodule
