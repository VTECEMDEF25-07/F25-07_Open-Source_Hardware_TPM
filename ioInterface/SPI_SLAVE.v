module SPI_SLAVE
(
	input			clock,		// 50 MHz
	input			reset_n,
	
	output	reg		RX_valid,	// data valid pulse
	output	reg	[7:0]	RX_data,	// receive byte
	
	input			TX_valid,	// data valid pulse
	output			TX_request,	// request next byte
	output	reg		TX_received,	// ack
	input		[7:0]	TX_data,	// send byte
	
	input			SPI_clock,
	output			SPI_miso,
	input			SPI_mosi,
	input			SPI_cs_n
);
	
	reg	[2:0]	RX_bitCount;
	reg	[7:0]	RX_tempByte;
	reg	[7:0]	RX_byte;
	reg		RX_done0, RX_done1, RX_done2;
	
	// mosi
	always @(posedge SPI_clock, posedge SPI_cs_n)
	begin
		if (SPI_cs_n)
		begin
			RX_bitCount <= 1'b0;
			RX_done0 <= 1'b0;
		end else begin
			RX_bitCount <= RX_bitCount + 1'b1;
			
			RX_tempByte <= { RX_tempByte[6:0], SPI_mosi };
			
			if (RX_bitCount == 3'd7)
			begin
				RX_done0 <= 1'b1;
				RX_byte <= { RX_tempByte[6:0], SPI_mosi };
			end
			else if (RX_bitCount == 3'd2)
			begin
				RX_done0 <= 1'b0;
			end
		end
	end
	
	// RX data sync
	always @(posedge clock, negedge reset_n)
	begin
		if (!reset_n)
		begin
			RX_done1 <= 1'b0;
			RX_done2 <= 1'b0;
			RX_valid <= 1'b0;
			RX_data  <= 8'h00;
		end else begin
			RX_done1 <= RX_done0;
			RX_done2 <= RX_done1;
			
			if (RX_done2 == 1'b0 && RX_done1 == 1'b1)
			begin
				RX_valid <= 1'b1;
				RX_data <= RX_byte;
			end else begin
				RX_valid <= 1'b0;
			end
		end
	end
	
	
	reg	[7:0]	TX_preload;
	reg		TX_bit;
	reg	[2:0]	TX_counter, prev_TX_counter;
	reg	[2:0]	sync0_TX_counter, sync1_TX_counter;
	reg		TX_done, prev_TX_done;
	assign	TX_request = TX_done & ~prev_TX_done;
	
	
	reg	prev_SPI_clock;
	always @(posedge clock)
	begin
		prev_SPI_clock <= SPI_clock;
		prev_TX_done <= TX_done;
		
		sync0_TX_counter <= TX_counter;
		sync1_TX_counter <= sync0_TX_counter;
		
		if (sync1_TX_counter == 3'd4)
			TX_done <= 1'b1;
		else if (sync1_TX_counter == 3'd2)
			TX_done <= 1'b0;
		
		
	end
	
	wire		CLOCK_100;
	PLL_100	PLL0( .refclk(clock), .rst(~reset_n), .outclk_0(CLOCK_100) );
	
	wire	det_clock0, det_clock1, det_clock;
	
	DET_FF	det_ff0
	(
		CLOCK_100, reset_n, SPI_clock, det_clock0
	);
	DET_FF	det_ff1
	(
		CLOCK_100, reset_n, det_clock0, det_clock1
	);
	
	assign	det_clock = det_clock0 & ~det_clock1;
	
	reg	[8:0]	TX_temp;
	
	always @(posedge det_clock) // @(negedge SPI_clock) //, posedge test)
	begin
		if (  TX_counter == 3'd7) // TX_valid ) //
		begin
			TX_temp <= { TX_temp[7], TX_preload };
//			TX_received <= 1'b1;
		end else begin
			TX_temp <= TX_temp << 1'b1;
//			TX_received <= 1'b0;
		end
	end
	
	reg	prev_TX_valid;
	wire	neg_TX_valid;
	
	always @(posedge clock)
		prev_TX_valid <= TX_valid;
	assign	neg_TX_valid = ~TX_valid & prev_TX_valid;
	
	always @(posedge clock, negedge reset_n)
	begin
		if (!reset_n)
		begin
			TX_preload <= 8'd0;
			TX_received <= 1'b0;
		end else if (SPI_cs_n)
		begin
			TX_preload <= 8'd0;
			TX_received <= 1'b0;
		end else if (TX_valid)
		begin
			TX_preload <= TX_data;
			TX_received <= 1'b1;
		end else
			TX_received <= 1'b0;
	end
	
	
	always @(negedge SPI_clock, posedge SPI_cs_n)
	begin	if (SPI_cs_n)
		begin
			TX_counter <= 3'd5;
		end else begin
			TX_counter <= TX_counter - 3'd1;
		end
		
		
	end
		
	assign	SPI_miso = TX_temp[8];
	
endmodule

module	DET_FF
(
	input	clock, reset_n,
	input	D,
	output	Q
);
	
	reg	p, n;
	
	always @(posedge clock, negedge reset_n)
		if (!reset_n)
			p <= 1'b0;
		else
			p <= D ^ n;
	always @(negedge clock, negedge reset_n)
		if (!reset_n)
			n <= 1'b0;
		else
			n <= D ^ p;
	
	assign	Q = p ^ n;
endmodule
