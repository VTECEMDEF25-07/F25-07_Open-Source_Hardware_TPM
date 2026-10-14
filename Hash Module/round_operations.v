// SHA-256 Padding Module
// Takes 512-bit input of full or padded block
// Performs expansion to return 32-bit word outputs

module round_operations(
	input wire clk,
	input wire reset_n,
	
	input wire [31:0] word_in,
	input wire word_valid,
	input wire start,
	
	output reg [255:0] hash_out,
	output reg hash_valid,
	output reg busy
);

	reg [31:0] H [0:7];
	reg [31:0] a, b, c, d, e, f, g, h;
	reg [6:0] round_count;
	wire [31:0] T1, T2;
	
	integer i;
	
	///////////////////////////////////////////
	// functions for calculations
	/////////////////////////////////////////// 
	 
	// rotate right function 
	function [31:0] rotr; 
		input [31:0] x;
		input [4:0] n;
		begin
			rotr = (x >> n) | (x << (32-n));
		end
	endfunction
	
	// choice function
	function [31:0] ch;
		input [31:0] x, y, z;
		begin
			ch = (x & y) ^ (~x & z);
		end
	endfunction
	
	// majority function
	function [31:0] maj;
		input [31:0] x, y, z;
		begin
			maj = (x & y) ^ (x & z) ^ (y & z);
		end
	endfunction
	
	// uppercase sigma0 function
	function [31:0] sig0b;
		input [31:0] x;
		begin
			sig0b = rotr(x, 2) ^ rotr(x, 13) ^ rotr(x, 22);
		end
	endfunction
	
	// uppercase sigma1 function
	function [31:0] sig1b;
		input [31:0] x;
		begin
			sig1b = rotr(x, 6) ^ rotr(x, 11) ^ rotr(x, 25);
		end
	endfunction
	
	///////////////////////////////////////////
	// assign constants
	///////////////////////////////////////////

	// K constants
	reg [31:0] K [0:63];
	initial begin
      K[0] = 32'h428a2f98; K[1] = 32'h71374491; K[2] = 32'hb5c0fbcf; K[3] = 32'he9b5dba5;
      K[4] = 32'h3956c25b; K[5] = 32'h59f111f1; K[6] = 32'h923f82a4; K[7] = 32'hab1c5ed5;
      K[8] = 32'hd807aa98; K[9] = 32'h12835b01; K[10]= 32'h243185be; K[11]= 32'h550c7dc3;
      K[12]= 32'h72be5d74; K[13]= 32'h80deb1fe; K[14]= 32'h9bdc06a7; K[15]= 32'hc19bf174;
      K[16]= 32'he49b69c1; K[17]= 32'hefbe4786; K[18]= 32'h0fc19dc6; K[19]= 32'h240ca1cc;
      K[20]= 32'h2de92c6f; K[21]= 32'h4a7484aa; K[22]= 32'h5cb0a9dc; K[23]= 32'h76f988da;
      K[24]= 32'h983e5152; K[25]= 32'ha831c66d; K[26]= 32'hb00327c8; K[27]= 32'hbf597fc7;
      K[28]= 32'hc6e00bf3; K[29]= 32'hd5a79147; K[30]= 32'h06ca6351; K[31]= 32'h14292967;
      K[32]= 32'h27b70a85; K[33]= 32'h2e1b2138; K[34]= 32'h4d2c6dfc; K[35]= 32'h53380d13;
      K[36]= 32'h650a7354; K[37]= 32'h766a0abb; K[38]= 32'h81c2c92e; K[39]= 32'h92722c85;
		K[40]= 32'ha2bfe8a1; K[41]= 32'ha81a664b; K[42]= 32'hc24b8b70; K[43]= 32'hc76c51a3;
		K[44]= 32'hd192e819; K[45]= 32'hd6990624; K[46]= 32'hf40e3585; K[47]= 32'h106aa070;
		K[48]= 32'h19a4c116; K[49]= 32'h1e376c08; K[50]= 32'h2748774c; K[51]= 32'h34b0bcb5;
		K[52]= 32'h391c0cb3; K[53]= 32'h4ed8aa4a; K[54]= 32'h5b9cca4f; K[55]= 32'h682e6ff3;
		K[56]= 32'h748f82ee; K[57]= 32'h78a5636f; K[58]= 32'h84c87814; K[59]= 32'h8cc70208;
		K[60]= 32'h90befffa; K[61]= 32'ha4506ceb; K[62]= 32'hbef9a3f7; K[63]= 32'hc67178f2;
	end

	///////////////////////////////////////////
	// assign T1 and T2
	///////////////////////////////////////////
	assign T1 = h + sig1b(e) + ch(e, f, g) + K[round_count] + word_in;
	assign T2 = sig0b(a) + maj(a, b, c);
	
	always @(posedge clk or negedge reset_n) begin
		if (!reset_n) begin
			H[0] <= 32'h6a09e667;
			H[1] <= 32'hbb67ae85;
			H[2] <= 32'h3c6ef372;
			H[3] <= 32'ha54ff53a;
			H[4] <= 32'h510e527f;
			H[5] <= 32'h9b05688c;
			H[6] <= 32'h1f83d9ab;
			H[7] <= 32'h5be0cd19;
			
			a <= 32'b0;
			b <= 32'b0;
			c <= 32'b0;
			d <= 32'b0;
			e <= 32'b0;
			f <= 32'b0;
			g <= 32'b0;
			h <= 32'b0;
			
			round_count <= 7'b0;
			hash_out <= 256'b0;
			hash_valid <= 1'b0;
			busy <= 1'b0;	
		end

		else begin
			hash_valid <= 1'b0;
		
			if (start && !busy) begin
				a <= H[0];
				b <= H[1];
				c <= H[2];
				d <= H[3];
				e <= H[4];
				f <= H[5];
				g <= H[6];
				h <= H[7];
				round_count <= 7'b0;
				busy <= 1'b1;
			end
			else if (busy && word_valid) begin

				h <= g;
				g <= f;
				f <= e;
				e <= d + T1;
				d <= c;
				c <= b;
				b <= a;
				a <= T1 + T2;	

				if (round_count == 7'd63) begin
					H[0] <= H[0] + (T1 + T2);
					H[1] <= H[1] + a;
					H[2] <= H[2] + b;
					H[3] <= H[3] + c;
					H[4] <= H[4] + (d + T1);
					H[5] <= H[5] + e;
					H[6] <= H[6] + f;
					H[7] <= H[7] + g;

					hash_out <= {H[0] + (T1 + T2),
								 H[1] + a, 
								 H[2] + b, 
								 H[3] + c, 
								 H[4] + (d + T1), 
								 H[5] + e, 
								 H[6] + f, 
								 H[7] + g};

					hash_valid <= 1'b1;
					busy <= 1'b0;
				end

				else begin
					round_count <= round_count + 1'b1;
				end
			end
		end
	end
		
endmodule