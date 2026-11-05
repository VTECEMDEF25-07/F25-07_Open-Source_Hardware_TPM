// SHA-256 Input Buffer Module
// Takes an 8-bit input, appends to 512-bit message block
// Prepares message for padding
// Feeds into padding module


module input_buffer(
	input wire			 clk,
	input	wire			 reset_n,
	
	input wire [7:0] 	 data_in,
	input	wire			 data_valid,
	input wire			 message_end,
	
	output reg [511:0] block_out,		// output for complete 256-bit message block
	output reg			 block_valid,
	
	output reg [511:0] partial_data,	// output for partial blocks
	output reg [6:0]   partial_bytes,
	output reg			 partial_valid,
	
	output reg [63:0]  message_length
);

	reg [511:0] buffer;
	reg [6:0] byte_count;
	reg [63:0] length_count;
	
	always @(posedge clk or negedge reset_n) begin
		if (!reset_n) begin
			buffer         <= 512'b0;
			block_out      <= 512'b0;
			byte_count 	   <= 6'b0;
			block_valid    <= 1'b0;
			partial_data   <= 512'b0;
			partial_bytes  <= 7'b0;
			partial_valid  <= 1'b0;
			message_length <= 64'b0;
			length_count   <= 64'b0;
		end
		else begin
			block_valid   <= 1'b0;
			partial_valid <= 1'b0;
			
			if (data_valid) begin
				length_count <= length_count + 64'd8;
				
				if (byte_count == 6'd63) begin
					block_out <= {buffer[503:0], data_in}; // assign buffer to out, shift message left 8 bits, append new input
					buffer <= 512'b0;
					byte_count <= 6'b0;
					block_valid <= 1'b1;
				end
				else begin
					buffer <= {buffer[503:0], data_in}; // shift message left 8 bits, append new input
					byte_count <= byte_count + 1'b1;
				end
			end
			
			else if (message_end) begin
				partial_data <= buffer;
				partial_bytes <= byte_count;
				partial_valid <= 1'b1;
				message_length <= length_count;
				length_count <= 64'b0;
				buffer <= 512'b0;
				byte_count <= 7'b0;
			end
		end
	end
endmodule
