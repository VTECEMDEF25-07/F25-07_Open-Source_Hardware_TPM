// Testbench for SHA-256 Input Buffer Module
// The input is 'abc'

`timescale 1ns/1ns

module tb_input_buffer;

	reg clk;
	reg reset_n;
	reg [7:0] data_in;
	reg data_valid;
	reg message_end;
	
	wire [511:0] block_out;
	wire block_valid;
	wire [511:0] partial_data;
	wire [6:0] partial_bytes;
	wire partial_valid;
	wire [63:0] message_length;
	
	input_buffer dut (
		.clk(clk),
      .reset_n(reset_n),
      .data_in(data_in),
      .data_valid(data_valid),
      .message_end(message_end),
      .block_out(block_out),
      .block_valid(block_valid),
      .partial_data(partial_data),
      .partial_bytes(partial_bytes),
      .partial_valid(partial_valid),
      .message_length(message_length)
	);
	 
	always begin
		#10;
		clk = ~clk;
   end
	
	initial begin
		clk = 0;
		reset_n = 0;
		data_in = 8'b0;
		data_valid = 0;
		message_end = 0;
		
		#20;
		reset_n = 1;
		
		#20;
		data_in = 8'h61; // 'a'
		data_valid = 1;
		
		#20;
		data_in = 8'h62; // 'b'
		
		#20;
		data_in = 8'h63; // 'c'
		
		#20;
		data_valid = 0;
		message_end = 1;
		
		#20;
		message_end = 0;
	end
endmodule
		