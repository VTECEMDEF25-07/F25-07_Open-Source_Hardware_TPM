// tpm_spi_ctrl.v
// modules:
//	tpm_spi_ctrl
//	fsm_transWrite
//	fsm_transRead
//	fsm_stall
//	fsm_obtainHeader
//
// Authors:
//	Ian Sizemore (idsizemore@vt.edu)
//
// Date: 11/6/25
//
// General Description:
//	The I/O transaction handler. This module handles TPM transactions, and acts
//	as a bridge between the SPI serializer and the frs.
//	Transactions consist of a header which indicates transaction size, direction,
//	and address. After the header comes the transaction data, which follows the
//	size, direction, and address indicated by the header.

`define READ 1
`define WRITE 0

module	tpm_spi_ctrl
(
	input			clock,
	input			reset_n,
	
	input			SPI_CS_n,	// SPI chip select, active low
	input		[7:0]	SPI_RX_byte,	// SPI received byte, from spi serializer
	input			SPI_RX_valid,	// SPI received byte valid pulse, from spi serializer
	
	output		[7:0]	SPI_TX_byte,	// SPI transfer byte, to spi serializer
	input			SPI_TX_prepare,	// SPI transfer byte prepare pulse, from spi serializer
	output			SPI_TX_valid,	// SPI transfer byte valid pulse, to spi serializer
	input			SPI_TX_ack,	// SPI transfer byte ack pulse, from spi serializer
	
	output		[15:0]	FRS_addr,	// transfer byte address, to frs
	output			FRS_wren_n,	// transfer byte write enable, to frs
	output			FRS_rden_n,	// transfer byte read enable, to frs
	output		[7:0]	FRS_wrByte,	// transfer write byte
	input		[7:0]	FRS_rdByte,	// transfer read byte
	
	output		[15:0]	FRS_baseAddr,	// transfer byte base address, to frs
	output		[5:0]	CMD_size,	// transfer size, to frs
	output			FRS_req,	// transfer request, to frs
	
	output			updateAddr	// pulse to update address, to fifo buffer
						// utilized for timing during FIFO buffer transfers
);
	
	localparam
		Idle		= 0,	// Wait for chipselect
		ObtainHeader	= 1,	// Obtain the transaction header
		Stall		= 2,	// Stall (delay to allow frs time to process)
		Transaction	= 3;	// Read/write transfer
	reg	[1:0]	state, next_state;
	
	// state machine register
	always @(posedge clock, negedge reset_n)
	begin
		if (!reset_n)
			state <= Idle;
		else
			state <= next_state;
	end
	
	wire	headerComplete, stallComplete, transactionComplete;
	
	// state machine next state combinational logic
	always @*
	begin
		// reset when device is not selected
		if (SPI_CS_n)
			next_state = Idle;
		else case (state)
			
			// go to ObtainHeader when device is selected
			Idle:
				next_state = SPI_CS_n ? Idle : ObtainHeader;
			// go to Stall once the header has been obtained
			ObtainHeader:
				next_state = headerComplete ? Stall : ObtainHeader;
			// go to Transacition once stall is completed
			Stall:
				next_state = stallComplete ? Transaction : Stall;
			// wait for device to be deselected
			Transaction:
				next_state = Transaction; // transactionComplete ? Idle : Transaction;
		
		endcase
	end
	
	assign	FRS_req = state == Transaction;
	
	wire	[31:0]	commandHeader;
	
	// fsm to get the header
	fsm_obtainHeader	fsm_OH
	(
		clock, reset_n,
		state, SPI_RX_byte, SPI_RX_valid,
		commandHeader, headerComplete
	);
	
	// individual components of the transaction header
	wire		CMD_rw;
	wire	[23:0]	CMD_addr;
	wire	[3:0]	CMD_locality;
	
	assign	CMD_rw = commandHeader[31];
	assign	CMD_size = commandHeader[29:24];
	assign	CMD_addr = commandHeader[23:0];
	assign	CMD_locality = commandHeader[15:12];
	
	// fsm for stalling
	fsm_stall	fsm_S
	(
		clock, reset_n, state,
		CMD_addr, FRS_baseAddr,
		stallComplete
	);
	
	
	// read and write signals (multiplexed to outputs)
	wire		r_transactionComplete, w_transactionComplete;
	wire	[15:0]	r_FRS_addr, w_FRS_addr;
	wire		r_FRS_wren_n, w_FRS_wren_n;
	wire		r_FRS_rden_n, w_FRS_rden_n;
	wire	[7:0]	r_FRS_wrByte, w_FRS_wrByte;
	wire	[7:0]	r_SPI_TX_byte, w_SPI_TX_byte;
	wire		r_SPI_TX_valid, w_SPI_TX_valid;
	wire		r_updateAddr, w_updateAddr;
	
	// mutiplex between read and write signals
	assign	transactionComplete = CMD_rw ? r_transactionComplete : w_transactionComplete;
	assign	FRS_addr = CMD_rw ? r_FRS_addr : w_FRS_addr;
	assign	FRS_wren_n = state == Idle ? 1'b1 : CMD_rw ? r_FRS_wren_n : w_FRS_wren_n;
	assign	FRS_rden_n = state == Idle ? 1'b1 : CMD_rw ? r_FRS_rden_n : w_FRS_rden_n;
	assign	FRS_wrByte = CMD_rw ? r_FRS_wrByte : w_FRS_wrByte;
	assign	SPI_TX_valid = CMD_rw ? r_SPI_TX_valid : w_SPI_TX_valid;
	assign	updateAddr = CMD_rw ? r_updateAddr : w_updateAddr;
	
	assign	SPI_TX_byte = state == Transaction ? CMD_rw ? r_SPI_TX_byte : w_SPI_TX_byte : 8'h00;
	
	// fsm for read transactions
	fsm_transRead	fsm_TR
	(
		clock, reset_n, state, r_transactionComplete,
		CMD_rw, CMD_size, FRS_baseAddr,
		r_FRS_addr, r_FRS_wren_n, r_FRS_rden_n, r_FRS_wrByte, FRS_rdByte,
		r_SPI_TX_byte, SPI_TX_prepare, r_SPI_TX_valid, SPI_TX_ack, r_updateAddr
	);
	
	// fsm for write transactions
	fsm_transWrite	fsm_TW
	(
		clock, reset_n, state, w_transactionComplete,
		CMD_rw, CMD_size, FRS_baseAddr, 
		w_FRS_addr, w_FRS_wren_n, w_FRS_rden_n, w_FRS_wrByte, FRS_rdByte,
		w_SPI_TX_byte, SPI_TX_prepare, w_SPI_TX_valid, SPI_TX_ack,
		SPI_RX_byte, SPI_RX_valid, w_updateAddr
	);
	
endmodule


// substate module for Transaction (write)
module	fsm_transWrite
(
	input			clock,
	input			reset_n,
	input		[1:0]	ex_state,	// state from TPM_SPI_CTRL
	output			done,		// transaction complete signal
	
	input			CMD_rw,		// transaction direction
	input		[5:0]	CMD_size,	// transaction size
	input		[15:0]	FRS_baseAddr,	// transaction base address
	
	output	reg	[15:0]	FRS_addr,	// transaction address
	output			FRS_wren_n,	// transaction write enable
	output			FRS_rden_n,	// transaction read enable
	output	reg	[7:0]	FRS_wrByte,	// transaction write byte
	input		[7:0]	FRS_rdByte,	// transaction read byte
	
	output		[7:0]	SPI_TX_byte,	// SPI transfer byte
	input			SPI_TX_prepare,	// SPI transfer byte prepare pulse
	output	reg		SPI_TX_valid,	// SPI transfer byte valid pulse
	input			SPI_TX_ack,	// SPI transfer byte ack
	
	input		[7:0]	SPI_RX_byte,	// SPI receive byte
	input			SPI_RX_valid,	// SPI receive byte valid pulse
	
	output			addrUpdate	// update addr for fifo buffer timing
);
	
	localparam
		Idle		= 0,	// wait for transaction to start
		Setup		= 1,	// setup transaction regs
		TX_wait		= 2,	// wait for SPI_TX_prepare signal
		TX_send		= 3,	// SPI_TX_valid pulse
		TX_hold		= 4,	// wait for SPI_TX_ack
		UpdateAddr	= 5,	// update address
		RX_wait		= 6,	// wait for SPI_RX_valid
		RX_read		= 7,	// read RX byte from SPI
		Write0		= 8,	// write RX byte to FRS
		Write1		= 9,	// two cycle write
		Complete	= 10,	// transaction complete
		ex_Idle		= 0,
		ex_Transaction	= 3;
	reg	[3:0]	state, next_state;
	
	// state machine register
	always @(posedge clock, negedge reset_n)
	begin
		if (!reset_n)
			state <= Idle;
		else
			state <= next_state;
	end
	
	reg	[5:0]	nBytesWritten;
	
	// state machine transfer combinational logic
	always @*
	begin
		// return to idle when the external state is in idle
		if (ex_state == ex_Idle)
			next_state = Idle;
		else case (state)
			
			// go to TX_wait when the external state is in transaction, write
			Idle:
				next_state = ex_state == ex_Transaction && ~CMD_rw ? TX_wait : Idle;
			// go to RX_wait once SPI_RX_valid is received
			Setup:
				next_state = SPI_RX_valid ? RX_wait : Setup;
			// go to TX_send once SPI_TX_prepare is received
			TX_wait:
				next_state = SPI_TX_prepare ? TX_send : TX_wait;
			// go to TX_hold
			TX_send:
				next_state = TX_hold;
			// go to Setup once SPI_TX_ack is received
			TX_hold:
				next_state = SPI_TX_ack ? Setup : TX_hold;
			// go to RX_wait
			UpdateAddr:
				next_state = RX_wait;
			// go to RX_read once SPI_RX_valid is received
			RX_wait:
				next_state = SPI_RX_valid ? RX_read : RX_wait;
			// go to Write0
			RX_read:
				next_state = Write0;
			// go to Write1
			Write0:
				next_state = Write1;
			// go to Complete once number of written bytes == transaction size, otherwise UpdateAddr
			Write1:
				next_state = nBytesWritten == CMD_size ? Complete : UpdateAddr;
			// go to Idle once the external state is Idle
			Complete:
				next_state = ex_state == ex_Idle ? Idle : Complete;
		endcase
	end
	
	assign done = state == Complete;
	
	// these outputs are constant in a write transaction
	assign FRS_wren_n = 1'b0;
	assign FRS_rden_n = 1'b1;
	assign SPI_TX_byte = 8'hFF;
	
	// state machine sequential logic
	always @(posedge clock, negedge reset_n)
	begin
		// reset logic
		if (!reset_n)
		begin
			FRS_addr <= 16'h0001;
			FRS_wrByte <= 8'hFF;
			nBytesWritten <= 6'h3F;
			SPI_TX_valid <= 1'b0;
		end else case (state)
			
			// reset logic
			Idle:
			begin
				FRS_addr <= 16'h0001;
				FRS_wrByte <= 8'hFF;
				SPI_TX_valid <= 1'b0;
			end
			
			// setup logic
			Setup:
			begin
				FRS_addr <= FRS_baseAddr;
				nBytesWritten <= 6'h3F;
				SPI_TX_valid <= 1'b0;
			end
				
			// increment address
			UpdateAddr:
				FRS_addr <= FRS_addr + 16'd1;
			
			// pulse SPI_TX_valid
			TX_send:
				SPI_TX_valid <= 1'b1;
			
			RX_wait:
				SPI_TX_valid <= 1'b0;
				
			// move byte from SPI serializer to FRS ; increment nBytesWritten counter
			RX_read:
			begin
				nBytesWritten <= nBytesWritten + 6'd1;
				FRS_wrByte <= SPI_RX_byte;
			end
				
		endcase
	end

	assign	addrUpdate = state == UpdateAddr || state == TX_send;
	
endmodule


// substate module for Transaction (read)
module	fsm_transRead
(
	input			clock,
	input			reset_n,
	input		[1:0]	ex_state,	// state from TPM_SPI_CTRL
	output			done,		// transaction complete signa
	
	input			CMD_rw,		// transaction direction
	input		[5:0]	CMD_size,	// transaction size
	input		[15:0]	FRS_baseAddr,	// transaction base address
	
	output	reg	[15:0]	FRS_addr,	// transaction address
	output			FRS_wren_n,	// transaction write enable
	output			FRS_rden_n,	// transaction read enable
	output		[7:0]	FRS_wrByte,	// transaction write byte
	input		[7:0]	FRS_rdByte,	// transaction read byte
	
	output	reg	[7:0]	SPI_TX_byte,	// SPI transfer byte
	input			SPI_TX_prepare,	// SPI transfer byte prepare pulse
	output	reg		SPI_TX_valid,	// SPI transfer byte valid pulse
	input			SPI_TX_ack,	// SPI transfer byte ack
	
	output			addrUpdate	// udate addr for fifo buffer timing
);

	localparam
		Idle		= 0,	// wait for transaction to begin
		Setup		= 1,	// setup
		UpdateAddr	= 2,	// update address
		Read0		= 3,	// read byte from frs
		Read1		= 4,	// two cycle read
		TX_wait		= 5,	// wait for SPI_TX_prepare
		TX_send		= 6,	// send SPI_TX_valid
		TX_hold		= 7,	// wait for SPI_TX_ack
		Complete	= 8,	// transaction complete
		ex_Idle		= 0,
		ex_Transaction	= 3;
	reg	[3:0]	state, next_state;
	
	// state machine register
	always @(posedge clock, negedge reset_n)
	begin
		if (!reset_n)
			state <= Idle;
		else
			state <= next_state;
	end
	
	reg	[5:0]	nBytesRead;
	
	// destall bool used to return from SPI Wait state
	reg		destall;
	
	// state machine transfer combinational logic
	always @*
	begin
		// go to idle when external state is idle
		if (ex_state == ex_Idle)
			next_state = Idle;
		else case (state)
			
			// go to TX_wait if the external state is Transaction, read
			Idle:
				next_state = ex_state == ex_Transaction && CMD_rw ? TX_wait : Idle;
			// go to Read0
			Setup:
				next_state = Read0;
			// go to Complete if number of read bytes == transaction size, otherwise Read0
			UpdateAddr:
				next_state = nBytesRead == CMD_size ? Complete : Read0;
			// go to Read1
			Read0:
				next_state = Read1;
			// go to TX_wait
			Read1:
				next_state = TX_wait;
			// go to TX_send once SPI_TX_prepare is received
			TX_wait:
				next_state = SPI_TX_prepare ? TX_send : TX_wait;
			// go to TX_hold
			TX_send:
				next_state = TX_hold;
			// on receipt of SPI_TX_ack, go to Setup if destall is true, otherwise UpdateAddr
			TX_hold:
				next_state = SPI_TX_ack ? destall ? Setup : UpdateAddr : TX_hold;
			// go to Idle once external state is Idle
			Complete:
				next_state = ex_state == ex_Idle ? Idle : Complete;
		endcase
	end
	
	assign	done = state == Complete;
	
	// these outputs are constant during a read
	assign	FRS_wren_n = 1'b1;
	assign	FRS_rden_n = 1'b0;
	assign	FRS_wrByte = 8'hFF;
	
	
	// state machine sequetial logic
	always @(posedge clock, negedge reset_n)
	begin
		// reset logic
		if (!reset_n)
		begin
			nBytesRead <= 6'h3f;
			FRS_addr <= 16'h0001;
			SPI_TX_byte <= 8'hFF;
			SPI_TX_valid <= 1'b0;
			destall <= 1'b1;
		end else case (state)
			
			// reset logic
			Idle:
			begin
				nBytesRead <= 6'h3f;
				FRS_addr <= 16'h0001;
				SPI_TX_byte <= 8'hFF;
				SPI_TX_valid <= 1'b0;
				destall <= 1'b1;
			end
			
			// initialize regs
			Setup:
			begin
				FRS_addr <= FRS_baseAddr;
				destall <= 1'b0;
				SPI_TX_valid <= 1'b0;
				nBytesRead <= 6'h3f;
			end
			
			// send byte from frs to SPI serializer
			Read1:
				SPI_TX_byte <= FRS_rdByte;
			
			// send TX_valid, update address, increment bytes read counter
			TX_send:
			begin
				SPI_TX_valid <= 1'b1;
				FRS_addr <= FRS_addr + 16'd1;
				nBytesRead <= nBytesRead + 6'd1;
			end
			
			// deassert SPI_TX_valid
			UpdateAddr:
				SPI_TX_valid <= 1'b0;
			
		endcase
	end
	
	reg	prev_destall;
	always @(posedge clock)
		prev_destall <= destall;
	
	assign	addrUpdate = state == UpdateAddr || state == Setup;
		
endmodule
	


// substate module for Stall
// the current implementation inserts a SPI Wait state (stall) for every transaction
// if more wait states are required in future functionality, this fsm should be modified to
// allow additional stalling
module	fsm_stall
(
	input			clock,
	input			reset_n,
	input		[1:0]	ex_state,	// state from TPM_SPI_CTRL
	input		[23:0]	CMD_addr,	// transaction address
	output	reg	[15:0]	FRS_baseAddr,	// base address to frs
	output			done		// complete signal
);
	
	localparam
		Idle		= 0,	// wait for external state to be stall
		Configure	= 1,	// configure FRS_baseAddr (other work may be added later if more stall time is added)
		Complete	= 2,	// stall complete
		ex_Idle		= 0,
		ex_Stall	= 2;
	reg	[1:0]	state, next_state;
	
	// state machine register
	always @(posedge clock, negedge reset_n)
	begin
		if (!reset_n)
			state <= Idle;
		else
			state <= next_state;
	end
	
	// state machine transfer logic
	always @*
	begin
		// go to idle if external state is idle
		if (ex_state == ex_Idle)
			next_state = Idle;
		else case (state)
			
			// go to Configure if external state is Stall
			Idle:
				next_state = ex_state == ex_Stall ? Configure : Idle;
			// go to Complete
			Configure:
				next_state = Complete;
			// go to Idle once external state is Idle
			Complete:
				next_state = ex_state == ex_Idle ? Idle : Complete;
			
		endcase
	end

	assign done = state == Complete;
	
	// configure FRS_baseAddr
	always @(posedge clock, negedge reset_n)
	begin
		if (!reset_n)
			FRS_baseAddr <= 16'h0001;
		else if (state == Configure)
			FRS_baseAddr <= CMD_addr[15:0];
	end
	
endmodule

// substate module for ObtainHeader
module	fsm_obtainHeader
(
	input			clock,
	input			reset_n,
	input		[1:0]	ex_state,	// state from TPM_SPI_CTRL
	input		[7:0]	RX_byte,	// SPI_RX_byte
	input			RX_valid,	// SPI_RX_valid
	output	reg	[31:0]	commandHeader,	// resulting command header
	output			done		// complete signal
);
	
	localparam
		Idle		= 0,	// wait for external state to be ObtainHeader
		WaitRX		= 1,	// wait for RX_valid
		ReadByte	= 2,	// read RX_byte
		Shift		= 3,	// counter to keep track of read bytes
		Complete	= 4,	// done
		ex_Idle		= 0,
		ex_ObtainHeader	= 1;
	reg	[2:0]	state, next_state;
	
	// state machine register
	always @(posedge clock, negedge reset_n)
	begin
		if (!reset_n)
			state <= Idle;
		else
			state <= next_state;
	end
	
	wire	header_complete;
	assign	done = state == Complete;
	
	// state machine transfer combinational logic
	always @*
	begin
		// go to Idle when external state is Idle
		if (ex_state == ex_Idle)
			next_state = Idle;
		else case (state)
			
			// go to WaitRX once external state is ObtainHeader
			Idle:
				next_state = ex_state == ex_ObtainHeader ? WaitRX : Idle;
			// go to ReadByte once RX_valid is received
			WaitRX:
				next_state = RX_valid ? ReadByte : WaitRX;
			// stay in ReadByte while RX_valid is held, then go to Complete if header_complete is true, else go to Shift
			ReadByte:
				next_state = RX_valid ? ReadByte : header_complete ? Complete : Shift;
			// Go to WaitRX
			Shift:
				next_state = WaitRX;
			// go to Idle once external state is Idle
			Complete:
				next_state = ex_state == ex_Idle ? Idle : Complete;
		endcase
	end
	
	// a shift register (rather than a counter) is used to kep track of the number of read bytes
	reg	[3:0]	shift_tracker;
	assign	header_complete = shift_tracker[0];
	
	// state machine sequential logic
	always @(posedge clock, negedge reset_n)
	begin
		// reset logic
		if (!reset_n)
		begin
			commandHeader <= 32'h0;
			shift_tracker <= 4'h8;
		end else case (state)
			
			// reset logic
			Idle:
			begin
				commandHeader <= 32'h0;
				shift_tracker <= 4'h8;
			end
			
			// read byte into commandHeader
			ReadByte:
				commandHeader[7:0] <= RX_byte;
			
			// update shift tracker, shift commandHeader
			Shift:
			begin
				commandHeader <= commandHeader << 8;
				shift_tracker <= shift_tracker >> 1;
			end
		
		endcase
	end
	

endmodule
