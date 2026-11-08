// SHA-256 Padding Module
// Takes 512-bit input of full or padded block
// Performs expansion to return 32-bit word outputs

module message_schedule(
	input wire clk,
	input wire reset_n,
	input wire [511:0] block_in,
	input wire block_valid,
	
	output reg [31:0] word_out,
	output reg [6:0] word_index,
	output reg word_valid,
	output reg schedule_done,
	output reg busy
);

	reg [31:0] W [0:63];
	reg [6:0] count;
	reg [6:0] output_count;
	reg output_phase;
	
	integer i;

	// functions for calculations
	 
	// right rotate function
	function [31:0] rotr; 
		input [31:0] x;
		input [4:0] n;
		begin
			rotr = (x >> n) | (x << (32-n));
		end
	endfunction
	
	// lowercase sigma0 function
	function [31:0] sig0s;
		input [31:0] x; 
		begin
			sig0s = rotr(x, 7) ^ rotr(x, 18) ^ (x >> 3);
		end
	endfunction
	
	// lowercase sigma1 function
	function [31:0] sig1s;
		input [31:0] x;
		begin
			sig1s = rotr(x, 17) ^ rotr(x, 19) ^ (x >> 10);
		end
	endfunction
	
	
	always @(posedge clk or negedge reset_n) begin
		if (!reset_n) begin
			word_out 		<= 32'b0;
			word_index  	<= 7'b0;
			word_valid  	<= 1'b0;
			schedule_done 	<= 1'b0;
			busy 				<= 1'b0;
			count 			<= 7'b0;
			output_count   <= 7'b0;
			output_phase   <= 1'b0;
			
			for (i = 0; i < 64; i = i + 1) begin
				W[i] <= 32'b0;
			end
			
		end
		
		else begin
			word_valid <= 1'b0;
			schedule_done <= 1'b0;
			
			if (block_valid && !busy) begin
				for (i = 0; i < 16; i = i + 1) begin
					W[i] <= block_in[511 - (i * 32) -: 32];
				end
				count <= 7'd16;
				output_count <= 7'b0;
				output_phase <= 1'b0;
				busy <= 1'b1;
			end 
			else if (busy && !output_phase) begin
				if (count < 7'd64) begin
					W[count] <= sig1s(W[count - 2]) + W[count - 7] + sig0s(W[count - 15]) + W[count - 16];
					count <= count + 1'b1;
				end
				else begin
					output_phase <= 1'b1;
					output_count <= 7'b0;
				end
			end
			else if (busy && output_phase) begin
				word_out <= W[output_count];
				word_index <= output_count;
				word_valid <= 1'b1;
				
				if (output_count == 7'd63) begin
					busy <= 1'b0;
					output_phase <= 1'b0;
					output_count <= 7'b0;
					schedule_done <= 1'b1;
				end
				else begin
					output_count <= output_count + 1'b1;
				end
			end
		end
	end
	
endmodule