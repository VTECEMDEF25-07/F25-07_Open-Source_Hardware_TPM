// Filename: tb_source_hold.sv
// Modules: tb_source_hold
// Authors: Project contributors; see Git history.
// Date: 2026-10-13
// General Description: Checks source hold behavior and reports failures.
// AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

`timescale 1ns/1ps
module tb_source_hold;
 reg clock_i=0; always #10 clock_i=~clock_i;
 reg reset_n_i=0,spi_clock_i=0,spi_cs_n_i=1,spi_mosi_i=0;
 wire spi_miso_o,interrupt_n_o;
 reg [63:0] response;
 reg [31:0] expected[0:7],held;
 string expected_file;
 reg stalled=0;
 integer k;
 keygen_demo_system dut(.temperatures_i(32'd0),.fan_status_i(32'd0),.fan_diagnostic_i(96'd0),.*);
 always @(posedge clock_i) begin
  if(reset_n_i && dut.source_reset_n && stalled && (!dut.core.generation_valid_i || dut.core.generation_data_i!==held))
   $fatal(1,"withdrawn or changed outstanding generation offer");
  stalled<=reset_n_i && dut.source_reset_n && dut.core.generation_valid_i && !dut.core.generation_ready_o;
  held<=dut.core.generation_data_i;
 end
 task frame(input[63:0]command);
  integer b;
  begin spi_cs_n_i=0;#200;response=0;
   for(b=63;b>=0;b=b-1)begin
    spi_mosi_i=command[b];#250;spi_clock_i=1;#100;
    response={response[62:0],spi_miso_o};#400;spi_clock_i=0;#250;
   end
   spi_cs_n_i=1;#200;
   if(response[63:32]!==32'ha5000000)$fatal(1,"bad SPI response");
  end
 endtask
 task write_reg(input[7:0]address,input[31:0]data);frame({8'd2,address,16'd0,data});endtask
 task tick;@(posedge clock_i);#1;endtask
 initial begin
  if(!$value$plusargs("EXPECTED=%s",expected_file))$fatal(1,"missing oracle");
  $readmemh(expected_file,expected);
  repeat(3)tick();@(negedge clock_i);reset_n_i=1;
  wait(dut.state_reg==1);write_reg(23,1);write_reg(4,1);write_reg(2,1);
  wait(dut.core.generation_valid_i);#1;
  if(dut.core.generation_data_i!==expected[0])$fatal(1,"first SHA word wrong");
  write_reg(11,1);
  repeat(20)tick();
  if(!dut.core.generation_valid_i || dut.core.index_reg!=0)$fatal(1,"pending word not retained");
  @(negedge clock_i);dut.core.allow_ready=1;tick();
  @(negedge clock_i);dut.core.allow_ready=0;
  repeat(20)tick();
  if(dut.core.index_reg!=1 || dut.core.generation_valid_i || dut.source_word_ready)
   $fatal(1,"pause did not follow exactly one accepted word");
  write_reg(11,0);wait(dut.core.generation_valid_i);#1;
  if(dut.core.generation_data_i!==expected[1])$fatal(1,"resume lost/duplicated word");
  write_reg(11,1);repeat(10)tick();
  @(negedge clock_i);dut.core.allow_ready=1;tick();
  repeat(10)tick();
  if(dut.core.index_reg!=2 || dut.core.generation_valid_i)$fatal(1,"ready-high pause consumed hidden words");
  write_reg(11,0);wait(dut.core_status_valid);#1;
  for(k=0;k<8;k=k+1)if(dut.receiver_data_reg[k]!==expected[k])$fatal(1,"replay word mismatch %0d",k);
  write_reg(2,2);wait(dut.state_reg==1);dut.core.allow_ready=0;
  write_reg(2,1);wait(dut.core.generation_valid_i);write_reg(11,1);
  @(negedge clock_i);reset_n_i=0;repeat(3)tick();
  @(negedge clock_i);reset_n_i=1;wait(dut.state_reg==1);
  if(dut.core.generation_valid_i)$fatal(1,"reset retained pending offer");
  $display("PASS SOURCE_HOLD actual_SPI outstanding_offer/one_transfer/pause/resume/SHA8/reset");$finish;
 end
 initial begin #3000000;$fatal(1,"timeout");end
endmodule
