// spi_slave.v
// modules:
//	spi_slave
//	DET_FF
//
// Authors:
//	Ian Sizemore (idsizemore@vt.edu)
//
// Date: 11/6/25
//
// General Description:
//	This is the SPI serializer module, which handles the SPI protocol connection between
//	the Host System and the I/O module (specifically the transaction handler).

module spi_slave
(
	input			clock50_i,	// 50 MHz (sysclock, arbitrary)
	input			clock100_i,	// 100 MHz (used for sampling SPI, >60 MHz should work)
	input			reset_n_i,
	
	output	reg		RX_valid_o,	// data valid pulse
	output	reg	[7:0]	RX_data_o,	// receive byte
	
	input			TX_valid_i,	// data valid pulse
	output			TX_request_o,	// request next byte
	output	reg		TX_received_o,	// ack
	input		[7:0]	TX_data_i,	// send byte
	
	input			SPI_clock_i,
	output			SPI_miso_o,
	input			SPI_mosi_i,
	input			SPI_cs_n_i
);
	
	reg	[2:0]	RX_bitCount;
	reg	[7:0]	RX_tempByte;
	reg	[7:0]	RX_byte;
	reg		RX_done0, RX_done1, RX_done2;
	
	// mosi
	always @(posedge SPI_clock_i, posedge SPI_cs_n_i)
	begin
		if (SPI_cs_n_i)
		begin
			RX_bitCount <= 1'b0;
			RX_done0 <= 1'b0;
		end else begin
			RX_bitCount <= RX_bitCount + 1'b1;
			
			RX_tempByte <= { RX_tempByte[6:0], SPI_mosi_i };
			
			if (RX_bitCount == 3'd7)
			begin
				RX_done0 <= 1'b1;
				RX_byte <= { RX_tempByte[6:0], SPI_mosi_i };
			end
			else if (RX_bitCount == 3'd2)
			begin
				RX_done0 <= 1'b0;
			end
		end
	end
	
	// RX data sync
	always @(posedge clock50_i, negedge reset_n_i)
	begin
		if (!reset_n_i)
		begin
			RX_done1 <= 1'b0;
			RX_done2 <= 1'b0;
			RX_valid_o <= 1'b0;
			RX_data_o  <= 8'h00;
		end else begin
			RX_done1 <= RX_done0;
			RX_done2 <= RX_done1;
			
			if (RX_done2 == 1'b0 && RX_done1 == 1'b1)
			begin
				RX_valid_o <= 1'b1;
				RX_data_o <= RX_byte;
			end else begin
				RX_valid_o <= 1'b0;
			end
		end
	end
	
	
	reg	[7:0]	TX_preload;
	reg		TX_bit;
	reg	[2:0]	TX_counter, prev_TX_counter;
	reg	[2:0]	sync0_TX_counter, sync1_TX_counter;
	reg		TX_done, prev_TX_done;
	assign	TX_request_o = TX_done & ~prev_TX_done;
	
	
	reg	prev_SPI_clock;
	always @(posedge clock50_i)
	begin
		prev_SPI_clock <= SPI_clock_i;
		prev_TX_done <= TX_done;
		
		sync0_TX_counter <= TX_counter;
		sync1_TX_counter <= sync0_TX_counter;
		
		if (sync1_TX_counter == 3'd4)
			TX_done <= 1'b1;
		else if (sync1_TX_counter == 3'd2)
			TX_done <= 1'b0;
		
		
	end
	
	
	wire	det_clock0, det_clock1, det_clock;
	
	DET_FF	det_ff0
	(
		clock100_i, reset_n_i, SPI_clock_i, det_clock0
	);
	DET_FF	det_ff1
	(
		clock100_i, reset_n_i, det_clock0, det_clock1
	);
	
	assign	det_clock = det_clock0 & ~det_clock1;
	
	reg	[8:0]	TX_temp;
	
	// TX_temp is a shift register, which shifts out MISO bits.
	// det_clock has a posedge sooner than SPI_clock_i does, which allows
	// slow SPI master devices more time to capture the MISO signal
	// (think of a device with a long MISO setup requirement).
	// det_clock is a negedge detector of the SPI_clock_i, and is fed by
	// dual edge triggered flipflops
	always @(posedge det_clock)
	begin
		if (  TX_counter == 3'd7)
		begin
			TX_temp <= { TX_temp[7], TX_preload };
		end else begin
			TX_temp <= TX_temp << 1'b1;
		end
	end
	
	reg	prev_TX_valid;
	wire	neg_TX_valid;
	
	always @(posedge clock50_i)
		prev_TX_valid <= TX_valid_i;
	assign	neg_TX_valid = ~TX_valid_i & prev_TX_valid;
	
	// preload TX byte early to avoid timing issues
	always @(posedge clock50_i, negedge reset_n_i)
	begin
		if (!reset_n_i)
		begin
			TX_preload <= 8'd0;
			TX_received_o <= 1'b0;
		end else if (SPI_cs_n_i)
		begin
			TX_preload <= 8'd0;
			TX_received_o <= 1'b0;
		end else if (TX_valid_i)
		begin
			TX_preload <= TX_data_i;
			TX_received_o <= 1'b1;
		end else
			TX_received_o <= 1'b0;
	end
	
	
	always @(negedge SPI_clock_i, posedge SPI_cs_n_i)
	begin	if (SPI_cs_n_i)
		begin
			TX_counter <= 3'd5;
		end else begin
			TX_counter <= TX_counter - 3'd1;
		end
		
		
	end
		
	assign	SPI_miso_o = TX_temp[8];
	
endmodule


// Dual edge triggered flipflop
module	DET_FF
(
	input	clock_i, reset_n_i,
	input	D_i,
	output	Q_o
);
	
	reg	p, n;
	
	always @(posedge clock_i, negedge reset_n_i)
		if (!reset_n_i)
			p <= 1'b0;
		else
			p <= D_i ^ n;
	always @(negedge clock_i, negedge reset_n_i)
		if (!reset_n_i)
			n <= 1'b0;
		else
			n <= D_i ^ p;
	
	assign	Q_o = p ^ n;
endmodule
