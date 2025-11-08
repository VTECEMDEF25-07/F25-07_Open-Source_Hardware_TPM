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

	test0_top	dut
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
	reg	in;
	integer i, j, genEntry, tries, errors;

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
		@(posedge clock);


		// test_hierarchyControl

		// Using Locality 0 as active locality.

		// GenEntry 0: Write 1 bytes to TPM_ACCESS0
		genEntry = 0;

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


		// GenEntry 1: Write 1 bytes to TPM_STS0
		genEntry = 1;

		header = 32'd1087635480;
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


		// Send command TPM_CC_STARTUP : TPM_SU_CLEAR -> put TPM in operational state.

		// GenEntry 2: Write 10 bytes to TPM_DATA_FIFO0
		genEntry = 2;

		header = 32'd1238630436;
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

		writeData = 8'd12;
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

		writeData = 8'd1;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd68;
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


		// GenEntry 3: Write 1 bytes to TPM_DATA_FIFO0
		genEntry = 3;

		header = 32'd1087635492;
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

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 4: Write 1 bytes to TPM_DATA_FIFO0
		genEntry = 4;

		header = 32'd1087635492;
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

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 5: Write 1 bytes to TPM_STS0
		genEntry = 5;

		header = 32'd1087635480;
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
			header = 32'd3235119128;
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
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[0] = readByte;

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


		// GenEntry 6: Read 10 bytes from TPM_DATA_FIFO0
		genEntry = 6;

		header = 32'd3386114084;
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

		for(j=0; j<10; j=j+1)
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


		// GenEntry 7: Write 1 bytes to TPM_STS0
		genEntry = 7;

		header = 32'd1087635480;
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


		// Management Module now in operational state.

		// GenEntry 8: Write 1 bytes to TPM_STS0
		genEntry = 8;

		header = 32'd1087635480;
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


		// Send command TPM_CC_HIERARCHYCONTROL : TPM_RH_PLATFORM, TPMI_YES

		// GenEntry 9: Write 10 bytes to TPM_DATA_FIFO0
		genEntry = 9;

		header = 32'd1238630436;
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

		writeData = 8'd2;
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

		writeData = 8'd103;
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

		writeData = 8'd1;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd33;
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


		// GenEntry 10: Write 4 bytes to TPM_DATA_FIFO0
		genEntry = 10;

		header = 32'd1137967140;
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

		writeData = 8'd18;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd52;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd86;
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


		// GenEntry 11: Write 4 bytes to TPM_DATA_FIFO0
		genEntry = 11;

		header = 32'd1137967140;
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

		writeData = 8'd80;
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


		// GenEntry 12: Write 64 bytes to TPM_DATA_FIFO0
		genEntry = 12;

		header = 32'd2144600100;
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

		writeData = 8'd52;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd86;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd120;
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

		writeData = 8'd36;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd84;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
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

		writeData = 8'd112;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd108;
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

		writeData = 8'd99;
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

		writeData = 8'd104;
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

		writeData = 8'd108;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd100;
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

		writeData = 8'd114;
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

		writeData = 8'd110;
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

		writeData = 8'd110;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd99;
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

		writeData = 8'd32;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd98;
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

		writeData = 8'd102;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd102;
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

		writeData = 8'd114;
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

		writeData = 8'd84;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
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

		writeData = 8'd112;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd108;
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

		writeData = 8'd99;
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

		writeData = 8'd104;
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

		writeData = 8'd108;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd100;
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


		// GenEntry 13: Write 16 bytes to TPM_DATA_FIFO0
		genEntry = 13;

		header = 32'd1339293732;
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

		writeData = 8'd52;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd86;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd120;
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

		writeData = 8'd36;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd84;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
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

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 14: Write 1 bytes to TPM_DATA_FIFO0
		genEntry = 14;

		header = 32'd1087635492;
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


		// GenEntry 15: Write 1 bytes to TPM_DATA_FIFO0
		genEntry = 15;

		header = 32'd1087635492;
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

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 16: Write 1 bytes to TPM_DATA_FIFO0
		genEntry = 16;

		header = 32'd1087635492;
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

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 17: Write 1 bytes to TPM_DATA_FIFO0
		genEntry = 17;

		header = 32'd1087635492;
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

		writeData = 8'd12;
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


		// GenEntry 18: Write 1 bytes to TPM_DATA_FIFO0
		genEntry = 18;

		header = 32'd1087635492;
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


		// GenEntry 19: Write 1 bytes to TPM_STS0
		genEntry = 19;

		header = 32'd1087635480;
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

		// GenEntry 1: Wait for TPM Execution
		genEntry = 1;

		readData[0] = 8'd0;
		for(tries = 0; tries < 15 && (readData[0] & 8'd16) == 8'd0; tries = tries+1)
		begin
			header = 32'd3235119128;
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
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[0] = readByte;

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


		// GenEntry 20: Read 10 bytes from TPM_DATA_FIFO0
		genEntry = 20;

		header = 32'd3386114084;
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

		for(j=0; j<10; j=j+1)
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

		if (
			readData[6] != 8'd0 ||
			readData[7] != 8'd0 ||
			readData[8] != 8'd0 ||
			readData[9] != 8'd132
		)
		begin
			$error("Expected TPM_RC_VALUE.");
			errors = errors + 1;
		end


		// GenEntry 21: Write 1 bytes to TPM_STS0
		genEntry = 21;

		header = 32'd1087635480;
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


		// GenEntry 22: Write 1 bytes to TPM_ACCESS0
		genEntry = 22;

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

		repeat(2) SPI_rst_n = #1 ~SPI_rst_n;
		@(posedge clock);


		// test_ccQuote

		// Using Locality 0 as active locality.

		// GenEntry 23: Write 1 bytes to TPM_ACCESS0
		genEntry = 23;

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


		// GenEntry 24: Write 1 bytes to TPM_STS0
		genEntry = 24;

		header = 32'd1087635480;
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


		// Send command TPM_CC_STARTUP : TPM_SU_CLEAR -> put TPM in operational state.

		// GenEntry 25: Write 10 bytes to TPM_DATA_FIFO0
		genEntry = 25;

		header = 32'd1238630436;
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

		writeData = 8'd12;
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

		writeData = 8'd1;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd68;
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


		// GenEntry 26: Write 1 bytes to TPM_DATA_FIFO0
		genEntry = 26;

		header = 32'd1087635492;
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

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 27: Write 1 bytes to TPM_DATA_FIFO0
		genEntry = 27;

		header = 32'd1087635492;
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

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 28: Write 1 bytes to TPM_STS0
		genEntry = 28;

		header = 32'd1087635480;
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

		// GenEntry 2: Wait for TPM Execution
		genEntry = 2;

		readData[0] = 8'd0;
		for(tries = 0; tries < 15 && (readData[0] & 8'd16) == 8'd0; tries = tries+1)
		begin
			header = 32'd3235119128;
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
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[0] = readByte;

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


		// GenEntry 29: Read 10 bytes from TPM_DATA_FIFO0
		genEntry = 29;

		header = 32'd3386114084;
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

		for(j=0; j<10; j=j+1)
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

		if (
			readData[6] != 8'd0 ||
			readData[7] != 8'd0 ||
			readData[8] != 8'd0 ||
			readData[9] != 8'd0
		)
		begin
			$error("Response code error: Expected TPM_RC_SUCCESS.");
			errors = errors + 1;
		end


		// GenEntry 30: Write 1 bytes to TPM_STS0
		genEntry = 30;

		header = 32'd1087635480;
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


		// Management Module now in operational state.

		// GenEntry 31: Write 1 bytes to TPM_STS0
		genEntry = 31;

		header = 32'd1087635480;
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


		// GenEntry 32: Write 10 bytes to TPM_DATA_FIFO0
		genEntry = 32;

		header = 32'd1238630436;
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

		writeData = 8'd19;
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

		writeData = 8'd1;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd88;
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


		// GenEntry 33: Write 4 bytes to TPM_DATA_FIFO0
		genEntry = 33;

		header = 32'd1137967140;
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

		writeData = 8'd64;
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


		// GenEntry 34: Write 1 bytes to TPM_DATA_FIFO0
		genEntry = 34;

		header = 32'd1087635492;
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


		// GenEntry 35: Write 1 bytes to TPM_DATA_FIFO0
		genEntry = 35;

		header = 32'd1087635492;
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

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 36: Write 1 bytes to TPM_DATA_FIFO0
		genEntry = 36;

		header = 32'd1087635492;
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

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 37: Write 1 bytes to TPM_DATA_FIFO0
		genEntry = 37;

		header = 32'd1087635492;
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

		writeData = 8'd12;
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


		// GenEntry 38: Write 1 bytes to TPM_DATA_FIFO0
		genEntry = 38;

		header = 32'd1087635492;
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


		// GenEntry 39: Write 1 bytes to TPM_STS0
		genEntry = 39;

		header = 32'd1087635480;
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

		// GenEntry 3: Wait for TPM Execution
		genEntry = 3;

		readData[0] = 8'd0;
		for(tries = 0; tries < 15 && (readData[0] & 8'd16) == 8'd0; tries = tries+1)
		begin
			header = 32'd3235119128;
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
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[0] = readByte;

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


		// GenEntry 40: Read 10 bytes from TPM_DATA_FIFO0
		genEntry = 40;

		header = 32'd3386114084;
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

		for(j=0; j<10; j=j+1)
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

		if (
			readData[6] != 8'd0 ||
			readData[7] != 8'd0 ||
			readData[8] != 8'd1 ||
			readData[9] != 8'd69
		)
		begin
			$error("Response code error: Expected TPM_RC_AUTH_CONTEXT.");
			errors = errors + 1;
		end


		// GenEntry 41: Write 1 bytes to TPM_STS0
		genEntry = 41;

		header = 32'd1087635480;
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


		// GenEntry 42: Write 1 bytes to TPM_STS0
		genEntry = 42;

		header = 32'd1087635480;
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


		// GenEntry 43: Write 10 bytes to TPM_DATA_FIFO0
		genEntry = 43;

		header = 32'd1238630436;
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

		writeData = 8'd2;
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

		writeData = 8'd103;
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

		writeData = 8'd1;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd88;
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


		// GenEntry 44: Write 4 bytes to TPM_DATA_FIFO0
		genEntry = 44;

		header = 32'd1137967140;
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

		writeData = 8'd64;
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


		// GenEntry 45: Write 4 bytes to TPM_DATA_FIFO0
		genEntry = 45;

		header = 32'd1137967140;
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

		writeData = 8'd80;
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


		// GenEntry 46: Write 64 bytes to TPM_DATA_FIFO0
		genEntry = 46;

		header = 32'd2144600100;
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

		writeData = 8'd18;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd52;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd86;
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

		writeData = 8'd36;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd84;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
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

		writeData = 8'd112;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd108;
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

		writeData = 8'd99;
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

		writeData = 8'd104;
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

		writeData = 8'd108;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd100;
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

		writeData = 8'd114;
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

		writeData = 8'd110;
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

		writeData = 8'd110;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd99;
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

		writeData = 8'd32;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd98;
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

		writeData = 8'd102;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd102;
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

		writeData = 8'd114;
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

		writeData = 8'd84;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
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

		writeData = 8'd112;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd108;
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

		writeData = 8'd99;
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

		writeData = 8'd104;
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

		writeData = 8'd108;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd100;
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


		// GenEntry 47: Write 16 bytes to TPM_DATA_FIFO0
		genEntry = 47;

		header = 32'd1339293732;
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

		writeData = 8'd18;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd52;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd86;
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

		writeData = 8'd36;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b0;
		end

		writeData = 8'd84;
		for(i=8; i!=0; i=i-1)
		begin
			SPI_mosi = writeData[i-1];
			`SPI_CLK_PERIOD;
			SPI_clock = 1'b1;
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

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 48: Write 1 bytes to TPM_DATA_FIFO0
		genEntry = 48;

		header = 32'd1087635492;
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


		// GenEntry 49: Write 1 bytes to TPM_DATA_FIFO0
		genEntry = 49;

		header = 32'd1087635492;
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

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 50: Write 1 bytes to TPM_DATA_FIFO0
		genEntry = 50;

		header = 32'd1087635492;
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

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 51: Write 1 bytes to TPM_DATA_FIFO0
		genEntry = 51;

		header = 32'd1087635492;
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

		writeData = 8'd12;
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


		// GenEntry 52: Write 1 bytes to TPM_DATA_FIFO0
		genEntry = 52;

		header = 32'd1087635492;
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


		// GenEntry 53: Write 1 bytes to TPM_STS0
		genEntry = 53;

		header = 32'd1087635480;
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

		// GenEntry 4: Wait for TPM Execution
		genEntry = 4;

		readData[0] = 8'd0;
		for(tries = 0; tries < 15 && (readData[0] & 8'd16) == 8'd0; tries = tries+1)
		begin
			header = 32'd3235119128;
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
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b1;
				readByte[i-1] = SPI_miso;
				`SPI_CLK_PERIOD;
				SPI_clock = 1'b0;
			end
			readData[0] = readByte;

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


		// GenEntry 54: Read 10 bytes from TPM_DATA_FIFO0
		genEntry = 54;

		header = 32'd3386114084;
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

		for(j=0; j<10; j=j+1)
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

		if (
			readData[6] != 8'd0 ||
			readData[7] != 8'd0 ||
			readData[8] != 8'd0 ||
			readData[9] != 8'd0
		)
		begin
			$error("Response code error: Expected TPM_RC_SUCCESS.");
			errors = errors + 1;
		end


		// GenEntry 55: Write 1 bytes to TPM_STS0
		genEntry = 55;

		header = 32'd1087635480;
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


		// GenEntry 56: Write 1 bytes to TPM_ACCESS0
		genEntry = 56;

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
