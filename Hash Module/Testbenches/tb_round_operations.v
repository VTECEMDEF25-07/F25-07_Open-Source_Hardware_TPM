// Testbench for SHA-256 Round Operations Module
// The input is 'abc'

`timescale 1ns/1ns

module tb_round_operations;

    reg clk;
    reg reset_n;
    reg [31:0] word_in;
    reg word_valid;
    reg start;
    
    wire [255:0] hash_out;
    wire hash_valid;
    wire busy;

    round_operations dut(
        .clk(clk),
        .reset_n(reset_n),
        .word_in(word_in),
        .word_valid(word_valid),
        .start(start),
        .hash_out(hash_out),
        .hash_valid(hash_valid),
        .busy(busy)
    );

    always begin
		#10;
		clk = ~clk;
    end

    initial begin 
        clk = 0;
        reset_n = 0;
        word_in = 32'b0;
        word_valid = 0;
        start = 0;

        #20;
        reset_n = 1;
        start = 1;

        // W[0]
        #20;
        start = 0;
        word_valid = 1;
        word_in = 32'h61626380;

        // W[1]
        #20;
        word_in = 32'h0;

        // W[2]
        #20;
        word_in = 32'h0;

        // W[3]
        #20;
        word_in = 32'h0;

        // W[4]
        #20;
        word_in = 32'h0;

        // W[5]
        #20;
        word_in = 32'h0;

        // W[6]
        #20;
        word_in = 32'h0;

        // W[7]
        #20;
        word_in = 32'h0;

        // W[8]
        #20;
        word_in = 32'h0;

        // W[9]
        #20;
        word_in = 32'h0;

        // W[10]
        #20;
        word_in = 32'h0;

        // W[11]
        #20;
        word_in = 32'h0;

        // W[12]
        #20;
        word_in = 32'h0;

        // W[13]
        #20;
        word_in = 32'h0;

        // W[14]
        #20;
        word_in = 32'h0;

        // W[15]
        #20;
        word_in = 32'h00000018;

        // W[16]
        #20;
        word_in = 32'h61626380;

        // W[17]
        #20;
        word_in = 32'h000F0000;

        // W[18]
        #20;
        word_in = 32'h7DA86405;

        // W[19]
        #20;
        word_in = 32'h600003C6;

        // W[20]
        #20;
        word_in = 32'h3E9D7B78;

        // W[21]
        #20;
        word_in = 32'h0183FC00;

        // W[22]
        #20;
        word_in = 32'h12DCBFDB;

        // W[23]
        #20;
        word_in = 32'hE2E2C38E;

        // W[24]
        #20;
        word_in = 32'hC8215C1A;

        // W[25]
        #20;
        word_in = 32'hB73679A2;

        // W[26]
        #20;
        word_in = 32'hE5BC3909;

        // W[27]
        #20;
        word_in = 32'h32663C5B;

        // W[28]
        #20;
        word_in = 32'h9D209D67;

        // W[29]
        #20;
        word_in = 32'hEC8726CB;

        // W[30]
        #20;
        word_in = 32'h702138A4;

        // W[31]
        #20;
        word_in = 32'hD3B7973B;

        // W[32]
        #20;
        word_in = 32'h93F5997F;

        // W[33]
        #20;
        word_in = 32'h3B68BA73;

        // W[34]
        #20;
        word_in = 32'hAFF4FFC1;

        // W[35]
        #20;
        word_in = 32'hF10A5C62;

        // W[36]
        #20;
        word_in = 32'h0A8B3996;

        // W[37]
        #20;
        word_in = 32'h72AF830A;

        // W[38]
        #20;
        word_in = 32'h9409E33E;

        // W[39]
        #20;
        word_in = 32'h24641522;

        // W[40]
        #20;
        word_in = 32'h9F47BF94;

        // W[41]
        #20;
        word_in = 32'hF0A64F5A;

        // W[42]
        #20;
        word_in = 32'h3E246A79;

        // W[43]
        #20;
        word_in = 32'h27333BA3;

        // W[44]
        #20;
        word_in = 32'h0C4763F2;

        // W[45]
        #20;
        word_in = 32'h840ABF27;

        // W[46]
        #20;
        word_in = 32'h7A290D5D;

        // W[47]
        #20;
        word_in = 32'h065C43DA;

        // W[48]
        #20;
        word_in = 32'hFB3E89CB;

        // W[49]
        #20;
        word_in = 32'hCC7617DB;

        // W[50]
        #20;
        word_in = 32'hB9E66C34;

        // W[51]
        #20;
        word_in = 32'hA9993667;

        // W[52]
        #20;
        word_in = 32'h84BADEDD;

        // W[53]
        #20;
        word_in = 32'hC21462BC;

        // W[54]
        #20;
        word_in = 32'h1487472C;

        // W[55]
        #20;
        word_in = 32'hB20F7A99;

        // W[56]
        #20;
        word_in = 32'hEF57B9CD;

        // W[57]
        #20;
        word_in = 32'hEBE6B238;

        // W[58]
        #20;
        word_in = 32'h9FE3095E;

        // W[59]
        #20;
        word_in = 32'h78BC8D4B;

        // W[60]
        #20;
        word_in = 32'hA43FCF15;

        // W[61]
        #20;
        word_in = 32'h668B2FF8;

        // W[62]
        #20;
        word_in = 32'hEEABA2CC;

        // W[63]
        #20;
        word_in = 32'h12B1EDEB;

        #20;
        word_valid = 0;

    end
    
endmodule

