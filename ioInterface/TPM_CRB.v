`define TPM_CC_STARTUP 32'h00000144
`define	TPM_RC_SUCCESS 32'h00000000
`define TPM_ST_NO_SESSIONS 16'h8001

module	TPM_CRB
(
	input			clock,
	input			reset_n,
	
	input		[7:0]	locality,
	input			cmdAbort,
	
	input		[31:0]	cmdSize,
	output	reg	[31:0]	rspSize,
	
	input			cmdSend,
	output			rspSend,
	
	output			cmdDone,
	output			rspDone,
	
	output		[11:0]	cmdOutAddr,
	output		[11:0]	rspOutAddr,
	
	input		[7:0]	cmdByteIn,
	output	reg	[7:0]	rspByteOut,
	
	output			execDone,
	output			execStart,
	
	output	reg	[31:0]	commandCode,
	input		[31:0]	responseCode,
	output	reg	[39:0]	commandParam
);
	
	reg	[15:0]	cmd_st;
	
	reg		cmdWren_n;
	reg	[11:0]	cmdAddr;
	reg	[7:0]	cmdIn;
	wire	[7:0]	cmdOut;
	
	GENERIC_BUFFER	cmdBuffer
	(
		.clock(clock),
		.wren_n(cmdWren_n), .addr(cmdAddr),
		.wrByte(cmdIn), .rdByte(cmdOut)
	);
	
	reg		rspWren_n;
	reg	[11:0]	rspAddr;
	reg	[7:0]	rspIn;
	wire	[7:0]	rspOut;
	
//	assign	rspByteOut = rspOut;
	
	GENERIC_BUFFER	rspBuffer
	(
		.clock(clock),
		.wren_n(rspWren_n), .addr(rspAddr),
		.wrByte(rspIn), .rdByte(rspOut)
	);
	
	wire		ci_start;
	wire		ci_done;
	wire	[11:0]	ci_addr;
	wire		ci_wren;
	
	CRB_TRANS fsm_ci
	(
		.clock(clock), .reset_n(reset_n),
		.start(ci_start), .done(ci_done),
		.size_in(cmdSize[11:0]), .addr(ci_addr), .wren_n(ci_wren)
	);
	
	localparam
		Idle		= 0,
		CmdIn_start	= 1,
		CmdIn_wait	= 2,
		Exec_setup0	= 3,
		Exec_setup1	= 4,
		Exec_start	= 5,
		Exec_wait0	= 6,
		Exec_wait1	= 7,
		Exec_done	= 8,
		AssembleRsp	= 9,
		RspOut_start	= 10,
		RspOut_wait	= 11,
		Complete	= 12;
	reg	[3:0]	state, next_state;
	
	always @(posedge clock, negedge reset_n)
	begin
		if (!reset_n)
			state <= Idle;
		else
			state <= next_state;
	end
	
	always @*
	begin
		case (state)
		
		Idle:
			next_state = cmdSend ? CmdIn_start : Idle;
		CmdIn_start:
			next_state = CmdIn_wait;
		CmdIn_wait:
			next_state = ci_done ? Exec_setup0 : CmdIn_wait;
		Exec_setup0:
			next_state = Exec_setup1;
		Exec_setup1:
			next_state = Exec_start;
		Exec_start:
			next_state = Exec_wait0;
		Exec_wait0:
			next_state = Exec_wait1;
		Exec_wait1:
			next_state = Exec_done;
		Exec_done:
			next_state = AssembleRsp;
		AssembleRsp:
			next_state = RspOut_start;
		RspOut_start:
			next_state = RspOut_wait;
		RspOut_wait:
			next_state = ci_done ? Complete : RspOut_wait;
		Complete:
			next_state = Idle; // rspAck ? Idle : Complete;
		default:
			next_state = 4'hx;
		
		endcase
	end
	
	always @(posedge clock, negedge reset_n)
	begin
		if (!reset_n)
		begin
			commandCode <= 32'h00000000;
			commandParam <= 32'h00000000;
			cmd_st <= 16'h0000;
			rspByteOut <= 8'hFF;
		end
		else if (state == Idle)
		begin
			commandCode <= 32'h00000000;
			commandParam <= 32'h00000000;
			cmd_st <= 16'h0000;
			rspByteOut <= 8'hFF;
		end
		else if (state == CmdIn_wait) case (ci_addr)
			
			12'h000: cmd_st[15:8] <= cmdIn;
			12'h001: cmd_st[7:0] <= cmdIn;
			
			12'h006: commandCode[31:24] <= cmdIn;
			12'h007: commandCode[23:16] <= cmdIn; 
			12'h008: commandCode[15:8] <= cmdIn;
			12'h009: commandCode[7:0] <= cmdIn;
			
			12'h00E: 
			begin
				if (commandCode == `TPM_CC_STARTUP)
					commandParam[15:8] <= cmdIn;
				else
					commandParam[39:32] <= cmdIn;
			end
			12'h00F:
			begin
				if (commandCode == `TPM_CC_STARTUP)
					commandParam[7:0] <= cmdIn;
				else
					commandParam[31:24] <= cmdIn;
			end
			12'h010:
			begin
				if (commandCode != `TPM_CC_STARTUP)
					commandParam[23:16] <= cmdIn;
			end
			12'h011:
			begin
				if (commandCode != `TPM_CC_STARTUP)
					commandParam[15:8] <= cmdIn;
			end
			12'h012:
			begin
				if (commandCode != `TPM_CC_STARTUP)
					commandParam[7:0] <= cmdIn;
			end
			
		endcase
		else if (state == AssembleRsp)
		begin
			if (responseCode != `TPM_RC_SUCCESS)
				cmd_st <= `TPM_ST_NO_SESSIONS;
		end
		else if (state == RspOut_wait) case (ci_addr)
			12'h000:	rspByteOut <= cmd_st[15:8];
			12'h001:	rspByteOut <= cmd_st[7:0];
			12'h002:	rspByteOut <= 8'h00;
			12'h003:	rspByteOut <= 8'h00;
			12'h004:	rspByteOut <= 8'h00;
			12'h005:	rspByteOut <= 8'h0A;
			12'h006:	rspByteOut <= responseCode[31:24];
			12'h007:	rspByteOut <= responseCode[23:16];
			12'h008:	rspByteOut <= responseCode[15:8];
			12'h009:	rspByteOut <= responseCode[7:0];
		endcase
	end
	
	always @(posedge clock, negedge reset_n)
	begin
		if (!reset_n)
		begin
			rspSize <= 32'h0;
		end
		else case (state)
		
		Idle:
		begin
			rspSize <= 32'h0;
		end
		
		CmdIn_start:
			rspSize <= 32'd10;
		
		endcase
	end
	
	always @*
	begin
		cmdAddr = 12'hFFF;
		cmdWren_n = 1'b1;
		cmdIn = 8'hFF;
		
		// debug
		rspAddr = cmdAddr;
		rspWren_n = cmdWren_n;
		rspIn = cmdIn;
	
		// debug
		rspIn = cmdIn;
		
		case (state)
		
		default:
		begin
			cmdAddr = 12'hFFF;
			cmdWren_n = 1'b1;
			cmdIn = 8'hFF;
			
			// debug
			rspAddr = cmdAddr;
			rspWren_n = cmdWren_n;
			rspIn = cmdIn;
		end
		
		CmdIn_start, CmdIn_wait:
		begin
			cmdAddr = ci_addr;
			cmdWren_n = ci_wren;
			cmdIn = cmdByteIn;
			rspAddr = cmdAddr;
			rspWren_n = cmdWren_n;
			rspIn = cmdIn;
		end
		
		RspOut_start, RspOut_wait:
		begin
			rspAddr = ci_addr;
			rspWren_n = 1'b1;
		end
		
		endcase
	end
	
	assign	ci_start = state == CmdIn_start || state == RspOut_start;
	
	assign	cmdOutAddr = cmdAddr;
	assign	rspOutAddr = rspAddr;
	assign	rspSend = ci_wren;
//	assign	rspByteOut = rspOut;
	assign	cmdDone = state == Exec_start;
	assign	rspDone = state == Complete;
	assign	execStart =
		state == Exec_wait0 || state == Exec_wait1 ||
		state == Exec_setup0 || state == Exec_setup1;
	assign	execDone = state == Exec_done;
	
endmodule

module	CRB_TRANS
(
	input			clock,
	input			reset_n,
	
	input			start,
	output			done,
	
	input		[11:0]	size_in,
	output	reg	[11:0]	addr,
	output			wren_n
);
	
	reg	[11:0]	size;
	
	localparam
		Idle		= 0,
		Setup		= 1,
		Write0		= 2,
		Write1		= 3,
		UpdateAddr	= 4,
		Complete	= 5;
	reg	[2:0]	state, next_state;
	
	always @(posedge clock, negedge reset_n)
	begin
		if (!reset_n)
			state <= Idle;
		else
			state <= next_state;
	end
	
	always @*
	begin
		case (state)
		
		Idle:
			next_state = start ? Setup : Idle;
		Setup:
			next_state = Write0;
		Write0:
			next_state = Write1;
		Write1:
			next_state = UpdateAddr;
		UpdateAddr:
			next_state = addr == size ? Complete : Write0;
		Complete:
			next_state = Idle;
		
		default:
			next_state = 3'hx;
	
		endcase
	end
	
	always @(posedge clock, negedge reset_n)
	begin
		if (!reset_n)
		begin
			addr <= 12'h000;
			size <= 12'h000;
		end
		else case (state)
		
		Idle:
		begin
			addr <= 12'h000;
			size <= 12'h000;
		end
		
		Setup:
			size <= size_in;
		
		UpdateAddr:
			addr <= addr + 12'h1;
		
		endcase
	end
	
	assign	wren_n = state != Write1;
	assign	done = state == Complete;
	
endmodule