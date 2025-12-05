// TPM_REG_SPACE.v
// modules:
//	TPM_REG_SPACE
//
// Authors:
//	Ian Sizemore (idsizemore@vt.edu)
//
// Date: 11/6/25
//
// General Description:
//	This module is the central module of the I/O module.
//	It is referred to as "frs" in comments ("fifo register space", from the spec).
//	This module contains the state machine for the I/O module, a state machine for handling locality,
//	handles the fifo register space, handles interrupts, and contains the instantiation of the fifo buffer.
//	Note: comments and net names containing "IDS" are debug features (a 'todo' which needs change/removal in the future).
//		Some of these have already been removed, and other that remain may not serve any debug purpose anymore.
//		Since the project is working and ready for submission, I'm going to leave these debug features present to
//		avoid breaking something on accident.

`define READ 1
`define WRITE 0

module	TPM_REG_SPACE
(
	input			clock,
	input			reset_n,
	
	// connections to transaction handler
	input			t_req,		// SPI transaction request
	input			t_dir,		// SPI transaction direction (READ = 1; WRITE = 0)
	input		[5:0]	t_size,		// SPI transaction size
	input		[15:0]	t_address,	// SPI transaction address
	input		[15:0]	t_baseAddr,	// SPI transaction starting address
	input		[7:0]	t_writeByte,	// SPI transaction write byte
	output	reg	[7:0]	t_readByte,	// SPI transaction read byte
	input			updateAddr,	// singal to update address, used for timing fifo buffer accesses
	
	input			e_execDone,	// execution done, from CRB
	output			e_execStart,	// UNUSED
	
	output			SPI_PIRQ_n,	// SPI IRQ to host
	
	output		[2:0]	debug,		// may be removed
	output			dbg,		// may be removed
		
	output	reg	[7:0]	locality_out,	// active locality
	
	// command response buffer connections
	output		[31:0]	c_cmdSize,	// command size
	input		[31:0]	c_rspSize,	// response size
	output			c_cmdSend,	// command send
	input			c_rspSend,	// response send
	input			c_cmdDone,	// command send done
	input			c_rspDone,	// response send done
	input		[11:0]	c_cmdInAddr,	// command send address
	input		[11:0]	c_rspInAddr,	// response send address
	output		[7:0]	c_cmdByteOut,	// command send byte
	input		[7:0]	c_rspByteIn,	// response send byte
	input			c_execDone,	// execution done
	output			c_execAck	// ack execution done
);
	
	// fifo reg names (r_ prefix for regs, w_ for wires; _e postfix for external, _i for internal)
	// note: some of these are unused
	
	// TPM_ACCESS -- STATE MACHINE
	reg		r_tpmRegValidSts [0:4];
	reg		r_activeLocality_i [0:4], r_activeLocality_e [0:4];
	reg		r_beenSeized [0:4];
	reg		r_Seize [0:4];
	reg		r_pendingRequest [0:4];
	reg		r_requestUse [0:4];
	reg		r_tpmEstablishment [0:4];
	
	// TPM_INT_ENABLE -- INTERRUPT
	reg		r_globalIntEnable;
	reg		r_commandReadyEnable;
	reg	[1:0]	r_typePolarity;
	reg		r_localityChangeIntEnable;
	reg		r_stsValidIntEnable;
	reg		r_dataAvailIntEnable;
	
	// SIRQ is unused in SPI protocol...
	// TPM_INT_VECTOR -- INTERRUPT
	reg	[3:0]	r_sIrqVec;
	
	// TPM_INT_STATUS -- INTERRUPT
	reg		r_commandReadyIntOccured;
	reg		r_localityChangeIntOccured;
	reg		r_stsValidIntOccured;
	reg		r_dataAvailIntOccured;
	
	// TPM_INTF_CAPABILITY -- STATIC
	wire	[2:0]	w_InterfaceVersion_cap;
	wire	[1:0]	w_DataTransferSizeSupport;
	wire		w_BurstCountStatic;
	wire		w_CommandReadyIntSupport;
	wire		w_InterruptEdgeFalling;
	wire		w_InterruptEdgeRising;
	wire		w_InterruptLevelLow;
	wire		w_InterruptLevelHigh;
	wire		w_LocalityChangeIntSupport;
	wire		w_stsValidIntSupport;
	wire		w_dataAvailIntSupport;
	
	// TPM_STS -- STATE MACHINE
	wire	[1:0]	w_tpmFamily;
	reg		r_resetEstablishmentBit;
	reg		r_commandCancel;
	reg	[15:0]	r_burstCount;
	reg		r_stsValid;
	reg		r_commandReady_i, r_commandReady_e;
	reg		r_tpmGo;
	reg		r_dataAvail;
	reg		r_Expect;
	reg		r_selfTestDone;
	reg		r_responseRetry;
	
	// TPM_INTERFACE_ID -- (mostly) STATIC
	reg		r_IntfSelLock;
	reg	[1:0]	r_InterfaceSelector;
	wire	[1:0]	w_CapIFRes;
	wire		w_CapCRB;
	wire		w_CapTIS;
	wire		w_CapLocality;
	wire	[3:0]	w_InterfaceVersion;
	wire	[3:0]	w_InterfaceType;
	
	// TPM_DID_VID -- STATIC
	wire	[15:0]	w_DID;
	wire	[15:0]	w_VID;
	
	// TPM_RID -- STATIC
	wire	[7:0]	w_RID;
	
	// DEBUG
	reg	[31:0]	r_IDS_TEST;
	reg		r_IDS_FIFO_W;
	reg		r_IDS_FIFO_R;
	reg		r_IDS_EXEC;
	reg	[7:0]	r_IDS_OVERFLOW;
	
	assign	dbg = r_IDS_FIFO_W;
	
	// Interrupts
	reg		i_commandReadyInterrupt;
	reg		i_dataAvailInterrupt;
	
	// FIFO request flags
	wire		f_fifoAccess;
	wire		f_fifoWrite;
	wire		f_fifoRead;
	wire		f_fifoComplete;
	wire		f_fifoEmpty;
	wire	[7:0]	f_fifoOut;
	
	// fifo access is true during a transaction request to one of these addresses
	assign	f_fifoAccess = t_req &
	(
		t_baseAddr[11:0] == 12'h027 |
		t_baseAddr[11:0] == 12'h026 |
		t_baseAddr[11:0] == 12'h025 |
		t_baseAddr[11:0] == 12'h024 |
		t_baseAddr[11:0] == 12'h083 |
		t_baseAddr[11:0] == 12'h082 |
		t_baseAddr[11:0] == 12'h081 |
		t_baseAddr[11:0] == 12'h080
	);
	assign	f_fifoRead = f_fifoAccess & t_dir;
	assign	f_fifoWrite = f_fifoAccess & ~t_dir;
//	assign	f_fifoComplete = r_IDS_FIFO_W;
//	assign	f_fifoEmpty = r_IDS_FIFO_R;
	
	// locality requests
	wire	[4:0]	l_requests;
	assign	l_requests[0] = r_requestUse[0];
	assign	l_requests[1] = r_requestUse[1];
	assign	l_requests[2] = r_requestUse[2];
	assign	l_requests[3] = r_requestUse[3];
	assign	l_requests[4] = r_requestUse[4];
	
	// r_Seize vector
	wire	[4:0]	r_Seize_v;
	assign	r_Seize_v = { r_Seize[4],r_Seize[3],r_Seize[2],r_Seize[1],r_Seize[0] };
	
	// combinational logic to determine l_SeizeRequest, which stores decimal priority level of the request
	reg	[7:0]	l_activeLocality;
	reg	[3:0]	l_SeizeRequest;
	always @*
	begin
		case (r_Seize_v)
		
		5'b10000:	l_SeizeRequest = 4'h4;
		5'b01000:	l_SeizeRequest = 4'h3;
		5'b00100:	l_SeizeRequest = 4'h2;
		5'b00010:	l_SeizeRequest = 4'h1;
		5'b00001:	l_SeizeRequest = 4'h0;
		default:	l_SeizeRequest = 4'hx;
		
		endcase
	end
	
	// l_trySeize is true if there is a SeizeRequest from a locality higher than the active locality
	wire		l_trySeize;
	assign	l_trySeize = |r_Seize_v & l_SeizeRequest > l_activeLocality;
	
	// state machine for keeping track of active locality
	localparam
		LocNull		= 0,	// no active locality
		LocRel		= 1,	// active locality reliquishes control
		Loc$0		= 2,	// locality 0
		Loc$1		= 3,	// locality 1
		Loc$2		= 4,	// locality 2
		Loc$3		= 5,	// locality 3
		Loc$4		= 6;	// locality 4
	reg	[2:0]	loc_s, loc_next_s;
	
	// state machine register
	always @(posedge clock, negedge reset_n)
	begin
		if (!reset_n)
			loc_s <= LocNull;
		// only update when there is not an active transaction ; if l_trySeize, force transfer to reliquish
		else if (~t_req | f_fifoAccess)
			loc_s <= l_trySeize ? LocRel : loc_next_s;
	end
	
	// combinational logic for active locality output
	always @* case (loc_s)
	
	default:	locality_out = 8'h00;
	Loc$0:		locality_out = 8'h01;
	Loc$1:		locality_out = 8'h02;
	Loc$2:		locality_out = 8'h04;
	Loc$3:		locality_out = 8'h08;
	Loc$4:		locality_out = 8'h10;
	
	endcase
	
	// locality state machine next state combinational logic
	always @*
	begin
		case (loc_s)
			// stay in Locality NULL until a request comes in, then NULL reliqushes
			LocNull:
				loc_next_s = l_requests == 5'h00 ? LocNull : LocRel;
			// reliquish control when r_activeLocality_i is written to
			Loc$0:
				loc_next_s = r_activeLocality_i[0] ? LocRel : Loc$0;
			// reliquish control when r_activeLocality_i is written to
			Loc$1:
				loc_next_s = r_activeLocality_i[1] ? LocRel : Loc$1;
			// reliquish control when r_activeLocality_i is written to
			Loc$2:
				loc_next_s = r_activeLocality_i[2] ? LocRel : Loc$2;
			// reliquish control when r_activeLocality_i is written to
			Loc$3:
				loc_next_s = r_activeLocality_i[3] ? LocRel : Loc$3;
			// reliquish control when r_activeLocality_i is written to
			Loc$4:
				loc_next_s = r_activeLocality_i[4] ? LocRel : Loc$4;
			// when a locality reliquishes control, control is transferred to the highest request
			LocRel:
			casez (l_requests)
				5'b1????: loc_next_s = Loc$4;
				5'b01???: loc_next_s = Loc$3;
				5'b001??: loc_next_s = Loc$2;
				5'b0001?: loc_next_s = Loc$1;
				5'b00001: loc_next_s = Loc$0;
				default:  loc_next_s = LocNull;
			endcase
			
			default:
				loc_next_s = LocNull;
		endcase
	end
	
	// combinational logic for l_activeLocality
	always @*
	begin
		case (loc_s)
		
		Loc$0:	l_activeLocality = 8'd0;
		Loc$1:	l_activeLocality = 8'd1;
		Loc$2:	l_activeLocality = 8'd2;
		Loc$3:	l_activeLocality = 8'd3;
		Loc$4:	l_activeLocality = 8'd4;
		default:l_activeLocality = 8'hFF;
		
		endcase
	end
	
	// signal that reports when a locality is changing
	wire	l_locChanged;
	assign	l_locChanged = loc_s == LocRel;
	
	// determines if the transaction should be allowed ... only if the transaction's locality is that of the active locality
	wire	l_allowAccess;
	assign	l_allowAccess = l_activeLocality == t_baseAddr[15:12];
	
	// TPM Status State Machine (TPM_STS)
	localparam
		Idle		= 0,
		Ready		= 1,
		Reception	= 2,
		Execution	= 3,
		Completion	= 4;
	reg	[2:0]	sts_s, sts_next_s;	assign debug = sts_s;
	
	// Status state machine 
	always @(posedge clock, negedge reset_n)
	begin
		if (!reset_n)
			sts_s <= Idle;
		// only update outside of transactions, return to Idle on a sucessful Seize
		else if (~t_req | f_fifoAccess)
			sts_s <= l_trySeize ? Idle : sts_next_s;
	end
	
	// status state machine next state combinational logic
	always @*
	begin
		case (sts_s)
// Transfer to Ready upon expiration of TIMEOUT_B (2 seconds) or receipt of 1 written to TPM_STS.commandReady
			Idle:
				sts_next_s = r_commandReady_i /*| expired_TIMEOUT_B*/ ? Ready : Idle;
// Transfer to Reception upon the first written byte to FIFO
			Ready:
				sts_next_s = f_fifoWrite ? Reception : Ready;
// Return to Idle on receipt of 1 written to TPM_STS.commandReady
// Transfer to Execution on receipt of 1 written to TPM_STS.tpmGo when FIFO is compelete
			Reception:
				sts_next_s = r_commandReady_i ? Idle : f_fifoComplete & r_tpmGo ? Execution : Reception;
// Return to Idle on receipt of 1 written to TPM_STS.commandReady
// Transfer to Completion once Execution is done
			Execution:
				sts_next_s = r_commandReady_i ? Idle : e_execDone ? Completion : Execution;
// Return to Idle on receipt of 1 written to TPM_STS.commandReady
			Completion:
				sts_next_s = r_commandReady_i ? Idle : Completion;
			
			default:
				sts_next_s = 3'hx;
			
		endcase
	end
	
	
	// FIFO register space block (also status state machine sequential logic, also interrupts)
	// Blocks are named to help document where individual register behaviors are implemented,
	//	block names end with $x, where x represents the byte of the register.
	//	I.e., block TPM_INT_ENABLE$3 implements read/write behavior of the TPM_INT_ENABLE register's fourth byte.
	always @(posedge clock, negedge reset_n)
	begin : REG_SPACE	
		if (!reset_n) // default values for registers
		begin : REG_SPACE_RESET
			
			// TPM_ACCESS
			integer i;
			for(i=0; i<5; i=i+1)
			begin
				r_tpmRegValidSts[i] <= 1'b0;
				r_activeLocality_i[i] <= 1'b0;
				r_activeLocality_e[i] <= 1'b0;
				r_beenSeized[i] <= 1'b0;
				r_Seize[i] <= 1'b0;
				r_pendingRequest[i] <= 1'b0;
				r_requestUse[i] <= 1'b0;
				r_tpmEstablishment[i] <= 1'b1;
			end
			
			// TPM_INT_ENABLE
			r_globalIntEnable <= 1'b0;
			r_commandReadyEnable <= 1'b0;
			r_typePolarity <= 2'b01;
			r_localityChangeIntEnable <= 1'b0;
			r_stsValidIntEnable <= 1'b0;
			r_dataAvailIntEnable <= 1'b0;
			
			// TPM_INT_VECTOR
			r_sIrqVec <= 4'd0;
			
			// TPM_INT_STATUS
			r_commandReadyIntOccured <= 1'b0;
			r_localityChangeIntOccured <= 1'b0;
			r_stsValidIntOccured <= 1'b0;
			r_dataAvailIntOccured <= 1'b0;
			
			// TPM_STS
			r_resetEstablishmentBit <= 1'b0;
			r_commandCancel <= 1'b0;
			r_burstCount <= 16'h64;
			r_stsValid <= 1'b0;
			r_commandReady_i <= 1'b0;
			r_commandReady_e <= 1'b0;
			r_tpmGo <= 1'b0;
			r_dataAvail <= 1'b0;
			r_Expect <= 1'b0;
			r_selfTestDone <= 1'b0;
			r_responseRetry <= 1'b0;
			
			// TPM_INTERFACE_ID
			r_IntfSelLock <= 1'b0;
			r_InterfaceSelector <= 2'b11;
			
			// INTERRUPTS
			i_commandReadyInterrupt <= 1'b0;
			i_dataAvailInterrupt <= 1'b0;
			
			// DEBUG
			r_IDS_TEST <= 32'hFFFFFFFF;
			r_IDS_FIFO_W <= 1'b0;
			r_IDS_FIFO_R <= 1'b0;
			r_IDS_EXEC <= 1'b0;
			r_IDS_OVERFLOW <= 8'h00;
		end
		// status state machine sequential logic block (and locality fsm)
		else if (~t_req | f_fifoAccess)
		begin : STS_FSM_SEQ
			// t_readByte is 0xFF unless the transaction is accessing the fifo buffer,
			// 	in the correct locality, and the fifo has data available
			t_readByte <= f_fifoAccess & l_allowAccess & r_dataAvail ? f_fifoOut : 8'hFF;
			
			case (sts_s) // TPM_STS status state machine
			
			Idle, Execution:
			begin
				r_commandReady_e <= 1'b0;
				r_dataAvail <= 1'b0;
				r_Expect <= 1'b0;
			end
			
			Ready:
			begin
				r_commandReady_e <= 1'b1;
				r_dataAvail <= 1'b0;
				r_Expect <= 1'b0;
			end
			
			Reception:
			begin
				r_commandReady_e <= 1'b0;
				r_dataAvail <= 1'b0;
				r_Expect <= ~f_fifoComplete;
				
				r_commandReadyIntOccured <= 1'b0;
			end
			
			Completion:
			begin
				r_commandReady_e <= 1'b0;
				r_dataAvail <= ~f_fifoEmpty;
				r_Expect <= 1'b0;
			end
			
			default:
			begin
				r_commandReady_e <= 1'b0;
				r_dataAvail <= 1'b0;
				r_Expect <= 1'b0;
			end
			
			endcase
			
			// TPM_ACCESS / locality state machine
			
			// if the active locality is being seized, notify the host by updating the register
			if (l_trySeize)
				r_beenSeized[l_activeLocality] <= 1'b1;
				
			// clear requests
			r_Seize[0] <= 1'b0;
			r_Seize[1] <= 1'b0;
			r_Seize[2] <= 1'b0;
			r_Seize[3] <= 1'b0;
			r_Seize[4] <= 1'b0;
			r_requestUse[l_activeLocality] <= 1'b0;
			
			// clear requests
			r_commandReady_i <= 1'b0;
			r_tpmGo <= 1'b0;
			r_responseRetry <= 1'b0;
			
			// INTERRUPTS
			if (r_globalIntEnable)
			begin
				i_commandReadyInterrupt <= r_commandReady_e;
				i_dataAvailInterrupt <= r_dataAvail;
				
				if (r_commandReadyEnable & r_commandReady_e & ~i_commandReadyInterrupt)
					r_commandReadyIntOccured <= 1'b1;
				
				if (r_dataAvailIntEnable & r_dataAvail & ~i_dataAvailInterrupt)
					r_dataAvailIntOccured <= 1'b1;
				
				if (r_localityChangeIntEnable)
					r_localityChangeIntOccured <= r_localityChangeIntOccured | l_locChanged;
			end
		end
		// The access register is the only register that may be accessed regardless of the active locality
		else if (t_req & ~f_fifoAccess & t_address[11:0] == 12'h000)
		begin : TPM_ACCESS$0
			if (t_dir)
				t_readByte <=
				{
					loc_s != LocRel, // r_tpmRegValidSts[t_address[15:12]],
					1'b0,
					l_activeLocality[3:0] == t_address[15:12], // r_activeLocality_e[t_address[15:12]],
					r_beenSeized[t_address[15:12]],
					1'b0,
					|l_requests, // r_pendingRequest[t_address[15:12]],
					r_requestUse[t_address[15:12]],
					1'b1 // IDS ??? r_tpmEstablishment[t_address[15:12]]
				};
			else
			begin
				r_activeLocality_i[t_address[15:12]] <= t_writeByte[5];
				r_beenSeized[t_address[15:12]] <= r_beenSeized[t_address[15:12]] & ~t_writeByte[4];
				r_Seize[t_address[15:12]] <= t_writeByte[3]; // IDS this WILL abort a command
				r_requestUse[t_address[15:12]] <= t_writeByte[1] | t_writeByte[3];
			end
		end
		// all other FIFO registers read and write behaviors
		else if (t_req & ~f_fifoAccess & l_allowAccess) case (t_address[11:0])
		12'h00B:
		begin : TPM_INT_ENABLE$3
			if (t_dir)
				t_readByte <=
				{
					r_globalIntEnable,
					7'h00
				};
			else
				r_globalIntEnable <= t_writeByte[7];
		end
		12'h00A:
		begin : TPM_INT_ENABLE$2
			if (t_dir)
				t_readByte <= 8'h00;
		end
		12'h009:
		begin : TPM_INT_ENABLE$1
			if (t_dir)
				t_readByte <= 8'h00;
		end
		12'h008:
		begin : TPM_INT_ENABLE$0
			if (t_dir)
				t_readByte <=
				{
					r_commandReadyEnable,
					2'h0,
					r_typePolarity,
					r_localityChangeIntEnable,
					r_stsValidIntEnable,
					r_dataAvailIntEnable
				};
			else
			begin
				r_commandReadyEnable <= t_writeByte[7];
				r_typePolarity <= t_writeByte[4:3];
				r_localityChangeIntEnable <= t_writeByte[2];
				r_stsValidIntEnable <= t_writeByte[1];
				r_dataAvailIntEnable <= t_writeByte[0];
			end
		end
		
		12'h00c:
		begin : TPM_INT_VECTOR$0
			if (t_dir)
				t_readByte <=
				{
					4'h0,
					r_sIrqVec
				};
			else
			begin
				r_sIrqVec <= t_writeByte[3:0];
			end
		end
		
		12'h013:
		begin : TPM_INT_STATUS$3
			if (t_dir)
				t_readByte <= 8'h00;
		end
		12'h012:
		begin : TPM_INT_STATUS$2
			if (t_dir)
				t_readByte <= 8'h00;
		end
		12'h011:
		begin : TPM_INT_STATUS$1
			if (t_dir)
				t_readByte <= 8'h00;
		end
		12'h010:
		begin : TPM_INT_STATUS$0
			if (t_dir)
				t_readByte <=
				{
					r_commandReadyIntOccured,
					4'h0,
					r_localityChangeIntOccured,
					r_stsValidIntOccured,
					r_dataAvailIntOccured
				};
			else
			begin // write 0: no effect ; write 1: clear register
				r_commandReadyIntOccured <= r_commandReadyIntOccured & ~t_writeByte[7];
				r_localityChangeIntOccured <= r_localityChangeIntOccured & ~t_writeByte[2];
				r_stsValidIntOccured <= r_stsValidIntOccured & ~t_writeByte[1];
				r_dataAvailIntOccured <= r_dataAvailIntOccured & ~t_writeByte[0];
			end
		end
		
		12'h017:
		begin : TPM_INTF_CAPABILITY$3
			if (t_dir)
				t_readByte <=
				{
					1'h0,
					w_InterfaceVersion_cap,
					4'h0
				};
		end
		12'h016:
		begin : TPM_INTF_CAPABILITY$2
			if (t_dir)
				t_readByte <= 8'h00;
		end
		12'h015:
		begin : TPM_INTF_CAPABILITY$1
			if (t_dir)
				t_readByte <=
				{
					5'h00,
					w_DataTransferSizeSupport,
					w_BurstCountStatic
				};
		end
		12'h014:
		begin : TPM_INTF_CAPABILITY$0
			if (t_dir)
				t_readByte <=
				{
					w_CommandReadyIntSupport,
					w_InterruptEdgeFalling,
					w_InterruptEdgeRising,
					w_InterruptLevelLow,
					w_InterruptLevelHigh,
					w_LocalityChangeIntSupport,
					w_stsValidIntSupport,
					w_dataAvailIntSupport
				};
		end
		
		12'h01B:
		begin : TPM_STS$3
			if (t_dir)
				t_readByte <=
				{
					4'h0,
					w_tpmFamily,
					2'h0
				};
			else
			begin
				r_resetEstablishmentBit <= t_writeByte[1];
				r_commandCancel <= t_writeByte[0]; // IDS todo
			end
		end
		12'h01A:
		begin : TPM_STS$2
			if (t_dir)
				t_readByte <= r_burstCount[15:8];
		end
		12'h019:
		begin : TPM_STS$1
			if (t_dir)
				t_readByte <= r_burstCount[7:0];
		end
		12'h018:
		begin : TPM_STS$0
			if (t_dir)
				t_readByte <=
				{
					1'b1, // r_stsValid, IDS .. always 1? no process delay
					r_commandReady_e,
					1'h0,
					r_dataAvail,
					r_Expect,
					r_selfTestDone,
					2'h0
				};
			else
			begin
				r_commandReady_i <= t_writeByte[6];
				r_tpmGo <= t_writeByte[5];
				r_responseRetry <= t_writeByte[1];
			end
		end
		
		12'h033:
		begin : TPM_INTERFACE_ID$3
			if (t_dir)
				t_readByte <= 8'h00;
		end
		12'h032:
		begin : TPM_INTERFACE_ID$2
			if (t_dir)
				t_readByte <=
				{
					4'h0,
					r_IntfSelLock,
					r_InterfaceSelector,
					w_CapIFRes[1]
				};
			else
			begin
				r_IntfSelLock <= r_IntfSelLock | t_writeByte[3];
				if (!r_IntfSelLock)
					r_InterfaceSelector <= t_writeByte[2:1];
			end
		end
		12'h031:
		begin : TPM_INTERFACE_ID$1
			if (t_dir)
				t_readByte <=
				{
					w_CapIFRes[0],
					w_CapCRB,
					w_CapTIS,
					4'h0,
					w_CapLocality
				};
		end
		12'h030:
		begin : TPM_INTERFACE_ID$0
			if (t_dir)
				t_readByte <=
				{
					w_InterfaceVersion,
					w_InterfaceType
				};
		end
		
		12'hF03:
		begin : TPM_DID_VID$3
			if (t_dir)
				t_readByte <= w_DID[15:8];
		end
		12'hF02:
		begin : TPM_DID_VID$2
			if (t_dir)
				t_readByte <= w_DID[7:0];
		end
		12'hF01:
		begin : TPM_DID_VID$1
			if (t_dir)
				t_readByte <= w_VID[15:8];
		end
		12'hF00:
		begin : TPM_DID_VID$0
			if (t_dir)
				t_readByte <= w_VID[7:0];
		end
		
		12'hF04:
		begin : TPM_RID$0
			if (t_dir)
				t_readByte <= w_RID;
		end
		
		default:
			t_readByte <= 8'hFF;
			
		// addresses beyond this point are reserved by spec and are being used for some debug purposes
		
		12'hF29:
		begin
			if (t_dir)
				t_readByte <=
				{
					2'h0,
					sts_s,
					sts_next_s
				};
			else
			begin
				r_IDS_EXEC <= t_writeByte[2];
				r_IDS_FIFO_R <= t_writeByte[1];
				r_IDS_FIFO_W <= t_writeByte[0];
			end
		end
		
		12'hF28:
		begin
			if (t_dir)
				t_readByte <= r_IDS_OVERFLOW;
			else
				r_IDS_OVERFLOW <= t_writeByte;
		end
		12'hF27:
		begin
			if (t_dir)
				t_readByte <= r_IDS_TEST[31:24];
			else
				r_IDS_TEST[31:24] <= t_writeByte;
		end
		12'hF26:
		begin
			if (t_dir)
				t_readByte <= r_IDS_TEST[23:16];
			else
				r_IDS_TEST[23:16] <= t_writeByte;
		end
		12'hF25:
		begin
			if (t_dir)
				t_readByte <= r_IDS_TEST[15:8];
			else
				r_IDS_TEST[15:8] <= t_writeByte;
		end
		12'hF24:
		begin
			if (t_dir)
				t_readByte <= r_IDS_TEST[7:0];
			else
				r_IDS_TEST[7:0] <= t_writeByte;
		end
		
		endcase
		else
			// read 0xFF on bad address
			t_readByte <= 8'hFF;
	end
	
	// STATIC ASSIGNMENTS
	
	// TPM_STS
	assign	w_tpmFamily = 2'b01;	// TPM2.0
	
	// TPM_INTERFACE_ID
	assign	w_CapIFRes = 2'b00;		// reserved
	assign	w_CapCRB = 1'b0;		// CRB unsupported
	assign	w_CapTIS = 1'b0;		// TIS unsupported
	assign	w_CapLocality = 1'b1;		// Localities supported
	assign	w_InterfaceVersion = 4'b0000;	// TPM2.0 FIFO Interface
	assign	w_InterfaceType = 4'b0000;	// TPM2.0 FIFO Interface
	
	// TPM_INTF_CAPABILITY
	assign	w_InterfaceVersion_cap = 3'b011;	// Interface 1.3 for TPM 2.0
	assign	w_DataTransferSizeSupport = 2'b11;	// 64-byte max data transfer support
	assign	w_BurstCountStatic = 1'b1;		// TPM_STS.burstCount is static
	assign	w_CommandReadyIntSupport = 1'b1;	// Supported (Implemented; Not Tested)
	assign	w_InterruptEdgeFalling = 1'b1;		// PIRQ is active low
	assign	w_InterruptEdgeRising = 1'b0;		// Not supported for PIRQ
	assign	w_InterruptLevelLow = 1'b1;		// Must be supported per spec.
	assign	w_InterruptLevelHigh = 1'b0;		// Not supported for PIRQ
	assign	w_LocalityChangeIntSupport = 1'b1;	// Must be supported per spec. (Unimplemented)
	assign	w_stsValidIntSupport = 1'b0;		// Not supported yet... (Unimplemented)
	assign	w_dataAvailIntSupport = 1'b1;		// Must be supported per spec. (Implemented; Not tested)
	
	// TPM_DID_VID
	assign	w_DID = 16'h5654;	// "VT"
	assign	w_VID = 16'h3037;	// "07" Note this is an invalid option per spec.
					// Valid options may include 17AAh (Lenovo: for customer) or 1414h (Microsoft: to match simulator).
					// There is no Null VID option.
	
	// TPM_RID
	assign	w_RID = 8'hFF;
	
	// PIRQ is low while any interrupt is active
	assign	SPI_PIRQ_n = 
	~(
		r_commandReadyIntOccured |
		r_localityChangeIntOccured |
		r_stsValidIntOccured |
		r_dataAvailIntOccured
	);
	
	assign	c_execAck = sts_s == Completion;
	
	// instantiation of the fifo buffer
	FIFO_BUFFER io_fifo
	(
		.clock(clock), .reset_n(reset_n),
		.cmdByteIn(t_writeByte), .cmdByteOut(c_cmdByteOut),
		.rspByteIn(c_rspByteIn), .rspByteOut(f_fifoOut),
		.f_fifoAccess(f_fifoAccess & l_allowAccess), .t_size(t_size),
		.f_fifoRead(f_fifoRead & l_allowAccess), .f_fifoWrite(f_fifoWrite & l_allowAccess & r_Expect),
		.f_fifoEmpty(f_fifoEmpty), .f_fifoComplete(f_fifoComplete),
		.r_tpmGo(r_tpmGo & ~t_req), .r_commandReady(r_commandReady_i & ~t_req), .r_responseRetry(r_responseRetry & ~t_req),
		.e_execDone(c_execDone), .f_abort(1'b0),
		.t_address(t_address), .t_baseAddr(t_baseAddr),
		.t_updateAddr(updateAddr),
		.c_cmdSize(c_cmdSize), .c_rspSize(c_rspSize),
		.c_cmdSend(c_cmdSend), .c_rspSend(c_rspSend),
		.c_cmdDone(c_cmdDone), .c_rspDone(c_rspDone),
		.c_cmdInAddr(c_cmdInAddr), .c_rspInAddr(c_rspInAddr)
	);
	
//	assign	c_execDone = r_IDS_EXEC;

endmodule