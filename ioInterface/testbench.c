#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <windows.h>
#include "FTDI/ftd2xx.h"
#include "FTDI/libMPSSE_spi.h"

#define STATUS_CHECK(exp) {if(exp!=FT_OK){printf("%s:%d:%s(): status(0x%x) \
!= FT_OK\n",__FILE__, __LINE__, __FUNCTION__,exp);exit(1);}else{;}};

int _devFound = -1;
ChannelConfig _devConfig;
FT_HANDLE _handle;
FT_STATUS _status;

unsigned _errors = 0;
unsigned _generateVerilogTB = 0;
unsigned _connected = 0;
char _verilogTBFilename[64];
FILE *_vFP = NULL;

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

void ftdi_close(void)
{
	if (!_connected)
		return;
	
	_connected = 0;
	SPI_CloseChannel(_handle);
}

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

unsigned init_verilog_gen(int argc, char **argv)
{
	if (argc == 1)
		return 1;
	
	unsigned i = 0;
	for(char *c = argv[1], *d = _verilogTBFilename; *c && i < 64; i++)
		*d++ = *c++;
	
	if (i == 64)
	{
		_verilogTBFilename[60] = '~';
		_verilogTBFilename[61] = '.';
		_verilogTBFilename[62] = 'v';
		_verilogTBFilename[63] = '\0';
	}
	else
		_verilogTBFilename[i] = '\0';
	
	if (i < 3)
	{
		printf("Could not use %s for output (filename too short). Verilog Testbench will not be generated.\n", _verilogTBFilename);
		return 1;
	}
	
	_vFP = fopen(_verilogTBFilename, "w");
	
	if (!_vFP)
	{
		printf("Could not use %s for output. Verilog Testbench will not be generated.\n", _verilogTBFilename);
		return 1;
	}
	
	_generateVerilogTB = 1;
	printf("Generating Verilog Testbench: %s\n\n", _verilogTBFilename);
	
	if (i == 64)
		_verilogTBFilename[60] = '\0';
	else
		_verilogTBFilename[i-2] = '\0';
	
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
		"\ttest0_top\ttpm\n"
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
		"\treg\tin, errors;\n"
		"\tinteger i, j, genEntry, tries;\n"
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
	
	if (i == 64)
		_verilogTBFilename[60] = '~';
	else
		_verilogTBFilename[i-2] = '.';
	
	return 0;
}

#define EQUAL 1
#define UNEQUAL 0

void tb_assert(unsigned char *data, unsigned byte, unsigned char filter, unsigned comp, unsigned char expected, char *str)
{
	if (!_connected)
		goto L_GEN;
	
	if (comp)
	{
		if ((data[byte] & filter) != expected)
		{
			printf("\n%s\n\n", str);
			_errors++;
		}
	} else {
		if ((data[byte] & filter) == expected)
		{
			printf("\n%s\n\n", str);
			_errors++;
		}
	}
	
L_GEN:	
	if (!_generateVerilogTB)
		return;
	
	fprintf(_vFP,
		"\t\tif ((readData[%u] & 8'd%u) %s 8'd%u)\n"
		"\t\tbegin\n"
		"\t\t\t$error(\"%s\");\n"
		"\t\t\terrors = errors + 1;\n"
		"\t\tend\n"
		"\n",
		byte, filter, comp ? "!=" : "==", expected, str);
}

void check_assert(void)
{
	if (!_connected)
		return;
	
	if (_errors)
		printf("\nThere were errors in testing.\n");
	else
		printf("\nThere were no errors in testing.\n");
}

void close_verilog_gen(void)
{	
	if (!_generateVerilogTB)
		return;
	
	_generateVerilogTB = 0;
	
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
	
	fclose(_vFP);
}

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
				"\t\t@(posedge clock)\n\n");
}

void tb_comment(char *str)
{
	if (!_generateVerilogTB)
		return;
	
	fprintf(_vFP, "\n\t\t// %s\n", str);
}

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

unsigned tpm_waitExec(unsigned locality, unsigned tries)
{
	unsigned timeout = 0;
	unsigned oldGen = _generateVerilogTB;
	_generateVerilogTB = 0;
	
	if (oldGen)
	{
		unsigned char header[4] =
		{
			(1 << 7) | (1 << 6),
			0xD4,
			((locality & 0xF) << 4) | (((unsigned)r_dataAvail & 0xF00) >> 8),
			(unsigned)r_dataAvail & 0xFF
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
			"\t\t\t\tSPI_mosi = writeData[i-1];\n"
			"\t\t\t\t`SPI_CLK_PERIOD;\n"
			"\t\t\t\tSPI_clock = 1'b1;\n"
			"\t\t\t\t`SPI_CLK_PERIOD;\n"
			"\t\t\t\tSPI_clock = 1'b0;\n"
			"\t\t\tend\n"
			"\t\t\treadData[j] = readByte;\n"
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
			printf("\nError: TPM Execution timeout.\n");
	}
	
	_generateVerilogTB = oldGen;
	return 0;
}

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

void test_debugRW(void);
void test_localityChanging(void);
void test_localityPermissions(void);
void test_statusStateMachine(void);
void test_localitySeizeCommandAbort(void);
void test_sendReceiveCMD(void);

int main(int argc, char **argv)
{
	ftdi_connect(24000000);
	init_verilog_gen(argc, argv);
	
	if (!(_connected || _generateVerilogTB))
		return 1;
	
	test_debugRW();
	test_localityChanging();
	test_localityPermissions();
	test_statusStateMachine();
	test_localitySeizeCommandAbort();
	test_sendReceiveCMD();
	
	check_assert();
	ftdi_close();
	close_verilog_gen();
	return 0;
}

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

void test_statusStateMachine(void)
{
	tpm_reset();
	tb_comment("test_statusStateMachine");
	
	unsigned char data[64];
	
tb_comment("Locality 4 will be used for this test");
	data[0] = r_requestUse;
	print_tpm_transaction(WRITE, 1, 4, TPM_ACCESS, data);
	print_tpm_transaction(READ, 1, 4, TPM_STS, data);
	
	tb_assert(data, 0, 0xff, EQUAL, 0,
		"Testbench failure: TPM_STS state incorrect.");
	
	data[0] = r_commandReady;
	print_tpm_transaction(WRITE, 1, 1, TPM_STS, data);
	print_tpm_transaction(READ, 1, 4, TPM_STS, data);
	
tb_comment("TPM should be in Idle state, as Locality 1 cannot control TPM_STS (Locality 4 is in control)");
	tb_assert(data, 0, 0xff, EQUAL, 0,
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
//	if ((data[0] & r_commandReadyIntOccurred) == 0)
//		printf("\nTestbench failure: commandReadyIntOccured incorrect (expected high).\n");
	
	tb_assert(data, 0, r_commandReadyIntOccurred, EQUAL, r_commandReadyIntOccurred,
		"Testbench Failure: commandReadyInt should be high.");
	
tb_comment("Reset interrupts");
	print_tpm_transaction(WRITE, 1, 4, TPM_INT_STATUS, data);
	
tb_comment("Ensure interrupts have been reset");
	print_tpm_transaction(READ, 1, 4, TPM_INT_STATUS, data);
//	if (data[0] != 0)
//		printf("\nTestbench failure: interrupts have not been cleared.\n");
	
	tb_assert(data, 0, r_commandReadyIntOccurred, EQUAL, 0,
		"Testbench Failure: commandReadyInt should be low.");
	
tb_comment("Write first byte to FIFO, state should transition to Reception");
	unsigned char str[64] = "This is a test string.\n";
	print_tpm_transaction(WRITE, 24, 4, TPM_DATA_FIFO, str);
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
	data[0] = r_dbgFifoComplete;
	print_tpm_transaction(WRITE, 1, 4, IDS_CTRL, data);
	print_tpm_transaction(READ, 1, 4, TPM_STS, data);
	
	tb_assert(data, 0, r_Expect, EQUAL, 0,
		"Testbench Failure: TPM_STS.Expect should be 0.");
	
tb_comment("Now tpmGo can be sent, state transitions to Execution");
	data[0] = r_tpmGo;
	print_tpm_transaction(WRITE, 1, 4, TPM_STS, data);
	print_tpm_transaction(READ, 1, 4, TPM_STS, data);
	
tb_comment("Once Execution is finished, state transitions to Complete ; dataAvail = 1");
	data[0] = r_dbgExecEngineDone;
	print_tpm_transaction(WRITE, 1, 4, IDS_CTRL, data);
	print_tpm_transaction(READ, 1, 4, TPM_STS, data);
	
	tb_assert(data, 0, r_dataAvail, EQUAL, r_dataAvail,
		"Testbench Failure: TPM_STS.dataAvail should be 1.");
	
tb_comment("Check the dataAvailInterrupt");
	print_tpm_transaction(READ, 1, 4, TPM_INT_STATUS, data);
//	if ((data[0] & r_dataAvailIntOccurred) == 0)
//		printf("\nTestbench failure: dataAvailIntOccured incorrect (expected high).\n");
	
	tb_assert(data, 0, r_dataAvailIntOccurred, EQUAL, r_dataAvailIntOccurred,
		"Testbench Failure: dataAvail Interrupt should be high.");
	
tb_comment("Reset interrupts");
	print_tpm_transaction(WRITE, 1, 4, TPM_INT_STATUS, data);
	
tb_comment("Ensure interrupts have been reset");
	print_tpm_transaction(READ, 1, 4, TPM_INT_STATUS, data);
//	if (data[0] != 0)
//		printf("\nTestbench failure: interrupts have not been cleared.\n");
	
	tb_assert(data, 0, r_dataAvailIntOccurred, EQUAL, 0,
		"Testbench Failure: dataAvail Interrupt should be low.");
	
	print_tpm_transaction(READ, 24, 4, TPM_DATA_FIFO, data);
	
tb_comment("Once Fifo has been fully read, dataAvail = 0");
	data[0] = r_dbgFifoEmpty;
	print_tpm_transaction(WRITE, 1, 4, IDS_CTRL, data);
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
#define TPM_ST_NO_SESSIONS 0x8001

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
	cmdHeader[2] = (cc & 0xFF000000) >> 24;
	cmdHeader[3] = (cc & 0x00FF0000) >> 16;
	cmdHeader[4] = (cc & 0x0000FF00) >> 8;
	cmdHeader[5] = (cc & 0x000000FF) >> 0;
	cmdHeader[6] = (cmdSize & 0xFF000000) >> 24;
	cmdHeader[7] = (cmdSize & 0x00FF0000) >> 16;
	cmdHeader[8] = (cmdSize & 0x0000FF00) >> 8;
	cmdHeader[9] = (cmdSize & 0x000000FF) >> 0;
	
	unsigned char data[64];
	
	tb_comment("Using locality 2 for this test.");
	data[0] = r_requestUse;
	tpm_transaction(WRITE, 1, 2, TPM_ACCESS, data);
	
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
	
	tb_comment("Write all but the last byte of the cmd data.");
	print_tpm_transaction(WRITE, strlen(cmdData), 2, TPM_DATA_FIFO, cmdData);
	
	print_tpm_transaction(READ, 1, 2, TPM_STS, data);
	tb_assert(data, 0, r_Expect, EQUAL, r_Expect,
		"Error: TPM should be expecting command data.");
	
	tb_comment("Write last byte of cmd data from wrong locality.");
	print_tpm_transaction(WRITE, 1, 1, TPM_DATA_FIFO, &cmdData[cmdDataSize_s]);
	
	print_tpm_transaction(READ, 1, 2, TPM_STS, data);
	tb_assert(data, 0, r_Expect, EQUAL, r_Expect,
		"Error: TPM should be expecting command data.");
	
	tb_comment("Write last byte of cmd data.");
	print_tpm_transaction(WRITE, 1, 2, TPM_DATA_FIFO, &cmdData[cmdDataSize_s]);
	
	print_tpm_transaction(READ, 1, 2, TPM_STS, data);
	tb_assert(data, 0, r_Expect, EQUAL, 0,
		"Error: TPM should no longer expect data.");
	
	data[0] = r_tpmGo;
	print_tpm_transaction(WRITE, 1, 2, TPM_STS, data);
	
	tpm_waitExec(2, 15);
}