// SHA-256 Padding Module
// Takes 512-bit input of partial data block, numbers of partial bytes, and message length
// Checks if message should be one block or two
// Appends a 1 and zeros to pad the message to 512 bits
// Returns block or blocks after padding

module padding(
	input wire			 clk,
	input wire			 reset_n,
	
	input wire [511:0] partial_data,
	input wire [6:0]   partial_bytes,
	input wire			 partial_valid,
	input wire [63:0]  message_length,
	
	output reg [511:0] block_out,
	output reg			 block_valid,
	output wire			 busy
);

	reg pending_length_block;
	reg [63:0] saved_length;
	
	wire [511:0] aligned_data;
	wire [511:0] padding_bit;
	
	assign aligned_data = partial_data << ((64 - partial_bytes) * 8); // moves message bytes 
	assign padding_bit = 512'h80 << ((63 - partial_bytes) * 8);
	assign busy = pending_length_block;
	
	always @(posedge clk or negedge reset_n) begin
		if (!reset_n) begin
			block_out <= 512'b0;
			block_valid <= 1'b0;
			pending_length_block <= 1'b0;
			saved_length <= 64'b0;
		end
		else begin
			block_valid <= 1'b0;
			
			if (pending_length_block) begin
				block_out <= {448'b0, saved_length};
				block_valid <= 1'b1;
				pending_length_block <= 1'b0;
			end
			else if (partial_valid && partial_bytes <= 7'd63) begin
				saved_length <= message_length;
				
				if (partial_bytes <= 7'd55) begin
					block_out <= aligned_data | padding_bit | {448'b0, message_length};
					block_valid <= 1'b1;
				end
				else begin
					block_out <= aligned_data | padding_bit;
					block_valid <= 1'b1;
					pending_length_block <= 1'b1;
				end
			end
		end
	end

endmodule