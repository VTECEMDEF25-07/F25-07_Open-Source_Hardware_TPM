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

		writeData = 8'd11;
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


		// GenEntry 3: Write 2 bytes to TPM_DATA_FIFO0
		genEntry = 3;

		header = 32'd1104412708;
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

		repeat (5) @(posedge clock);
		SPI_cs_n = 1'b1;
		repeat (5) @(posedge clock);


		// GenEntry 4: Write 1 bytes to TPM_STS0
		genEntry = 4;

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


		// GenEntry 5: Write 1 bytes to DEBUG_CTRL0
		genEntry = 5;

		header = 32'd1087639337;
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


		// GenEntry 6: Write 1 bytes to TPM_STS0
		genEntry = 6;

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


		// Management Module should be in operational state.

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


		// GenEntry 8: Write 10 bytes to TPM_DATA_FIFO0
		genEntry = 8;

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

		writeData = 8'd18;
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


		// GenEntry 9: Write 9 bytes to TPM_DATA_FIFO0
		genEntry = 9;

		header = 32'd1221853220;
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

		writeData = 8'd1;
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


		// GenEntry 10: Write 1 bytes to TPM_STS0
		genEntry = 10;

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


		// GenEntry 11: Write 1 bytes to DEBUG_CTRL0
		genEntry = 11;

		header = 32'd1087639337;
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


		// GenEntry 12: Read 10 bytes from TPM_DATA_FIFO0
		genEntry = 12;

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


		// GenEntry 13: Write 1 bytes to TPM_STS0
		genEntry = 13;

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
