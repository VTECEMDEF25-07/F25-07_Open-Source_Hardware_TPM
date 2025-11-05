module	FIFO_BUFFER
(
	input			clock,
	input			reset_n,
	
	input		[7:0]	cmdByteIn,	// byte of command data from frs
	input		[7:0]	rspByteIn,	// byte of response data from exec
	output		[7:0]	cmdByteOut,	// byte of command data to exec
	output	reg	[7:0]	rspByteOut,	// byte of response data to frs
	
	input			f_fifoAccess,	// frs is making a r/w request to fifo buffer
	input			f_fifoRead,	// frs wants to read
	input			f_fifoWrite,	// frs wants to write
	input			f_abort,	// frs needs to reset the buffer
	input		[5:0]	t_size,		// size of current frs transaction
	input			r_tpmGo,	// TPM_STS.tpmGo signal
	input			r_commandReady, // TPM_STS.commandReady signal
	input			r_responseRetry,// TPM_STS.responseRetry signal
	
	input			e_execDone,	// signal that response data is ready to be loaded
	
	output			f_fifoComplete,	// fifo buffer contains full frs command data
	output			f_fifoEmpty,	// fifo buffer's response data has been fully read to frs
	
	input		[11:0]	t_address,	// apparent address from transaction perspective
	input		[11:0]	t_baseAddr,	// initial transaction address (used to calculate internal buffer address)
	input			t_updateAddr,
	
	output		[31:0]	c_cmdSize,
	input		[31:0]	c_rspSize,
	output			c_cmdSend,
	input			c_rspSend,
	input			c_cmdDone,
	input			c_rspDone,
	input		[11:0]	c_cmdInAddr,
	input		[11:0]	c_rspInAddr
);
	
	reg		bufWren_n;
	reg	[11:0]	bufAddr, m_bufAddr;
	reg	[31:0]	b_size;
	reg	[7:0]	bufIn;
	wire	[7:0]	bufOut;
	
	GENERIC_BUFFER	buffer
	(
		.clock(clock),
		.wren_n(bufWren_n), .addr(m_bufAddr),
		.wrByte(bufIn), .rdByte(bufOut)
	);
	
	localparam
		Idle			= 0,
		GetCmdSize		= 1,
		CmdIn			= 2,
		CmdIn_last		= 3,
		TpmGo_wait		= 4,
		CmdOut_start		= 5,
		CmdOut_wait		= 6,
		Exec_wait		= 7,
		GetRspSize		= 8,
		RspIn_start		= 9,
		RspIn_wait		= 10,
		AddrRst			= 11,
		RspOut			= 12,
		CommandReady_wait	= 13;
	reg	[3:0]	state, next_state;
	
	always @(posedge clock, negedge reset_n)
	begin
		if (!reset_n)
			state <= Idle;
		else if (f_abort)
			state <= Idle;
		else //if (f_fifoAccess)
			state <= next_state;
	end
	
	always @*
	begin
		case (state)
		
		Idle:
			next_state = f_fifoAccess ? GetCmdSize : Idle;
		GetCmdSize:
			next_state = bufAddr == 12'd6 ? CmdIn : GetCmdSize;
		CmdIn:
			next_state = ~f_fifoAccess & (bufAddr >= b_size[11:0]-12'd1) ? TpmGo_wait : CmdIn;
		TpmGo_wait:
			next_state = r_tpmGo ? CmdOut_start : TpmGo_wait;
		CmdOut_start:
			next_state = CmdOut_wait;
		CmdOut_wait:
			next_state = c_cmdDone ? Exec_wait : CmdOut_wait;
		Exec_wait:
			next_state = e_execDone ? GetRspSize : Exec_wait;
		GetRspSize:
			next_state = RspIn_start;
		RspIn_start:
			next_state = RspIn_wait;
		RspIn_wait:
			next_state = c_rspDone ? AddrRst : RspIn_wait;
		AddrRst:
			next_state = RspOut;
		RspOut:
			next_state = r_commandReady ? Idle : ~f_fifoAccess & (bufAddr == b_size[11:0] + 12'd2) ? CommandReady_wait : RspOut;
		CommandReady_wait:
			next_state = r_commandReady ? Idle : r_responseRetry ? AddrRst : CommandReady_wait;
		
		default:
			next_state = 4'hx;
			
		endcase
	end
	
	reg	prev_updateAddr, prev_fifoWrite, prev_fifoRead;
	always @(posedge clock)
	begin
		prev_updateAddr <= t_updateAddr;
		prev_fifoWrite <= f_fifoWrite;
		prev_fifoRead <= f_fifoRead;
	end
	
	reg	allowWrite;
	always @(posedge clock, negedge reset_n)
	begin
		if (!reset_n)
			allowWrite <= 1'b1;
		else if (~f_fifoWrite & prev_fifoWrite || f_fifoWrite & ~prev_fifoWrite)
			allowWrite <= 1'b1;
		else if (prev_updateAddr & f_fifoAccess)
			allowWrite <= 1'b0;
	end
	
	always @(posedge clock, negedge reset_n)
	begin
		if (!reset_n)
		begin
			bufAddr <= 12'hFFF;
	//		bufWren_n <= 1'b1;
	//		bufIn <= 8'h00;
			b_size <= 32'hFFFFFFFF;
		end
		else case (state)
		
		Idle:
		begin
			bufAddr <= 12'hFFF;
	//		bufWren_n <= 1'b1;
	//		bufIn <= 8'h00;
			b_size <= 32'hFFFFFFFF;
		end
		
		GetCmdSize:
		begin
	//		bufWren_n <= ~f_fifoWrite;
			bufAddr <= t_updateAddr & f_fifoWrite ? bufAddr + 12'h1 : bufAddr;
			case (bufAddr[2:0])
			
			3'd2:	b_size <= { cmdByteIn, b_size[23:0] };
			3'd3:	b_size <= { b_size[31:24], cmdByteIn, b_size[15:0] };
			3'd4:	b_size <= { b_size[31:16], cmdByteIn, b_size[7:0] };
			3'd5:	b_size <= { b_size[31:8], cmdByteIn };
			
			endcase
		end
		
		CmdIn:
		begin
	//		bufWren_n <= ~f_fifoWrite;
			bufAddr <= t_updateAddr & f_fifoWrite ? bufAddr + 12'h1 : bufAddr;
		end
		
		Exec_wait, AddrRst:
		begin
			bufAddr <= 12'h0;
		end
		
		GetRspSize:
		begin
			b_size <= c_rspSize;
		end
		
		RspOut:
		begin
			if (f_fifoRead & t_updateAddr)
				bufAddr <= bufAddr + 12'h1;
			else if (~f_fifoRead & prev_fifoRead)
				bufAddr <= bufAddr - 12'h1;
			//bufAddr <= t_updateAddr & f_fifoRead ? bufAddr + 12'h1 : bufAddr;
		end
		
/*		CmdIn_last:
		begin
			bufWren_n <= ~f_fifoWrite;
		end
		
		TpmGo_wait:
		begin
			bufWren_n <= 1'b1; // ~f_fifoWrite;
		end*/
		
		endcase
	end
	
	always @*
	begin
		bufIn = 8'hFF;
		rspByteOut = 8'hFF;
		bufWren_n = 1'b1;
		m_bufAddr = bufAddr;
		
		case (state)
		
		default:
		begin
			bufIn = 8'hFF;
			rspByteOut = 8'hFF;
			bufWren_n = 1'b1;
			m_bufAddr = bufAddr;
		end
		
		GetCmdSize, CmdIn, CmdIn_last, CmdIn_last:
		begin
			bufIn = cmdByteIn;
			bufWren_n = ~f_fifoWrite | allowWrite;
			m_bufAddr = bufAddr;
		end
		
		RspOut:
		begin
			rspByteOut = bufOut;
			m_bufAddr = bufAddr;
		end
		
		CmdOut_wait:
		begin
			bufWren_n = 1'b1;
			m_bufAddr = c_cmdInAddr;
		end
		
		RspIn_wait:
		begin
			bufWren_n = c_rspSend;
			bufIn = rspByteIn;
			m_bufAddr = c_rspInAddr;
		end
		
		endcase
	end
	
	assign	f_fifoComplete = state >= TpmGo_wait;
	assign	f_fifoEmpty = state == CommandReady_wait;
	
	assign	c_cmdSize = b_size;
	assign	c_cmdSend = state == CmdOut_start;
	assign	cmdByteOut = bufOut;
	
	
endmodule

module	GENERIC_BUFFER
#(parameter WORD_SIZE = 8, BUF_SIZE = 4096)
(
	input					clock,
	input					wren_n,
	input		[$clog2(BUF_SIZE)-1:0]	addr,
	input		[WORD_SIZE-1:0]		wrByte,
	output	reg	[WORD_SIZE-1:0]		rdByte
);
	
	reg	[WORD_SIZE-1:0]	mem[0:BUF_SIZE-1];
	
	always @(posedge clock)
		rdByte <= mem[addr];
	always @(posedge clock)
		if (!wren_n)
			mem[addr] <= wrByte;
endmodule