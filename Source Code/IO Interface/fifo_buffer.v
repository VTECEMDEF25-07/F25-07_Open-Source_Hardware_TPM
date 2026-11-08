// fifo_buffer.v
// modules:
//	fifo_buffer
//	GENERIC_BUFFER
//
// Authors:
//	Ian Sizemore (idsizemore@vt.edu)
//
// Date: 11/6/25
//
// General Description:
//	This file describes the FIFO buffer of the TPM.
//	The FIFO buffer is part of the FRS module (FIFO-Register-Space;
//	the controlling logic module of the I/O system).
//	Its purpose is to store command data as it is being send to the I/O system,
//	store response data as it is being read from the I/O system,
//	and to move command/response data back and forth from the CRB (Command/Reponse Buffer).

module	fifo_buffer
(
	input			clock_i,
	input			reset_n_i,
	
	input		[7:0]	cmdByteIn_i,	// byte of command data from frs
	input		[7:0]	rspByteIn_i,	// byte of response data from exec
	output		[7:0]	cmdByteOut_o,	// byte of command data to exec
	output	reg	[7:0]	rspByteOut_o,	// byte of response data to frs
	
	input			f_fifoAccess_i,	// frs is making a r/w request to fifo buffer
	input			f_fifoRead_i,	// frs wants to read
	input			f_fifoWrite_i,	// frs wants to write
	input			f_abort_i,	// frs needs to reset the buffer
	input		[5:0]	t_size_i,		// size of current frs transaction
	input			r_tpmGo_i,	// TPM_STS.tpmGo signal
	input			r_commandReady_i, // TPM_STS.commandReady signal
	input			r_responseRetry_i,// TPM_STS.responseRetry signal
	
	input			e_execDone_i,	// signal that response data is ready to be loaded
	
	output			f_fifoComplete_o,	// fifo buffer contains full frs command data
	output			f_fifoEmpty_o,	// fifo buffer's response data has been fully read to frs
	
	input		[11:0]	t_address_i,	// unused
	input		[11:0]	t_baseAddr_i,	// unused
	input			t_updateAddr_i,	// signals that it is time to increment the internal buffer address
	
	output		[31:0]	c_cmdSize_o,	// command length, from TPM command header
	input		[31:0]	c_rspSize_i,	// response length, from TPM response header
	output			c_cmdSend_o,	// signals to CRB that we are ready to send command data
	input			c_rspSend_i,	// signal from CRB that indicates a write of 1 byte of response data (this is buf.wren_n_i during response data transmission)
	input			c_cmdDone_i,	// signal from CRB that it is finished reading command data
	input			c_rspDone_i,	// signal from CRB that is is finished sending response data
						// 	During FIFO-to-CRB command data and CRB-to-FIFO response data transmissions,
						//	the CRB gains full control of the FIFO buffer, including the buffer address
						//	and the buffer wren_n_i (during response transmission).
	input		[11:0]	c_cmdInAddr_i,	// CRB-controlled buffer address during command transmission
	input		[11:0]	c_rspInAddr_i	// CRB-controlled buffer address during response transmission
);
	
	// connections and instantiation of the internal buffer
	reg		bufWren_n;
	reg	[11:0]	bufAddr, m_bufAddr;
	reg	[31:0]	b_size;
	reg	[7:0]	bufIn;
	wire	[7:0]	bufOut;
	
	GENERIC_BUFFER	internal_buffer
	(
		.clock_i(clock_i),
		.wren_n_i(bufWren_n), .addr_i(m_bufAddr),
		.wrByte_i(bufIn), .rdByte_o(bufOut)
	);
	
	// State machine of the FIFO Buffer
	localparam
		Idle			= 0,	// waiting for a fifoAccess request from FRS...
		GetCmdSize		= 1,	// in the first 6 bytes of the command, bytes 3,4,5,6 indicate the command size
		CmdIn			= 2,	// after obtaining the command size, this state controls obtaining the rest of the command
		CmdIn_last		= 3,	// unusued
		TpmGo_wait		= 4,	// wait for a TpmGo signal from FRS (signals to move command to execution)
		CmdOut_start		= 5,	// start the transmission of command data to CRB
		CmdOut_wait		= 6,	// transmission of command data to CRB
		Exec_wait		= 7,	// wait for execution to finish ; waiting for a response to be ready
		GetRspSize		= 8,	// in the first 6 bytes of the response, bytes 3,4,5,6 indicate response size
		RspIn_start		= 9,	// start the transmission of response data from CRB
		RspIn_wait		= 10,	// transmission of response data from CRB
		AddrRst			= 11,	// used to reset the internal address in the case FRB signals responseRetry
		RspOut			= 12,	// transmission state for response data being read to the FRS
		CommandReady_wait	= 13;	// after the response has been fully read, we wait for the FRS to return to its Idle state (signaled by commandReady)
	reg	[3:0]	state, next_state;
	
	always @(posedge clock_i, negedge reset_n_i)
	begin
		if (!reset_n_i)
			state <= Idle;
		else if (f_abort_i) // reset on receipt of f_abort_i
			state <= Idle;
		else
			state <= next_state;
	end
	
	// combinational logic to implement the FIFO buffer state machine
	always @*
	begin
		case (state)
		
		// go to GetCmdSize if fifoAccess is requested
		Idle:
			next_state = f_fifoAccess_i ? GetCmdSize : Idle;
		// go to CmdIn after 6 bytes have been read
		GetCmdSize:
			next_state = bufAddr == 12'd6 ? CmdIn : GetCmdSize;
		// go to TpmGo_wait once the command has been fully read
		CmdIn:
			next_state = ~f_fifoAccess_i & (bufAddr >= b_size[11:0]-12'd1) ? TpmGo_wait : CmdIn;
		// go to CmdOut_start after tpmGo has been received (from frs, signals to start command execution)
		TpmGo_wait:
			next_state = r_tpmGo_i ? CmdOut_start : TpmGo_wait;
		// go to CmdOut_wait (used to pulse a control signal)
		CmdOut_start:
			next_state = CmdOut_wait;
		// go to Exec_wait after c_cmdDone_i has been received (command fully read)
		CmdOut_wait:
			next_state = c_cmdDone_i ? Exec_wait : CmdOut_wait;
		// go to GetRspSize after e_execDone_i has been received
		Exec_wait:
			next_state = e_execDone_i ? GetRspSize : Exec_wait;
		// go to RspIn_start ; rspSize is read from execution engine
		GetRspSize:
			next_state = RspIn_start;
		// go to RspIn_wait (this is a pulse control signal)
		RspIn_start:
			next_state = RspIn_wait;
		// go to AddrRst after c_rspDone_i has been received (response fully read)
		RspIn_wait:
			next_state = c_rspDone_i ? AddrRst : RspIn_wait;
		// go to RspOut (this sets the address index to 0)
		AddrRst:
			next_state = RspOut;
		// go to Idle if r_commandReady_i is received from frs ; go to AddrRst if r_responseRetry_i is received from frs ; go to CommandReady_wait after response has been fully read out
		RspOut:
			next_state = r_commandReady_i ? Idle : r_responseRetry_i ? AddrRst : ~f_fifoAccess_i & (bufAddr == b_size[11:0] + 12'd1) ? CommandReady_wait : RspOut;
		// go to Idle if r_commandReady_i is received from frs ; go to AddrRst if r_responseRetry_i is received from frs 
		CommandReady_wait:
			next_state = r_commandReady_i ? Idle : r_responseRetry_i ? AddrRst : CommandReady_wait;
		
		default:
			next_state = 4'hx;
			
		endcase
	end
	
	// these regs are used for edge detection of the named signals
	reg	prev_updateAddr, prev_fifoWrite, prev_fifoRead;
	always @(posedge clock_i)
	begin
		prev_updateAddr <= t_updateAddr_i;
		prev_fifoWrite <= f_fifoWrite_i;
		prev_fifoRead <= f_fifoRead_i;
	end
	
	// this reg is used to control the timing when the frs writes to the FIFO buffer
	reg	allowWrite;
	always @(posedge clock_i, negedge reset_n_i)
	begin
		if (!reset_n_i)
			allowWrite <= 1'b1;
		else if (~f_fifoWrite_i & prev_fifoWrite || f_fifoWrite_i & ~prev_fifoWrite)
			allowWrite <= 1'b1;
		else if (prev_updateAddr & f_fifoAccess_i)
			allowWrite <= 1'b0;
	end
	
	// state machine sequential logic
	always @(posedge clock_i, negedge reset_n_i)
	begin
		// reset logic
		if (!reset_n_i)
		begin
			bufAddr <= 12'hFFF;
			b_size <= 32'hFFFFFFFF;
		end
		else case (state)
		
		// reset logic
		Idle:
		begin
			bufAddr <= 12'hFFF;
			b_size <= 32'hFFFFFFFF;
		end
		
		// during GetCmdSize, the cmdSize is stored within b_size (buffer size)
		GetCmdSize:
		begin
			bufAddr <= t_updateAddr_i & f_fifoWrite_i ? bufAddr + 12'h1 : bufAddr;
			case (bufAddr[2:0])
			
			3'd2:	b_size <= { bufOut, b_size[23:0] };
			3'd3:	b_size <= { b_size[31:24], bufOut, b_size[15:0] };
			3'd4:	b_size <= { b_size[31:16], bufOut, b_size[7:0] };
			3'd5:	b_size <= { b_size[31:8], bufOut };
			
			endcase
		end
		
		CmdIn:
		begin
			bufAddr <= t_updateAddr_i & f_fifoWrite_i ? bufAddr + 12'h1 : bufAddr;
		end
		
		Exec_wait, AddrRst:
		begin
			bufAddr <= 12'h0;
		end
		
		// obtain response size from execution engine
		GetRspSize:
		begin
			b_size <= c_rspSize_i;
		end
		
		// address update behavior is odd for this state, but this is necessary to handle both single-byte and multi-byte reads
		RspOut:
		begin
			if (f_fifoRead_i & t_updateAddr_i)
				bufAddr <= bufAddr + 12'h1;
			else if (~f_fifoRead_i & prev_fifoRead)
				bufAddr <= bufAddr - 12'h1;
		end
		
		
		endcase
	end
	
	// state machine combinational logic
	always @*
	begin
		// base condition
		bufIn = 8'hFF;
		rspByteOut_o = 8'hFF;
		bufWren_n = 1'b1;
		m_bufAddr = bufAddr;
		
		case (state)
		
		// base condition
		default:
		begin
			bufIn = 8'hFF;
			rspByteOut_o = 8'hFF;
			bufWren_n = 1'b1;
			m_bufAddr = bufAddr;
		end
		
		// for cmd reading states
		GetCmdSize, CmdIn, CmdIn_last, CmdIn_last:
		begin
			bufIn = cmdByteIn_i;
			bufWren_n = ~f_fifoWrite_i | allowWrite;
			m_bufAddr = bufAddr;
		end
		
		// for response read out to frs
		RspOut:
		begin
			rspByteOut_o = bufOut;
			m_bufAddr = bufAddr;
		end
		
		// for command send to crb
		CmdOut_wait:
		begin
			bufWren_n = 1'b1;
			m_bufAddr = c_cmdInAddr_i;
		end
		
		// for response read from crb
		RspIn_wait:
		begin
			bufWren_n = c_rspSend_i;
			bufIn = rspByteIn_i;
			m_bufAddr = c_rspInAddr_i;
		end
		
		endcase
	end
	
	
	// static assignments
	assign	f_fifoComplete_o = state >= TpmGo_wait;
	assign	f_fifoEmpty_o = state == CommandReady_wait;
	
	assign	c_cmdSize_o = b_size;
	assign	c_cmdSend_o = state == CmdOut_start;
	assign	cmdByteOut_o = bufOut;
	
	
endmodule


// A generic buffer module, which instantiates as sync-ram
// Defaults to 4096 addressable bytes
module	GENERIC_BUFFER
#(parameter WORD_SIZE = 8, BUF_SIZE = 4096)
(
	input					clock_i,
	input					wren_n_i,	// write enable, active low
	input		[$clog2(BUF_SIZE)-1:0]	addr_i,	// mem address
	input		[WORD_SIZE-1:0]		wrByte_i,	// write byte in
	output	reg	[WORD_SIZE-1:0]		rdByte_o	// read byte out
);
	
	reg	[WORD_SIZE-1:0]	mem[0:BUF_SIZE-1];
	
	always @(posedge clock_i)
		rdByte_o <= mem[addr_i];
	always @(posedge clock_i)
		if (!wren_n_i)
			mem[addr_i] <= wrByte_i;
endmodule