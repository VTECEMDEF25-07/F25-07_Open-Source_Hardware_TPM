`define READ 1
`define WRITE 0

module	TPM_SPI_CTRL
(
	input			clock,
	input			reset_n,
	
	input			SPI_CS_n,
	input		[7:0]	SPI_RX_byte,
	input			SPI_RX_valid,
	
	output		[7:0]	SPI_TX_byte,
	input			SPI_TX_prepare,
	output			SPI_TX_valid,
	input			SPI_TX_ack,
	
	output		[15:0]	FRS_addr,
	output			FRS_wren_n,
	output			FRS_rden_n,
	output		[7:0]	FRS_wrByte,
	input		[7:0]	FRS_rdByte,
	
	output		[15:0]	FRS_baseAddr,
	output		[5:0]	CMD_size,
	output			FRS_req,
	
	output			updateAddr
);
	
	localparam
		Idle		= 0,
		ObtainHeader	= 1,
		Stall		= 2,
		Transaction	= 3;
	reg	[1:0]	state, next_state;
	
	always @(posedge clock, negedge reset_n)
	begin
		if (!reset_n)
			state <= Idle;
		else
			state <= next_state;
	end
	
	wire	headerComplete, stallComplete, transactionComplete;
	
	always @*
	begin
		if (SPI_CS_n)
			next_state = Idle;
		else case (state)
			
			Idle:
				next_state = SPI_CS_n ? Idle : ObtainHeader;
			ObtainHeader:
				next_state = headerComplete ? Stall : ObtainHeader;
			Stall:
				next_state = stallComplete ? Transaction : Stall;
			Transaction:
				next_state = Transaction; // transactionComplete ? Idle : Transaction;
		
		endcase
	end
	
	assign	FRS_req = state == Transaction;
	
	wire	[31:0]	commandHeader;
	
	fsm_obtainHeader	fsm_OH
	(
		clock, reset_n,
		state, SPI_RX_byte, SPI_RX_valid,
		commandHeader, headerComplete
	);
	
	wire		CMD_rw;
//	wire	[5:0]	CMD_size;
	wire	[23:0]	CMD_addr;
	wire	[3:0]	CMD_locality;
//	wire	[15:0]	FRS_baseAddr;
	
	assign	CMD_rw = commandHeader[31];
	assign	CMD_size = commandHeader[29:24];
	assign	CMD_addr = commandHeader[23:0];
	assign	CMD_locality = commandHeader[15:12];
	
	fsm_stall	fsm_S
	(
		clock, reset_n, state,
		CMD_addr, FRS_baseAddr,
		stallComplete
	);
	
	
	wire		r_transactionComplete, w_transactionComplete;
	wire	[15:0]	r_FRS_addr, w_FRS_addr;
	wire		r_FRS_wren_n, w_FRS_wren_n;
	wire		r_FRS_rden_n, w_FRS_rden_n;
	wire	[7:0]	r_FRS_wrByte, w_FRS_wrByte;
	wire	[7:0]	r_SPI_TX_byte, w_SPI_TX_byte;
	wire		r_SPI_TX_valid, w_SPI_TX_valid;
	wire		r_updateAddr, w_updateAddr;
	
	assign	transactionComplete = CMD_rw ? r_transactionComplete : w_transactionComplete;
	assign	FRS_addr = CMD_rw ? r_FRS_addr : w_FRS_addr;
	assign	FRS_wren_n = state == Idle ? 1'b1 : CMD_rw ? r_FRS_wren_n : w_FRS_wren_n;
	assign	FRS_rden_n = state == Idle ? 1'b1 : CMD_rw ? r_FRS_rden_n : w_FRS_rden_n;
	assign	FRS_wrByte = CMD_rw ? r_FRS_wrByte : w_FRS_wrByte;
	assign	SPI_TX_valid = CMD_rw ? r_SPI_TX_valid : w_SPI_TX_valid;
	assign	updateAddr = CMD_rw ? r_updateAddr : w_updateAddr;
	
	assign	SPI_TX_byte = state == Transaction ? CMD_rw ? r_SPI_TX_byte : w_SPI_TX_byte : 8'h00;
	
	fsm_transRead	fsm_TR
	(
		clock, reset_n, state, r_transactionComplete,
		CMD_rw, CMD_size, FRS_baseAddr,
		r_FRS_addr, r_FRS_wren_n, r_FRS_rden_n, r_FRS_wrByte, FRS_rdByte,
		r_SPI_TX_byte, SPI_TX_prepare, r_SPI_TX_valid, SPI_TX_ack, r_updateAddr
	);
	
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
	input		[1:0]	ex_state,
	output			done,
	
	input			CMD_rw,
	input		[5:0]	CMD_size,
	input		[15:0]	FRS_baseAddr,
	
	output	reg	[15:0]	FRS_addr,
	output			FRS_wren_n,
	output			FRS_rden_n,
	output	reg	[7:0]	FRS_wrByte,
	input		[7:0]	FRS_rdByte,
	
	output		[7:0]	SPI_TX_byte,
	input			SPI_TX_prepare,
	output	reg		SPI_TX_valid,
	input			SPI_TX_ack,
	
	input		[7:0]	SPI_RX_byte,
	input			SPI_RX_valid,
	
	output			addrUpdate
);
	
	localparam
		Idle		= 0,
		Setup		= 1,
		TX_wait		= 2,
		TX_send		= 3,
		TX_hold		= 4,
		UpdateAddr	= 5,
		RX_wait		= 6,
		RX_read		= 7,
		Write0		= 8,
		Write1		= 9,
		Complete	= 10,
		ex_Idle		= 0,
		ex_Transaction	= 3;
	reg	[3:0]	state, next_state;
	
	always @(posedge clock, negedge reset_n)
	begin
		if (!reset_n)
			state <= Idle;
		else
			state <= next_state;
	end
	
	reg	[5:0]	nBytesWritten;
	
	always @*
	begin
		if (ex_state == ex_Idle)
			next_state = Idle;
		else case (state)
			
			Idle:
				next_state = ex_state == ex_Transaction && ~CMD_rw ? TX_wait : Idle;
			Setup:
				next_state = SPI_RX_valid ? RX_wait : Setup;
			TX_wait:
				next_state = SPI_TX_prepare ? TX_send : TX_wait;
			TX_send:
				next_state = TX_hold;
			TX_hold:
				next_state = SPI_TX_ack ? Setup : TX_hold;
			UpdateAddr:
				next_state = /* nBytesWritten == CMD_size ? Complete : */ RX_wait;
			RX_wait:
				next_state = SPI_RX_valid ? RX_read : RX_wait;
			RX_read:
				next_state = Write0;
			Write0:
				next_state = Write1;
			Write1:
				next_state = nBytesWritten == CMD_size ? Complete : UpdateAddr;
			Complete:
				next_state = ex_state == ex_Idle ? Idle : Complete;
		endcase
	end
	
	assign done = state == Complete;
	assign FRS_wren_n = 1'b0;
	assign FRS_rden_n = 1'b1;
	assign SPI_TX_byte = 8'hFF;
	
	always @(posedge clock, negedge reset_n)
	begin
		if (!reset_n)
		begin
			FRS_addr <= 16'h0001;
			FRS_wrByte <= 8'hFF;
			nBytesWritten <= 6'h3F;
			SPI_TX_valid <= 1'b0;
		end else case (state)
			
			Idle:
			begin
				FRS_addr <= 16'h0001;
				FRS_wrByte <= 8'hFF;
				SPI_TX_valid <= 1'b0;
			end
			
			Setup:
			begin
				FRS_addr <= FRS_baseAddr;
				nBytesWritten <= 6'h3F;
				SPI_TX_valid <= 1'b0;
			end
				
			UpdateAddr:
				FRS_addr <= FRS_addr + 16'd1;
			
			TX_send:
				SPI_TX_valid <= 1'b1;
			
			RX_wait:
				SPI_TX_valid <= 1'b0;
				
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
	input		[1:0]	ex_state,
	output			done,
	
	input			CMD_rw,
	input		[5:0]	CMD_size,
	input		[15:0]	FRS_baseAddr,
	
	output	reg	[15:0]	FRS_addr,
	output			FRS_wren_n,
	output			FRS_rden_n,
	output		[7:0]	FRS_wrByte,
	input		[7:0]	FRS_rdByte,
	
	output	reg	[7:0]	SPI_TX_byte,
	input			SPI_TX_prepare,
	output	reg		SPI_TX_valid,
	input			SPI_TX_ack,
	
	output			addrUpdate
);

	localparam
		Idle		= 0,
		Setup		= 1,
		UpdateAddr	= 2,
		Read0		= 3,
		Read1		= 4,
		TX_wait		= 5,
		TX_send		= 6,
		TX_hold		= 7,
		Complete	= 8,
		ex_Idle		= 0,
		ex_Transaction	= 3;
	reg	[3:0]	state, next_state;
	
	always @(posedge clock, negedge reset_n)
	begin
		if (!reset_n)
			state <= Idle;
		else
			state <= next_state;
	end
	
	reg	[5:0]	nBytesRead;
	reg		destall;
	
	always @*
	begin
		if (ex_state == ex_Idle)
			next_state = Idle;
		else case (state)
			
			Idle:
				next_state = ex_state == ex_Transaction && CMD_rw ? TX_wait : Idle;
			Setup:
				next_state = Read0;
			UpdateAddr:
				next_state = nBytesRead == CMD_size ? Complete : Read0;
			Read0:
				next_state = Read1;
			Read1:
				next_state = TX_wait;
			TX_wait:
				next_state = SPI_TX_prepare ? TX_send : TX_wait;
			TX_send:
				next_state = TX_hold;
			TX_hold:
				next_state = SPI_TX_ack ? destall ? Setup : UpdateAddr : TX_hold;
			Complete:
				next_state = ex_state == ex_Idle ? Idle : Complete;
		endcase
	end
	
	assign	done = state == Complete;
	assign	FRS_wren_n = 1'b1;
	assign	FRS_rden_n = 1'b0;
	assign	FRS_wrByte = 8'hFF;
	
	
	always @(posedge clock, negedge reset_n)
	begin
		if (!reset_n)
		begin
			nBytesRead <= 6'h3f;
			FRS_addr <= 16'h0001;
			SPI_TX_byte <= 8'hFF;
			SPI_TX_valid <= 1'b0;
			destall <= 1'b1;
		end else case (state)
			
			Idle:
			begin
				nBytesRead <= 6'h3f;
				FRS_addr <= 16'h0001;
				SPI_TX_byte <= 8'hFF;
				SPI_TX_valid <= 1'b0;
				destall <= 1'b1;
			end
			
			Setup:
			begin
				FRS_addr <= FRS_baseAddr;
				destall <= 1'b0;
				SPI_TX_valid <= 1'b0;
				nBytesRead <= 6'h3f;
			end
			
			Read1:
				SPI_TX_byte <= FRS_rdByte;
			
			TX_send:
			begin
				SPI_TX_valid <= 1'b1;
				FRS_addr <= FRS_addr + 16'd1;
				nBytesRead <= nBytesRead + 6'd1;
			end
			
			UpdateAddr:
				SPI_TX_valid <= 1'b0;
			
		endcase
	end
	
	reg	prev_destall;
	always @(posedge clock)
		prev_destall <= destall;
	
	assign	addrUpdate = state == UpdateAddr || state == Setup;// || (~destall & prev_destall);// || state == Setup;
		
endmodule
	


// substate module for Stall (placeholder)
module	fsm_stall
(
	input			clock,
	input			reset_n,
	input		[1:0]	ex_state,
	input		[23:0]	CMD_addr,
	output	reg	[15:0]	FRS_baseAddr,
	output			done
);
	
	localparam
		Idle		= 0,
		Configure	= 1,
		Complete	= 2,
		ex_Idle		= 0,
		ex_Stall	= 2;
	reg	[1:0]	state, next_state;
	
	always @(posedge clock, negedge reset_n)
	begin
		if (!reset_n)
			state <= Idle;
		else
			state <= next_state;
	end
	
	always @*
	begin
		if (ex_state == ex_Idle)
			next_state = Idle;
		else case (state)
			
			Idle:
				next_state = ex_state == ex_Stall ? Configure : Idle;
			Configure:
				next_state = Complete;
			Complete:
				next_state = ex_state == ex_Idle ? Idle : Complete;
			
		endcase
	end

	assign done = state == Complete;
	
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
	input		[1:0]	ex_state,
	input		[7:0]	RX_byte,
	input			RX_valid,
	output	reg	[31:0]	commandHeader,
	output			done
);
	
	localparam
		Idle		= 0,
		WaitRX		= 1,
		ReadByte	= 2,
		Shift		= 3,
		Complete	= 4,
		ex_Idle		= 0,
		ex_ObtainHeader	= 1;
	reg	[2:0]	state, next_state;
	
	always @(posedge clock, negedge reset_n)
	begin
		if (!reset_n)
			state <= Idle;
		else
			state <= next_state;
	end
	
	wire	header_complete;
	assign	done = state == Complete;
	
	always @*
	begin
		if (ex_state == ex_Idle)
			next_state = Idle;
		else case (state)
			
			Idle:
				next_state = ex_state == ex_ObtainHeader ? WaitRX : Idle;
			WaitRX:
				next_state = RX_valid ? ReadByte : WaitRX;
			ReadByte:
				next_state = RX_valid ? ReadByte : header_complete ? Complete : Shift;
			Shift:
				next_state = WaitRX;
			Complete:
				next_state = ex_state == ex_Idle ? Idle : Complete;
		endcase
	end
	
	
	reg	[3:0]	shift_tracker;
	assign	header_complete = shift_tracker[0];
	
	always @(posedge clock, negedge reset_n)
	begin
		if (!reset_n)
		begin
			commandHeader <= 32'h0;
			shift_tracker <= 4'h8;
		end else case (state)
			
			Idle:
			begin
				commandHeader <= 32'h0;
				shift_tracker <= 4'h8;
			end
			
			ReadByte:
				commandHeader[7:0] <= RX_byte;
			
			Shift:
			begin
				commandHeader <= commandHeader << 8;
				shift_tracker <= shift_tracker >> 1;
			end
		
		endcase
	end
	

endmodule
