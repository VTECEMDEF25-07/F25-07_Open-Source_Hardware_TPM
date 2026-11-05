// Testbench for SHA-256 Padding Module
// The input is 'abc'

`timescale 1ns/1ns

module tb_padding;

	reg clk;
   reg reset_n;
   reg [511:0] partial_data;
   reg [6:0] partial_bytes;
   reg partial_valid;
   reg [63:0] message_length;

   wire [511:0] block_out;
   wire block_valid;
   wire busy;

	padding dut (
		.clk(clk),
      .reset_n(reset_n),
      .partial_data(partial_data),
      .partial_bytes(partial_bytes),
      .partial_valid(partial_valid),
      .message_length(message_length),
      .block_out(block_out),
      .block_valid(block_valid),
      .busy(busy)
	);
	
	always begin
		#10;
		clk = ~clk;
   end
	
	initial begin
		clk = 0;
		reset_n = 0;
		
		partial_data = 512'b0;
		partial_bytes = 7'b0;
		partial_valid = 0;
		message_length = 64'b0;
		
		#20;
		reset_n = 1;
		
		#20;
		partial_data = 512'h616263;
		partial_bytes = 7'd3;
		partial_valid = 1;
		message_length = 64'd24;
		
		#20;
		partial_valid = 0;
		
	end
endmodule