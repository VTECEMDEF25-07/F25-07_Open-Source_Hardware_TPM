// Testbench for SHA-256 Message Schedule Module
// The input is 'abc'

`timescale 1ns/1ns

module tb_message_schedule;

	reg clk;
	reg reset_n;
	reg [511:0] block_in;
	reg block_valid;
	
	wire [31:0] word_out;
	wire [6:0] word_index;
	wire word_valid;
	wire schedule_done;
	wire busy;
	
	message_schedule dut (
		.clk(clk),
      .reset_n(reset_n),
      .block_in(block_in),
      .block_valid(block_valid),
      .word_out(word_out),
      .word_index(word_index),
      .word_valid(word_valid),
      .schedule_done(schedule_done),
      .busy(busy)
	);
	
	always begin
		#10;
		clk = ~clk;
   end
	
	initial begin
		clk = 0;
		reset_n = 0;
		block_in = 512'b0;
		block_valid = 0;
		
		#20;
		reset_n = 1;
		
		#20;
		block_in = {
		32'h61626380,
		32'h0,
		32'h0,
		32'h0,
		32'h0,
		32'h0,
		32'h0,
		32'h0,
		32'h0,
		32'h0,
		32'h0,
		32'h0,
		32'h0,
		32'h0,
		32'h0,
		32'h00000018};
		block_valid = 1;
		
		#20;
		block_valid = 0;
		
	end
endmodule
		