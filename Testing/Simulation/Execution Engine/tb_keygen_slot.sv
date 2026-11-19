`timescale 1ns/1ps
// Public directed fixtures only. No production key export or stimulus fallback.
module tb_keygen_slot #(parameter IP_TYPE=0, parameter TEST_CASE=0);
 reg clk=0; always #5 clk=~clk;
 reg rst=0, req=0, allow=1, ack=0, release_slot=0;
 reg [1:0] profile=0; reg [31:0] id=32'h1234;
 reg [7:0] address=0;
 reg results=1, ownership=1, terminal=1, fault=0, silent=0, word_enable=1;
 wire ready,busy,done,valid,open_source,grant_source,close_source,closed_source;
 wire [3:0] code; wire [31:0] done_id,data,word_data;
 wire [1:0] kind; wire [7:0] words;
 wire lifecycle_word_ready;
 wire word_valid,word_ready,source_fault,kg_timeout,source_timeout,random_request;
 wire [31:0] health_repetition; wire detector_fault;
 wire [255:0] random_data; wire random_valid,real_fault;
 assign word_ready=lifecycle_word_ready && word_enable;
 reg [255:0] mock_data=0; reg mock_valid=0;
 reg host_req=0,host_commit=0; wire host_wait,host_valid,host_fault; wire [255:0] host_data;
 reg [31:0] stimulus[0:383], expected[0:128];
 integer cursor=0,cycles=0,checks=0,draws=0,latency=0;
 string stimulus_path,expected_path;
 integer stimulus_fd,expected_fd;
 reg passed=0;reg stuck=0;
 always @(negedge clk) if(TEST_CASE==1) results=(cycles%7<4);
 execution_engine_keygen #(.ENABLE(1),.IP_TYPE(IP_TYPE),.WAIT_LIMIT(TEST_CASE==1 ? 900000000 : 100000)) dut (
 .clock_i(clk),.reset_n_i(rst),.request_valid_i(req),.request_ready_o(ready),.profile_i(profile),.id_i(id),.allow_i(allow),.busy_o(busy),
 .completion_valid_o(done),.completion_ready_i(ack),.completion_code_o(code),.completion_id_o(done_id),
 .release_i(release_slot),.slot_valid_o(valid),.slot_type_o(kind),.slot_words_o(words),.private_address_i(address),.private_data_o(data),
 .result_enable_i(results),.ownership_enable_i(ownership),.terminal_enable_i(terminal),
 .source_open_o(open_source),.source_grant_i(grant_source),.source_close_o(close_source),.source_closed_i(closed_source),
 .source_word_i(word_data),.source_valid_i(word_valid && word_enable),.source_ready_o(lifecycle_word_ready),.source_fault_i(source_fault),.timeout_o(kg_timeout));
 rng_word_service #(.WAIT_LIMIT(20000)) service (
 .clock_i(clk),.reset_n_i(rst),.random_i(random_data),.random_valid_i(random_valid),.fault_i(fault || real_fault),
 .random_request_o(random_request),.timeout_o(source_timeout),.key_open_i(open_source),.key_grant_o(grant_source),
 .key_close_i(close_source),.key_closed_o(closed_source),.word_o(word_data),.word_valid_o(word_valid),.word_ready_i(word_ready),.key_fault_o(source_fault),
 .host_request_i(host_req),.host_commit_i(host_commit),.host_timeout_i(kg_timeout),.host_wait_o(host_wait),
 .host_random_o(host_data),.host_valid_o(host_valid),.host_fault_o(host_fault));
 generate if(TEST_CASE>=2) begin: real_source
   wire [7:0] hdata; wire hv,hl,hr,dv; wire [255:0] digest;
   reg sample=0; always @(negedge clk) sample<=stuck ? 1'b0 : !sample;
   phase_one_rng #(.ENABLE(1)) rng (.clk(clk),.rst_n(rst),.request_i(random_request),.timeout_i(source_timeout),
    .random_o(random_data),.valid_o(random_valid),.fault_o(real_fault),.hash_data_o(hdata),.hash_valid_o(hv),.hash_last_o(hl),
    .hash_ready_i(hr),.digest_i(digest),.digest_valid_i(dv));
   assign health_repetition=rng.enabled.health.repetition;
   assign detector_fault=rng.health_fault;
   initial force rng.enabled.entropy.sampled_bit=sample;
   hash_subsystem sha (.clk_i(clk),.reset_n_i(rst),.raw_request_i(1'b0),.raw_data_i(8'd0),.raw_valid_i(1'b0),.raw_end_i(1'b0),.raw_digest_ready_i(1'b1),
    .hmac_start_en_i(1'b0),.hmac_key_data_i(8'd0),.hmac_key_valid_i(1'b0),.hmac_key_end_i(1'b0),.hmac_message_data_i(8'd0),
    .hmac_message_valid_i(1'b0),.hmac_message_end_i(1'b0),.hmac_digest_ready_i(1'b1),
    .pcr_extend_start_en_i(1'b0),.pcr_extend_index_i(5'd0),.pcr_measurement_i(256'd0),.pcr_read_index_i(5'd0),
    .rng_hash_msg_data_i(hdata),.rng_hash_msg_valid_i(hv),.rng_hash_msg_last_i(hl),.rng_hash_msg_ready_o(hr),
    .rng_hash_digest_o(digest),.rng_hash_digest_valid_o(dv));
   always @(posedge clk) if(rst) begin
    if(rng.enabled.entropy_valid && rng.health_ready && !real_fault && rng.enabled.drbg.entropy_needed)
      $display("PUBLIC_ENTROPY %h",rng.enabled.entropy_data);
    if(random_valid) $display("PUBLIC_DRBG %h",random_data);
   end
 end else begin: mock_source
   assign random_data=mock_data; assign random_valid=mock_valid; assign real_fault=0; assign health_repetition=0; assign detector_fault=0;
   always @(posedge clk) begin
    mock_valid<=0;
    if(!rst) begin cursor<=0; latency<=0; end
    else if(random_request && !silent) begin
     if(latency==5) begin
      for(integer j=0;j<8;j=j+1) mock_data[255-32*j -:32]<=TEST_CASE==1 ? stimulus[cursor+j] : 32'h10100000+cursor+j;
      cursor<=cursor+8; mock_valid<=1; latency<=0;
     end else latency<=latency+1;
    end else latency<=0;
   end
 end endgenerate
 always @(posedge clk) if(rst) begin
   cycles<=cycles+1;
   if(TEST_CASE==1 && dut.status_valid && dut.status!=0) $fatal(1,"RSA core terminal error %0d draws=%0d results=%0d",dut.status,draws,dut.count);
   if(TEST_CASE==1 && dut.failed) $fatal(1,"RSA lifecycle failed draws=%0d results=%0d",draws,dut.count);
   if(TEST_CASE==1 && word_valid && word_ready && draws>=384) $fatal(1,"RSA public fixture exhausted");
   if(TEST_CASE==1 && cycles>0 && cycles%10000000==0) begin
    $display("KEYGEN_PROGRESS cycles=%0d draws=%0d results=%0d",cycles,draws,dut.count);$fflush();
   end
   if(word_valid && word_ready) draws<=draws+1;
   if(!valid && (data!==0 || words!==0 || kind!==0)) $fatal(1,"partial private visibility");
   if(valid && (!dut.owned || dut.outcome!=0 || !closed_source)) $fatal(1,"publication without successful terminal and source close");
   if(valid && ready) $fatal(1,"occupied slot admitted reuse");
 end
 task tick; @(posedge clk); #1; endtask
 task reset_all;
  @(negedge clk); rst=0; req=0;ack=0;release_slot=0;fault=0;silent=0;host_req=0;host_commit=0;
  results=1;ownership=1;terminal=1;allow=1;draws=0;stuck=0;word_enable=1;
  repeat(3)tick(); @(negedge clk);rst=1; wait(ready); #1;
  for(integer j=0;j<129;j=j+1) if(dut.slot[j]!==0) $fatal(1,"reset failed full scrub");
 endtask
 task launch(input [1:0] mode);
  wait(ready); @(negedge clk);profile=mode;id=32'h1234;req=1;tick();@(negedge clk);req=0;profile=3;id=32'hffffffff;
 endtask
 task finish_failure(input [3:0] expected_code=4'd2);
  wait(done);#1;
  if(code!==expected_code || valid || done_id!=32'h1234) $fatal(1,"fault/denial published success");
  for(integer j=0;j<129;j=j+1) if(dut.slot[j]!==0) $fatal(1,"failure failed full scrub");
  repeat(3)tick();if(!done) $fatal(1,"completion not held");
  @(negedge clk);ack=1;tick();@(negedge clk);ack=0;checks=checks+1;
 endtask
 task finish_success(input integer count);
  wait(done);#1;
  if(code!==0 || !valid || words!=count || done_id!=32'h1234 || kind!=(count==4 ? 0 : count==8 ? 1 : 2)) $fatal(1,"slot metadata/completion");
  for(integer j=0;j<count;j=j+1) begin
   address=j;#1;
   if(TEST_CASE<2 && data!==(TEST_CASE==1 ? expected[j] : 32'h10100000+j)) $fatal(1,"independent result mismatch at %0d",j);
   if(TEST_CASE>=2) $display("PUBLIC_SLOT %0d %h",j,data);
  end
  repeat(5)tick();if(!done || ready) $fatal(1,"held completion/busy");
  @(negedge clk);req=1;tick();if(ready || !valid) $fatal(1,"busy request accepted");@(negedge clk);req=0;ack=1;tick();@(negedge clk);ack=0;
  if(ready || !valid) $fatal(1,"slot lifetime ended with completion");
  @(negedge clk);release_slot=1;#1;if(valid || data!=0) $fatal(1,"release visibility");tick();@(negedge clk);release_slot=0;
  repeat(5)tick();if(ready) $fatal(1,"reuse before scrub");wait(ready);#1;
  for(integer j=0;j<129;j=j+1) if(dut.slot[j]!==0) $fatal(1,"release failed full scrub");
  checks=checks+1;
 endtask
 initial begin
  if(TEST_CASE==1) begin
   if(!$value$plusargs("STIMULUS=%s",stimulus_path) || !$value$plusargs("EXPECTED=%s",expected_path)) $fatal(1,"public fixtures required");
   stimulus_fd=$fopen(stimulus_path,"r");expected_fd=$fopen(expected_path,"r");
   if(!stimulus_fd || !expected_fd) $fatal(1,"missing fixture file");
   $fclose(stimulus_fd);$fclose(expected_fd);
   $readmemh(stimulus_path,stimulus);$readmemh(expected_path,expected);
  end
  reset_all();
  if(TEST_CASE==1) begin ownership=0;terminal=0;launch(2);wait(dut.ownership_ready);repeat(37)tick();@(negedge clk);ownership=1;wait(dut.status_valid);repeat(13)tick();@(negedge clk);terminal=1;finish_success(129);if(draws!=384) $fatal(1,"RSA stream consumption");end
  else if(TEST_CASE==2) begin launch(1);finish_success(8);end
  else if(TEST_CASE==3) begin
   for(integer phase=0;phase<4;phase=phase+1) begin
    reset_all();results=0;ownership=0;terminal=0;launch(1);
    if(phase==0) wait(dut.result_valid);
    else begin results=1;wait(dut.ownership_ready);end
    if(phase>=2) begin ownership=1;wait(dut.status_valid);end
    @(negedge clk);stuck=1;
    if(phase==3) begin
     // At repetition29, terminal acceptance, source release and publication
     // are the next three edges. The third raw sample must reject publication.
     wait(health_repetition==29);@(negedge clk);terminal=1;
     wait(real_fault);
     if(!close_source || !closed_source) $fatal(1,"health failure missed intended publication edge");
     tick();if(valid || dut.published || !detector_fault) $fatal(1,"raw health failure published a slot");
    end
    wait(real_fault);results=1;ownership=1;terminal=1;finish_failure();
   end
   reset_all();launch(0);finish_success(4);
  end
  else begin
   allow=0;launch(0);finish_failure(9);if(cursor!=0) $fatal(1,"denied RNG activity");
   allow=1;launch(3);finish_failure(1);if(cursor!=0) $fatal(1,"invalid RNG activity");
   for(integer m=0;m<2;m=m+1) begin
    reset_all();results=0;ownership=0;terminal=0;launch(m);
    wait(dut.result_valid);repeat(7)tick();if(valid || done) $fatal(1,"result stall publication");
    @(negedge clk);results=1;wait(dut.ownership_ready);repeat(7)tick();if(valid || done) $fatal(1,"ownership stall publication");
    @(negedge clk);ownership=1;wait(dut.status_valid);repeat(7)tick();if(valid || done) $fatal(1,"terminal stall publication");
    @(negedge clk);terminal=1;finish_success(m==0 ? 4 : 8);
   end
   // Fault at every transfer/commit boundary, including after provisional ownership.
   for(integer boundary=0;boundary<7;boundary=boundary+1) begin
    reset_all();ownership=0;terminal=0;launch(1);
    case(boundary)
     0: wait(word_valid && word_ready);
     1: wait(draws==7 && word_valid);
     2: wait(dut.count==7 && dut.result_valid);
     3: wait(dut.ownership_ready);
     4: begin wait(dut.ownership_ready);@(negedge clk);ownership=1;wait(dut.owned);end
     5: begin wait(dut.ownership_ready);@(negedge clk);ownership=1;wait(dut.status_valid);end
     6: begin wait(dut.ownership_ready);@(negedge clk);ownership=1;terminal=1;wait(close_source && closed_source);end
    endcase
    @(negedge clk);fault=1;ownership=1;terminal=1;finish_failure();
   end
   reset_all();silent=1;launch(0);finish_failure();if(!source_timeout) $fatal(1,"source watchdog absent");
   for(integer phase=0;phase<4;phase=phase+1) begin
    reset_all();
    if(phase==1) results=0;
    if(phase==2) ownership=0;
    if(phase==3) terminal=0;
    launch(1);
    if(phase==0) begin wait(draws==7);@(negedge clk);word_enable=0;end
    wait(kg_timeout);finish_failure();
   end
   // Reset during reservation, generation, result, ownership, terminal and held completion.
   for(integer phase=0;phase<8;phase=phase+1) begin
    reset_all();ownership=0;terminal=0;results=0;launch(1);
    case(phase)
     0: wait(open_source);
     1: wait(word_valid);
     2: wait(dut.result_valid);
     3: begin results=1;wait(dut.ownership_ready);end
     4: begin results=1;ownership=1;wait(dut.status_valid);end
     5: begin results=1;ownership=1;terminal=1;wait(done);end
     6: begin results=1;ownership=1;terminal=1;wait(close_source);end
     7: begin results=1;ownership=1;terminal=1;wait(close_source && closed_source);end
    endcase
    reset_all();if(done || valid) $fatal(1,"stale reset completion");checks=checks+1;
   end
   launch(0);finish_success(4);
  end
  passed=1;$display("KEYGEN_SLOT_PASS case=%0d backend=%0d checks=%0d draws=%0d cycles=%0d",TEST_CASE,IP_TYPE,checks,draws,cycles);$finish;
 end
 initial begin #(64'd90000000000); $fatal(1,"bounded test deadline");end
endmodule

