// tpm_crb.v
// modules:
//	tpm_crb
//	CRB_TRANS
//
// Authors:
//	Ian Sizemore (idsizemore@vt.edu)
//
// Date: 11/6/25
//
// General Description:
//	This file describes the Command/Reponse Buffer of the TPM.
//	The CRB handles data flow from the FRS to the management/execution modules.
//	Command data is parsed into a set of output busses, and reponse data is fed to the FIFO buffer.

// this includes defined TPM constants (command codes, etc.)
`include "TPM_TYPES.vh"

module	tpm_crb
(
	input			clock,
	input			reset_n,
	
	input		[7:0]	locality,	// locality, from frs
	input			cmdAbort,	// abort command, from frs
	
	input		[31:0]	cmdSize,	// command size, from fifo buffer
	output		[31:0]	rspSize,	// reponse size, to fifo buffer
	
	input			cmdSend,	// ready to send command, from fifo buffer
	output			rspSend,	// response byte write pulse, to fifo buffer
	
	output			cmdDone,	// command data fully read, to fifo buffer
	output			rspDone,	// response data fully sent, to fifo buffer
	
	output		[11:0]	cmdOutAddr,	// command buffer address, to fifo buffer
	output		[11:0]	rspOutAddr,	// response buffer address, to fifo buffer
	
	input		[7:0]	cmdByteIn,	// command byte, from fifo buffer
	output	reg	[7:0]	rspByteOut,	// response byte, to fifo buffer
	
	output			execDone,	// execution completed, to fifo buffer
	output	reg		execStart,	// start execution, to management/execution
	input			execAck,	// ack of execDone, from fifo buffer
	input			rspReady,	// response data ready, from execution
	
	output	reg	[31:0]	commandCode,	// command code, to management/execution
	output		[15:0]	commandTag,	// command tag, to management/execution
	input		[31:0]	responseCode,	// response code, from management/execution
	output	reg	[39:0]	commandParam,	// command params, to management
	output	reg	[15:0]	expectedTag,	// expected tag (unusued)
	
	output		[31:0]	handle0, handle1, handle2,					// command handle data, to execution
	output		[31:0]	sessionHandle0, sessionHandle1, sessionHandle2,			// command session handle data, to execution
	output		[15:0]	sessionNonceSize0, sessionNonceSize1, sessionNonceSize2,	// command session nonce buffer size, to execution (unusued)
	output		[11:0]	sessionNonceAddr0, sessionNonceAddr1, sessionNonceAddr2,	// command session nonce buffer data, to execution (unusued)
	output		[7:0]	sessionAttributes0, sessionAttributes1, sessionAttributes2,	// command session attributes, to execution
	output		[15:0]	sessionHmacSize0, sessionHmacSize1, sessionHmacSize2,		// command session hmac buffer size, to execution
	output		[11:0]	sessionHmacAddr0, sessionHmacAddr1, sessionHmacAddr2,		// command session hmac buffer data, to execution (unusued)
	output	reg	[31:0]	authSize,							// command auth size, to execution
	
	output	reg		sessionValid0, sessionValid1, sessionValid2			// command session valid, to execution
);
	
	// command tag
	reg	[15:0]	cmd_st;
	
	// local cmd buffer (unusued)
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
	
	// local response buffer (unusued; non-functional placeholder)
	reg		rspWren_n;
	reg	[11:0]	rspAddr;
	reg	[7:0]	rspIn;
	wire	[7:0]	rspOut;
	
	GENERIC_BUFFER	rspBuffer
	(
		.clock(clock),
		.wren_n(rspWren_n), .addr(rspAddr),
		.wrByte(rspIn), .rdByte(rspOut)
	);
	
	// note: neither unused buffers above sythensize (the synthesis tool should recognize this, and optimize them away)
	//	a future team may find use for these buffer, so they are left as-is
	
	// a state machine in a separate module is used to clock bytes to/from the fifo buffer
	// the ci_ connections are used to communicate with this state mahcine
	
	reg		ci_start;	// start transfer
	wire		ci_done;	// transfer done
	wire	[11:0]	ci_addr;	// current byte address
	reg	[11:0]	ci_size;	// transfer size
	reg		ci_restart;	// reset the transfer fsm
	wire		ci_wren;	// write enable pulse for transfers
	wire	[11:0]	ci_rel;		// relative address for current byte
	
	// relative address explanation:
	//	reading command buffer of 24 bytes
	//	after the first 8 bytes, lets say we want the following 4 bytes
	//	reset -> size = 8, start : done
	//	then, size = 4, start
	//		during this transfer, ci_addr will be 8 .. 12
	//		ci_rel will be 0 .. 4
	//	: done
	
	CRB_TRANS fsm_ci
	(
		.clock(clock), .reset_n(reset_n),
		.start(ci_start), .restart(ci_restart), .done(ci_done),
		.size_in(ci_size), .addr(ci_addr), .wren_n(ci_wren),
		.rel_addr(ci_rel)
	);
	
	
	// state machine
	localparam
		Idle			= 0,	// waiting for cmdSend from fifo buffer
		CmdHeader_start		= 1,	// start reading command header from fifo
		CmdHeader_wait		= 2,	// read command header
		CmdDecode		= 3,	// determine command session, handle count
	// loop	
	/*{*/	HandleCountCheck	= 4,	// compare counter to handle count
		ReadHandle_start	= 5,	// start reading command handle
		ReadHandle_wait		= 6,	// read command handle
	/*}*/	UpdateHandleCount	= 7,	// update counter
		ReadAuthSize_start	= 8,	// start reading command auth size
		ReadAuthSize_wait	= 9,	// read command auth size
	// loop
	/*{*/	SessionCountCheck	= 10,	// compare counter to session count
		ReadSessionA_start	= 11,	// start reading command session data
		ReadSessionA_wait	= 12,	// read command session data
		ReadNonce_start		= 13,	// start reading nonce data
		ReadNonce_wait		= 14,	// read nonce data
		ReadSessionB_start	= 15,	// start reading command session data
		ReadSessionB_wait	= 16,	// read command session data
		ReadHmac_start		= 17,	// start reading hmac data
		ReadHmac_wait		= 18,	// read hmac data
	/*}*/	UpdateSessionCount	= 19,	// update counter
	
		CmdRead_start		= 20,	// start reading command data
		CmdRead_wait		= 21,	// read command data
		FullRead		= 22,	// determine if read bytes == expected bytes
		Exec_setup0		= 23,	// setup execution
		Exec_setup1		= 24,	// setup execution
		Exec_start		= 25,	// start execution
		Exec_wait0		= 26,	// wait for execution
		Exec_wait1		= 27,	// wait for execution
		Exec_done		= 28,	// execution complete
		AssembleRsp		= 29,	// assemble response
		RspOut_start		= 30,	// start sending response to fifo
		RspOut_wait		= 31,	// send response to fifo
		Complete		= 32;	// complete
	reg	[5:0]	state, next_state;
	
	reg	[2:0]	it; // iterator for loops
	reg	[2:0]	nHandles, nHandles_comb;	// number of handles
	reg	[2:0]	nSessions, nSessions_comb;	// number of sessions
	reg		proc_ee, badRead, setup_mm;
	// proc_ee: is the command processed by the execution engine?
	// badRead: does the fully read number of bytes mismatch from the command header indicated cmdSize?
	// setup_mm: has the management module been setup? (it requires an extra pulse on initialization)
	
	// state machine register
	always @(posedge clock, negedge reset_n)
	begin
		if (!reset_n)
			state <= Idle;
		// "cheat" transfer to Exec_setup0 for malformed command data (more data than expected)
		else if (state > CmdDecode && state < FullRead && ci_addr > cmdSize[11:0] + 12'd1)
			state <= Exec_setup0;
		else
			state <= next_state;
	end
	
	// state machine transfer comb logic
	always @*
	begin
		case (state)
		
		// go to CmdHeader_start when cmdSend is received from fifo buffer
		Idle:
			next_state = cmdSend ? CmdHeader_start : Idle;
		// go to CmdHeader_wait
		CmdHeader_start:
			next_state = CmdHeader_wait;
		// go to CmdDecode when ci_done is received
		CmdHeader_wait:
			next_state = ci_done ? CmdDecode : CmdHeader_wait;
		// go to go to HandleCountCheck
		CmdDecode:
			next_state = HandleCountCheck;
		// go to ReadHandle_start while it < nHandles, otherwise transfer to CmdRead_start (if no sessions), or ReadAuthSize_start (if sessions)
		HandleCountCheck:
			next_state = it < nHandles ? ReadHandle_start : (nSessions == 3'd0 ? CmdRead_start : ReadAuthSize_start);
		// go to go to ReadHandle_wait
		ReadHandle_start:
			next_state = ReadHandle_wait;
		// go to UpdateHandleCount when ci_done is received
		ReadHandle_wait:
			next_state = ci_done ? UpdateHandleCount : ReadHandle_wait;
		// go to HandleCountCheck
		UpdateHandleCount:
			next_state = HandleCountCheck;
		// go to ReadAuthSize_wait
		ReadAuthSize_start:
			next_state = ReadAuthSize_wait;
		// go to SessionCountCheck when ci_done is received
		ReadAuthSize_wait:
			next_state = ci_done ? SessionCountCheck : ReadAuthSize_wait;
		// go to ReadSessionA_start while it < nSessions, otherwise CmdRead_start
		SessionCountCheck:
			next_state = it < nSessions ? ReadSessionA_start : CmdRead_start;
		// go to ReadSessionA_wait
		ReadSessionA_start:
			next_state = ReadSessionA_wait;
		// go to ReadNonce_start when ci_done is received
		ReadSessionA_wait:
			next_state = ci_done ? ReadNonce_start : ReadSessionA_wait;
		// go to ReadNonce_wait
		ReadNonce_start:
			next_state = ReadNonce_wait;
		// go to ReadSessionB_start when ci_done is received
		ReadNonce_wait:
			next_state = ci_done ? ReadSessionB_start : ReadNonce_wait;
		// go to ReadSessionB_wait
		ReadSessionB_start:
			next_state = ReadSessionB_wait;
		// go to ReadHmac_start when ci_done is received
		ReadSessionB_wait:
			next_state = ci_done ? ReadHmac_start : ReadSessionB_wait;
		// go to ReadHmac_wait
		ReadHmac_start:
			next_state = ReadHmac_wait;
		// go to UpdateSessionCount when ci_done is received
		ReadHmac_wait:
			next_state = ci_done ? UpdateSessionCount : ReadHmac_wait;
		// go to SessionCountCheck
		UpdateSessionCount:
			next_state = SessionCountCheck;
		// go to CmdRead_wait
		CmdRead_start:
			next_state = CmdRead_wait;
		// go to FullRead when ci_done is received
		CmdRead_wait:
			next_state = ci_done ? FullRead : CmdRead_wait;
		// go to Exec_setup0
		FullRead:
			next_state = Exec_setup0;
		// go to Exec_setup1
		Exec_setup0:
			next_state = Exec_setup1;
		// go to Exec_start
		Exec_setup1:
			next_state = Exec_start;
		// go to Exec_wait0
		Exec_start:
			next_state = Exec_wait0;
		// go to Exec_wait1 if the command is not processed by execution, or if response is ready
		Exec_wait0:
			next_state = (proc_ee & ~rspReady) ? Exec_wait0 : Exec_wait1;
		// go to Exec_done
		Exec_wait1:
			next_state = Exec_done;
		// go to AssembleRsp once execAck is received from fifo buffer
		Exec_done:
			next_state = execAck ? AssembleRsp : Exec_done;
		// go to RspOut_start
		AssembleRsp:
			next_state = RspOut_start;
		// go to RspOut_wait
		RspOut_start:
			next_state = RspOut_wait;
		// go to Complete when ci_done is received
		RspOut_wait:
			next_state = ci_done ? Complete : RspOut_wait;
		// go to Idle
		Complete:
			next_state = Idle;
		
		default:
			next_state = 5'hxx;
		
		endcase
	end
	
	// these signals are the same as their similarly named output wires,
	// but are internally handled by more convenient arrays
	reg	[31:0]	handle [0:2];
	reg	[31:0]	sessionHandle [0:2];
	reg	[15:0]	sessionNonceSize [0:2];
	reg	[11:0]	sessionNonceAddr [0:2];
	reg	[7:0]	sessionAttributes [0:2];
	reg	[15:0]	sessionHmacSize [0:2];
	reg	[11:0]	sessionHmacAddr [0:2];
	reg	[31:0]	responseCode_hold;
	reg		responseRec;
	
	// is the command code valid?
	wire		ccValid;
	
	// state machine sequential logic
	always @(posedge clock, negedge reset_n)
	begin
		// reset logic
		if (!reset_n)
		begin : ASYNC_RESET
			integer i;
			for(i=0; i<3; i=i+1)
			begin
				handle[i] <= 32'h00;
				sessionHandle[i] <= 32'h00;
				sessionNonceSize[i] <= 16'h00;
				sessionNonceAddr[i] <= 12'h00;
				sessionAttributes[i] <= 8'h00;
				sessionHmacSize[i] <= 16'h00;
				sessionHmacAddr[i] <= 12'h00;
			end
			
			responseCode_hold <= `TPM_RC_SUCCESS;
			responseRec <= 1'b0;
			commandCode <= 32'h00;
			commandParam <= 32'h00;
			expectedTag <= `TPM_ST_NO_SESSIONS;
			cmd_st <= 16'h00;
			rspByteOut <= 8'hFF;
			
			it <= 3'd0;
			nHandles <= 3'd7;
			nSessions <= 3'd7;
			authSize <= 32'h00;
			proc_ee <= 1'b0;
			setup_mm <= 1'b0;
			badRead <= 1'b1;
			
			ci_start <= 1'b0;
			ci_size <= 12'd00;
			ci_restart <= 1'b1;
		end
		else case (state)
			
			// reset logic
			Idle:
			begin : IDLE_RESET
		/* this reset logic section has been disabled so that the values can be seen within simulation for validation purposes
		   it may be enabled, but is not necessary for operation
				integer i;
				for(i=0; i<3; i=i+1)
				begin
					handle[i] <= 32'h00;
					sessionHandle[i] <= 32'h00;
					sessionNonceSize[i] <= 16'h00;
					sessionNonceAddr[i] <= 12'h00;
					sessionAttributes[i] <= 8'h00;
					sessionHmacSize[i] <= 16'h00;
					sessionHmacAddr[i] <= 12'h00;
				end
		*/		
				responseCode_hold <= `TPM_RC_SUCCESS;
				responseRec <= 1'b0;
				commandCode <= 32'h00;
				commandParam <= 32'h00;
				expectedTag <= `TPM_ST_NO_SESSIONS;
				cmd_st <= 16'h00;
				rspByteOut <= 8'hFF;
				
				it <= 3'd0;
				nHandles <= 3'd7;
				nSessions <= 3'd7;
				authSize <= 32'h00;
				proc_ee <= 1'b0;
				badRead <= 1'b1;
				
				ci_start <= 1'b0;
				ci_size <= 12'd00;
				ci_restart <= 1'b1;
			end
			
			// update the iterator in these states
			UpdateHandleCount, UpdateSessionCount:
				it <= it + 3'd1;
			
			// setup the transfer fsm to read the command header
			CmdHeader_start:
			begin
				ci_start <= 1'b1;
				ci_size <= 12'd10;
				ci_restart <= 1'b0;
			end
			
			// read in command header data
			CmdHeader_wait:
			begin
				ci_start <= 1'b0;
				case (ci_addr)
				
				12'h000: cmd_st[15:8] <= cmdIn;
				12'h001: cmd_st[7:0] <= cmdIn;
			
				12'h006: commandCode[31:24] <= cmdIn;
				12'h007: commandCode[23:16] <= cmdIn; 
				12'h008: commandCode[15:8] <= cmdIn;
				12'h009: commandCode[7:0] <= cmdIn;
				
				endcase
			end
			
			// set regs based on read command header data
			CmdDecode:
			begin
				ci_restart <= 1'b0;
				nHandles <= nHandles_comb;
				nSessions <= nSessions_comb;
				expectedTag <= nSessions_comb == 0 ? `TPM_ST_NO_SESSIONS : `TPM_ST_SESSIONS;
				proc_ee <= ~(commandCode == `TPM_CC_HierarchyControl
					|| commandCode == `TPM_CC_Startup);
			end
			
			// setup transfer fsm to read handle data
			ReadHandle_start:
			begin
				ci_start <= 1'b1;
				ci_size <= 12'd4;
			end
			
			// read in handle data
			ReadHandle_wait:
			begin
				ci_start <= 1'b0;
				case (ci_rel)
				
				12'h000: handle[it][31:24] <= cmdIn;
				12'h001: handle[it][23:16] <= cmdIn;
				12'h002: handle[it][15:8] <= cmdIn;
				12'h003: handle[it][7:0] <= cmdIn;
				
				endcase
			end
			
			// setup transfer fsm to read auth size
			ReadAuthSize_start:
			begin
				ci_start <= 1'b1;
				ci_size <= 12'd4;
				it <= 3'd0;
			end
			
			// read in auth size
			ReadAuthSize_wait:
			begin
				ci_start <= 1'b0;
				case (ci_rel)
				
				12'h000: authSize[31:24] <= cmdIn;
				12'h001: authSize[23:16] <= cmdIn;
				12'h002: authSize[15:8] <= cmdIn;
				12'h003: authSize[7:0] <= cmdIn;
				
				endcase
			end
			
			// setup transfer fsm to read session data
			ReadSessionA_start:
			begin
				ci_start <= 1'b1;
				ci_size <= 12'd6;
			end
			
			// read in session data
			ReadSessionA_wait:
			begin
				ci_start <= 1'b0;
				case (ci_rel)
				
				12'h000: sessionHandle[it][31:24] <= cmdIn;
				12'h001: sessionHandle[it][23:16] <= cmdIn;
				12'h002: sessionHandle[it][15:8] <= cmdIn;
				12'h003: sessionHandle[it][7:0] <= cmdIn;
				12'h004: sessionNonceSize[it][15:8] <= cmdIn;
				12'h005: sessionNonceSize[it][7:0] <= cmdIn;
				
				endcase
			end
			
			// setup transfer fsm to read nonce data
			ReadNonce_start:
			begin
				ci_start <= 1'b1;
				ci_size <= sessionNonceSize[it][11:0];
				sessionNonceAddr[it] <= ci_addr;
			end
			
			// read in nonce data
			ReadNonce_wait:
				ci_start <= 1'b0;
			
			// setup transfer fsm to read session data
			ReadSessionB_start:
			begin
				ci_start <= 1'b1;
				ci_size <= 12'd3;
			end
			
			// read session data
			ReadSessionB_wait:
			begin
				ci_start <= 1'b0;
				case (ci_rel)
				
				12'h000: sessionAttributes[it] <= cmdIn;
				12'h001: sessionHmacSize[it][15:8] <= cmdIn;
				12'h002: sessionHmacSize[it][7:0] <= cmdIn;
				
				endcase
			end
			
			// setup transfer fsm to read hmac
			ReadHmac_start:
			begin
				ci_start <= 1'b1;
				ci_size <= sessionHmacSize[it][11:0];
				sessionHmacAddr[it] <= ci_addr;
			end
			
			// read in hmac data
			ReadHmac_wait:
				ci_start <= 1'b0;
			
			// setup transfer fsm to read remaining command data (parameters)
			CmdRead_start:
			begin
				ci_start <= 1'b1;
				ci_size <= cmdSize[11:0] - ci_addr;
			end
			
			// read in remaining command data (parameters)
			CmdRead_wait:
			begin
				ci_start <= 1'b0;
				case (ci_rel)
				
				// due to the way the management module is setup (the only module that currently utilizes command parameters),
				// the commandParam output uses different bytes depending on the command code
				12'h000: 
				begin
					if (commandCode == `TPM_CC_Startup)
						commandParam[15:8] <= cmdIn;
					else
						commandParam[39:32] <= cmdIn;
				end
				12'h001:
				begin
					if (commandCode == `TPM_CC_Startup)
						commandParam[7:0] <= cmdIn;
					else
						commandParam[31:24] <= cmdIn;
				end
				12'h002:
				begin
					if (commandCode != `TPM_CC_Startup)
						commandParam[23:16] <= cmdIn;
				end
				12'h003:
				begin
					if (commandCode != `TPM_CC_Startup)
						commandParam[15:8] <= cmdIn;
				end
				12'h004:
				begin
					if (commandCode != `TPM_CC_Startup)
						commandParam[7:0] <= cmdIn;
				end
				
				endcase
			end
			
			// determine if the command was read correctly
			FullRead:
				badRead <= 1'b0;
			
			// execution setup
			Exec_setup0:
				ci_restart <= 1'b1;
			
			// execution setup
			Exec_setup1:
				ci_restart <= 1'b0;
			
			// execution start
			Exec_start:
				setup_mm <= 1'b1;
			
			// wait for execution response, hold response code once it is received
			Exec_wait0:
			begin
				if (!responseRec)
					responseRec <= rspReady;
				responseCode_hold <= responseCode;
			end
			
			// execution done, store response code if the processor was execution engine
			Exec_done:
				if (!proc_ee)
					responseCode_hold <= responseCode;
			
			// currently, all there is to assemble of the response is the tag
			AssembleRsp:
			begin
				if (responseCode != `TPM_RC_SUCCESS)
					cmd_st <= `TPM_ST_NO_SESSIONS;
			end
			
			// setup transfer fsm for sending response
			RspOut_start:
			begin
				ci_start <= 1'b1;
				ci_size <= 12'd10;
			end
			
			// send out response
			RspOut_wait:
			begin
				ci_start <= 1'b0;
				case (ci_addr)
				
				12'h000:	rspByteOut <= cmd_st[15:8];
				12'h001:	rspByteOut <= cmd_st[7:0];
				12'h002:	rspByteOut <= 8'h00;
				12'h003:	rspByteOut <= 8'h00;
				12'h004:	rspByteOut <= 8'h00;
				12'h005:	rspByteOut <= 8'h0A;
				12'h006:	rspByteOut <= responseCode_hold[31:24];
				12'h007:	rspByteOut <= responseCode_hold[23:16];
				12'h008:	rspByteOut <= responseCode_hold[15:8];
				12'h009:	rspByteOut <= responseCode_hold[7:0];
				
				endcase
			end
			
		endcase
			
	end
	
	// state machine combinational logic
	always @*
	begin
		// base logic
		cmdAddr = 12'hFFF;
		cmdWren_n = 1'b1;
		cmdIn = 8'hFF;
		
		//debug
		rspAddr = cmdAddr;
		rspWren_n = cmdWren_n;
		rspIn = cmdIn;
		
		case (state)
		
		// inactive logic
		Idle, Complete:
		begin
			cmdAddr = 12'hFFF;
			cmdWren_n = 1'b1;
			cmdIn = 8'hFF;
			
			// debug
			rspAddr = cmdAddr;
			rspWren_n = cmdWren_n;
			rspIn = cmdIn;
		end
		
		// command in states
		default:
		begin
			cmdAddr = ci_addr;
			cmdWren_n = ci_wren;
			cmdIn = cmdByteIn;
			rspAddr = cmdAddr;
			rspWren_n = cmdWren_n;
			rspIn = cmdIn;
		end
		
		// response in states
		Exec_setup0, Exec_setup1, Exec_start,
		Exec_wait0, Exec_wait1, Exec_done,
		AssembleRsp, RspOut_start, RspOut_wait:
		begin
			rspAddr = ci_addr;
			rspWren_n = 1'b1;
		end
		
		endcase
	end
	
	// static assignments
	assign	cmdOutAddr = cmdAddr;
	assign	rspOutAddr = rspAddr;
	assign	rspSend = ci_wren;
	
	assign	cmdDone = state == Exec_start;
	assign	rspDone = state == Complete;
	
	assign	execDone = state == Exec_done;
	assign	commandTag = cmd_st;
	
	// combinational logic for execStart
	always @*
	begin
		if (proc_ee)
			execStart = state == Exec_start;
		else
			execStart =
				state == Exec_wait0 || state == Exec_wait1 ||
				~setup_mm && (state == Exec_setup0 || state == Exec_setup1);
	end
	
	// placeholder
	assign	rspSize = 32'd10;
	
	// combinational logic to determine number of handles, sessions; ccValid (from spec)
	always @* case (commandCode)
		`TPM_CC_Startup:			{ nHandles_comb, nSessions_comb } = { 3'd0, 3'd0 };
		`TPM_CC_Shutdown:			{ nHandles_comb, nSessions_comb } = { 3'd0, 3'd0 };
		`TPM_CC_SelfTest:			{ nHandles_comb, nSessions_comb } = { 3'd0, 3'd0 };
		`TPM_CC_IncrementalSelfTest:		{ nHandles_comb, nSessions_comb } = { 3'd0, 3'd0 };
		`TPM_CC_GetTestResult:			{ nHandles_comb, nSessions_comb } = { 3'd0, 3'd0 };
		`TPM_CC_StirRandom:			{ nHandles_comb, nSessions_comb } = { 3'd0, 3'd0 };
		`TPM_CC_GetRandom:			{ nHandles_comb, nSessions_comb } = { 3'd0, 3'd0 };
		`TPM_CC_GetCapability:			{ nHandles_comb, nSessions_comb } = { 3'd0, 3'd0 };
		`TPM_CC_FirmwareRead:			{ nHandles_comb, nSessions_comb } = { 3'd0, 3'd0 };
		`TPM_CC_GetTime:			{ nHandles_comb, nSessions_comb } = { 3'd2, 3'd2 }; // ***
		`TPM_CC_ReadClock:			{ nHandles_comb, nSessions_comb } = { 3'd0, 3'd0 };
		`TPM_CC_ECC_Parameters:			{ nHandles_comb, nSessions_comb } = { 3'd0, 3'd0 };
		`TPM_CC_TestParms:			{ nHandles_comb, nSessions_comb } = { 3'd0, 3'd0 };
		`TPM_CC_Hash:				{ nHandles_comb, nSessions_comb } = { 3'd0, 3'd0 };
		`TPM_CC_PCR_Read:			{ nHandles_comb, nSessions_comb } = { 3'd0, 3'd0 };
		`TPM_CC_GetCommandAuditDigest:		{ nHandles_comb, nSessions_comb } = { 3'd2, 3'd2 }; // ***
		`TPM_CC_GetSessionAuditDigest:		{ nHandles_comb, nSessions_comb } = { 3'd3, 3'd2 }; // ***
		`TPM_CC_NV_ReadPublic:			{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd0 }; // ***
		`TPM_CC_AC_GetCapability:		{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd0 }; // ***
		
		`TPM_CC_Clear:				{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd1 };
		`TPM_CC_HierarchyControl:		{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd1 };
		`TPM_CC_ClearControl:			{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd1 };
		`TPM_CC_ClockSet:			{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd1 };
		`TPM_CC_ClockRateAdjust:		{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd1 };
		`TPM_CC_HierarchyChangeAuth:		{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd1 };
		`TPM_CC_NV_DefineSpace:			{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd1 };
		`TPM_CC_PCR_Allocate:			{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd1 };
		`TPM_CC_PCR_SetAuthPolicy:		{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd1 };
		`TPM_CC_PP_Commands:			{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd1 };
		`TPM_CC_SetPrimaryPolicy:		{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd1 };
		`TPM_CC_SetAlgorithmSet:		{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd1 };
		`TPM_CC_SetCommandCodeAuditStatus:	{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd1 };
		`TPM_CC_CreatePrimary:			{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd1 };
		`TPM_CC_NV_GlobalWriteLock:		{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd1 };
		`TPM_CC_NV_Increment:			{ nHandles_comb, nSessions_comb } = { 3'd2, 3'd1 }; // ***
		`TPM_CC_NV_SetBits:			{ nHandles_comb, nSessions_comb } = { 3'd2, 3'd1 }; // ***
		`TPM_CC_NV_Extend:			{ nHandles_comb, nSessions_comb } = { 3'd2, 3'd1 }; // ***
		`TPM_CC_NV_WriteLock:			{ nHandles_comb, nSessions_comb } = { 3'd2, 3'd1 }; // ***
		`TPM_CC_DictionaryAttackLockReset:	{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd1 };
		`TPM_CC_DictionaryAttackParameters:	{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd1 };
		`TPM_CC_NV_ChangeAuth:			{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd1 };
		`TPM_CC_PCR_Event:			{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd1 };
		`TPM_CC_PCR_Reset:			{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd1 };
		`TPM_CC_PCR_Extend:			{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd1 };
		`TPM_CC_PCR_SetAuthValue:		{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd1 };
		`TPM_CC_SequenceComplete:		{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd1 };
		`TPM_CC_EventSequenceComplete:		{ nHandles_comb, nSessions_comb } = { 3'd2, 3'd2 }; // ***
		`TPM_CC_FlushContext:			{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd0 };
		`TPM_CC_Create:				{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd1 };
		`TPM_CC_Load:				{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd1 };
		`TPM_CC_Unseal:				{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd1 };
		`TPM_CC_Sign:				{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd1 };
		`TPM_CC_ReadPublic:			{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd0 };
		`TPM_CC_ECDH_KeyGen: 			{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd0 };
		`TPM_CC_RSA_Decrypt:			{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd0 };
		`TPM_CC_ECDH_ZGen: 			{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd1 };
		`TPM_CC_ContextSave:			{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd0 };
		`TPM_CC_ContextLoad:			{ nHandles_comb, nSessions_comb } = { 3'd0, 3'd0 }; // ***
		`TPM_CC_NV_Read:			{ nHandles_comb, nSessions_comb } = { 3'd2, 3'd1 }; // ***
		`TPM_CC_NV_ReadLock:			{ nHandles_comb, nSessions_comb } = { 3'd2, 3'd1 }; // ***
		`TPM_CC_ObjectChangeAuth:		{ nHandles_comb, nSessions_comb } = { 3'd2, 3'd1 }; // ***
		`TPM_CC_PolicySecret:			{ nHandles_comb, nSessions_comb } = { 3'd2, 3'd1 }; // ***
		`TPM_CC_Rewrap:				{ nHandles_comb, nSessions_comb } = { 3'd2, 3'd1 }; // ***
		`TPM_CC_RSA_Encrypt:			{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd0 };
		`TPM_CC_VerifySignature:		{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd0 };
		`TPM_CC_Commit:				{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd1 };
		`TPM_CC_EC_Ephemeral:			{ nHandles_comb, nSessions_comb } = { 3'd0, 3'd0 }; // ***
		`TPM_CC_CreateLoaded:			{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd1 };
		`TPM_CC_AC_Send:			{ nHandles_comb, nSessions_comb } = { 3'd3, 3'd2 }; // ***
		
		`TPM_CC_NV_UndefineSpace:		{ nHandles_comb, nSessions_comb } = { 3'd2, 3'd1 };
		`TPM_CC_NV_UndefineSpaceSpecial:	{ nHandles_comb, nSessions_comb } = { 3'd2, 3'd2 };
		`TPM_CC_EvictControl:			{ nHandles_comb, nSessions_comb } = { 3'd2, 3'd1 };
		`TPM_CC_ChangeEPS:			{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd1 }; // ***
		`TPM_CC_ChangePPS:			{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd1 }; // ***
		`TPM_CC_NV_Write:			{ nHandles_comb, nSessions_comb } = { 3'd2, 3'd1 };
		`TPM_CC_StartAuthSession:		{ nHandles_comb, nSessions_comb } = { 3'd2, 3'd0 };
		`TPM_CC_ActivateCredential:		{ nHandles_comb, nSessions_comb } = { 3'd2, 3'd2 };
		`TPM_CC_Certify:			{ nHandles_comb, nSessions_comb } = { 3'd2, 3'd2 };
		`TPM_CC_PolicyNV:			{ nHandles_comb, nSessions_comb } = { 3'd3, 3'd1 }; // ***
		`TPM_CC_CertifyCreation:		{ nHandles_comb, nSessions_comb } = { 3'd2, 3'd1 };
		`TPM_CC_Duplicate:			{ nHandles_comb, nSessions_comb } = { 3'd2, 3'd1 };
		`TPM_CC_Quote:				{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd1 }; // ***
		`TPM_CC_HMAC:				{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd1 }; // ***
		`TPM_CC_Import:				{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd1 }; // ***
		`TPM_CC_PolicySigned:			{ nHandles_comb, nSessions_comb } = { 3'd2, 3'd0 };
		`TPM_CC_EncryptDecrypt: 		{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd1 }; // ***
		`TPM_CC_MakeCredential: 		{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd0 }; // ***
		`TPM_CC_PolicyAuthorize: 		{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd0 }; // ***
		`TPM_CC_PolicyAuthValue: 		{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd0 }; // ***
		`TPM_CC_PolicyCommandCode: 		{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd0 }; // ***
		`TPM_CC_PolicyCounterTimer:		{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd0 }; // ***
		`TPM_CC_PolicyCpHash:			{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd0 }; // ***
		`TPM_CC_PolicyLocality:			{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd0 }; // ***
		`TPM_CC_PolicyNameHash:			{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd0 }; // ***
		`TPM_CC_PolicyOR:			{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd0 }; // ***
		`TPM_CC_PolicyTicket:			{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd0 }; // ***
		`TPM_CC_PolicyPCR:			{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd0 }; // ***
		`TPM_CC_PolicyRestart:			{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd0 }; // ***
		`TPM_CC_PolicyPhysicalPresence: 	{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd0 }; // ***
		`TPM_CC_PolicyDuplicationSelect:	{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd0 }; // ***
		`TPM_CC_PolicyGetDigest:		{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd0 }; // ***
		`TPM_CC_PolicyPassword:			{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd0 }; // ***
		`TPM_CC_ZGen_2Phase: 			{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd1 }; // ***
		`TPM_CC_PolicyNvWritten:		{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd0 }; // ***
		`TPM_CC_PolicyTemplate:			{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd0 }; // ***
		`TPM_CC_PolicyAuthorizeNV:		{ nHandles_comb, nSessions_comb } = { 3'd3, 3'd1 }; // ***
		`TPM_CC_EncryptDecrypt2:		{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd1 }; // ***
		`TPM_CC_Policy_AC_SendSelect:		{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd0 }; // ***
		`TPM_CC_NV_Certify:			{ nHandles_comb, nSessions_comb } = { 3'd3, 3'd2 }; // ***
	
		`TPM_CC_HashSequenceStart:		{ nHandles_comb, nSessions_comb } = { 3'd0, 3'd0 };
		`TPM_CC_HMAC_Start:			{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd1 }; // ***
		`TPM_CC_SequenceUpdate:			{ nHandles_comb, nSessions_comb } = { 3'd1, 3'd1 }; // ***
		`TPM_CC_LoadExternal:			{ nHandles_comb, nSessions_comb } = { 3'd0, 3'd0 };
		
		// default case represents an undefined command code
		default:				{ nHandles_comb, nSessions_comb } = { 3'd7, 3'd7 };
		
	endcase
	
	assign	ccValid = nHandles_comb != 3'd7;
	
	// logic to determine which sessions index values are valid
	always @(posedge clock, negedge reset_n)
	begin
		if (!reset_n)
			{ sessionValid0, sessionValid1, sessionValid2 } = { 3'b000 };
		else if (badRead)
			{ sessionValid0, sessionValid1, sessionValid2 } = { 3'b000 };
		else case (nSessions)
			
			3'd0:	{ sessionValid0, sessionValid1, sessionValid2 } = { 3'b000 };
			3'd1:	{ sessionValid0, sessionValid1, sessionValid2 } = { 3'b100 };
			3'd2:	{ sessionValid0, sessionValid1, sessionValid2 } = { 3'b110 };
			3'd3:	{ sessionValid0, sessionValid1, sessionValid2 } = { 3'b111 };
			default:{ sessionValid0, sessionValid1, sessionValid2 } = { 3'b000 };
		
		endcase
	end
	
	// static assignments for outputs
	assign	handle0 = handle[0];
	assign	handle1 = handle[1];
	assign	handle2 = handle[2];
	assign	sessionHandle0 = sessionHandle[0];
	assign	sessionHandle1 = sessionHandle[1];
	assign	sessionHandle2 = sessionHandle[2];
	assign	sessionNonceSize0 = sessionNonceSize[0];
	assign	sessionNonceSize1 = sessionNonceSize[1];
	assign	sessionNonceSize2 = sessionNonceSize[2];
	assign	sessionNonceAddr0 = sessionNonceAddr[0];
	assign	sessionNonceAddr1 = sessionNonceAddr[1];
	assign	sessionNonceAddr2 = sessionNonceAddr[2];
	assign	sessionAttributes0 = sessionAttributes[0];
	assign	sessionAttributes1 = sessionAttributes[1];
	assign	sessionAttributes2 = sessionAttributes[2];
	assign	sessionHmacSize0 = sessionHmacSize[0];
	assign	sessionHmacSize1 = sessionHmacSize[1];
	assign	sessionHmacSize2 = sessionHmacSize[2];
	assign	sessionHmacAddr0 = sessionHmacAddr[0];
	assign	sessionHmacAddr1 = sessionHmacAddr[1];
	assign	sessionHmacAddr2 = sessionHmacAddr[2];
	
endmodule


// Module to contain transfer state machine
// Handles logic to transfer data from buffer to buffer (between fifo and crb)
module	CRB_TRANS
(
	input			clock,
	input			reset_n,
	
	input			start,		// start transfer
	input			restart,	// reset address
	output			done,		// transfer complete
	
	input		[11:0]	size_in,	// size of transfer
	output	reg	[11:0]	addr,		// address
	output			wren_n,		// write enable active low
	
	output		[11:0]	rel_addr	// relative address
);
	// local size, previous transfer size
	reg	[11:0]	size, prev_index;
	
	// state machine
	localparam
		Idle		= 0,	// wait for start
		Setup		= 1,	// setup
		Write0		= 2,	// write
		Write1		= 3,	// write (two clock cycles per write)
		UpdateAddr	= 4,	// update address
		Complete	= 5;	// completed
	reg	[2:0]	state, next_state;
	
	// state machine reg
	always @(posedge clock, negedge reset_n)
	begin
		if (!reset_n)
			state <= Idle;
		else
			state <= next_state;
	end
	
	// state machine next state combinational logic
	always @*
	begin
		case (state)
		
		// go to Setup when start is received
		Idle:
			next_state = start ? Setup : Idle;
		// go to Write0 if size_in is not 0
		Setup:
			next_state = size_in == 12'd0 ? Complete : Write0;
		// go to Write1
		Write0:
			next_state = Write1;
		// go to UpdateAddr
		Write1:
			next_state = UpdateAddr;
		// go to Write0 if addr != size, else Complete
		UpdateAddr:
			next_state = addr == size ? Complete : Write0;
		// go to Idle
		Complete:
			next_state = Idle;
		
		default:
			next_state = 3'hx;
	
		endcase
	end
	
	// state machine sequential logic
	always @(posedge clock, negedge reset_n)
	begin
		// reset logic
		if (!reset_n)
		begin
			addr <= 12'h000;
			size <= 12'h000;
			prev_index <= 12'h000;
		end
		// restart logic
		else if (restart)
		begin
			addr <= 12'h000;
			size <= 12'h000;
			prev_index <= 12'h000;
		end
		else case (state)
		
		// prev_index is updated to the previous size
		Idle:
			prev_index <= size;
		// size is incremented by input size
		Setup:
			size <= size + size_in;
		// addr is incremented
		UpdateAddr:
			addr <= addr + 12'h1;
		// addr is decremented to re-adjust
		Complete:
			addr <= addr - 12'h1;
		
		endcase
	end
	
	// static assignments
	assign	wren_n = state != Write1;
	assign	done = state == Complete;
	assign	rel_addr = addr - prev_index;
	
endmodule