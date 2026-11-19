// Independent arithmetic-only coverage of the 2048-bit word engine. The
// integration suites separately enforce the committed slot, e=65537 and d.
`timescale 1ns/1ps
module tb_rsa_words;
    localparam CASES=5;
    reg clk=0, rst=0, start=0, load=0;
    always #5 clk=~clk;
    reg [5:0] address=0;
    reg [31:0] n_word=0, base_word=0, exp_word=0;
    wire ready, done, error;
    wire [31:0] result;
    reg [2047:0] vectors[0:4*CASES-1];
    integer cycles=0, first_latency=0, begin_cycle;
    always @(posedge clk)cycles<=cycles+1;
    rsa_montgomery_words dut(
        .clock_i(clk),.reset_n_i(rst),.start_i(start),.load_n_i(load),
        .load_base_i(load),.load_exp_i(load),.load_address_i(address),
        .inspect_address_i(address),.n_word_i(n_word),.base_word_i(base_word),
        .exp_word_i(exp_word),.n_word_o(),.result_word_o(result),
        .ready_o(ready),.done_o(done),.error_o(error));
    initial begin
        $readmemh("word_vectors.hex",vectors);
        for(integer k=0;k<CASES;k++)begin
            @(negedge clk);rst=0;
            repeat(2)@(negedge clk);
            rst=1; wait(ready);
            for(integer j=0;j<64;j++)begin
                @(negedge clk);address=j;load=1;
                n_word=vectors[4*k][j*32+:32];
                base_word=vectors[4*k+1][j*32+:32];
                exp_word=vectors[4*k+2][j*32+:32];
            end
            @(negedge clk);load=0;start=1;begin_cycle=cycles;
            @(negedge clk);start=0;
            wait(done);@(negedge clk);
            if(error)$fatal(1,"MAC invariant failed case %0d",k);
            if(k==0)first_latency=cycles-begin_cycle;
            else if(cycles-begin_cycle!=first_latency)$fatal(1,"operand-dependent latency");
            for(integer j=0;j<64;j++)begin
                address=j;@(posedge clk);#1;
                if(result!==vectors[4*k+3][j*32+:32])
                    $fatal(1,"word oracle mismatch case=%0d limb=%0d",k,j);
                @(negedge clk);
            end
            $display("RSA_WORD_VECTOR_PASS case=%0d cycles=%0d",k,first_latency);$fflush();
        end
        $display("RSA_WORDS_PASS full_bits=2048 cases=%0d cycles_per_operation=%0d",CASES,first_latency);
        $finish;
    end
    initial begin #(64'd3000000000);$fatal(1,"word engine timeout");end
endmodule
