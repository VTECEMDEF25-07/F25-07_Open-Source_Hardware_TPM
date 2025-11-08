`include "TPM_TYPES.vh"

module	TPM_CRB
(
	input			clock,
	input			reset_n,
	
	input		[7:0]	locality,
	input			cmdAbort,
	
	input		[31:0]	cmdSize,
	output		[31:0]	rspSize,
	
	input			cmdSend,
	output			rspSend,
	
	output			cmdDone,
	output			rspDone,
	
	output		[11:0]	cmdOutAddr,
	output		[11:0]	rspOutAddr,
	
	input		[7:0]	cmdByteIn,
	output	reg	[7:0]	rspByteOut,
	
	output			execDone,
	output	reg		execStart,
	input			execAck,
	input			rspReady,
	
	output	reg	[31:0]	commandCode,
	output		[15:0]	commandTag,
	input		[31:0]	responseCode,
	output	reg	[39:0]	commandParam,
	output	reg	[15:0]	expectedTag,
	
	output		[31:0]	handle0, handle1, handle2,
	output		[31:0]	sessionHandle0, sessionHandle1, sessionHandle2,
	output		[15:0]	sessionNonceSize0, sessionNonceSize1, sessionNonceSize2,
	output		[11:0]	sessionNonceAddr0, sessionNonceAddr1, sessionNonceAddr2,
	output		[7:0]	sessionAttributes0, sessionAttributes1, sessionAttributes2,
	output		[15:0]	sessionHmacSize0, sessionHmacSize1, sessionHmacSize2,
	output		[11:0]	sessionHmacAddr0, sessionHmacAddr1, sessionHmacAddr2,
	output	reg	[31:0]	authSize,
	
	output	reg		sessionValid0, sessionValid1, sessionValid2
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
	
	reg		ci_start;
	wire		ci_done;
	wire	[11:0]	ci_addr;
	reg	[11:0]	ci_size;
	reg		ci_restart;
	wire		ci_wren;
	wire	[11:0]	ci_rel;
	
	CRB_TRANS fsm_ci
	(
		.clock(clock), .reset_n(reset_n),
		.start(ci_start), .restart(ci_restart), .done(ci_done),
		.size_in(ci_size), .addr(ci_addr), .wren_n(ci_wren),
		.rel_addr(ci_rel)
	);
	
	
	
	localparam
		Idle			= 0,
		CmdHeader_start		= 1,
		CmdHeader_wait		= 2,
		CmdDecode		= 3,
		HandleCountCheck	= 4,	// {
		ReadHandle_start	= 5,
		ReadHandle_wait		= 6,
		UpdateHandleCount	= 7,	// }
		ReadAuthSize_start	= 8,
		ReadAuthSize_wait	= 9,
		SessionCountCheck	= 10,	// {
		ReadSessionA_start	= 11,
		ReadSessionA_wait	= 12,
		ReadNonce_start		= 13,
		ReadNonce_wait		= 14,
		ReadSessionB_start	= 15,
		ReadSessionB_wait	= 16,
		ReadHmac_start		= 17,
		ReadHmac_wait		= 18,
		UpdateSessionCount	= 19,	// }
		CmdRead_start		= 20,
		CmdRead_wait		= 21,
		FullRead		= 22,
		Exec_setup0		= 23,
		Exec_setup1		= 24,
		Exec_start		= 25,
		Exec_wait0		= 26,
		Exec_wait1		= 27,
		Exec_done		= 28,
		AssembleRsp		= 29,
		RspOut_start		= 30,
		RspOut_wait		= 31,
		Complete		= 32;
	reg	[5:0]	state, next_state;
	
	reg	[2:0]	it;
	reg	[2:0]	nHandles, nHandles_comb;
	reg	[2:0]	nSessions, nSessions_comb;
	reg		proc_ee, badRead, setup_mm;
	
	always @(posedge clock, negedge reset_n)
	begin
		if (!reset_n)
			state <= Idle;
		else if (state > CmdDecode && state < FullRead && ci_addr > cmdSize[11:0] + 12'd1)
			state <= Exec_setup0;
		else
			state <= next_state;
	end
	
	always @*
	begin
		case (state)
		
		Idle:
			next_state = cmdSend ? CmdHeader_start : Idle;
		CmdHeader_start:
			next_state = CmdHeader_wait;
		CmdHeader_wait:
			next_state = ci_done ? CmdDecode : CmdHeader_wait;
		CmdDecode:
			next_state = HandleCountCheck;
		HandleCountCheck:
			next_state = it < nHandles ? ReadHandle_start : (nSessions == 3'd0 ? CmdRead_start : ReadAuthSize_start);
		ReadHandle_start:
			next_state = ReadHandle_wait;
		ReadHandle_wait:
			next_state = ci_done ? UpdateHandleCount : ReadHandle_wait;
		UpdateHandleCount:
			next_state = HandleCountCheck;
		ReadAuthSize_start:
			next_state = ReadAuthSize_wait;
		ReadAuthSize_wait:
			next_state = ci_done ? SessionCountCheck : ReadAuthSize_wait;
		SessionCountCheck:
			next_state = it < nSessions ? ReadSessionA_start : CmdRead_start;
		ReadSessionA_start:
			next_state = ReadSessionA_wait;
		ReadSessionA_wait:
			next_state = ci_done ? ReadNonce_start : ReadSessionA_wait;
		ReadNonce_start:
			next_state = ReadNonce_wait;
		ReadNonce_wait:
			next_state = ci_done ? ReadSessionB_start : ReadNonce_wait;
		ReadSessionB_start:
			next_state = ReadSessionB_wait;
		ReadSessionB_wait:
			next_state = ci_done ? ReadHmac_start : ReadSessionB_wait;
		ReadHmac_start:
			next_state = ReadHmac_wait;
		ReadHmac_wait:
			next_state = ci_done ? UpdateSessionCount : ReadHmac_wait;
		UpdateSessionCount:
			next_state = SessionCountCheck;
		CmdRead_start:
			next_state = CmdRead_wait;
		CmdRead_wait:
			next_state = ci_done ? FullRead : CmdRead_wait;
		FullRead:
			next_state = Exec_setup0;
		Exec_setup0:
			next_state = Exec_setup1;
		Exec_setup1:
			next_state = Exec_start;
		Exec_start:
			next_state = Exec_wait0;
		Exec_wait0:
			next_state = (proc_ee & ~rspReady) ? Exec_wait0 : Exec_wait1;
		Exec_wait1:
			next_state = Exec_done;
		Exec_done:
			next_state = execAck ? AssembleRsp : Exec_done;
		AssembleRsp:
			next_state = RspOut_start;
		RspOut_start:
			next_state = RspOut_wait;
		RspOut_wait:
			next_state = ci_done ? Complete : RspOut_wait;
		Complete:
			next_state = Idle;
		
		default:
			next_state = 5'hxx;
		
		endcase
	end
	
	reg	[31:0]	handle [0:2];
	reg	[31:0]	sessionHandle [0:2];
	reg	[15:0]	sessionNonceSize [0:2];
	reg	[11:0]	sessionNonceAddr [0:2];
	reg	[7:0]	sessionAttributes [0:2];
	reg	[15:0]	sessionHmacSize [0:2];
	reg	[11:0]	sessionHmacAddr [0:2];
	reg	[31:0]	responseCode_hold;
	reg		responseRec;
	
	wire		ccValid;
	
	always @(posedge clock, negedge reset_n)
	begin
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
			
			Idle:
			begin : IDLE_RESET
		/*		integer i;
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
			
			UpdateHandleCount, UpdateSessionCount:
				it <= it + 3'd1;
			
			CmdHeader_start:
			begin
				ci_start <= 1'b1;
				ci_size <= 12'd10;
				ci_restart <= 1'b0;
			end
			
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
			
			CmdDecode:
			begin
				ci_restart <= 1'b0;
				nHandles <= nHandles_comb;
				nSessions <= nSessions_comb;
				expectedTag <= nSessions_comb == 0 ? `TPM_ST_NO_SESSIONS : `TPM_ST_SESSIONS;
				proc_ee <= ~(commandCode == `TPM_CC_HierarchyControl
					|| commandCode == `TPM_CC_Startup);
			end
			
			ReadHandle_start:
			begin
				ci_start <= 1'b1;
				ci_size <= 12'd4;
			end
			
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
			
			ReadAuthSize_start:
			begin
				ci_start <= 1'b1;
				ci_size <= 12'd4;
				it <= 3'd0;
			end
			
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
			
			ReadSessionA_start:
			begin
				ci_start <= 1'b1;
				ci_size <= 12'd6;
			end
			
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
			
			ReadNonce_start:
			begin
				ci_start <= 1'b1;
				ci_size <= sessionNonceSize[it][11:0];
				sessionNonceAddr[it] <= ci_addr;
			end
			
			ReadNonce_wait:
				ci_start <= 1'b0;
			
			ReadSessionB_start:
			begin
				ci_start <= 1'b1;
				ci_size <= 12'd3;
			end
			
			ReadSessionB_wait:
			begin
				ci_start <= 1'b0;
				case (ci_rel)
				
				12'h000: sessionAttributes[it] <= cmdIn;
				12'h001: sessionHmacSize[it][15:8] <= cmdIn;
				12'h002: sessionHmacSize[it][7:0] <= cmdIn;
				
				endcase
			end
			
			ReadHmac_start:
			begin
				ci_start <= 1'b1;
				ci_size <= sessionHmacSize[it][11:0];
				sessionHmacAddr[it] <= ci_addr;
			end
			
			ReadHmac_wait:
				ci_start <= 1'b0;
			
			CmdRead_start:
			begin
				ci_start <= 1'b1;
				ci_size <= cmdSize[11:0] - ci_addr;
			end
			
			CmdRead_wait:
			begin
				ci_start <= 1'b0;
				case (ci_rel)
				
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
			
			FullRead:
				badRead <= 1'b0;
			
			Exec_setup0:
				ci_restart <= 1'b1;
			
			Exec_setup1:
				ci_restart <= 1'b0;
			
			Exec_start:
				setup_mm <= 1'b1;
			
			Exec_wait0:
			begin
				if (!responseRec)
					responseRec <= rspReady;
				responseCode_hold <= responseCode;
			end
			
			Exec_done:
				if (!proc_ee)
					responseCode_hold <= responseCode;
			
			AssembleRsp:
			begin
				if (responseCode != `TPM_RC_SUCCESS)
					cmd_st <= `TPM_ST_NO_SESSIONS;
			end
			
			RspOut_start:
			begin
				ci_start <= 1'b1;
				ci_size <= 12'd10;
			end
			
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
	
	always @*
	begin
		cmdAddr = 12'hFFF;
		cmdWren_n = 1'b1;
		cmdIn = 8'hFF;
		
		//debug
		rspAddr = cmdAddr;
		rspWren_n = cmdWren_n;
		rspIn = cmdIn;
		
		case (state)
		
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
		
		default:
		begin
			cmdAddr = ci_addr;
			cmdWren_n = ci_wren;
			cmdIn = cmdByteIn;
			rspAddr = cmdAddr;
			rspWren_n = cmdWren_n;
			rspIn = cmdIn;
		end
		
		Exec_setup0, Exec_setup1, Exec_start,
		Exec_wait0, Exec_wait1, Exec_done,
		AssembleRsp, RspOut_start, RspOut_wait:
		begin
			rspAddr = ci_addr;
			rspWren_n = 1'b1;
		end
		
		endcase
	end
	
//	assign	ci_start = state == CmdIn_start || state == RspOut_start;
	
	assign	cmdOutAddr = cmdAddr;
	assign	rspOutAddr = rspAddr;
	assign	rspSend = ci_wren;
//	assign	rspByteOut = rspOut;
	assign	cmdDone = state == Exec_start;
	assign	rspDone = state == Complete;
//	assign	execStart =
//		state == Exec_wait0 || state == Exec_wait1 ||
//		~setup_mm && (state == Exec_setup0 || state == Exec_setup1);
	assign	execDone = state == Exec_done;
	assign	commandTag = cmd_st;
	
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

module	CRB_TRANS
(
	input			clock,
	input			reset_n,
	
	input			start,
	input			restart,
	output			done,
	
	input		[11:0]	size_in,
	output	reg	[11:0]	addr,
	output			wren_n,
	
	output		[11:0]	rel_addr
);
	
	reg	[11:0]	size, prev_index;
	
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
			next_state = size_in == 12'd0 ? Complete : Write0;
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
			prev_index <= 12'h000;
		end
		else if (restart)
		begin
			addr <= 12'h000;
			size <= 12'h000;
			prev_index <= 12'h000;
		end
		else case (state)
		
		Idle:
			prev_index <= size;
		
		Setup:
			size <= size + size_in;
		
		UpdateAddr:
			addr <= addr + 12'h1;
		
		Complete:
			addr <= addr - 12'h1;
		
		endcase
	end
	
	assign	wren_n = state != Write1;
	assign	done = state == Complete;
	assign	rel_addr = addr - prev_index;
	
endmodule