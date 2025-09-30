// Auto-Generated Verilog Testbench
`timescale 1ns/1ns

`define SPI_CLK_PERIOD #33

module	tb_test();
	reg		clock;
	reg		reset_n;

	reg		SPI_clock;
	reg		SPI_mosi;
	wire		SPI_miso;
	reg		SPI_cs_n;
	reg		SPI_rst_n;
	wire		SPI_PIRQ_n;

	test0_top	tpm
	(
		.CLOCK_50(clock), .RESET_N(reset_n),
		.GPIO_1_2(SPI_clock), .GPIO_1_3(SPI_mosi),
		.GPIO_1_4(SPI_miso), .GPIO_1_5(SPI_cs_n),
		.GPIO_1_6(SPI_rst_n), .GPIO_1_7(SPI_PIRQ_n)
	);

	initial
	begin : tb_clock_50
		reset_n = 1'b1;
		repeat(2) reset_n = #1 ~reset_n;
		clock = 1'b0;
		forever clock = #10 ~clock;
	end

	reg	[31:0]	header;
	reg	[7:0]	writeData;
	reg	[7:0]	readData [0:63];
	reg	[7:0]	readByte;
	reg	in, errors;
	integer i, j, genEntry, tries;

	initial
	begin : tb_main
		errors = 1'b0;
		SPI_clock = 1'b0;
		SPI_mosi = 1'b0;
		SPI_cs_n = 1'b1;
		SPI_rst_n = 1'b1;

		header = 32'd0;
		writeData = 8'd0;
		readByte = 8'd0;

		repeat(2) SPI_rst_n = #1 ~SPI_rst_n;
		@(posedge clock)


		// test_debugRW

		// GenEntry 0: Write 1 bytes to TPM_ACCESS1
		genEntry = 0;

		header = 32'd1087639552;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd2;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 1: Write 4 bytes to invalid!1
		genEntry = 1;

		header = 32'd1137975076;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd222;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd173;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd190;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd239;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 2: Read 4 bytes from invalid!1
		genEntry = 2;

		header = 32'd3285458724;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd2;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<4; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		if ((readData[0] & 8'd255) != 8'd222)
		begin
			$error("Testbench Failure (RW).");
			errors = errors + 1;
		end

		if ((readData[1] & 8'd255) != 8'd173)
		begin
			$error("Testbench Failure (RW).");
			errors = errors + 1;
		end

		if ((readData[2] & 8'd255) != 8'd190)
		begin
			$error("Testbench Failure (RW).");
			errors = errors + 1;
		end

		if ((readData[3] & 8'd255) != 8'd239)
		begin
			$error("Testbench Failure (RW).");
			errors = errors + 1;
		end

		repeat(2) SPI_rst_n = #1 ~SPI_rst_n;
		@(posedge clock)


		// test_localityChanging

		// GenEntry 3: Read 1 bytes from TPM_ACCESS0
		genEntry = 3;

		header = 32'd3235119104;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd239;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 4: Read 1 bytes from TPM_ACCESS1
		genEntry = 4;

		header = 32'd3235123200;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd239;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 5: Read 1 bytes from TPM_ACCESS2
		genEntry = 5;

		header = 32'd3235127296;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd239;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 6: Read 1 bytes from TPM_ACCESS3
		genEntry = 6;

		header = 32'd3235131392;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd239;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 7: Read 1 bytes from TPM_ACCESS4
		genEntry = 7;

		header = 32'd3235135488;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd239;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 8: Write 1 bytes to TPM_ACCESS2
		genEntry = 8;

		header = 32'd1087643648;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd2;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 9: Read 1 bytes from TPM_ACCESS0
		genEntry = 9;

		header = 32'd3235119104;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd2;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 10: Read 1 bytes from TPM_ACCESS1
		genEntry = 10;

		header = 32'd3235123200;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd2;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 11: Read 1 bytes from TPM_ACCESS2
		genEntry = 11;

		header = 32'd3235127296;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd2;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 12: Read 1 bytes from TPM_ACCESS3
		genEntry = 12;

		header = 32'd3235131392;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd2;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 13: Read 1 bytes from TPM_ACCESS4
		genEntry = 13;

		header = 32'd3235135488;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd2;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 14: Write 1 bytes to TPM_ACCESS4
		genEntry = 14;

		header = 32'd1087651840;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd8;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 15: Read 1 bytes from TPM_ACCESS0
		genEntry = 15;

		header = 32'd3235119104;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd8;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 16: Read 1 bytes from TPM_ACCESS1
		genEntry = 16;

		header = 32'd3235123200;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd8;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 17: Read 1 bytes from TPM_ACCESS2
		genEntry = 17;

		header = 32'd3235127296;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd8;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 18: Read 1 bytes from TPM_ACCESS3
		genEntry = 18;

		header = 32'd3235131392;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd8;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 19: Read 1 bytes from TPM_ACCESS4
		genEntry = 19;

		header = 32'd3235135488;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd8;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 20: Write 1 bytes to TPM_ACCESS2
		genEntry = 20;

		header = 32'd1087643648;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd16;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 21: Read 1 bytes from TPM_ACCESS0
		genEntry = 21;

		header = 32'd3235119104;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd16;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 22: Read 1 bytes from TPM_ACCESS1
		genEntry = 22;

		header = 32'd3235123200;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd16;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 23: Read 1 bytes from TPM_ACCESS2
		genEntry = 23;

		header = 32'd3235127296;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd16;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 24: Read 1 bytes from TPM_ACCESS3
		genEntry = 24;

		header = 32'd3235131392;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd16;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 25: Read 1 bytes from TPM_ACCESS4
		genEntry = 25;

		header = 32'd3235135488;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd16;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 26: Write 1 bytes to TPM_ACCESS1
		genEntry = 26;

		header = 32'd1087639552;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd2;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 27: Write 1 bytes to TPM_ACCESS2
		genEntry = 27;

		header = 32'd1087643648;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd2;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 28: Read 1 bytes from TPM_ACCESS0
		genEntry = 28;

		header = 32'd3235119104;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd2;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 29: Read 1 bytes from TPM_ACCESS1
		genEntry = 29;

		header = 32'd3235123200;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd2;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 30: Read 1 bytes from TPM_ACCESS2
		genEntry = 30;

		header = 32'd3235127296;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd2;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 31: Read 1 bytes from TPM_ACCESS3
		genEntry = 31;

		header = 32'd3235131392;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd2;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 32: Read 1 bytes from TPM_ACCESS4
		genEntry = 32;

		header = 32'd3235135488;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd2;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 33: Write 1 bytes to TPM_ACCESS4
		genEntry = 33;

		header = 32'd1087651840;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd32;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 34: Read 1 bytes from TPM_ACCESS0
		genEntry = 34;

		header = 32'd3235119104;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd32;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 35: Read 1 bytes from TPM_ACCESS1
		genEntry = 35;

		header = 32'd3235123200;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd32;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 36: Read 1 bytes from TPM_ACCESS2
		genEntry = 36;

		header = 32'd3235127296;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd32;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 37: Read 1 bytes from TPM_ACCESS3
		genEntry = 37;

		header = 32'd3235131392;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd32;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 38: Read 1 bytes from TPM_ACCESS4
		genEntry = 38;

		header = 32'd3235135488;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd32;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 39: Write 1 bytes to TPM_ACCESS0
		genEntry = 39;

		header = 32'd1087635456;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd8;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 40: Read 1 bytes from TPM_ACCESS0
		genEntry = 40;

		header = 32'd3235119104;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd8;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 41: Read 1 bytes from TPM_ACCESS1
		genEntry = 41;

		header = 32'd3235123200;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd8;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 42: Read 1 bytes from TPM_ACCESS2
		genEntry = 42;

		header = 32'd3235127296;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd8;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 43: Read 1 bytes from TPM_ACCESS3
		genEntry = 43;

		header = 32'd3235131392;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd8;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 44: Read 1 bytes from TPM_ACCESS4
		genEntry = 44;

		header = 32'd3235135488;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd8;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 45: Write 1 bytes to TPM_ACCESS2
		genEntry = 45;

		header = 32'd1087643648;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd32;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 46: Read 1 bytes from TPM_ACCESS0
		genEntry = 46;

		header = 32'd3235119104;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd32;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 47: Read 1 bytes from TPM_ACCESS1
		genEntry = 47;

		header = 32'd3235123200;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd32;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 48: Read 1 bytes from TPM_ACCESS2
		genEntry = 48;

		header = 32'd3235127296;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd32;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 49: Read 1 bytes from TPM_ACCESS3
		genEntry = 49;

		header = 32'd3235131392;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd32;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 50: Read 1 bytes from TPM_ACCESS4
		genEntry = 50;

		header = 32'd3235135488;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd32;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		repeat(2) SPI_rst_n = #1 ~SPI_rst_n;
		@(posedge clock)


		// test_localityPermissions

		// GenEntry 51: Read 4 bytes from TPM_DID_VID0
		genEntry = 51;

		header = 32'd3285454592;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd224;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<4; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		if ((readData[0] & 8'd255) != 8'd255)
		begin
			$error("Error: Read allowed from wrong locality.");
			errors = errors + 1;
		end

		if ((readData[1] & 8'd255) != 8'd255)
		begin
			$error("Error: Read allowed from wrong locality.");
			errors = errors + 1;
		end

		if ((readData[2] & 8'd255) != 8'd255)
		begin
			$error("Error: Read allowed from wrong locality.");
			errors = errors + 1;
		end

		if ((readData[3] & 8'd255) != 8'd255)
		begin
			$error("Error: Read allowed from wrong locality.");
			errors = errors + 1;
		end


		// GenEntry 52: Read 4 bytes from TPM_DID_VID3
		genEntry = 52;

		header = 32'd3285466880;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd224;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<4; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		if ((readData[0] & 8'd255) != 8'd255)
		begin
			$error("Error: Read allowed from wrong locality.");
			errors = errors + 1;
		end

		if ((readData[1] & 8'd255) != 8'd255)
		begin
			$error("Error: Read allowed from wrong locality.");
			errors = errors + 1;
		end

		if ((readData[2] & 8'd255) != 8'd255)
		begin
			$error("Error: Read allowed from wrong locality.");
			errors = errors + 1;
		end

		if ((readData[3] & 8'd255) != 8'd255)
		begin
			$error("Error: Read allowed from wrong locality.");
			errors = errors + 1;
		end


		// GenEntry 53: Read 1 bytes from TPM_ACCESS0
		genEntry = 53;

		header = 32'd3235119104;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd224;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 54: Write 1 bytes to TPM_ACCESS0
		genEntry = 54;

		header = 32'd1087635456;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd2;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 55: Read 1 bytes from TPM_ACCESS0
		genEntry = 55;

		header = 32'd3235119104;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd2;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 56: Read 4 bytes from TPM_DID_VID0
		genEntry = 56;

		header = 32'd3285454592;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd2;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<4; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		if ((readData[0] & 8'd255) != 8'd55)
		begin
			$error("Error: This locality should be able to read!");
			errors = errors + 1;
		end

		if ((readData[1] & 8'd255) != 8'd48)
		begin
			$error("Error: This locality should be able to read!");
			errors = errors + 1;
		end

		if ((readData[2] & 8'd255) != 8'd84)
		begin
			$error("Error: This locality should be able to read!");
			errors = errors + 1;
		end

		if ((readData[3] & 8'd255) != 8'd86)
		begin
			$error("Error: This locality should be able to read!");
			errors = errors + 1;
		end


		// GenEntry 57: Read 4 bytes from TPM_DID_VID3
		genEntry = 57;

		header = 32'd3285466880;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd2;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<4; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		if ((readData[0] & 8'd255) != 8'd255)
		begin
			$error("Error: Read allowed from wrong locality.");
			errors = errors + 1;
		end

		if ((readData[1] & 8'd255) != 8'd255)
		begin
			$error("Error: Read allowed from wrong locality.");
			errors = errors + 1;
		end

		if ((readData[2] & 8'd255) != 8'd255)
		begin
			$error("Error: Read allowed from wrong locality.");
			errors = errors + 1;
		end

		if ((readData[3] & 8'd255) != 8'd255)
		begin
			$error("Error: Read allowed from wrong locality.");
			errors = errors + 1;
		end


		// GenEntry 58: Read 1 bytes from TPM_ACCESS3
		genEntry = 58;

		header = 32'd3235131392;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd2;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 59: Write 1 bytes to TPM_ACCESS3
		genEntry = 59;

		header = 32'd1087647744;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd2;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 60: Read 1 bytes from TPM_ACCESS0
		genEntry = 60;

		header = 32'd3235119104;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd2;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		if ((readData[0] & 8'd36) != 8'd36)
		begin
			$error("Error: Locality requestUse error.");
			errors = errors + 1;
		end


		// GenEntry 61: Read 1 bytes from TPM_ACCESS3
		genEntry = 61;

		header = 32'd3235131392;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd2;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		if ((readData[0] & 8'd32) != 8'd0)
		begin
			$error("Error: This locality should not be active.");
			errors = errors + 1;
		end

		if ((readData[0] & 8'd2) != 8'd2)
		begin
			$error("Error: This locality should be requesting use.");
			errors = errors + 1;
		end


		// GenEntry 62: Write 1 bytes to TPM_ACCESS0
		genEntry = 62;

		header = 32'd1087635456;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd32;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 63: Read 1 bytes from TPM_ACCESS0
		genEntry = 63;

		header = 32'd3235119104;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd32;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		if ((readData[0] & 8'd32) != 8'd0)
		begin
			$error("Error: This locality should not be active.");
			errors = errors + 1;
		end

		if ((readData[0] & 8'd4) != 8'd0)
		begin
			$error("Error: There should be no locality requesting use.");
			errors = errors + 1;
		end


		// GenEntry 64: Read 1 bytes from TPM_ACCESS3
		genEntry = 64;

		header = 32'd3235131392;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd32;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		if ((readData[0] & 8'd32) != 8'd32)
		begin
			$error("Error: This locality should be the active locality.");
			errors = errors + 1;
		end

		if ((readData[0] & 8'd2) != 8'd0)
		begin
			$error("Error: This locality's request should be set low, as it is active now.");
			errors = errors + 1;
		end


		// GenEntry 65: Read 4 bytes from TPM_DID_VID0
		genEntry = 65;

		header = 32'd3285454592;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd32;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<4; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		if ((readData[0] & 8'd255) != 8'd255)
		begin
			$error("Error: Read allowed from wrong locality.");
			errors = errors + 1;
		end

		if ((readData[1] & 8'd255) != 8'd255)
		begin
			$error("Error: Read allowed from wrong locality.");
			errors = errors + 1;
		end

		if ((readData[2] & 8'd255) != 8'd255)
		begin
			$error("Error: Read allowed from wrong locality.");
			errors = errors + 1;
		end

		if ((readData[3] & 8'd255) != 8'd255)
		begin
			$error("Error: Read allowed from wrong locality.");
			errors = errors + 1;
		end


		// GenEntry 66: Read 4 bytes from TPM_DID_VID3
		genEntry = 66;

		header = 32'd3285466880;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd32;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<4; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		if ((readData[0] & 8'd255) != 8'd55)
		begin
			$error("Error: This locality should be able to read!");
			errors = errors + 1;
		end

		if ((readData[1] & 8'd255) != 8'd48)
		begin
			$error("Error: This locality should be able to read!");
			errors = errors + 1;
		end

		if ((readData[2] & 8'd255) != 8'd84)
		begin
			$error("Error: This locality should be able to read!");
			errors = errors + 1;
		end

		if ((readData[3] & 8'd255) != 8'd86)
		begin
			$error("Error: This locality should be able to read!");
			errors = errors + 1;
		end


		// GenEntry 67: Write 1 bytes to TPM_ACCESS3
		genEntry = 67;

		header = 32'd1087647744;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd32;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 68: Read 1 bytes from TPM_ACCESS3
		genEntry = 68;

		header = 32'd3235131392;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd32;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		if ((readData[0] & 8'd32) != 8'd0)
		begin
			$error("Error: This locality should not be active.");
			errors = errors + 1;
		end


		// GenEntry 69: Read 4 bytes from TPM_DID_VID0
		genEntry = 69;

		header = 32'd3285454592;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd32;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<4; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		if ((readData[0] & 8'd255) != 8'd255)
		begin
			$error("Error: Read allowed from wrong locality.");
			errors = errors + 1;
		end

		if ((readData[1] & 8'd255) != 8'd255)
		begin
			$error("Error: Read allowed from wrong locality.");
			errors = errors + 1;
		end

		if ((readData[2] & 8'd255) != 8'd255)
		begin
			$error("Error: Read allowed from wrong locality.");
			errors = errors + 1;
		end

		if ((readData[3] & 8'd255) != 8'd255)
		begin
			$error("Error: Read allowed from wrong locality.");
			errors = errors + 1;
		end


		// GenEntry 70: Read 4 bytes from TPM_DID_VID3
		genEntry = 70;

		header = 32'd3285466880;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd32;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<4; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		if ((readData[0] & 8'd255) != 8'd255)
		begin
			$error("Error: Read allowed from wrong locality.");
			errors = errors + 1;
		end

		if ((readData[1] & 8'd255) != 8'd255)
		begin
			$error("Error: Read allowed from wrong locality.");
			errors = errors + 1;
		end

		if ((readData[2] & 8'd255) != 8'd255)
		begin
			$error("Error: Read allowed from wrong locality.");
			errors = errors + 1;
		end

		if ((readData[3] & 8'd255) != 8'd255)
		begin
			$error("Error: Read allowed from wrong locality.");
			errors = errors + 1;
		end

		repeat(2) SPI_rst_n = #1 ~SPI_rst_n;
		@(posedge clock)


		// test_statusStateMachine

		// Locality 4 will be used for this test

		// GenEntry 71: Write 1 bytes to TPM_ACCESS4
		genEntry = 71;

		header = 32'd1087651840;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd2;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 72: Read 1 bytes from TPM_STS4
		genEntry = 72;

		header = 32'd3235135512;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd2;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		if ((readData[0] & 8'd255) != 8'd0)
		begin
			$error("Testbench failure: TPM_STS state incorrect.");
			errors = errors + 1;
		end


		// GenEntry 73: Write 1 bytes to TPM_STS1
		genEntry = 73;

		header = 32'd1087639576;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd64;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 74: Read 1 bytes from TPM_STS4
		genEntry = 74;

		header = 32'd3235135512;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd64;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// TPM should be in Idle state, as Locality 1 cannot control TPM_STS (Locality 4 is in control)
		if ((readData[0] & 8'd255) != 8'd0)
		begin
			$error("Testbench failure: TPM_STS state incorrect.");
			errors = errors + 1;
		end


		// Check which interrupts are supported

		// GenEntry 75: Read 4 bytes from TPM_INTF_CAPABILITY4
		genEntry = 75;

		header = 32'd3285467156;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd64;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<4; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// Enable specific interrupts

		// GenEntry 76: Write 4 bytes to TPM_INT_ENABLE4
		genEntry = 76;

		header = 32'd1137983496;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd133;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd0;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd0;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd128;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 77: Write 1 bytes to TPM_STS4
		genEntry = 77;

		header = 32'd1087651864;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd64;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 78: Read 1 bytes from TPM_STS4
		genEntry = 78;

		header = 32'd3235135512;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd64;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// TPM should now be in Ready state ... commandReadyInterrupt should be active
		if ((readData[0] & 8'd64) != 8'd64)
		begin
			$error("Testbench failure: TPM_STS.commandReady != 1.");
			errors = errors + 1;
		end


		// Check the commandReadyInterrupt

		// GenEntry 79: Read 1 bytes from TPM_INT_STATUS4
		genEntry = 79;

		header = 32'd3235135504;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd64;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		if ((readData[0] & 8'd128) != 8'd128)
		begin
			$error("Testbench Failure: commandReadyInt should be high.");
			errors = errors + 1;
		end


		// Reset interrupts

		// GenEntry 80: Write 1 bytes to TPM_INT_STATUS4
		genEntry = 80;

		header = 32'd1087651856;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd64;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// Ensure interrupts have been reset

		// GenEntry 81: Read 1 bytes from TPM_INT_STATUS4
		genEntry = 81;

		header = 32'd3235135504;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd64;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		if ((readData[0] & 8'd128) != 8'd0)
		begin
			$error("Testbench Failure: commandReadyInt should be low.");
			errors = errors + 1;
		end


		// Write first byte to FIFO, state should transition to Reception

		// GenEntry 82: Write 24 bytes to TPM_DATA_FIFO4
		genEntry = 82;

		header = 32'd1473527844;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd84;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd104;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd105;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd115;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd32;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd105;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd115;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd32;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd97;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd32;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd116;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd101;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd115;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd116;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd32;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd115;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd116;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd114;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd105;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd110;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd103;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd46;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd10;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd0;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 83: Read 1 bytes from TPM_STS4
		genEntry = 83;

		header = 32'd3235135512;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd64;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		if ((readData[0] & 8'd8) != 8'd8)
		begin
			$error("Testbench Failure: TPM_STS.Expect should be 1.");
			errors = errors + 1;
		end


		// Write of tpmGo does nothing, as the command hasn't finished sending ; Expect = 1

		// GenEntry 84: Write 1 bytes to TPM_STS4
		genEntry = 84;

		header = 32'd1087651864;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd32;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 85: Read 1 bytes from TPM_STS4
		genEntry = 85;

		header = 32'd3235135512;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd32;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		if ((readData[0] & 8'd8) != 8'd8)
		begin
			$error("Testbench Failure: TPM_STS.Expect should be 1.");
			errors = errors + 1;
		end


		// Once FIFO is full (command fully sent), tmpGo may be used ; Expect = 0

		// GenEntry 86: Write 1 bytes to DEBUG_CTRL4
		genEntry = 86;

		header = 32'd1087655721;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd1;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 87: Read 1 bytes from TPM_STS4
		genEntry = 87;

		header = 32'd3235135512;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd1;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		if ((readData[0] & 8'd8) != 8'd0)
		begin
			$error("Testbench Failure: TPM_STS.Expect should be 0.");
			errors = errors + 1;
		end


		// Now tpmGo can be sent, state transitions to Execution

		// GenEntry 88: Write 1 bytes to TPM_STS4
		genEntry = 88;

		header = 32'd1087651864;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd32;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 89: Read 1 bytes from TPM_STS4
		genEntry = 89;

		header = 32'd3235135512;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd32;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// Once Execution is finished, state transitions to Complete ; dataAvail = 1

		// GenEntry 90: Write 1 bytes to DEBUG_CTRL4
		genEntry = 90;

		header = 32'd1087655721;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd4;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 91: Read 1 bytes from TPM_STS4
		genEntry = 91;

		header = 32'd3235135512;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd4;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		if ((readData[0] & 8'd16) != 8'd16)
		begin
			$error("Testbench Failure: TPM_STS.dataAvail should be 1.");
			errors = errors + 1;
		end


		// Check the dataAvailInterrupt

		// GenEntry 92: Read 1 bytes from TPM_INT_STATUS4
		genEntry = 92;

		header = 32'd3235135504;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd4;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		if ((readData[0] & 8'd1) != 8'd1)
		begin
			$error("Testbench Failure: dataAvail Interrupt should be high.");
			errors = errors + 1;
		end


		// Reset interrupts

		// GenEntry 93: Write 1 bytes to TPM_INT_STATUS4
		genEntry = 93;

		header = 32'd1087651856;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd4;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// Ensure interrupts have been reset

		// GenEntry 94: Read 1 bytes from TPM_INT_STATUS4
		genEntry = 94;

		header = 32'd3235135504;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd4;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		if ((readData[0] & 8'd1) != 8'd0)
		begin
			$error("Testbench Failure: dataAvail Interrupt should be low.");
			errors = errors + 1;
		end


		// GenEntry 95: Read 24 bytes from TPM_DATA_FIFO4
		genEntry = 95;

		header = 32'd3621011492;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd4;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<24; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// Once Fifo has been fully read, dataAvail = 0

		// GenEntry 96: Write 1 bytes to DEBUG_CTRL4
		genEntry = 96;

		header = 32'd1087655721;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd2;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 97: Read 1 bytes from TPM_STS4
		genEntry = 97;

		header = 32'd3235135512;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd2;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		if ((readData[0] & 8'd16) != 8'd0)
		begin
			$error("Testbench Failure: TPM_STS.dataAvail should be 0.");
			errors = errors + 1;
		end


		// State transitions back to Idle

		// GenEntry 98: Write 1 bytes to TPM_STS4
		genEntry = 98;

		header = 32'd1087651864;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd64;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 99: Read 1 bytes from TPM_STS4
		genEntry = 99;

		header = 32'd3235135512;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd64;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// Locality 4 gives up control

		// GenEntry 100: Write 1 bytes to TPM_ACCESS4
		genEntry = 100;

		header = 32'd1087651840;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd32;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 101: Read 1 bytes from TPM_ACCESS4
		genEntry = 101;

		header = 32'd3235135488;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd32;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		if ((readData[0] & 8'd32) != 8'd0)
		begin
			$error("Testbench Failure: Locality 4 should not be active.");
			errors = errors + 1;
		end

		repeat(2) SPI_rst_n = #1 ~SPI_rst_n;
		@(posedge clock)


		// test_localitySeizeCommandAbort

		// GenEntry 102: Write 1 bytes to TPM_ACCESS2
		genEntry = 102;

		header = 32'd1087643648;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd2;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 103: Write 4 bytes to TPM_INT_ENABLE2
		genEntry = 103;

		header = 32'd1137975304;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd4;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd0;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd0;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd128;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 104: Write 1 bytes to TPM_STS2
		genEntry = 104;

		header = 32'd1087643672;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd64;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 105: Write 40 bytes to TPM_DATA_FIFO2
		genEntry = 105;

		header = 32'd1741955108;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd64;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd0;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd0;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd128;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd216;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd254;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd97;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd0;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd204;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd255;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd97;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd0;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd192;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd204;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd111;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd117;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd250;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd59;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd255;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd82;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd254;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd255;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd255;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd255;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd8;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd255;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd97;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd0;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd59;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd24;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd64;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd0;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd5;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd0;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd0;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd0;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd5;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd0;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd0;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd0;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 106: Read 1 bytes from TPM_STS2
		genEntry = 106;

		header = 32'd3235127320;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd64;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		if ((readData[0] & 8'd8) != 8'd8)
		begin
			$error("Error: TPM is not in Command Reception State. Expect should be 1.");
			errors = errors + 1;
		end


		// GenEntry 107: Write 1 bytes to TPM_ACCESS1
		genEntry = 107;

		header = 32'd1087639552;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd8;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 108: Read 1 bytes from TPM_STS2
		genEntry = 108;

		header = 32'd3235127320;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd8;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		if ((readData[0] & 8'd8) != 8'd8)
		begin
			$error("Error: Expect should still be 1.");
			errors = errors + 1;
		end


		// GenEntry 109: Read 1 bytes from TPM_ACCESS1
		genEntry = 109;

		header = 32'd3235123200;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd8;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		if ((readData[0] & 8'd32) != 8'd0)
		begin
			$error("Error: Locality 1 may not Seize control from Locality 2.");
			errors = errors + 1;
		end

		if ((readData[0] & 8'd2) != 8'd2)
		begin
			$error("Error: Locality 1 should now be requesting use.");
			errors = errors + 1;
		end


		// GenEntry 110: Read 1 bytes from TPM_ACCESS2
		genEntry = 110;

		header = 32'd3235127296;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd8;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		if ((readData[0] & 8'd36) != 8'd36)
		begin
			$error("Error: Locality 2 should be active / There should be another locality asking for access.");
			errors = errors + 1;
		end


		// GenEntry 111: Read 1 bytes from TPM_INT_STATUS2
		genEntry = 111;

		header = 32'd3235127312;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd8;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		if ((readData[0] & 8'd4) != 8'd0)
		begin
			$error("Testbench failure: localityChangeIntOccured incorrect (expected low).");
			errors = errors + 1;
		end


		// GenEntry 112: Write 1 bytes to TPM_INT_STATUS2
		genEntry = 112;

		header = 32'd1087643664;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd255;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 113: Write 1 bytes to TPM_ACCESS4
		genEntry = 113;

		header = 32'd1087651840;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd8;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 114: Read 1 bytes from TPM_STS2
		genEntry = 114;

		header = 32'd3235127320;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd8;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		if ((readData[0] & 8'd255) != 8'd255)
		begin
			$error("Error: Locality 2 should no longer be able to read TPM_STS.");
			errors = errors + 1;
		end


		// GenEntry 115: Read 1 bytes from TPM_STS4
		genEntry = 115;

		header = 32'd3235135512;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd8;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		if ((readData[0] & 8'd8) != 8'd0)
		begin
			$error("Error: TPM should be in Idle following a Seize.");
			errors = errors + 1;
		end


		// GenEntry 116: Read 1 bytes from TPM_ACCESS1
		genEntry = 116;

		header = 32'd3235123200;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd8;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 117: Read 1 bytes from TPM_ACCESS2
		genEntry = 117;

		header = 32'd3235127296;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd8;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		if ((readData[0] & 8'd32) != 8'd0)
		begin
			$error("Error: Locality 2 should no longer be in control.");
			errors = errors + 1;
		end

		if ((readData[0] & 8'd16) != 8'd16)
		begin
			$error("Error: Locality 2's beenSeized flag should be set.");
			errors = errors + 1;
		end


		// GenEntry 118: Read 1 bytes from TPM_ACCESS4
		genEntry = 118;

		header = 32'd3235135488;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd8;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		if ((readData[0] & 8'd32) != 8'd32)
		begin
			$error("Error: Locality 4 should be active.");
			errors = errors + 1;
		end


		// GenEntry 119: Read 1 bytes from TPM_INT_STATUS4
		genEntry = 119;

		header = 32'd3235135504;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd8;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		if ((readData[0] & 8'd4) != 8'd4)
		begin
			$error("Testbench failure: localityChangeIntOccured incorrect (expected high).");
			errors = errors + 1;
		end


		// GenEntry 120: Write 1 bytes to TPM_INT_STATUS4
		genEntry = 120;

		header = 32'd1087651856;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd255;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 121: Write 1 bytes to TPM_ACCESS4
		genEntry = 121;

		header = 32'd1087651840;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd32;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 122: Read 1 bytes from TPM_ACCESS1
		genEntry = 122;

		header = 32'd3235123200;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd32;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		if ((readData[0] & 8'd32) != 8'd32)
		begin
			$error("Error: Locality 1 should be active.");
			errors = errors + 1;
		end

		if ((readData[0] & 8'd4) != 8'd0)
		begin
			$error("Error: There should be no pending requests.");
			errors = errors + 1;
		end


		// GenEntry 123: Read 1 bytes from TPM_ACCESS2
		genEntry = 123;

		header = 32'd3235127296;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd32;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		if ((readData[0] & 8'd16) != 8'd16)
		begin
			$error("Error: Locality 2's beenSeized flag should still be set.");
			errors = errors + 1;
		end


		// GenEntry 124: Read 1 bytes from TPM_ACCESS4
		genEntry = 124;

		header = 32'd3235135488;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd32;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		if ((readData[0] & 8'd32) != 8'd0)
		begin
			$error("Error: Locality 4 is no longer in control.");
			errors = errors + 1;
		end


		// GenEntry 125: Read 1 bytes from TPM_INT_STATUS1
		genEntry = 125;

		header = 32'd3235123216;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd32;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		if ((readData[0] & 8'd4) != 8'd4)
		begin
			$error("Testbench failure: localityChangeIntOccured incorrect (expected high).");
			errors = errors + 1;
		end


		// GenEntry 126: Write 1 bytes to TPM_INT_STATUS1
		genEntry = 126;

		header = 32'd1087639568;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd255;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 127: Write 1 bytes to TPM_ACCESS2
		genEntry = 127;

		header = 32'd1087643648;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd16;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 128: Read 1 bytes from TPM_ACCESS2
		genEntry = 128;

		header = 32'd3235127296;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd16;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		if ((readData[0] & 8'd16) != 8'd0)
		begin
			$error("Error: Locality 2's beenSeized flag should no longer be set.");
			errors = errors + 1;
		end

		repeat(2) SPI_rst_n = #1 ~SPI_rst_n;
		@(posedge clock)


		// test_SendReceiveCMD

		// Using locality 2 for this test.

		// GenEntry 129: Write 1 bytes to TPM_ACCESS2
		genEntry = 129;

		header = 32'd1087643648;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd2;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// Set TPM to be ready to receive command data

		// GenEntry 130: Write 1 bytes to TPM_STS2
		genEntry = 130;

		header = 32'd1087643672;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd64;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 131: Read 1 bytes from TPM_STS2
		genEntry = 131;

		header = 32'd3235127320;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd64;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		if ((readData[0] & 8'd64) != 8'd64)
		begin
			$error("Error: TPM should be ready to receive command data.");
			errors = errors + 1;
		end


		// Send command header.

		// GenEntry 132: Write 10 bytes to TPM_DATA_FIFO2
		genEntry = 132;

		header = 32'd1238638628;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd128;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd1;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd32;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd0;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd0;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd0;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd0;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd0;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd0;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd35;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 133: Read 1 bytes from TPM_STS2
		genEntry = 133;

		header = 32'd3235127320;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd64;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		if ((readData[0] & 8'd8) != 8'd8)
		begin
			$error("Error: TPM should be expecting command data.");
			errors = errors + 1;
		end


		// Send data size.

		// GenEntry 134: Write 2 bytes to TPM_DATA_FIFO2
		genEntry = 134;

		header = 32'd1104420900;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd0;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd24;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 135: Read 1 bytes from TPM_STS2
		genEntry = 135;

		header = 32'd3235127320;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd64;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		if ((readData[0] & 8'd8) != 8'd8)
		begin
			$error("Error: TPM should be expecting command data.");
			errors = errors + 1;
		end


		// Write all but the last byte of the cmd data.

		// GenEntry 136: Write 23 bytes to TPM_DATA_FIFO2
		genEntry = 136;

		header = 32'd1456742436;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd84;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd104;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd105;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd115;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd32;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd105;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd115;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd32;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd97;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd32;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd116;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd101;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd115;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd116;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd32;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd109;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd101;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd115;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd115;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd97;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd103;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd101;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd46;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 137: Read 1 bytes from TPM_STS2
		genEntry = 137;

		header = 32'd3235127320;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd64;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		if ((readData[0] & 8'd8) != 8'd8)
		begin
			$error("Error: TPM should be expecting command data.");
			errors = errors + 1;
		end


		// Write last byte of cmd data from wrong locality.

		// GenEntry 138: Write 1 bytes to TPM_DATA_FIFO1
		genEntry = 138;

		header = 32'd1087639588;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd128;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 139: Read 1 bytes from TPM_STS2
		genEntry = 139;

		header = 32'd3235127320;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd64;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		if ((readData[0] & 8'd8) != 8'd8)
		begin
			$error("Error: TPM should be expecting command data.");
			errors = errors + 1;
		end


		// Write last byte of cmd data.

		// GenEntry 140: Write 1 bytes to TPM_DATA_FIFO2
		genEntry = 140;

		header = 32'd1087643684;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd128;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 141: Read 1 bytes from TPM_STS2
		genEntry = 141;

		header = 32'd3235127320;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd64;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		for(j=0; j<1; j=j+1)
		begin
			for(i=8; i!=0; i=i-1)
			begin
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		if ((readData[0] & 8'd8) != 8'd0)
		begin
			$error("Error: TPM should no longer expect data.");
			errors = errors + 1;
		end


		// GenEntry 142: Write 1 bytes to TPM_STS2
		genEntry = 142;

		header = 32'd1087643672;
		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b0;
		repeat (5) @(posedge clock);

		for(i=32; i!=0; i=i-1)
		begin
			SPI_mosi = header[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd32;
		while(in == 1'b0) for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			in = SPI_miso;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);

		// GenEntry 0: Wait for TPM Execution
		genEntry = 0;

		readData[0] = 8'd0;
		for(tries = 0; tries < 15 && (readData[0] & 8'd16) == 8'd0; tries = tries+1)
		begin
			header = 32'd3235127312;
			repeat (5) @(posedge clock);
			SPI_cs_n = 1'b0;
			repeat (5) @(posedge clock);

			for(i=32; i!=0; i=i-1)
			begin
				SPI_mosi = header[i-1];
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				in = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end

			while(in == 1'b0) for(i=8; i!=0; i=i-1)
			begin
				SPI_mosi = writeData[i-1];
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				in = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end

			for(i=8; i!=0; i=i-1)
			begin
				SPI_mosi = writeData[i-1];
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[j] = readByte;

			repeat (5) @(posedge clock);
			SPI_cs_n = 1'b1;
			repeat (5) @(posedge clock);

			#200;
		end

		if (tries == 15)
		begin
			$error("TPM Execution timeout.");
			errors = errors + 1;
			$stop;
		end


		if (errors)
			$display("There were errors in simulation.");
		else
			$display("There were no errors in simulation.");

		#200;
		$stop;
	end

endmodule

module	PLL_100
(
	input		refclk, rst,
	output	reg	outclk_0
);

	initial
	begin : pll_clock_100
		outclk_0 = 1'b0;
		forever outclk_0 = #5 ~outclk_0;
	end

endmodule
