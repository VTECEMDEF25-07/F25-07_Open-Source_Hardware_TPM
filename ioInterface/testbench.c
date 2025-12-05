// testbench.c
//
// functions:
//	ftdi_connect
//	ftdi_close
//	init_verilog_gen
//	tb_assert
//	tb_assertRC
//	check_assert
//	tb_stop
//	close_verilog_gen
//	tpm_reset
//	tb_comment
//	verilog_tpm_transaction
//	tpm_transaction
//	tpm_waitExec
//	print_tpm_transaction
//	tpm_command
//	
// test functions:
//	test_debugRW
//	test_localityChanging
//	test_localityPermissions
//	test_statusStateMachine
//	test_localitySeizeCommandAbort
//	test_sendReceiveCMD
//	test_hierarchyControl
//	test_hierarchyControl2
//	test_ccQuote
//
// this file is compilable:
//	main
// 
// Compile Directions:
//	gcc testbench.c -llibMPSSE -L.
//	The above assumes libmpsse.dll is in the working directory, replace -L.
//	with -L <path to libmpsse.dll> otherwise.
//	The resulting executable must also be able to find the DLL; the DLL should either be
//	in the same directory as the executable, or the DLL should be in a system path.
//
// Dependencies:
//	windows.h
//	FTDI/ftd2xx.h
//	FTDI/libMPSSE_spi.h
//	libmpsse.dll
//
//	Check the FTDI folder in the project documents for the FTDI files, or download from:
//		https://ftdichip.com/wp-content/uploads/2025/08/libmpsse-windows-1.0.8.zip
//	
// Drivers:
//	FTDI D2XX Drivers (https://ftdichip.com/drivers/d2xx-drivers/)
//	For VT students: these drivers should already be on your computer after Quartus
//	and its USB Blaster have been installed (the USB Blaster uses the same drivers).
//
// Authors:
//	Ian Sizemore (idsizemore@vt.edu)
//
// Date: 11/6/25
//
// General Description:
//	This file implements the testing strategy for the I/O module, and integration testing.
//	This file could be (should be) partitioned into several source files, but I would rather
//	not break something so close to submission.
//	The layout is as follows:
//		Functions/definitions used by test functions
//		Main
//		Test functions
//	
//	This file both tests the physical FPGA, and generates equivalent Verilog testbench
//	code. This allows for one testscript to be written in C to test both hardware and simulation.
//	
//	The program communicates with the board using the 
//	FTDI C232HM-DDHSL-0 Cable (https://ftdichip.com/products/c232hm-ddhsl-0-2/).
//	
// Usage:
//	Compile tests:
//		gcc testbench.c -llibMPSSE -L. -o testing.exe
//	1. Board/cable are plugged into PC
//		> testing.exe
//		(tests run, results shown)
//		> testing.exe tb_test.v
//		(tests run, results shown ; Verilog testbench generated to tb_test.v)
//	2. Board/cable not plugged into PC
//		> testing.exe
//		(cable not found, nothing happens)
//		> testing.exe tb_test.v
//		(Verilog testbench generated to tb_test.v)
//

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <windows.h>
#include "FTDI/ftd2xx.h"
#include "FTDI/libMPSSE_spi.h"

// macro for checking ftdi status during initialization
#define STATUS_CHECK(exp) {if(exp!=FT_OK){printf("%s:%d:%s(): status(0x%x) \
!= FT_OK\n",__FILE__, __LINE__, __FUNCTION__,exp);exit(1);}else{;}};

// ftdi cable values
int _devFound = -1;
ChannelConfig _devConfig;
FT_HANDLE _handle;
FT_STATUS _status;

// global error counter
unsigned _errors = 0;
// global generate verilog testbench bool
unsigned _generateVerilogTB = 0;
// global connected via cable bool
unsigned _connected = 0;
// global verilog testbench filename
char _verilogTBFilename[64];
// global verilog testbench file pointer
FILE *_vFP = NULL;

// connect to FTDI cable at frequency specified by freq
int ftdi_connect(DWORD freq)
{
	FT_DEVICE_LIST_INFO_NODE devList;
	ChannelConfig devConfig = 
	{
		freq,
		255,
		SPI_CONFIG_OPTION_MODE0 | SPI_CONFIG_OPTION_CS_DBUS3 | SPI_CONFIG_OPTION_CS_ACTIVELOW,
		0x00101010
	};
	
	_devConfig = devConfig;
	
	DWORD nChannels;
	_status = SPI_GetNumChannels(&nChannels); STATUS_CHECK(_status);
	
	if (!nChannels)
	{
		printf("FTDI SPI cable not found. Cannot test physical device.\n");
		return 1;
	}
	
	for(unsigned i=0; i<nChannels; i++)
	{
		_status = SPI_GetChannelInfo(i, &devList); STATUS_CHECK(_status);
		
		if ((devList.ID & 0xFFFF) == 0x6014) // device ID of USB->SPI cable
			_devFound = i;
	}
	
	if (_devFound == -1)
	{
		printf("FTDI SPI cable not found. Cannot test physical device.\n");
		return 1;
	}
	
	_status = SPI_OpenChannel(_devFound, &_handle); STATUS_CHECK(_status);
	_status = SPI_InitChannel(_handle, &_devConfig); STATUS_CHECK(_status);
	
	printf("Connected via FTDI cable.\n\n");
	_connected = 1;
	return 0;
}

// close connection to ftdi cable
void ftdi_close(void)
{
	if (!_connected)
		return;
	
	_connected = 0;
	SPI_CloseChannel(_handle);
}

// definitions for FIFO Registers
enum
{
	TPM_ACCESS = 0x000,
	TPM_INT_ENABLE = 0x008,
	TPM_INT_VECTOR = 0x00C,
	TPM_INT_STATUS = 0x010,
	TPM_INTF_CAPABILITY = 0x014,
	TPM_STS = 0x018,
	TPM_INTERFACE_ID = 0x030,
	TPM_DID_VID = 0xF00,
	TPM_RID = 0xF04,
	
	TPM_DATA_FIFO = 0x024,
	TPM_XDATA_FIFO = 0x080,
	
	// debug registers
	IDS_RW = 0xF24,
	IDS_OVERFLOW = 0xF28,
	IDS_CTRL = 0xF29,
	
	READ = 1,
	WRITE = 0,
	
	LOC0 = 0,
	LOC1 = 1,
	LOC2 = 2,
	LOC3 = 3,
	LOC4 = 4
};

// initialize verilog generation from CLI
unsigned init_verilog_gen(int argc, char **argv)
{
	// do nothing if no arguments
	if (argc == 1)
		return 1;
	
	// otherwise, copy argument 2 into _verilogTBFilename
	unsigned i = 0;
	for(char *c = argv[1], *d = _verilogTBFilename; *c && i < 64; i++)
		*d++ = *c++;
	
	// append filename with ~.v if it is too large
	if (i == 64)
	{
		_verilogTBFilename[60] = '~';
		_verilogTBFilename[61] = '.';
		_verilogTBFilename[62] = 'v';
		_verilogTBFilename[63] = '\0';
	}
	else
		_verilogTBFilename[i] = '\0';
	
	// if filename is too small, exit
	if (i < 3)
	{
		printf("Could not use %s for output (filename too short). Verilog Testbench will not be generated.\n", _verilogTBFilename);
		return 1;
	}
	
	// open file for writing
	_vFP = fopen(_verilogTBFilename, "w");
	
	// if we could not open the file, exit
	if (!_vFP)
	{
		printf("Could not use %s for output. Verilog Testbench will not be generated.\n", _verilogTBFilename);
		return 1;
	}
	
	// we have opened a file, set the generateVerilogTB bool to true
	_generateVerilogTB = 1;
	printf("Generating Verilog Testbench: %s\n\n", _verilogTBFilename);
	
	// change string so that it can be used to name the top module in the testbench
	if (i == 64)
		_verilogTBFilename[60] = '\0';
	else
		_verilogTBFilename[i-2] = '\0';
	
	// testbench code
	fprintf(_vFP,
		"// Auto-Generated Verilog Testbench\n"
		"`timescale 1ns/1ns\n"
		"\n"
		"`define SPI_CLK_PERIOD #33\n"
		"\n"
		"module\t%s();\n"
		"\treg\t\tclock;\n"
		"\treg\t\treset_n;\n"
		"\n"
		"\treg\t\tSPI_clock;\n"
		"\treg\t\tSPI_mosi;\n"
		"\twire\t\tSPI_miso;\n"
		"\treg\t\tSPI_cs_n;\n"
		"\treg\t\tSPI_rst_n;\n"
		"\twire\t\tSPI_PIRQ_n;\n"
		"\n"
		"\ttest0_top\tdut\n"		// if the top module name changes, this will need to match it
		"\t(\n"
		"\t\t.CLOCK_50(clock), .RESET_N(reset_n),\n"
		"\t\t.GPIO_1_2(SPI_clock), .GPIO_1_3(SPI_mosi),\n"
		"\t\t.GPIO_1_4(SPI_miso), .GPIO_1_5(SPI_cs_n),\n"
		"\t\t.GPIO_1_6(SPI_rst_n), .GPIO_1_7(SPI_PIRQ_n)\n"
		"\t);\n"
		"\n"
		"\tinitial\n"
		"\tbegin : tb_clock_50\n"
		"\t\treset_n = 1'b1;\n"
		"\t\trepeat(2) reset_n = #1 ~reset_n;\n"
		"\t\tclock = 1'b0;\n"
		"\t\tforever clock = #10 ~clock;\n"
		"\tend\n"
		"\n"
		"\treg\t[31:0]\theader;\n"
		"\treg\t[7:0]\twriteData;\n"
		"\treg\t[7:0]\treadData [0:63];\n"
		"\treg\t[7:0]\treadByte;\n"
		"\treg\tin;\n"
		"\tinteger i, j, genEntry, tries, errors;\n"
		"\n"
		"\tinitial\n"
		"\tbegin : tb_main\n"
		"\t\terrors = 1'b0;\n"
		"\t\tSPI_clock = 1'b0;\n"
		"\t\tSPI_mosi = 1'b0;\n"
		"\t\tSPI_cs_n = 1'b1;\n"
		"\t\tSPI_rst_n = 1'b1;\n"
		"\n"
		"\t\theader = 32'd0;\n"
		"\t\twriteData = 8'd0;\n"
		"\t\treadByte = 8'd0;\n"
		"\n",
		_verilogTBFilename);
	
	// return filename string to original state
	if (i == 64)
		_verilogTBFilename[60] = '~';
	else
		_verilogTBFilename[i-2] = '.';
	
	return 0;
}

#define EQUAL 1
#define UNEQUAL 0

// this function is used for checking test results.
// while a simple if () can be used in the C testbench, this function performs
// both tests in C and generates the equivalent verilog
// *data: the read data vector,
// byte: the index of *data
// filter: bitmash for the byte
// comp: comparison (EQUAL or UNEQUAL)
// expected: expected value
// *str: string to print on error
unsigned tb_assert(unsigned char *data, unsigned byte, unsigned char filter, unsigned comp, unsigned char expected, char *str)
{
	unsigned retVal = 0;
	
	if (!_connected)
		goto L_GEN;
	
	if (comp)
	{
		if ((data[byte] & filter) != expected)
		{
			printf("\n%s\n\n", str);
			_errors++;
			retVal = 1;
		}
	} else {
		if ((data[byte] & filter) == expected)
		{
			printf("\n%s\n\n", str);
			_errors++;
			retVal = 1;
		}
	}
	
L_GEN:	
	if (!_generateVerilogTB)
		return retVal;
	
	fprintf(_vFP,
		"\t\tif ((readData[%u] & 8'd%u) %s 8'd%u)\n"
		"\t\tbegin\n"
		"\t\t\t$error(\"%s\");\n"
		"\t\t\terrors = errors + 1;\n"
		"\t\tend\n"
		"\n",
		byte, filter, comp ? "!=" : "==", expected, str);
	
	return retVal;
}

// this function is used to assert response codes
// *rspData: response code data pointer
// expected: expected response code
// *str: message to print on error
void tb_assertRC(unsigned char *rspData, unsigned expected, char *str)
{
	if (_connected)
	{
		if 	(rspData[6] != (expected & 0xFF000000) >> 24 ||
			 rspData[7] != (expected & 0x00FF0000) >> 16 ||
			 rspData[8] != (expected & 0x0000FF00) >>  8 ||
			 rspData[9] != (expected & 0x000000FF) >>  0)
		{
			printf("\n%s\n\n", str);
			_errors++;
		}
	}
	
	if (_generateVerilogTB)
	{
		fprintf(_vFP,
			"\t\tif (\n"
			"\t\t\treadData[6] != 8'd%u ||\n"
			"\t\t\treadData[7] != 8'd%u ||\n"
			"\t\t\treadData[8] != 8'd%u ||\n"
			"\t\t\treadData[9] != 8'd%u\n"
			"\t\t)\n"
			"\t\tbegin\n"
			"\t\t\t$error(\"%s\");\n"
			"\t\t\terrors = errors + 1;\n"
			"\t\tend\n"
			"\n",
			(expected & 0xFF000000) >> 24,
			(expected & 0x00FF0000) >> 16,
			(expected & 0x0000FF00) >> 8,
			(expected & 0x000000FF) >> 0,
			str);
	}
}

// use this function to print a summary of whether or not errors have occured
void check_assert(void)
{
	if (!_connected)
		return;
	
	if (_errors)
		printf("\nThere were errors in testing.\n");
	else
		printf("\nThere were no errors in testing.\n");
}

// use this function to issue $stop in the verilog testbench
void tb_stop(void)
{
	if (_generateVerilogTB)
		fprintf(_vFP, "\n\t\t$stop;\n");
	
/*	if (_connected)
	{
		char trash;
		scanf("%c", &trash);
	}
*/
}

// use this function to wrap up the verilog testbench
void close_verilog_gen(void)
{	
	// do nothing if we arent generating the verilog testbench
	if (!_generateVerilogTB)
		return;
	
	// disable verilog testbench generation
	_generateVerilogTB = 0;
	
	// close verilog
	fprintf(_vFP,
		"\n"
		"\t\tif (errors)\n"
		"\t\t\t$display(\"There were errors in simulation.\");\n"
		"\t\telse\n"
		"\t\t\t$display(\"There were no errors in simulation.\");\n"
		"\n"
		"\t\t#200;\n"
		"\t\t$stop;\n"
		"\tend\n"
		"\n"
		"endmodule\n"
		"\n"
		"module\tPLL_100\n"
		"(\n"
		"\tinput\t\trefclk, rst,\n"
		"\toutput\treg\toutclk_0\n"
		");\n"
		"\n"
		"\tinitial\n"
		"\tbegin : pll_clock_100\n"
		"\t\toutclk_0 = 1'b0;\n"
		"\t\tforever outclk_0 = #5 ~outclk_0;\n"
		"\tend\n"
		"\n"
		"endmodule\n");
	
	// close file pointer
	fclose(_vFP);
}

// use this function to reset the tpm via SPI_RST signal
void tpm_reset(void)
{
	if (_connected)
	{	
		_status = SPI_CloseChannel(_handle); STATUS_CHECK(_status);
		_status = SPI_OpenChannel(_devFound, &_handle); STATUS_CHECK(_status);
		_status = SPI_InitChannel(_handle, &_devConfig); STATUS_CHECK(_status);
		printf("TPM reset.\n");
	}
	
	if (_generateVerilogTB)
		fprintf(_vFP, "\t\trepeat(2) SPI_rst_n = #1 ~SPI_rst_n;\n"
				"\t\t@(posedge clock);\n\n");
}

// this function prints *str to console during hardware testing,
// and adds comments within the verilog testbench. this second functionality
// is useful for ctrl-finding within the generated verilog code for debugging tests
void tb_comment(char *str)
{
	if (_connected)
		printf("\ntb_comment:\n\t%s\n\n", str);
	
	if (_generateVerilogTB)
		fprintf(_vFP, "\n\t\t// %s\n", str);
}

// this function generates verilog to control a tpm transaction
// size: transaction size
// dir: transaction direction
// locality: transaction locality
// reg: transaction regsiter
// *header: transaction header
// *data: transaction read/write data
void verilog_tpm_transaction(unsigned size, unsigned dir, unsigned locality, unsigned reg, unsigned char *header, unsigned char *data)
{
	static unsigned entry = 0;
	
	fprintf(_vFP, "\n\t\t// GenEntry %u: ", entry);
	if (dir)	fprintf(_vFP, "Read %u bytes from ", size);
	else		fprintf(_vFP, "Write %u bytes to ", size);
	switch (reg)
	{
	case TPM_ACCESS:
		fprintf(_vFP, "TPM_ACCESS"); break;
	case TPM_INT_ENABLE:
		fprintf(_vFP, "TPM_INT_ENABLE"); break;
	case TPM_INT_VECTOR:
		fprintf(_vFP, "TPM_INT_VECTOR"); break;
	case TPM_INT_STATUS:
		fprintf(_vFP, "TPM_INT_STATUS"); break;
	case TPM_INTF_CAPABILITY:
		fprintf(_vFP, "TPM_INTF_CAPABILITY"); break;
	case TPM_STS:
		fprintf(_vFP, "TPM_STS"); break;
	case TPM_INTERFACE_ID:
		fprintf(_vFP, "TPM_INTERFACE_ID"); break;
	case TPM_DID_VID:
		fprintf(_vFP, "TPM_DID_VID"); break;
	case TPM_RID:
		fprintf(_vFP, "TPM_RID"); break;
	case TPM_DATA_FIFO:
		fprintf(_vFP, "TPM_DATA_FIFO"); break;
	case TPM_XDATA_FIFO:
		fprintf(_vFP, "TPM_XDATA_FIFO"); break;
	case IDS_CTRL:
		fprintf(_vFP, "DEBUG_CTRL"); break;
	default:
		fprintf(_vFP, "invalid!"); break;
	}
	fprintf(_vFP, "%u\n", locality);
	
	fprintf(_vFP, "\t\tgenEntry = %u;\n\n", entry++);
	
	unsigned uHeader = 0;
	uHeader |= header[0] << 24;
	uHeader |= header[1] << 16;
	uHeader |= header[2] << 8;
	uHeader |= header[3] << 0;
	
	fprintf(_vFP, "\t\theader = 32'd%u;\n", uHeader);
	
	fprintf(_vFP, "\t\trepeat (5) @(posedge clock);\n");
	fprintf(_vFP, "\t\tSPI_cs_n = 1'b0;\n");
	fprintf(_vFP, "\t\trepeat (5) @(posedge clock);\n\n");
	
	fprintf(_vFP, // send header
		"\t\tfor(i=32; i!=0; i=i-1)\n"
		"\t\tbegin\n"
		"\t\t\tSPI_mosi = header[i-1];\n"
		"\t\t\t`SPI_CLK_PERIOD;\n"
		"\t\t\tSPI_clock = 1'b1;\n"
		"\t\t\tin = SPI_miso;\n"
		"\t\t\t`SPI_CLK_PERIOD;\n"
		"\t\t\tSPI_clock = 1'b0;\n"
		"\t\tend\n\n");
	
	fprintf(_vFP, "\t\twriteData = 8'd%u;\n", data[0]);
	
	fprintf(_vFP, // wait state
		"\t\twhile(in == 1'b0) for(i=8; i!=0; i=i-1)\n"
		"\t\tbegin\n"
		"\t\t\tSPI_mosi = writeData[i-1];\n"
		"\t\t\t`SPI_CLK_PERIOD;\n"
		"\t\t\tSPI_clock = 1'b1;\n"
		"\t\t\tin = SPI_miso;\n"
		"\t\t\t`SPI_CLK_PERIOD;\n"
		"\t\t\tSPI_clock = 1'b0;\n"
		"\t\tend\n\n");
	
	if (dir)
	{ // read
		fprintf(_vFP,
			"\t\tfor(j=0; j<%u; j=j+1)\n"
			"\t\tbegin\n"
			"\t\t\tfor(i=8; i!=0; i=i-1)\n"
			"\t\t\tbegin\n"
			"\t\t\t\t`SPI_CLK_PERIOD;\n"
			"\t\t\t\tSPI_clock = 1'b1;\n"
			"\t\t\t\treadByte[i-1] = SPI_miso;\n"
			"\t\t\t\t`SPI_CLK_PERIOD;\n"
			"\t\t\t\tSPI_clock = 1'b0;\n"
			"\t\t\tend\n"
			"\t\t\treadData[j] = readByte;\n"
			"\t\tend\n\n", size);
	} else { // write
		for(unsigned i=1; i<size; i++)
		{
			fprintf(_vFP, "\t\twriteData = 8'd%u;\n", data[i]);
			fprintf(_vFP,
				"\t\tfor(i=8; i!=0; i=i-1)\n"
				"\t\tbegin\n"
				"\t\t\tSPI_mosi = writeData[i-1];\n"
				"\t\t\t`SPI_CLK_PERIOD;\n"
				"\t\t\tSPI_clock = 1'b1;\n"
				"\t\t\t`SPI_CLK_PERIOD;\n"
				"\t\t\tSPI_clock = 1'b0;\n"
				"\t\tend\n\n");
		}
	}
	
	fprintf(_vFP, "\t\trepeat (5) @(posedge clock);\n");
	fprintf(_vFP, "\t\tSPI_cs_n = 1'b1;\n");
	fprintf(_vFP, "\t\trepeat (5) @(posedge clock);\n\n");
}

// this function handles tpm transactions
// dir: transaction direction
// size: transaction size
// locality: transaction locality
// reg: transaction register
// *data: transaction read/write data
void tpm_transaction(unsigned dir, unsigned size, unsigned locality, unsigned reg, unsigned char *data)
{
	unsigned char in, header[4] =
	{
		((dir & 1) << 7) | (size-1) & 0x3F | 1 << 6,
		0xD4,
		((locality & 0xF) << 4) | ((reg & 0xF00) >> 8),
		reg & 0xFF
	};
	
	if (_generateVerilogTB)
		verilog_tpm_transaction(size, dir, locality, reg, header, data);
	if (!_connected)
		return;
	
	DWORD byteTran = 0, byteRec = 0;
	
	SPI_Write(_handle, header, 3, &byteTran,
		SPI_TRANSFER_OPTIONS_SIZE_IN_BYTES |
		SPI_TRANSFER_OPTIONS_CHIPSELECT_ENABLE);
	
	SPI_ReadWrite(_handle, &in, &header[3], 1, &byteTran,
		SPI_TRANSFER_OPTIONS_SIZE_IN_BYTES);
	
	if (dir)
	{ // read
		while((in & 1) == 0) // wait state
		{ // wait state
			SPI_Read(_handle, &in, 1, &byteRec,
				SPI_TRANSFER_OPTIONS_SIZE_IN_BYTES);
		}
		SPI_Read(_handle, data, size, &byteRec,
			SPI_TRANSFER_OPTIONS_SIZE_IN_BYTES |
			SPI_TRANSFER_OPTIONS_CHIPSELECT_DISABLE);
	} else { // write
		while((in & 1) == 0)
		{ // wait state
			SPI_ReadWrite(_handle, &in, &data[0], 1, &byteRec,
				SPI_TRANSFER_OPTIONS_SIZE_IN_BYTES);
		}
		SPI_Write(_handle, &data[1], size-1, &byteTran,
			SPI_TRANSFER_OPTIONS_SIZE_IN_BYTES |
			SPI_TRANSFER_OPTIONS_CHIPSELECT_DISABLE);
	}
}


// definitions for bit fields within the TPM FIFO Register Space
// names match those within TPM_REG_SPACE.v
enum
{
	// TPM_ACCESS
	r_tpmRegValidSts = 1 << 7,
	r_activeLocality = 1 << 5,
	r_beenSeized = 1 << 4,
	r_Seize = 1 << 3,
	r_pendingRequest = 1 << 2,
	r_requestUse = 1 << 1,
	r_tpmEstablishment = 1 << 0,
	
	// TPM_STATUS
	r_tpmFamily = 1 << 2,
	r_resetEstablishmentBit = 1 << 1,
	r_commandCancel = 1 << 0,
	r_burstCount = 1 << 0,
	r_stsValid = 1 << 7,
	r_commandReady = 1 << 6,
	r_tpmGo = 1 << 5,
	r_dataAvail = 1 << 4,
	r_Expect = 1 << 3,
	r_selfTestDone = 1 << 2,
	r_responseRetry = 1 << 1,
	
	// TPM_INT_ENABLE
	r_globalIntEnable = 1 << 7,
	r_commandReadyIntEnable = 1 << 7,
	r_localityChangeIntEnable = 1 << 2,
	r_stsValidIntEnable = 1 << 1,
	r_dataAvailIntEnable = 1 << 0,
	
	// TPM_INT_STATUS
	r_commandReadyIntOccurred = 1 << 7,
	r_localityChangeIntOccurred = 1 << 2,
	r_stsValidIntOccurred = 1 << 1,
	r_dataAvailIntOccurred = 1 << 0,
	
	// IDS_DEBUG
	r_dbgExecEngineDone = 1 << 2,
	r_dbgFifoEmpty = 1 << 1,
	r_dbgFifoComplete = 1 << 0
};

// this function is used to wait for the tpm to finish executing a command
// locality: must be the active locality
// tries: how many times we should poll the dataAvail register to check for command completion
unsigned tpm_waitExec(unsigned locality, unsigned tries)
{
	unsigned timeout = 0;
	unsigned oldGen = _generateVerilogTB;
	_generateVerilogTB = 0;
	
	if (oldGen)
	{
		unsigned reg = TPM_STS;
		unsigned char header[4] =
		{
			(1 << 7) | (1 << 6),
			0xD4,
			((locality & 0xF) << 4) | ((reg & 0xF00) >> 8),
			reg & 0xFF
		};
		
		unsigned uHeader = 0;
		uHeader |= header[0] << 24;
		uHeader |= header[1] << 16;
		uHeader |= header[2] << 8;
		uHeader |= header[3] << 0;		
		
		static unsigned entry = 0;
		fprintf(_vFP,
			"\t\t// GenEntry %u: Wait for TPM Execution\n\t\tgenEntry = %u;\n",
			entry, entry);
		entry++;
		
		fprintf(_vFP,
			"\n"
			"\t\treadData[0] = 8'd0;\n"
			"\t\tfor(tries = 0; tries < %u && (readData[0] & 8'd16) == 8'd0; tries = tries+1)\n"
			"\t\tbegin\n"
			"\t\t\theader = 32'd%u;\n"
			"\t\t\trepeat (5) @(posedge clock);\n"
			"\t\t\tSPI_cs_n = 1'b0;\n"
			"\t\t\trepeat (5) @(posedge clock);\n"
			"\n"
			"\t\t\tfor(i=32; i!=0; i=i-1)\n"
			"\t\t\tbegin\n"
			"\t\t\t\tSPI_mosi = header[i-1];\n"
			"\t\t\t\t`SPI_CLK_PERIOD;\n"
			"\t\t\t\tSPI_clock = 1'b1;\n"
			"\t\t\t\tin = SPI_miso;\n"
			"\t\t\t\t`SPI_CLK_PERIOD;\n"
			"\t\t\t\tSPI_clock = 1'b0;\n"
			"\t\t\tend\n"
			"\n"
			"\t\t\twhile(in == 1'b0) for(i=8; i!=0; i=i-1)\n"
			"\t\t\tbegin\n"
			"\t\t\t\tSPI_mosi = writeData[i-1];\n"
			"\t\t\t\t`SPI_CLK_PERIOD;\n"
			"\t\t\t\tSPI_clock = 1'b1;\n"
			"\t\t\t\tin = SPI_miso;\n"
			"\t\t\t\t`SPI_CLK_PERIOD;\n"
			"\t\t\t\tSPI_clock = 1'b0;\n"
			"\t\t\tend\n"
			"\n"
			"\t\t\tfor(i=8; i!=0; i=i-1)\n"
			"\t\t\tbegin\n"
			"\t\t\t\t`SPI_CLK_PERIOD;\n"
			"\t\t\t\tSPI_clock = 1'b1;\n"
			"\t\t\t\treadByte[i-1] = SPI_miso;\n"
			"\t\t\t\t`SPI_CLK_PERIOD;\n"
			"\t\t\t\tSPI_clock = 1'b0;\n"
			"\t\t\tend\n"
			"\t\t\treadData[0] = readByte;\n"
			"\n"
			"\t\t\trepeat (5) @(posedge clock);\n"
			"\t\t\tSPI_cs_n = 1'b1;\n"
			"\t\t\trepeat (5) @(posedge clock);\n"
			"\n"
			"\t\t\t#200;\n"
			"\t\tend\n"
			"\n"
			"\t\tif (tries == %u)\n"
			"\t\tbegin\n"
			"\t\t\t$error(\"TPM Execution timeout.\");\n"
			"\t\t\terrors = errors + 1;\n"
			"\t\t\t$stop;\n"
			"\t\tend\n"
			"\n", tries, uHeader, tries);
	}
	
	if (_connected)
	{
		unsigned attempt = 0;
		for(unsigned char data = 0; attempt < tries && !(data & r_dataAvail); attempt++)
			tpm_transaction(READ, 1, locality, TPM_STS, &data);
		if (attempt == tries)
		{
			printf("\nError: TPM Execution timeout.\n");
			_generateVerilogTB = oldGen;
			return 1;
		}
	}
	
	_generateVerilogTB = oldGen;
	return 0;
}

// a wrapper for tpm_transaction, which also prints information about the transaction to console
// dir: transaction direction
// size: transaction size
// locality: transaction locality
// reg: transaction register
// *data: transaction read/write data
void print_tpm_transaction(unsigned dir, unsigned size, unsigned locality, unsigned reg, unsigned char *data)
{
	tpm_transaction(dir, size, locality, reg, data);
	
	if (!_connected)
		return;
	
	if (dir)	printf("Read from ");
	else		printf("Write to ");
	
	switch(reg)
	{
		case TPM_ACCESS:
			printf("TPM_ACCESS%u:\n"
				"\ttpmRegValidSts: %u\n"
				"\tactiveLocality: %u\n"
				"\tbeenSeized: %u\n"
				"\tSeize: %u\n"
				"\tpendingRequest: %u\n"
				"\trequestUse: %u\n"
				"\ttpmEstablishment: %u\n",
				locality,
				(data[0] >> 7) & 0x1,
				(data[0] >> 5) & 0x1,
				(data[0] >> 4) & 0x1,
				(data[0] >> 3) & 0x1,
				(data[0] >> 2) & 0x1,
				(data[0] >> 1) & 0x1,
				(data[0] >> 0) & 0x1); break;
		case TPM_DID_VID:
			printf("TPM_DID_VID%u:\n"
				"\tDID: %c%c\n"
				"\tVID: %c%c\n",
				locality,
				data[3],data[2],
				data[1],data[0]); break;
		case TPM_STS:
			printf("TPM_STATUS%u:\n"
				"\tstsValid: %u\n"
				"\tcommandReady: %u\n"
				"\ttpmGo: %u\n"
				"\tdataAvail: %u\n"
				"\tExpect: %u\n"
				"\tselfTestDone: %u\n"
				"\treposnseRetry: %u\n",
				locality,
				(data[0] >> 7) & 0x1,
				(data[0] >> 6) & 0x1,
				(data[0] >> 5) & 0x1,
				(data[0] >> 4) & 0x1,
				(data[0] >> 3) & 0x1,
				(data[0] >> 2) & 0x1,
				(data[0] >> 1) & 0x1); break;
		case TPM_INT_ENABLE:
			printf("TPM_INT_ENABLE%u:\n"
				"\tglobalIntEnable: %u\n"
				"\tcommandReadyEnable: %u\n"
				"\tlocalityChangeIntEnable: %u\n"
				"\tstsValidIntEnable: %u\n"
				"\tdataAvailIntEnable: %u\n",
				locality,
				(data[3] >> 7) & 0x1,
				(data[0] >> 7) & 0x1,
				(data[0] >> 2) & 0x1,
				(data[0] >> 1) & 0x1,
				(data[0] >> 0) & 0x1); break;
		case TPM_INT_STATUS:
			printf("TPM_INT_STATUS%u:\n"
				"\tcommandReadyIntOccurred: %u\n"
				"\tlocalityChangeIntOccurred: %u\n"
				"\tstsValidIntOccurred: %u\n"
				"\tdataAvailIntOccurred: %u\n",
				locality,
				(data[0] >> 7) & 0x1,
				(data[0] >> 2) & 0x1,
				(data[0] >> 1) & 0x1,
				(data[0] >> 0) & 0x1); break;
		case TPM_INTF_CAPABILITY:
			printf("TPM_INTF_CAPABILITY%u:\n"
				"\tInterfaceVersion: 0x%X\n"
				"\tDataTransferSizeSupport: 0x%X\n"
				"\tBurstCountStatic: %u\n"
				"\tCommandReadyIntSupport: %u\n"
				"\tInterruptEdgeFalling: %u\n"
				"\tInterruptEdgeRising: %u\n"
				"\tInterruptLevelLow: %u\n"
				"\tInterruptLevelHigh: %u\n"
				"\tLocalityChangeIntSupport: %u\n"
				"\tstsValidIntSupport: %u\n"
				"\tdataAvailIntSupport: %u\n",
				locality,
				((data[3] & 0x70) >> 4),
				((data[1] & 0x06) >> 1),
				((data[1] & 0x01) >> 0),
				(data[0] >> 7) & 0x1,
				(data[0] >> 6) & 0x1,
				(data[0] >> 5) & 0x1,
				(data[0] >> 4) & 0x1,
				(data[0] >> 3) & 0x1,
				(data[0] >> 2) & 0x1,
				(data[0] >> 1) & 0x1,
				(data[0] >> 0) & 0x1); break;
		case TPM_DATA_FIFO:
			printf("FIFO\n"); break;
		case IDS_CTRL:
			printf("DEBUG_CONTROL%u:\n"
				"\tdbgExecEngineDone: %u\n"
				"\tdbgFifoEmpty: %u\n"
				"\tdbgFifoComplete: %u\n",
				locality,
				(data[0] >> 2) & 0x1,
				(data[0] >> 1) & 0x1,
				(data[0] >> 0) & 0x1); break;				
			
		default: printf("unimplemented printout.\n"); break;	
	}
}

#include "TpmTypes.h"

// used to send command to the TPM
// locality: locality sending command
// commandCode: code of command
// tag: command tag
// the size of the follow three arrays is determined internally by the command code. to be safe, they should be size 4
// *handles: array of handle data
// *sessionHandles: array of sessionHandles
// *sessionAttributes: array of sessionAttributes
// nParams: number of parameters (in bytes)
// *parameters: parameters
void tpm_command(unsigned locality, unsigned commandCode, unsigned short tag, unsigned *handles, unsigned *sessionHandles, unsigned char *sessionAttributes, unsigned nParams, unsigned char *parameters)
{
	unsigned nHandles = 0;
	unsigned nSessions = 0;
	
	// decode number of handles, sessions from command code
	switch (commandCode)
	{
		case TPM_CC_Startup:			nHandles = 0, nSessions = 0; break; // 3'd0, 3'd0
		case TPM_CC_Shutdown:			nHandles = 0, nSessions = 0; break; // 3'd0, 3'd0
		case TPM_CC_SelfTest:			nHandles = 0, nSessions = 0; break; // 3'd0, 3'd0
		case TPM_CC_IncrementalSelfTest:	nHandles = 0, nSessions = 0; break; // 3'd0, 3'd0
		case TPM_CC_GetTestResult:		nHandles = 0, nSessions = 0; break; // 3'd0, 3'd0
		case TPM_CC_StirRandom:			nHandles = 0, nSessions = 0; break; // 3'd0, 3'd0
		case TPM_CC_GetRandom:			nHandles = 0, nSessions = 0; break; // 3'd0, 3'd0
		case TPM_CC_GetCapability:		nHandles = 0, nSessions = 0; break; // 3'd0, 3'd0
		case TPM_CC_FirmwareRead:		nHandles = 0, nSessions = 0; break; // 3'd0, 3'd0
		case TPM_CC_GetTime:			nHandles = 2, nSessions = 2; break; // 3'd2, 3'd2
		case TPM_CC_ReadClock:			nHandles = 0, nSessions = 0; break; // 3'd0, 3'd0
		case TPM_CC_ECC_Parameters:		nHandles = 0, nSessions = 0; break; // 3'd0, 3'd0
		case TPM_CC_TestParms:			nHandles = 0, nSessions = 0; break; // 3'd0, 3'd0
		case TPM_CC_Hash:			nHandles = 0, nSessions = 0; break; // 3'd0, 3'd0
		case TPM_CC_PCR_Read:			nHandles = 0, nSessions = 0; break; // 3'd0, 3'd0
		case TPM_CC_GetCommandAuditDigest:	nHandles = 2, nSessions = 2; break; // 3'd2, 3'd2
		case TPM_CC_GetSessionAuditDigest:	nHandles = 3, nSessions = 2; break; // 3'd3, 3'd2
		case TPM_CC_NV_ReadPublic:		nHandles = 1, nSessions = 0; break; // 3'd1, 3'd0
		case TPM_CC_AC_GetCapability:		nHandles = 1, nSessions = 0; break; // 3'd1, 3'd0
		
		case TPM_CC_Clear:			nHandles = 1, nSessions = 1; break; // 3'd1, 3'd1
		case TPM_CC_HierarchyControl:		nHandles = 1, nSessions = 1; break; // 3'd1, 3'd1
		case TPM_CC_ClearControl:		nHandles = 1, nSessions = 1; break; // 3'd1, 3'd1
		case TPM_CC_ClockSet:			nHandles = 1, nSessions = 1; break; // 3'd1, 3'd1
		case TPM_CC_ClockRateAdjust:		nHandles = 1, nSessions = 1; break; // 3'd1, 3'd1
		case TPM_CC_HierarchyChangeAuth:	nHandles = 1, nSessions = 1; break; // 3'd1, 3'd1
		case TPM_CC_NV_DefineSpace:		nHandles = 1, nSessions = 1; break; // 3'd1, 3'd1
		case TPM_CC_PCR_Allocate:		nHandles = 1, nSessions = 1; break; // 3'd1, 3'd1
		case TPM_CC_PCR_SetAuthPolicy:		nHandles = 1, nSessions = 1; break; // 3'd1, 3'd1
		case TPM_CC_PP_Commands:		nHandles = 1, nSessions = 1; break; // 3'd1, 3'd1
		case TPM_CC_SetPrimaryPolicy:		nHandles = 1, nSessions = 1; break; // 3'd1, 3'd1
		case TPM_CC_SetAlgorithmSet:		nHandles = 1, nSessions = 1; break; // 3'd1, 3'd1
		case TPM_CC_SetCommandCodeAuditStatus:	nHandles = 1, nSessions = 1; break; // 3'd1, 3'd1
		case TPM_CC_CreatePrimary:		nHandles = 1, nSessions = 1; break; // 3'd1, 3'd1
		case TPM_CC_NV_GlobalWriteLock:		nHandles = 1, nSessions = 1; break; // 3'd1, 3'd1
		case TPM_CC_NV_Increment:		nHandles = 2, nSessions = 1; break; // 3'd2, 3'd1
		case TPM_CC_NV_SetBits:			nHandles = 2, nSessions = 1; break; // 3'd2, 3'd1
		case TPM_CC_NV_Extend:			nHandles = 2, nSessions = 1; break; // 3'd2, 3'd1
		case TPM_CC_NV_WriteLock:		nHandles = 2, nSessions = 1; break; // 3'd2, 3'd1
		case TPM_CC_DictionaryAttackLockReset:	nHandles = 1, nSessions = 1; break; // 3'd1, 3'd1
		case TPM_CC_DictionaryAttackParameters:	nHandles = 1, nSessions = 1; break; // 3'd1, 3'd1
		case TPM_CC_NV_ChangeAuth:		nHandles = 1, nSessions = 1; break; // 3'd1, 3'd1
		case TPM_CC_PCR_Event:			nHandles = 1, nSessions = 1; break; // 3'd1, 3'd1
		case TPM_CC_PCR_Reset:			nHandles = 1, nSessions = 1; break; // 3'd1, 3'd1
		case TPM_CC_PCR_Extend:			nHandles = 1, nSessions = 1; break; // 3'd1, 3'd1
		case TPM_CC_PCR_SetAuthValue:		nHandles = 1, nSessions = 1; break; // 3'd1, 3'd1
		case TPM_CC_SequenceComplete:		nHandles = 1, nSessions = 1; break; // 3'd1, 3'd1
		case TPM_CC_EventSequenceComplete:	nHandles = 2, nSessions = 2; break; // 3'd2, 3'd2
		case TPM_CC_FlushContext:		nHandles = 1, nSessions = 0; break; // 3'd1, 3'd0
		case TPM_CC_Create:			nHandles = 1, nSessions = 1; break; // 3'd1, 3'd1
		case TPM_CC_Load:			nHandles = 1, nSessions = 1; break; // 3'd1, 3'd1
		case TPM_CC_Unseal:			nHandles = 1, nSessions = 1; break; // 3'd1, 3'd1
		case TPM_CC_Sign:			nHandles = 1, nSessions = 1; break; // 3'd1, 3'd1
		case TPM_CC_ReadPublic:			nHandles = 1, nSessions = 0; break; // 3'd1, 3'd0
		case TPM_CC_ECDH_KeyGen: 		nHandles = 1, nSessions = 0; break; // 3'd1, 3'd0
		case TPM_CC_RSA_Decrypt:		nHandles = 1, nSessions = 0; break; // 3'd1, 3'd0
		case TPM_CC_ECDH_ZGen: 			nHandles = 1, nSessions = 1; break; // 3'd1, 3'd1
		case TPM_CC_ContextSave:		nHandles = 1, nSessions = 0; break; // 3'd1, 3'd0
		case TPM_CC_ContextLoad:		nHandles = 0, nSessions = 0; break; // 3'd0, 3'd0
		case TPM_CC_NV_Read:			nHandles = 2, nSessions = 1; break; // 3'd2, 3'd1
		case TPM_CC_NV_ReadLock:		nHandles = 2, nSessions = 1; break; // 3'd2, 3'd1
		case TPM_CC_ObjectChangeAuth:		nHandles = 2, nSessions = 1; break; // 3'd2, 3'd1
		case TPM_CC_PolicySecret:		nHandles = 2, nSessions = 1; break; // 3'd2, 3'd1
		case TPM_CC_Rewrap:			nHandles = 2, nSessions = 1; break; // 3'd2, 3'd1
		case TPM_CC_RSA_Encrypt:		nHandles = 1, nSessions = 0; break; // 3'd1, 3'd0
		case TPM_CC_VerifySignature:		nHandles = 1, nSessions = 0; break; // 3'd1, 3'd0
		case TPM_CC_Commit:			nHandles = 1, nSessions = 1; break; // 3'd1, 3'd1
		case TPM_CC_EC_Ephemeral:		nHandles = 0, nSessions = 0; break; // 3'd0, 3'd0
		case TPM_CC_CreateLoaded:		nHandles = 1, nSessions = 1; break; // 3'd1, 3'd1
		case TPM_CC_AC_Send:			nHandles = 3, nSessions = 2; break; // 3'd3, 3'd2
		
		case TPM_CC_NV_UndefineSpace:		nHandles = 2, nSessions = 1; break; // 3'd2, 3'd1
		case TPM_CC_NV_UndefineSpaceSpecial:	nHandles = 2, nSessions = 2; break; // 3'd2, 3'd2
		case TPM_CC_EvictControl:		nHandles = 2, nSessions = 1; break; // 3'd2, 3'd1
		case TPM_CC_ChangeEPS:			nHandles = 1, nSessions = 1; break; // 3'd1, 3'd1
		case TPM_CC_ChangePPS:			nHandles = 1, nSessions = 1; break; // 3'd1, 3'd1
		case TPM_CC_NV_Write:			nHandles = 2, nSessions = 1; break; // 3'd2, 3'd1
		case TPM_CC_StartAuthSession:		nHandles = 2, nSessions = 0; break; // 3'd2, 3'd0
		case TPM_CC_ActivateCredential:		nHandles = 2, nSessions = 2; break; // 3'd2, 3'd2
		case TPM_CC_Certify:			nHandles = 2, nSessions = 2; break; // 3'd2, 3'd2
		case TPM_CC_PolicyNV:			nHandles = 3, nSessions = 1; break; // 3'd3, 3'd1
		case TPM_CC_CertifyCreation:		nHandles = 2, nSessions = 1; break; // 3'd2, 3'd1
		case TPM_CC_Duplicate:			nHandles = 2, nSessions = 1; break; // 3'd2, 3'd1
		case TPM_CC_Quote:			nHandles = 1, nSessions = 1; break; // 3'd1, 3'd1
		case TPM_CC_HMAC:			nHandles = 1, nSessions = 1; break; // 3'd1, 3'd1
		case TPM_CC_Import:			nHandles = 1, nSessions = 1; break; // 3'd1, 3'd1
		case TPM_CC_PolicySigned:		nHandles = 2, nSessions = 0; break; // 3'd2, 3'd0
		case TPM_CC_EncryptDecrypt: 		nHandles = 1, nSessions = 1; break; // 3'd1, 3'd1
		case TPM_CC_MakeCredential: 		nHandles = 1, nSessions = 0; break; // 3'd1, 3'd0
		case TPM_CC_PolicyAuthorize: 		nHandles = 1, nSessions = 0; break; // 3'd1, 3'd0
		case TPM_CC_PolicyAuthValue: 		nHandles = 1, nSessions = 0; break; // 3'd1, 3'd0
		case TPM_CC_PolicyCommandCode: 		nHandles = 1, nSessions = 0; break; // 3'd1, 3'd0
		case TPM_CC_PolicyCounterTimer:		nHandles = 1, nSessions = 0; break; // 3'd1, 3'd0
		case TPM_CC_PolicyCpHash:		nHandles = 1, nSessions = 0; break; // 3'd1, 3'd0
		case TPM_CC_PolicyLocality:		nHandles = 1, nSessions = 0; break; // 3'd1, 3'd0
		case TPM_CC_PolicyNameHash:		nHandles = 1, nSessions = 0; break; // 3'd1, 3'd0
		case TPM_CC_PolicyOR:			nHandles = 1, nSessions = 0; break; // 3'd1, 3'd0
		case TPM_CC_PolicyTicket:		nHandles = 1, nSessions = 0; break; // 3'd1, 3'd0
		case TPM_CC_PolicyPCR:			nHandles = 1, nSessions = 0; break; // 3'd1, 3'd0
		case TPM_CC_PolicyRestart:		nHandles = 1, nSessions = 0; break; // 3'd1, 3'd0
		case TPM_CC_PolicyPhysicalPresence: 	nHandles = 1, nSessions = 0; break; // 3'd1, 3'd0
		case TPM_CC_PolicyDuplicationSelect:	nHandles = 1, nSessions = 0; break; // 3'd1, 3'd0
		case TPM_CC_PolicyGetDigest:		nHandles = 1, nSessions = 0; break; // 3'd1, 3'd0
		case TPM_CC_PolicyPassword:		nHandles = 1, nSessions = 0; break; // 3'd1, 3'd0
		case TPM_CC_ZGen_2Phase: 		nHandles = 1, nSessions = 1; break; // 3'd1, 3'd1
		case TPM_CC_PolicyNvWritten:		nHandles = 1, nSessions = 0; break; // 3'd1, 3'd0
		case TPM_CC_PolicyTemplate:		nHandles = 1, nSessions = 0; break; // 3'd1, 3'd0
		case TPM_CC_PolicyAuthorizeNV:		nHandles = 3, nSessions = 1; break; // 3'd3, 3'd1
		case TPM_CC_EncryptDecrypt2:		nHandles = 1, nSessions = 1; break; // 3'd1, 3'd1
		case TPM_CC_Policy_AC_SendSelect:	nHandles = 1, nSessions = 0; break; // 3'd1, 3'd0
		case TPM_CC_NV_Certify:			nHandles = 3, nSessions = 2; break; // 3'd3, 3'd2
	
		case TPM_CC_HashSequenceStart:		nHandles = 0, nSessions = 0; break; // 3'd0, 3'd0
		case TPM_CC_HMAC_Start:			nHandles = 1, nSessions = 1; break; // 3'd1, 3'd1
		case TPM_CC_SequenceUpdate:		nHandles = 1, nSessions = 1; break; // 3'd1, 3'd1
		case TPM_CC_LoadExternal:		nHandles = 0, nSessions = 0; break; // 3'd0, 3'd0
		
		// default case represents an undefined command code
		default:				nHandles = 0, nSessions = 0; break; // 3'd7, 3'd7
	}
	
	// if the tag dictates there will be no sessions, overwrite nSessions to 0
	if (tag == TPM_ST_NO_SESSIONS)
		nSessions = 0;
	
	// placeholder nonce and hmac data
	unsigned char nonce[] = "This is a placeholder nonce buffer.";
	unsigned char hmac[] = "This is a placeholder HMAC buffer.";
	
	// calculate nonce buffer size
	unsigned char nonceSize[2];
	nonceSize[0] = ((unsigned short)sizeof(nonce) & 0xFF00) >> 8;
	nonceSize[1] = ((unsigned short)sizeof(nonce) & 0x00FF) >> 0;
	
	// calculate hmac buffer size
	unsigned char hmacSize[2];
	hmacSize[0] = ((unsigned short)sizeof(hmac) & 0xFF00) >> 8;
	hmacSize[1] = ((unsigned short)sizeof(hmac) & 0x00FF) >> 0;
	
	// calculate command, auth sizes
	unsigned cmdSize = 10;
	unsigned authSize = nSessions*(9 + sizeof(nonce) + sizeof(hmac));
	
	cmdSize += nParams;
	cmdSize += nHandles*4;
	if (nSessions)
		cmdSize += 4 + authSize;
	
	// create command header
	unsigned char cmdHeader[10];
	cmdHeader[0] = (tag & 0xFF00) >> 8;
	cmdHeader[1] = (tag & 0x00FF) >> 0;
	cmdHeader[2] = (cmdSize & 0xFF000000) >> 24;
	cmdHeader[3] = (cmdSize & 0x00FF0000) >> 16;
	cmdHeader[4] = (cmdSize & 0x0000FF00) >> 8;
	cmdHeader[5] = (cmdSize & 0x000000FF) >> 0;
	cmdHeader[6] = (commandCode & 0xFF000000) >> 24;
	cmdHeader[7] = (commandCode & 0x00FF0000) >> 16;
	cmdHeader[8] = (commandCode & 0x0000FF00) >> 8;
	cmdHeader[9] = (commandCode & 0x000000FF) >> 0;
	
	unsigned char word[4], buf[4096];
	
	// send command header
	tpm_transaction(WRITE, sizeof(cmdHeader), locality, TPM_DATA_FIFO, cmdHeader);
	
	// send handles
	for(unsigned i=0; i<nHandles; i++)
	{
		word[0] = (handles[i] & 0xFF000000) >> 24;
		word[1] = (handles[i] & 0x00FF0000) >> 16;
		word[2] = (handles[i] & 0x0000FF00) >> 8;
		word[3] = (handles[i] & 0x000000FF) >> 0;
		memcpy(buf, word, sizeof(word));
	}
	if (nHandles)
		tpm_transaction(WRITE, nHandles*sizeof(word), locality, TPM_DATA_FIFO, buf);
	
	// send authorization area size
	if (nSessions)
	{
		word[0] = (authSize & 0xFF000000) >> 24;
		word[1] = (authSize & 0x00FF0000) >> 16;
		word[2] = (authSize & 0x0000FF00) >> 8;
		word[3] = (authSize & 0x000000FF) >> 0;
		tpm_transaction(WRITE, sizeof(word), locality, TPM_DATA_FIFO, word);
	}
	
	// send sessions (auths)
	for(unsigned i=0; i<nSessions; i++)
	{
		unsigned index = 0;
		
		// send session handle
		word[0] = (sessionHandles[i] & 0xFF000000) >> 24;
		word[1] = (sessionHandles[i] & 0x00FF0000) >> 16;
		word[2] = (sessionHandles[i] & 0x0000FF00) >> 8;
		word[3] = (sessionHandles[i] & 0x000000FF) >> 0;
		memcpy(buf, word, sizeof(word)); index += sizeof(word);
		
		// send nonce size
		memcpy(buf+index, nonceSize, sizeof(nonceSize)); index += sizeof(nonceSize);
		
		// send nonce
		memcpy(buf+index, nonce, sizeof(nonce)); index += sizeof(nonce);
		
		// send session attribute
		memcpy(buf+index, sessionAttributes+i, 1); index += 1;
		
		// send hmac size
		memcpy(buf+index, hmacSize, sizeof(hmacSize)); index += sizeof(hmacSize);
		
		// send hmac
		memcpy(buf+index, hmac, sizeof(hmac)); index += sizeof(hmac);
		
	//	for(unsigned j=0; j<index; j++)
	//		printf("%02X ", buf[j]);
		
		// bulk write of auth area
		while(index>64)
		{
			tpm_transaction(WRITE, 64, locality, TPM_DATA_FIFO, buf);
			index -= 64;
		}
		tpm_transaction(WRITE, index, locality, TPM_DATA_FIFO, buf);
	}
	
	// send command parameters by byte (not extendable, will need replacement)
	for(unsigned i=0; i<nParams; i++)
	{
		tpm_transaction(WRITE, 1, locality, TPM_DATA_FIFO, parameters+i);
	}
	
}


// name test function signatures here
void test_debugRW(void);
void test_localityChanging(void);
void test_localityPermissions(void);
void test_statusStateMachine(void);
void test_localitySeizeCommandAbort(void);
void test_sendReceiveCMD(void);
void test_hierarchyControl(void);
void test_hierarchyControl2(void);
void test_ccQuote(void);

// main simply runs setup functions, test function, and closing functions
int main(int argc, char **argv)
{
	// initialize ftdi connection at 24 MHz
	ftdi_connect(24000000);
	// init verilog tb generation with command line inputs
	init_verilog_gen(argc, argv);
	
	// if we could not connect to the ftdi cable nor are setup to generate a verilog file, return
	if (!(_connected || _generateVerilogTB))
		return 1;
	
	
	// test functions
	test_debugRW(); // pass
	test_localityChanging(); // pass
	test_localityPermissions(); // pass
	test_statusStateMachine(); // pass
	test_localitySeizeCommandAbort(); // pass
	test_hierarchyControl(); // pass
	test_hierarchyControl2(); // pass
	test_ccQuote(); // pass


/*	// expo demo table loop
	for(;; Sleep(1000))
	{

		test_hierarchyControl2();
		check_assert();
		_errors = 0;
		
		test_ccQuote();
		check_assert();
		_errors = 0;
		
		// resetting error count was necessary as
		// the cable will occasionally drop a transmission, and these test functions
		// do not properly run the checks to see if the transmission made it before trying
		// to execution tpm commands, which would result with errors
	}
*/	
	
	// check for any errors that occured during testing
	check_assert();
	// close ftdi connection
	ftdi_close();
	//close verilog file generation
	close_verilog_gen();
	
	return 0;
}

// this test simply writes 4 bytes, reads them back, and sees if they match
// this uses debug FIFO registers, and is the simplest test.
// if this test does not work, something has been setup wrong (check cables?)
void test_debugRW(void)
{
	tpm_reset();
	tb_comment("test_debugRW");
	
	unsigned char data[64];
	data[0] = r_requestUse;
	tpm_transaction(WRITE, 1, 1, TPM_ACCESS, data);
	
	data[4] = 0xDE;
	data[5] = 0xAD;
	data[6] = 0xBE;
	data[7] = 0xEF;
	
	tpm_transaction(WRITE, 4, 1, IDS_RW, &data[4]);
	tpm_transaction(READ, 4, 1, IDS_RW, data);
	
	for(unsigned i=0; i<4; i++)
		tb_assert(data, i, 0xFF, EQUAL, data[i+4],
			"Testbench Failure (RW).");
}

// this tests the changing of the active locality
void test_localityChanging(void)
{
	tpm_reset();
	tb_comment("test_localityChanging");
	
	unsigned char data[64];
	
	for(unsigned i=0; i<5; i++)
		print_tpm_transaction(READ, 1, i, TPM_ACCESS, data);
	printf("\n");
	
	data[0] = r_requestUse;
	print_tpm_transaction(WRITE, 1, 2, TPM_ACCESS, data);
	printf("\n");
	
	for(unsigned i=0; i<5; i++)
		print_tpm_transaction(READ, 1, i, TPM_ACCESS, data);
	printf("\n");
	
	data[0] = r_Seize;
	print_tpm_transaction(WRITE, 1, 4, TPM_ACCESS, data);
	printf("\n");
	
	for(unsigned i=0; i<5; i++)
		print_tpm_transaction(READ, 1, i, TPM_ACCESS, data);
	printf("\n");
	
	data[0] = r_beenSeized;
	print_tpm_transaction(WRITE, 1, 2, TPM_ACCESS, data);
	printf("\n");
	
	for(unsigned i=0; i<5; i++)
		print_tpm_transaction(READ, 1, i, TPM_ACCESS, data);
	printf("\n");
	
	data[0] = r_requestUse;
	print_tpm_transaction(WRITE, 1, 1, TPM_ACCESS, data);
	
	data[0] = r_requestUse;
	print_tpm_transaction(WRITE, 1, 2, TPM_ACCESS, data);
	printf("\n");
	
	for(unsigned i=0; i<5; i++)
		print_tpm_transaction(READ, 1, i, TPM_ACCESS, data);
	printf("\n");
	
	data[0] = r_activeLocality;
	print_tpm_transaction(WRITE, 1, 4, TPM_ACCESS, data);
	printf("\n");
	
	for(unsigned i=0; i<5; i++)
		print_tpm_transaction(READ, 1, i, TPM_ACCESS, data);
	printf("\n");
	
	data[0] = r_Seize;
	print_tpm_transaction(WRITE, 1, 0, TPM_ACCESS, data);
	printf("\n");
	
	for(unsigned i=0; i<5; i++)
		print_tpm_transaction(READ, 1, i, TPM_ACCESS, data);
	printf("\n");
	
	data[0] = r_activeLocality;
	print_tpm_transaction(WRITE, 1, 2, TPM_ACCESS, data);
	printf("\n");
	
	for(unsigned i=0; i<5; i++)
		print_tpm_transaction(READ, 1, i, TPM_ACCESS, data);
	printf("\n");
}

// this tests locality permissions:
// only the active locality should be able to read/write to a specific register
void test_localityPermissions(void)
{
	tpm_reset();
	tb_comment("test_localityPermissions");
	
	unsigned char data[64];
	
	print_tpm_transaction(READ, 4, 0, TPM_DID_VID, data);
	
	for(unsigned i=0; i<4; i++)
		tb_assert(data, i, 0xFF, EQUAL, 0xFF,
			"Error: Read allowed from wrong locality.");
	
	print_tpm_transaction(READ, 4, 3, TPM_DID_VID, data);
	
	for(unsigned i=0; i<4; i++)
		tb_assert(data, i, 0xFF, EQUAL, 0xFF,
			"Error: Read allowed from wrong locality.");
	
	print_tpm_transaction(READ, 1, 0, TPM_ACCESS, data);
	
	data[0] = r_requestUse;
	print_tpm_transaction(WRITE, 1, 0, TPM_ACCESS, data);
	
	print_tpm_transaction(READ, 1, 0, TPM_ACCESS, data);
	print_tpm_transaction(READ, 4, 0, TPM_DID_VID, data);
	
	tb_assert(data, 0, 0xFF, EQUAL, 0x37,
		"Error: This locality should be able to read!");
	tb_assert(data, 1, 0xFF, EQUAL, 0x30,
		"Error: This locality should be able to read!");
	tb_assert(data, 2, 0xFF, EQUAL, 0x54,
		"Error: This locality should be able to read!");
	tb_assert(data, 3, 0xFF, EQUAL, 0x56,
		"Error: This locality should be able to read!");
	
	print_tpm_transaction(READ, 4, 3, TPM_DID_VID, data);
	
	for(unsigned i=0; i<4; i++)
		tb_assert(data, i, 0xFF, EQUAL, 0xFF,
			"Error: Read allowed from wrong locality.");
	
	print_tpm_transaction(READ, 1, 3, TPM_ACCESS, data);
	
	data[0] = r_requestUse;
	print_tpm_transaction(WRITE, 1, 3, TPM_ACCESS, data);
	
	print_tpm_transaction(READ, 1, 0, TPM_ACCESS, data);
	
	tb_assert(data, 0, r_activeLocality | r_pendingRequest, EQUAL, r_activeLocality | r_pendingRequest,
		"Error: Locality requestUse error.");
	
	print_tpm_transaction(READ, 1, 3, TPM_ACCESS, data);
	tb_assert(data, 0, r_activeLocality, EQUAL, 0,
		"Error: This locality should not be active.");
	tb_assert(data, 0, r_requestUse, EQUAL, r_requestUse,
		"Error: This locality should be requesting use.");
	
	
	data[0] = r_activeLocality;
	print_tpm_transaction(WRITE, 1, 0, TPM_ACCESS, data);
	print_tpm_transaction(READ, 1, 0, TPM_ACCESS, data);
	tb_assert(data, 0, r_activeLocality, EQUAL, 0,
		"Error: This locality should not be active.");
	tb_assert(data, 0, r_pendingRequest, EQUAL, 0,
		"Error: There should be no locality requesting use.");
	
	print_tpm_transaction(READ, 1, 3, TPM_ACCESS, data);
	tb_assert(data, 0, r_activeLocality, EQUAL, r_activeLocality,
		"Error: This locality should be the active locality.");
	tb_assert(data, 0, r_requestUse, EQUAL, 0,
		"Error: This locality's request should be set low, as it is active now.");
	
	print_tpm_transaction(READ, 4, 0, TPM_DID_VID, data);
	for(unsigned i=0; i<4; i++)
		tb_assert(data, i, 0xFF, EQUAL, 0xFF,
			"Error: Read allowed from wrong locality.");
	
	print_tpm_transaction(READ, 4, 3, TPM_DID_VID, data);
	
	tb_assert(data, 0, 0xFF, EQUAL, 0x37,
		"Error: This locality should be able to read!");
	tb_assert(data, 1, 0xFF, EQUAL, 0x30,
		"Error: This locality should be able to read!");
	tb_assert(data, 2, 0xFF, EQUAL, 0x54,
		"Error: This locality should be able to read!");
	tb_assert(data, 3, 0xFF, EQUAL, 0x56,
		"Error: This locality should be able to read!");
	
	data[0] = r_activeLocality;
	print_tpm_transaction(WRITE, 1, 3, TPM_ACCESS, data);
	print_tpm_transaction(READ, 1, 3, TPM_ACCESS, data);
	tb_assert(data, 0, r_activeLocality, EQUAL, 0,
		"Error: This locality should not be active.");
	
	print_tpm_transaction(READ, 4, 0, TPM_DID_VID, data);
	for(unsigned i=0; i<4; i++)
		tb_assert(data, i, 0xFF, EQUAL, 0xFF,
			"Error: Read allowed from wrong locality.");
	
	print_tpm_transaction(READ, 4, 3, TPM_DID_VID, data);
	for(unsigned i=0; i<4; i++)
		tb_assert(data, i, 0xFF, EQUAL, 0xFF,
			"Error: Read allowed from wrong locality.");
}

// this tests the i/o status state machine
void test_statusStateMachine(void)
{
	tpm_reset();
	tb_comment("test_statusStateMachine");
	
	unsigned char data[64];
	
tb_comment("Locality 4 will be used for this test");
	data[0] = r_requestUse;
	print_tpm_transaction(WRITE, 1, 4, TPM_ACCESS, data);
	print_tpm_transaction(READ, 1, 4, TPM_STS, data);
	
	tb_assert(data, 0, 0xff, EQUAL, r_stsValid,
		"Testbench failure: TPM_STS state incorrect.");
	
	data[0] = r_commandReady;
	print_tpm_transaction(WRITE, 1, 1, TPM_STS, data);
	print_tpm_transaction(READ, 1, 4, TPM_STS, data);
	
tb_comment("TPM should be in Idle state, as Locality 1 cannot control TPM_STS (Locality 4 is in control)");
	tb_assert(data, 0, 0xff, EQUAL, r_stsValid,
		"Testbench failure: TPM_STS state incorrect.");
	
tb_comment("Check which interrupts are supported");
	print_tpm_transaction(READ, 4, 4, TPM_INTF_CAPABILITY, data);
	
tb_comment("Enable specific interrupts");
	data[3] = r_globalIntEnable;
	data[1] = data[2] = 0x00;
	data[0] = r_dataAvailIntEnable | r_commandReadyIntEnable | r_localityChangeIntEnable;
	print_tpm_transaction(WRITE, 4, 4, TPM_INT_ENABLE, data);
	
	data[0] = r_commandReady;
	print_tpm_transaction(WRITE, 1, 4, TPM_STS, data);
	print_tpm_transaction(READ, 1, 4, TPM_STS, data);
	
tb_comment("TPM should now be in Ready state ... commandReadyInterrupt should be active");
	
	tb_assert(data, 0, r_commandReady, EQUAL, r_commandReady,
		"Testbench failure: TPM_STS.commandReady != 1.");
	
tb_comment("Check the commandReadyInterrupt");
	print_tpm_transaction(READ, 1, 4, TPM_INT_STATUS, data);
	
	tb_assert(data, 0, r_commandReadyIntOccurred, EQUAL, r_commandReadyIntOccurred,
		"Testbench Failure: commandReadyInt should be high.");
	
tb_comment("Reset interrupts");
	print_tpm_transaction(WRITE, 1, 4, TPM_INT_STATUS, data);
	
tb_comment("Ensure interrupts have been reset");
	print_tpm_transaction(READ, 1, 4, TPM_INT_STATUS, data);
	
	tb_assert(data, 0, r_commandReadyIntOccurred, EQUAL, 0,
		"Testbench Failure: commandReadyInt should be low.");
	
tb_comment("Write first byte to FIFO, state should transition to Reception");

tb_comment("Send first byte of command tag.");
	data[0] = TPM_ST_NO_SESSIONS >> 8;
	print_tpm_transaction(WRITE, 1, 4, TPM_DATA_FIFO, data);
	print_tpm_transaction(READ, 1, 4, TPM_STS, data);
	
	tb_assert(data, 0, r_Expect, EQUAL, r_Expect,
		"Testbench Failure: TPM_STS.Expect should be 1.");
	
tb_comment("Write of tpmGo does nothing, as the command hasn't finished sending ; Expect = 1");
	data[0] = r_tpmGo;
	print_tpm_transaction(WRITE, 1, 4, TPM_STS, data);
	print_tpm_transaction(READ, 1, 4, TPM_STS, data);
	
	tb_assert(data, 0, r_Expect, EQUAL, r_Expect,
		"Testbench Failure: TPM_STS.Expect should be 1.");
	
tb_comment("Once FIFO is full (command fully sent), tmpGo may be used ; Expect = 0");

tb_comment("Send second byte of command tag.");
	data[0] = TPM_ST_NO_SESSIONS & 0xFF;
	print_tpm_transaction(WRITE, 1, 4, TPM_DATA_FIFO, data);

tb_comment("Send command header.");
	data[0] = 0x00;
	for(unsigned i=0; i<3; i++)
		tpm_transaction(WRITE, 1, 4, TPM_DATA_FIFO, data);
	data[0] = 0x0A;
	print_tpm_transaction(WRITE, 1, 4, TPM_DATA_FIFO, data);
	
	print_tpm_transaction(READ, 1, 4, TPM_STS, data);
	tb_assert(data, 0, r_Expect, EQUAL, r_Expect,
		"Testbench Failure: TPM_STS.Expect should be 1.");
	
tb_comment("Send command code.");
	data[0] = (TPM_CC_Startup & 0xFF000000) >> 24;
	data[1] = (TPM_CC_Startup & 0x00FF0000) >> 16;
	data[2] = (TPM_CC_Startup & 0x0000FF00) >> 8;
	print_tpm_transaction(WRITE, 3, 4, TPM_DATA_FIFO, data);
	
	print_tpm_transaction(READ, 1, 4, TPM_STS, data);
	tb_assert(data, 0, r_Expect, EQUAL, r_Expect,
		"Testbench Failure: TPM_STS.Expect should be 1.");
	
	data[0] = (TPM_CC_Startup & 0x000000FF) >> 0;
	print_tpm_transaction(WRITE, 1, 4, TPM_DATA_FIFO, data);
	
	print_tpm_transaction(READ, 1, 4, TPM_STS, data);
	tb_assert(data, 0, r_Expect, EQUAL, 0,
		"Testbench Failure: TPM_STS.Expect should be 0.");
	
tb_comment("Now tpmGo can be sent, state transitions to Execution");
	data[0] = r_tpmGo;
	print_tpm_transaction(WRITE, 1, 4, TPM_STS, data);
	print_tpm_transaction(READ, 1, 4, TPM_STS, data);
	
tb_comment("Once Execution is finished, state transitions to Complete ; dataAvail = 1");
// old debug feature use, from before CRB was implemented
//	data[0] = r_dbgExecEngineDone;
//	print_tpm_transaction(WRITE, 1, 4, IDS_CTRL, data);
	
	tpm_waitExec(4, 15);
	print_tpm_transaction(READ, 1, 4, TPM_STS, data);
	
	tb_assert(data, 0, r_dataAvail, EQUAL, r_dataAvail,
		"Testbench Failure: TPM_STS.dataAvail should be 1.");
	
tb_comment("Check the dataAvailInterrupt");
	print_tpm_transaction(READ, 1, 4, TPM_INT_STATUS, data);
	
	tb_assert(data, 0, r_dataAvailIntOccurred, EQUAL, r_dataAvailIntOccurred,
		"Testbench Failure: dataAvail Interrupt should be high.");
	
tb_comment("Reset interrupts");
	print_tpm_transaction(WRITE, 1, 4, TPM_INT_STATUS, data);
	
tb_comment("Ensure interrupts have been reset");
	print_tpm_transaction(READ, 1, 4, TPM_INT_STATUS, data);
	
	tb_assert(data, 0, r_dataAvailIntOccurred, EQUAL, 0,
		"Testbench Failure: dataAvail Interrupt should be low.");
	
tb_comment("Read data out of FIFO.");
	print_tpm_transaction(READ, 10, 4, TPM_DATA_FIFO, data);

tb_comment("Once Fifo has been fully read, dataAvail = 0");
// old debug feature use, from before FIFO buffer was implemented
//	data[0] = r_dbgFifoEmpty;
//	print_tpm_transaction(WRITE, 1, 4, IDS_CTRL, data);

	print_tpm_transaction(READ, 1, 4, TPM_STS, data);
	tb_assert(data, 0, r_dataAvail, EQUAL, 0,
		"Testbench Failure: TPM_STS.dataAvail should be 0.");

tb_comment("Test responseRetry");
	data[0] = r_responseRetry;
	print_tpm_transaction(WRITE, 1, 4, TPM_STS, data);
	
	print_tpm_transaction(READ, 1, 4, TPM_STS, data);
	tb_assert(data, 0, r_dataAvail, EQUAL, r_dataAvail,
		"Testbench Failure: TPM_STS.dataAvail should be 1.");

tb_comment("Read data out of FIFO.");
	for(unsigned i=0; i<10; i++)
		tpm_transaction(READ, 1, 4, TPM_DATA_FIFO, data);

	print_tpm_transaction(READ, 1, 4, TPM_STS, data);
	tb_assert(data, 0, r_dataAvail, EQUAL, 0,
		"Testbench Failure: TPM_STS.dataAvail should be 0.");
	
tb_comment("State transitions back to Idle");
	data[0] = r_commandReady;
	print_tpm_transaction(WRITE, 1, 4, TPM_STS, data);
	print_tpm_transaction(READ, 1, 4, TPM_STS, data);
	
tb_comment("Locality 4 gives up control");
	data[0] = r_activeLocality;
	print_tpm_transaction(WRITE, 1, 4, TPM_ACCESS, data);
	tpm_transaction(READ, 1, 4, TPM_ACCESS, data);
	
	tb_assert(data, 0, r_activeLocality, EQUAL, 0,
		"Testbench Failure: Locality 4 should not be active.");
}

// test the ability for locality seizure
// higher localities should be able to seize control from lesser localities
void test_localitySeizeCommandAbort(void)
{
	tpm_reset();
	tb_comment("test_localitySeizeCommandAbort");
	
	unsigned char data[64];
	
	// Make Locality 2 be in charge
	data[0] = r_requestUse;
	print_tpm_transaction(WRITE, 1, 2, TPM_ACCESS, data);

	// Enable localityChangeInterrupt
	data[3] = r_globalIntEnable;
	data[1] = data[2] = 0x00;
	data[0] = r_localityChangeIntEnable;
	print_tpm_transaction(WRITE, 4, 2, TPM_INT_ENABLE, data);
	
	// Put TPM into Command Reception state
	data[0] = r_commandReady;
	print_tpm_transaction(WRITE, 1, 2, TPM_STS, data);
	print_tpm_transaction(WRITE, 40, 2, TPM_DATA_FIFO, data);
	
	// Check status ; Expect should be equal to 1
	print_tpm_transaction(READ, 1, 2, TPM_STS, data);
	
	tb_assert(data, 0, r_Expect, EQUAL, r_Expect,
		"Error: TPM is not in Command Reception State. Expect should be 1.");
	
	// Locality 1 tries to Seize ... state does not change.
	data[0] = r_Seize;
	print_tpm_transaction(WRITE, 1, 1, TPM_ACCESS, data);
	print_tpm_transaction(READ, 1, 2, TPM_STS, data);
	tb_assert(data, 0, r_Expect, EQUAL, r_Expect,
		"Error: Expect should still be 1.");
	print_tpm_transaction(READ, 1, 1, TPM_ACCESS, data);
	tb_assert(data, 0, r_activeLocality, EQUAL, 0,
		"Error: Locality 1 may not Seize control from Locality 2.");
	tb_assert(data, 0, r_requestUse, EQUAL, r_requestUse,
		"Error: Locality 1 should now be requesting use.");
	print_tpm_transaction(READ, 1, 2, TPM_ACCESS, data);
	tb_assert(data, 0, r_activeLocality | r_pendingRequest, EQUAL, r_activeLocality | r_pendingRequest,
		"Error: Locality 2 should be active / There should be another locality asking for access.");
	
	// Check the localityChangeInterrupt
	print_tpm_transaction(READ, 1, 2, TPM_INT_STATUS, data);
//	if ((data[0] & r_localityChangeIntOccurred) != 0)
//		printf("\nTestbench failure: localityChangeIntOccured incorrect (expected low).\n");

	tb_assert(data, 0, r_localityChangeIntOccurred, EQUAL, 0,
		"Testbench failure: localityChangeIntOccured incorrect (expected low).");
	
	data[0] = 0xff;
	tpm_transaction(WRITE, 1, 2, TPM_INT_STATUS, data);
	
	// Locality 4 tries to Seize ... state returns to Idle.
	data[0] = r_Seize;
	print_tpm_transaction(WRITE, 1, 4, TPM_ACCESS, data);
	print_tpm_transaction(READ, 1, 2, TPM_STS, data); // Cannot read! Locality 2 is no longer active.
	tb_assert(data, 0, 0xff, EQUAL, 0xff,
		"Error: Locality 2 should no longer be able to read TPM_STS.");
	print_tpm_transaction(READ, 1, 4, TPM_STS, data); // Expect != 1
	tb_assert(data, 0, r_Expect, EQUAL, 0,
		"Error: TPM should be in Idle following a Seize.");
	print_tpm_transaction(READ, 1, 1, TPM_ACCESS, data);
	print_tpm_transaction(READ, 1, 2, TPM_ACCESS, data); // beenSeized!
	tb_assert(data, 0, r_activeLocality, EQUAL, 0,
		"Error: Locality 2 should no longer be in control.");
	tb_assert(data, 0, r_beenSeized, EQUAL, r_beenSeized,
		"Error: Locality 2's beenSeized flag should be set.");
	print_tpm_transaction(READ, 1, 4, TPM_ACCESS, data);
	tb_assert(data, 0, r_activeLocality, EQUAL, r_activeLocality,
		"Error: Locality 4 should be active.");
	
	// Check the localityChangeInterrupt
	print_tpm_transaction(READ, 1, 4, TPM_INT_STATUS, data);
//	if ((data[0] & r_localityChangeIntOccurred) == 0)
//		printf("\nTestbench failure: localityChangeIntOccured incorrect (expected high).\n");

	tb_assert(data, 0, r_localityChangeIntOccurred, EQUAL, r_localityChangeIntOccurred,
		"Testbench failure: localityChangeIntOccured incorrect (expected high).");

	data[0] = 0xff;
	tpm_transaction(WRITE, 1, 4, TPM_INT_STATUS, data);
	
	// Give control to Locality 1
	data[0] = r_activeLocality;
	print_tpm_transaction(WRITE, 1, 4, TPM_ACCESS, data);
	print_tpm_transaction(READ, 1, 1, TPM_ACCESS, data);
	tb_assert(data, 0, r_activeLocality, EQUAL, r_activeLocality,
		"Error: Locality 1 should be active.");
	tb_assert(data, 0, r_pendingRequest, EQUAL, 0,
		"Error: There should be no pending requests.");
	print_tpm_transaction(READ, 1, 2, TPM_ACCESS, data);
	tb_assert(data, 0, r_beenSeized, EQUAL, r_beenSeized,
		"Error: Locality 2's beenSeized flag should still be set.");
	print_tpm_transaction(READ, 1, 4, TPM_ACCESS, data);
	tb_assert(data, 0, r_activeLocality, EQUAL, 0,
		"Error: Locality 4 is no longer in control.");
	
	// Check the localityChangeInterrupt
	print_tpm_transaction(READ, 1, 1, TPM_INT_STATUS, data);
//	if ((data[0] & r_localityChangeIntOccurred) == 0)
//		printf("\nTestbench failure: localityChangeIntOccured incorrect (expected high).\n");

	tb_assert(data, 0, r_localityChangeIntOccurred, EQUAL, r_localityChangeIntOccurred,
		"Testbench failure: localityChangeIntOccured incorrect (expected high).");

	data[0] = 0xff;
	tpm_transaction(WRITE, 1, 1, TPM_INT_STATUS, data);
	
	data[0] = r_beenSeized;
	print_tpm_transaction(WRITE, 1, 2, TPM_ACCESS, data);
	print_tpm_transaction(READ, 1, 2, TPM_ACCESS, data);
	tb_assert(data, 0, r_beenSeized, EQUAL, 0,
		"Error: Locality 2's beenSeized flag should no longer be set.");
}

#define TPM_CC_VEND 0x20000000
// #define TPM_ST_NO_SESSIONS 0x8001


// this test function no longer works, as it relied on old debug features that have been
// removed during development of the TPM. it remains to illustrate how debug features can be added to the TPM
// this used to test sending/receiving command data (before the CRB existed, a dummy module would simply echo the sent data)
// new tests replace this
void test_sendReceiveCMD(void)
{
	tpm_reset();
	tb_comment("test_SendReceiveCMD");
	
	// the test command will be to send a string
	unsigned char cmdHeader[10];
	unsigned char cmdData[] = "This is a test message.";
	unsigned short cmdDataSize_s = strlen(cmdData)+1;
	unsigned char cmdDataSize[2] = { (cmdDataSize_s & 0xFF00) >> 8, cmdDataSize_s & 0xFF };
	
	unsigned cc = TPM_CC_VEND;
	unsigned cmdSize = 11+cmdDataSize_s;
	unsigned short st = TPM_ST_NO_SESSIONS;
	
	cmdHeader[0] = (st & 0xFF00) >> 8;
	cmdHeader[1] = (st & 0x00FF) >> 0;
	cmdHeader[2] = (cmdSize & 0xFF000000) >> 24;
	cmdHeader[3] = (cmdSize & 0x00FF0000) >> 16;
	cmdHeader[4] = (cmdSize & 0x0000FF00) >> 8;
	cmdHeader[5] = (cmdSize & 0x000000FF) >> 0;
	cmdHeader[6] = (cc & 0xFF000000) >> 24;
	cmdHeader[7] = (cc & 0x00FF0000) >> 16;
	cmdHeader[8] = (cc & 0x0000FF00) >> 8;
	cmdHeader[9] = (cc & 0x000000FF) >> 0;
	
	unsigned char data[64];
	
	tb_comment("Using locality 2 for this test.");
	data[0] = r_requestUse;
	tpm_transaction(WRITE, 1, 2, TPM_ACCESS, data);
	
	tb_comment("Enable dataAvail interrupt.");
	data[3] = r_globalIntEnable;
	data[1] = data[2] = 0x00;
	data[0] = r_dataAvailIntEnable;
	print_tpm_transaction(WRITE, 4, 2, TPM_INT_ENABLE, data);
	
	tb_comment("Set TPM to be ready to receive command data");
	data[0] = r_commandReady;
	tpm_transaction(WRITE, 1, 2, TPM_STS, data);
	
	tpm_transaction(READ, 1, 2, TPM_STS, data);
	tb_assert(data, 0, r_commandReady, EQUAL, r_commandReady,
		"Error: TPM should be ready to receive command data.");
	
	tb_comment("Send command header.");
	print_tpm_transaction(WRITE, 10, 2, TPM_DATA_FIFO, cmdHeader);
	
	print_tpm_transaction(READ, 1, 2, TPM_STS, data);
	tb_assert(data, 0, r_Expect, EQUAL, r_Expect,
		"Error: TPM should be expecting command data.");
	
	tb_comment("Send data size.");
	print_tpm_transaction(WRITE, 2, 2, TPM_DATA_FIFO, cmdDataSize);
	
	print_tpm_transaction(READ, 1, 2, TPM_STS, data);
	tb_assert(data, 0, r_Expect, EQUAL, r_Expect,
		"Error: TPM should be expecting command data.");
	
//	tb_comment("Write command data.");
//	print_tpm_transaction(WRITE, cmdDataSize_s, 2, TPM_DATA_FIFO, cmdData);
//	tb_comment("Read command data.");
//	print_tpm_transaction(WRITE, cmdDataSize_s, 2, TPM_DATA_FIFO, cmdData);
	
//	return;

	tb_comment("Write all but the last byte of the cmd data.");
	print_tpm_transaction(WRITE, cmdDataSize_s-1, 2, TPM_DATA_FIFO, cmdData);
//	for(unsigned i=0; i<cmdDataSize_s-1; i++)
//		tpm_transaction(WRITE, 1, 2, TPM_DATA_FIFO, &cmdData[i]);
	
	print_tpm_transaction(READ, 1, 2, TPM_STS, data);
	tb_assert(data, 0, r_Expect, EQUAL, r_Expect,
		"Error: TPM should be expecting command data.");
	
	tb_comment("Write last byte of cmd data from wrong locality.");
	print_tpm_transaction(WRITE, 1, 1, TPM_DATA_FIFO, &cmdData[cmdDataSize_s-1]);
	
	print_tpm_transaction(READ, 1, 2, TPM_STS, data);
	tb_assert(data, 0, r_Expect, EQUAL, r_Expect,
		"Error: TPM should be expecting command data.");
	
	tb_comment("Write last byte of cmd data.");
	print_tpm_transaction(WRITE, 1, 2, TPM_DATA_FIFO, &cmdData[cmdDataSize_s-1]);
	
	print_tpm_transaction(READ, 1, 2, TPM_STS, data);
	tb_assert(data, 0, r_Expect, EQUAL, 0,
		"Error: TPM should no longer expect data.");

	tb_comment("Try to write more to the buffer.");
	print_tpm_transaction(WRITE, cmdDataSize_s/2, 2, TPM_DATA_FIFO, cmdData);
	
	print_tpm_transaction(READ, 1, 2, TPM_STS, data);
	tb_assert(data, 0, r_Expect, EQUAL, 0,
		"Error: TPM should no longer expect data.");
	
	tb_comment("Send tpmGo; start execution.");
	data[0] = r_tpmGo;
	print_tpm_transaction(WRITE, 1, 2, TPM_STS, data);
	
	print_tpm_transaction(READ, 1, 2, TPM_STS, data);
	tb_assert(data, 0, r_dataAvail, EQUAL, 0,
		"Error: TPM not yet have a response.");
	
	tb_comment("Check the localityChangeInterrupt.");
	print_tpm_transaction(READ, 1, 2, TPM_INT_STATUS, data);
	tb_assert(data, 0, r_dataAvailIntOccurred, EQUAL, 0,
		"Testbench failure: r_dataAvailIntOccured incorrect (expected low).");
	
	data[0] = r_dbgExecEngineDone;
	print_tpm_transaction(WRITE, 1, 2, IDS_CTRL, data);
	
	tpm_waitExec(2, 15);
	
	tb_comment("Check the localityChangeInterrupt.");
	print_tpm_transaction(READ, 1, 2, TPM_INT_STATUS, data);
	tb_assert(data, 0, r_dataAvailIntOccurred, EQUAL, r_dataAvailIntOccurred,
		"Testbench failure: r_dataAvailIntOccured incorrect (expected high).");
	
	tb_comment("Clear interrupts.");
	data[0] = 0xff;
	tpm_transaction(WRITE, 1, 2, TPM_INT_STATUS, data);
	
	print_tpm_transaction(READ, 1, 2, TPM_STS, data);
	tb_assert(data, 0, r_dataAvail, EQUAL, r_dataAvail,
		"Error: TPM should have a response.");
	
	tb_comment("Read response data in 1-byte transactions.");
	for(unsigned i=0; i<12; i++)
	{
		tpm_transaction(READ, 1, 2, TPM_DATA_FIFO, &data[i]);
		if (_connected) printf("%02x ", data[i]);
	}
	for(unsigned i=12; i<cmdSize+1; i++)
	{
		tpm_transaction(READ, 1, 2, TPM_DATA_FIFO, &data[i]);
		if (tb_assert(data, i, 0xFF, EQUAL, cmdData[i-12],
			"Incorrect response data."))
			printf("[%u] Expected %02x, got %02x\n", i, cmdData[i-12], data[i]);
		if (_connected) printf("%02x ", data[i]);
	}
	
	print_tpm_transaction(READ, 1, 2, TPM_STS, data);
	tb_assert(data, 0, r_dataAvail, EQUAL, 0,
		"Error: TPM response data should be fully read out.");
/*	
	if (_connected)
	{
		for(unsigned i=0; i<cmdSize; i++)
			printf("%02x ", data[i]);
		printf("\n");
		for(unsigned i=0; i<cmdSize; i++)
			printf("%c", data[i]);
		printf("\n");
	}
*/	
	
	tb_comment("Disable interrupts.");
	data[0] = 0x00;
	tpm_transaction(WRITE, 1, 2, TPM_INT_ENABLE+3, data);
	
	tb_comment("Attempt to responseRetry from wrong locality.");
	data[0] = r_responseRetry;
	print_tpm_transaction(WRITE, 1, 1, TPM_STS, data);
	
	print_tpm_transaction(READ, 1, 2, TPM_STS, data);
	tb_assert(data, 0, r_dataAvail, EQUAL, 0,
		"Error: dataAvail should have not been reset from incorrect locality.");
	
	tb_comment("Send responseRetry from correct locality.");
	data[0] = r_responseRetry;
	print_tpm_transaction(WRITE, 1, 2, TPM_STS, data);
	
	print_tpm_transaction(READ, 1, 2, TPM_STS, data);
	tb_assert(data, 0, r_dataAvail, EQUAL, r_dataAvail,
		"Error: TPM response should be available again.");
	
	tb_comment("Check the localityChangeInterrupt.");
	print_tpm_transaction(READ, 1, 2, TPM_INT_STATUS, data);
	tb_assert(data, 0, r_dataAvailIntOccurred, EQUAL, 0,
		"Testbench failure: r_dataAvailIntOccured incorrect (expected low).");
	
	tb_comment("Read all but last byte of fifo response. (bulk read)");
	print_tpm_transaction(READ, cmdSize, 2, TPM_DATA_FIFO, data);
	
	print_tpm_transaction(READ, 1, 2, TPM_STS, data);
	tb_assert(data, 0, r_dataAvail, EQUAL, r_dataAvail,
		"Error: dataAvail should still be true for one more byte.");
	
	tb_comment("Read last byte of fifo response.");
	print_tpm_transaction(READ, 1, 2, TPM_DATA_FIFO, &data[cmdSize]);
	
	print_tpm_transaction(READ, 1, 2, TPM_STS, data);
	tb_assert(data, 0, r_dataAvail, EQUAL, 0,
		"Error: TPM data should be fully read out.");
	
	tb_comment("Compare bulk read with expected data.");
	for(unsigned i=0; i<cmdDataSize_s; i++)
	{
		if (tb_assert(data, i+12, 0xFF, EQUAL, cmdData[i],
			"Incorrect response data."))
			printf("[%u] Expected %02x, got %02x\n", i, cmdData[i], data[i+12]);
	}
	
	if (_connected) for(unsigned i=0; i<cmdSize+1; i++)
		printf("%02x ", data[i]);
	
	tb_comment("Send responseRetry.");
	data[0] = r_responseRetry;
	print_tpm_transaction(WRITE, 1, 2, TPM_STS, data);
	
	tb_comment("Read response buffer in four bulk reads.");
	print_tpm_transaction(READ, 10, 2, TPM_DATA_FIFO, &data[0]);
		
	print_tpm_transaction(READ, 10, 2, TPM_DATA_FIFO, &data[10]);
	
	print_tpm_transaction(READ, 10, 2, TPM_DATA_FIFO, &data[20]);
	for(unsigned i=0; i<10; i++)
	{
		if (tb_assert(&data[20], i, 0xFF, EQUAL, cmdData[cmdDataSize_s+i-16],
			"Incorrect response data."))
			printf("[%u] Expected %02x, got %02x\n", i, cmdData[cmdDataSize_s+i-16], data[i]);
	}
	

	print_tpm_transaction(READ, 6, 2, TPM_DATA_FIFO, &data[30]);
	for(unsigned i=0; i<6; i++)
	{
		if (tb_assert(&data[30], i, 0xFF, EQUAL, cmdData[cmdDataSize_s+i-6],
			"Incorrect response data."))
			printf("[%u] Expected %02x, got %02x\n", i, cmdData[cmdDataSize_s+i-6], data[i]);
	}
	
	
	if (_connected) for(unsigned i=0; i<cmdSize+1; i++)
		printf("%02x ", data[i]);
	
	tb_comment("Send responseRetry.");
	data[0] = r_responseRetry;
	print_tpm_transaction(WRITE, 1, 2, TPM_STS, data);
	
	tb_comment("Read response buffer in one bulk read.");
	print_tpm_transaction(READ, cmdSize+1, 2, TPM_DATA_FIFO, data);
	
	tb_comment("Compare bulk read with expected data.");
	for(unsigned i=0; i<cmdDataSize_s; i++)
	{
		if (tb_assert(data, i+12, 0xFF, EQUAL, cmdData[i],
			"Incorrect response data."))
			printf("[%u] Expected %02x, got %02x\n", i, cmdData[i], data[i+12]);
	}
	
	if (_connected) for(unsigned i=0; i<cmdSize+1; i++)
		printf("%02x ", data[i]);

}

// #define TPM_RC_SUCCESS 0x00000000
// #define TPM_RC_VALUE 0x00000084
#define TPM_CC_STARTUP 0x00000144
#define TPM_CC_HIERARCHYCONTROL 0x00000121
// #define TPM_ST_SESSIONS 0x8002 // TPM_ST_NO_SESSIONS 0x8001


// this tests the hierarchyControl command, which is managed by the management module (this tests the integration with the management module)
// this is different from the following test, which uses tpm_command to send command data.
// this test sends command data through tpm_transaction calls, and remains as it shows how this can be done
// when more control on how command data is sent is needed
void test_hierarchyControl(void)
{
	tpm_reset();
	tb_comment("test_hierarchyControl");
	
	unsigned char cmdHeader[10];
	unsigned char cmdDataStartup[] =
	{
		0x00, 0x00 // TPM_SU_CLEAR
	};
	unsigned short cmdDataSize_s = sizeof(cmdDataStartup);
	unsigned char cmdDataSize[2] = { (cmdDataSize_s & 0xFF00) >> 8, cmdDataSize_s & 0xFF };
	
	unsigned cc = TPM_CC_STARTUP;
	unsigned cmdSize = 9+cmdDataSize_s;
	unsigned short st = TPM_ST_NO_SESSIONS;
	
	cmdHeader[0] = (st & 0xFF00) >> 8;
	cmdHeader[1] = (st & 0x00FF) >> 0;
	cmdHeader[2] = (cmdSize & 0xFF000000) >> 24;
	cmdHeader[3] = (cmdSize & 0x00FF0000) >> 16;
	cmdHeader[4] = (cmdSize & 0x0000FF00) >> 8;
	cmdHeader[5] = (cmdSize & 0x000000FF) >> 0;
	cmdHeader[6] = (cc & 0xFF000000) >> 24;
	cmdHeader[7] = (cc & 0x00FF0000) >> 16;
	cmdHeader[8] = (cc & 0x0000FF00) >> 8;
	cmdHeader[9] = (cc & 0x000000FF) >> 0;
	
	unsigned char data[64];
	
	tb_comment("Using Locality 0 as active locality.");
	
	data[0] = r_requestUse;
	print_tpm_transaction(WRITE, 1, 0, TPM_ACCESS, data);
	
	data[0] = r_commandReady;
	print_tpm_transaction(WRITE, 1, 0, TPM_STS, data);
	
	tb_comment("Send command TPM_CC_STARTUP : TPM_SU_CLEAR -> put TPM in operational state.");
	
	if (_connected)
	{
		printf("TPM Command:\n\t");
		for(unsigned i=0; i<10; i++)
		{
			printf("%02x ", cmdHeader[i]);
		}
		for(unsigned i=0; i<2; i++)
		{
			printf("%02x ", cmdDataStartup[i]);
		}
		printf("\n");
	}
	
	print_tpm_transaction(WRITE, 10, 0, TPM_DATA_FIFO, cmdHeader);
	print_tpm_transaction(WRITE, 2, 0, TPM_DATA_FIFO, cmdDataStartup);
	
	data[0] = r_tpmGo;
	print_tpm_transaction(WRITE, 1, 0, TPM_STS, data);
	
	tpm_waitExec(0, 15);
	
	print_tpm_transaction(READ, 10, 0, TPM_DATA_FIFO, data);
	if (_connected)
	{
		printf("TPM Response:\n\t");
		for(unsigned i=0; i<10; i++)
		{
			printf("%02x ", data[i]);
		}
		printf("\n");
	}
	
	data[0] = r_commandReady;
	print_tpm_transaction(WRITE, 1, 0, TPM_STS, data);
	
	tb_comment("Management Module now in operational state.");
	
	unsigned char cmdData[] =
	{
		0x40, 0x00, 0x00, 0x0C, // TPMI_RH_ENABLES ; PLATFORM ENABLE
		0x01 // TPMI_YES_NO
	};
	cmdDataSize_s = sizeof(cmdData);
	
	unsigned char handle[4];
	handle[0] = 0xde;
	handle[1] = 0xad;
	handle[2] = 0xbe;
	handle[3] = 0xef;
	
	unsigned char sessionHandle[4];
	sessionHandle[0] = 0xBA;
	sessionHandle[1] = 0xAD;
	sessionHandle[2] = 0xF0;
	sessionHandle[3] = 0x0D;
	
	unsigned char sessionAttribute[1];
	sessionAttribute[0] = 0x2A;
	
	unsigned char nonce[] = "This is the nonce buffer.";
	
	unsigned char nonceSize[2];
	nonceSize[0] = 0x00;
	nonceSize[1] = sizeof(nonce);
	
	unsigned char hmac[] = "This is the hmac buffer.";
	
	unsigned char hmacSize[2];
	hmacSize[0] = 0x00;
	hmacSize[1] = sizeof(hmac);
	
	unsigned char authSize[4];
	authSize[0] = 0x00;
	authSize[1] = 0x00;
	authSize[2] = 0x00;
	authSize[3] = 0x09 + sizeof(hmac) + sizeof(nonce);
	
	cc = TPM_CC_HIERARCHYCONTROL;
	cmdSize = 9+cmdDataSize_s + 4+9+4 + sizeof(hmac) + sizeof(nonce);
	st = TPM_ST_SESSIONS;
	
	cmdHeader[0] = (st & 0xFF00) >> 8;
	cmdHeader[1] = (st & 0x00FF) >> 0;
	cmdHeader[2] = (cmdSize & 0xFF000000) >> 24;
	cmdHeader[3] = (cmdSize & 0x00FF0000) >> 16;
	cmdHeader[4] = (cmdSize & 0x0000FF00) >> 8;
	cmdHeader[5] = (cmdSize & 0x000000FF) >> 0;
	cmdHeader[6] = (cc & 0xFF000000) >> 24;
	cmdHeader[7] = (cc & 0x00FF0000) >> 16;
	cmdHeader[8] = (cc & 0x0000FF00) >> 8;
	cmdHeader[9] = (cc & 0x000000FF) >> 0;
	
	print_tpm_transaction(WRITE, 1, 0, TPM_STS, data);
	
	if (cmdData[8])
		tb_comment("Send command TPM_CC_HIERARCHYCONTROL : TPM_RH_PLATFORM, TPMI_YES");
	else
		tb_comment("Send command TPM_CC_HIERARCHYCONTROL : TPM_RH_PLATFORM, TPMI_NO");
	
	if (_connected)
	{
		printf("TPM Command:\n\t");
		for(unsigned i=0; i<10; i++)
		{
			printf("%02x ", cmdHeader[i]);
		}
		for(unsigned i=0; i<9; i++)
		{
			printf("%02x ", cmdData[i]);
		}
		printf("\n");
	}
	
	print_tpm_transaction(WRITE, 10, 0, TPM_DATA_FIFO, cmdHeader);
	print_tpm_transaction(WRITE, 4, 0, TPM_DATA_FIFO, handle);
	print_tpm_transaction(WRITE, 4, 0, TPM_DATA_FIFO, authSize);
	print_tpm_transaction(WRITE, 4, 0, TPM_DATA_FIFO, sessionHandle);
	print_tpm_transaction(WRITE, 2, 0, TPM_DATA_FIFO, nonceSize);
	print_tpm_transaction(WRITE, sizeof(nonce), 0, TPM_DATA_FIFO, nonce);
	print_tpm_transaction(WRITE, 1, 0, TPM_DATA_FIFO, sessionAttribute);
	print_tpm_transaction(WRITE, 2, 0, TPM_DATA_FIFO, hmacSize);
	print_tpm_transaction(WRITE, sizeof(hmac), 0, TPM_DATA_FIFO, hmac);
	print_tpm_transaction(WRITE, sizeof(cmdData), 0, TPM_DATA_FIFO, cmdData);
	
	data[0] = r_tpmGo;
	print_tpm_transaction(WRITE, 1, 0, TPM_STS, data);
	
	tpm_waitExec(0, 15);
	
	print_tpm_transaction(READ, 10, 0, TPM_DATA_FIFO, data);
	if (_connected)
	{
		printf("TPM Response:\n\t");
		for(unsigned i=0; i<10; i++)
		{
			printf("%02x ", data[i]);
		}
		printf("\n");
	}
	
	data[0] = r_commandReady;
	print_tpm_transaction(WRITE, 1, 0, TPM_STS, data);
	
	data[0] = r_activeLocality;
	print_tpm_transaction(WRITE, 1, 0, TPM_ACCESS, data);
	
}

// this tests the hierarchyControl function
// the command data is sent using tpm_command, rather than tpm_transaction calls (see above test function)
void test_hierarchyControl2(void)
{
	tpm_reset();
	tb_comment("test_hierarchyControl");
	
	unsigned char cmdHeader[10];
	unsigned char cmdDataStartup[] =
	{
		0x00, 0x00 // TPM_SU_CLEAR
	};
	
	unsigned char data[64];
	
	tb_comment("Using Locality 0 as active locality.");

	data[0] = r_requestUse;
	print_tpm_transaction(WRITE, 1, 0, TPM_ACCESS, data);
	
	data[0] = r_commandReady;
	print_tpm_transaction(WRITE, 1, 0, TPM_STS, data);
	
	tb_comment("Send command TPM_CC_STARTUP : TPM_SU_CLEAR -> put TPM in operational state.");
	
	unsigned handles[3];
	unsigned sessionHandles[3];
	unsigned char sessionAttributes[3];
	unsigned nParams;
	unsigned char parameters[3];
	
	tpm_command(0, TPM_CC_Startup, TPM_ST_NO_SESSIONS,
		handles, sessionHandles, sessionAttributes, sizeof(cmdDataStartup), cmdDataStartup);
	
	data[0] = r_tpmGo;
	print_tpm_transaction(WRITE, 1, 0, TPM_STS, data);
	
	tpm_waitExec(0, 15);
	
	print_tpm_transaction(READ, 10, 0, TPM_DATA_FIFO, data);
	if (_connected)
	{
		printf("TPM Response:\n\t");
		for(unsigned i=0; i<10; i++)
		{
			printf("%02x ", data[i]);
		}
		printf("\n");
	}
	
	data[0] = r_commandReady;
	print_tpm_transaction(WRITE, 1, 0, TPM_STS, data);
	
	tb_comment("Management Module now in operational state.");
	
	unsigned char cmdData[] =
	{
		0x40, 0x00, 0x00, 0x0C, // TPMI_RH_ENABLES ; PLATFORM ENABLE
		0x01 // TPMI_YES_NO
	};
	
	print_tpm_transaction(WRITE, 1, 0, TPM_STS, data);
	
	if (cmdData[4])
		tb_comment("Send command TPM_CC_HIERARCHYCONTROL : TPM_RH_PLATFORM, TPMI_YES");
	else
		tb_comment("Send command TPM_CC_HIERARCHYCONTROL : TPM_RH_PLATFORM, TPMI_NO");
		
	handles[0] = 0x02123456;
	sessionHandles[0] = 0x02345678;
	sessionAttributes[0] = 0x00;
	
	tpm_command(0, TPM_CC_HierarchyControl, TPM_ST_SESSIONS,
		handles, sessionHandles, sessionAttributes, sizeof(cmdData), cmdData);
		
	data[0] = r_tpmGo;
	print_tpm_transaction(WRITE, 1, 0, TPM_STS, data);
	
	tpm_waitExec(0, 15);
	
	print_tpm_transaction(READ, 10, 0, TPM_DATA_FIFO, data);
	if (_connected)
	{
		printf("TPM Response:\n\t");
		for(unsigned i=0; i<10; i++)
		{
			printf("%02x ", data[i]);
		}
		printf("\n");
	}
	
	tb_assertRC(data, TPM_RC_VALUE,
		"Expected TPM_RC_VALUE.");
	
	cmdData[4] = 0x00;
	
	data[0] = r_commandReady;
	print_tpm_transaction(WRITE, 1, 0, TPM_STS, data);
	print_tpm_transaction(WRITE, 1, 0, TPM_STS, data);
	
	if (cmdData[4])
		tb_comment("Send command TPM_CC_HIERARCHYCONTROL : TPM_RH_PLATFORM, TPMI_YES");
	else
		tb_comment("Send command TPM_CC_HIERARCHYCONTROL : TPM_RH_PLATFORM, TPMI_NO");
	
	tpm_command(0, TPM_CC_HierarchyControl, TPM_ST_SESSIONS,
		handles, sessionHandles, sessionAttributes, sizeof(cmdData), cmdData);
		
	data[0] = r_tpmGo;
	print_tpm_transaction(WRITE, 1, 0, TPM_STS, data);
	
	tpm_waitExec(0, 15);
	
	print_tpm_transaction(READ, 10, 0, TPM_DATA_FIFO, data);
	if (_connected)
	{
		printf("TPM Response:\n\t");
		for(unsigned i=0; i<10; i++)
		{
			printf("%02x ", data[i]);
		}
		printf("\n");
	}
	
	tb_assertRC(data, TPM_RC_SUCCESS,
		"Expected TPM_RC_SUCCESS.");
	
	data[0] = r_commandReady;
	print_tpm_transaction(WRITE, 1, 0, TPM_STS, data);
	
	data[0] = r_activeLocality;
	print_tpm_transaction(WRITE, 1, 0, TPM_ACCESS, data);
}

// this tests the ccQuote command with and without sessions (it requires sessions)
// this is handles by the execution engine, and therefore this tests the integration with the execution engine
void test_ccQuote(void)
{
	tpm_reset();
	tb_comment("test_ccQuote");
	
	unsigned char data[64];
	
	unsigned char startupParam[] =
	{
		0x00, 0x00 // TPM_SU_CLEAR
	};
	
	tb_comment("Using Locality 0 as active locality.");
	
	data[0] = r_requestUse;
	print_tpm_transaction(WRITE, 1, 0, TPM_ACCESS, data);
	
	data[0] = r_commandReady;
	print_tpm_transaction(WRITE, 1, 0, TPM_STS, data);
	
	tb_comment("Send command TPM_CC_STARTUP : TPM_SU_CLEAR -> put TPM in operational state.");
		
	unsigned handles[3];
	unsigned sessionHandles[3];
	unsigned char sessionAttributes[3];
	unsigned nParams;
	unsigned char parameters[3];
	
	tpm_command(0, TPM_CC_Startup, TPM_ST_NO_SESSIONS,
		handles, sessionHandles, sessionAttributes, sizeof(startupParam), startupParam);
	
	data[0] = r_tpmGo;
	print_tpm_transaction(WRITE, 1, 0, TPM_STS, data);
	
	if (tpm_waitExec(0, 15))
	{
		printf("Critical error: TPM timeout. Terminating test.\n");
		_connected = 0;
	}
	
	print_tpm_transaction(READ, 10, 0, TPM_DATA_FIFO, data);
	if (_connected)
	{
		printf("TPM Response:\n\t");
		for(unsigned i=0; i<10; i++)
		{
			printf("%02x ", data[i]);
		}
		printf("\n");
	}

	tb_assertRC(data, TPM_RC_SUCCESS,
		"Response code error: Expected TPM_RC_SUCCESS.");
	
	data[0] = r_commandReady;
	print_tpm_transaction(WRITE, 1, 0, TPM_STS, data);
	
	tb_comment("Management Module now in operational state.");
	
	unsigned char cmdData[] =
	{
		0x40, 0x00, 0x00, 0x0C, // TPMI_RH_ENABLES ; PLATFORM ENABLE
		0x01 // TPMI_YES_NO
	};
	
	print_tpm_transaction(WRITE, 1, 0, TPM_STS, data);
	
	handles[0] = TPM_HT_PERMANENT;
	sessionHandles[0] = (TPM_HT_TRANSIENT << 24) | 0x123456;
	sessionAttributes[0] = 0x00;

	tb_comment("Send command TPM_CC_QUOTE [Without Sessions]. Expect RC of 0x145.");
	
	tpm_command(0, TPM_CC_Quote, TPM_ST_NO_SESSIONS,
		handles, sessionHandles, sessionAttributes, sizeof(cmdData), cmdData);
		
	data[0] = r_tpmGo;
	print_tpm_transaction(WRITE, 1, 0, TPM_STS, data);
	
	if (tpm_waitExec(0, 15))
	{
		printf("Critical error: TPM timeout. Terminating test.\n");
		_connected = 0;
	}
	
	print_tpm_transaction(READ, 10, 0, TPM_DATA_FIFO, data);
	if (_connected)
	{
		printf("TPM Response:\n\t");
		for(unsigned i=0; i<10; i++)
		{
			printf("%02x ", data[i]);
		}
		printf("\n");
	}
	
	tb_assertRC(data, TPM_RC_AUTH_CONTEXT,
		"Response code error: Expected TPM_RC_AUTH_CONTEXT.");
	
	data[0] = r_commandReady;
	print_tpm_transaction(WRITE, 1, 0, TPM_STS, data);
	
	print_tpm_transaction(WRITE, 1, 0, TPM_STS, data);

	tb_comment("Send command TPM_CC_QUOTE [With Sessions]. Expect RC of 0x000.");
	
	tpm_command(0, TPM_CC_Quote, TPM_ST_SESSIONS,
		handles, sessionHandles, sessionAttributes, sizeof(cmdData), cmdData);
		
	data[0] = r_tpmGo;
	print_tpm_transaction(WRITE, 1, 0, TPM_STS, data);
	
	if (tpm_waitExec(0, 15))
	{
		printf("Critical error: TPM timeout. Terminating test.\n");
		_connected = 0;
	}
	
	print_tpm_transaction(READ, 10, 0, TPM_DATA_FIFO, data);
	if (_connected)
	{
		printf("TPM Response:\n\t");
		for(unsigned i=0; i<10; i++)
		{
			printf("%02x ", data[i]);
		}
		printf("\n");
	}
	
	tb_assertRC(data, TPM_RC_SUCCESS,
		"Response code error: Expected TPM_RC_SUCCESS.");
	
	data[0] = r_commandReady;
	print_tpm_transaction(WRITE, 1, 0, TPM_STS, data);
	
	data[0] = r_activeLocality;
	print_tpm_transaction(WRITE, 1, 0, TPM_ACCESS, data);
}