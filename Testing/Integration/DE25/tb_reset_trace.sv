`timescale 1ns/1ps
module tb_reset_trace;
    reg clock=0,configuration_reset=1,pll_locked=1,spi_reset_n=1,board_reset_n=1,core_reset_n=1;
    wire [159:0] gray;
    always #10 clock=~clock;
    benchmark_reset_trace dut(clock,configuration_reset,pll_locked,spi_reset_n,board_reset_n,core_reset_n,gray);
    function automatic [31:0] binary(input [31:0] g);
        integer i;
        begin binary[31]=g[31];for(i=30;i>=0;i=i-1)binary[i]=binary[i+1]^g[i];end
    endfunction
    initial begin
        #85;configuration_reset=0;#200;
        if(gray!==0)$fatal(1,"startup count");
        // Short asynchronous PLL event and a long SPI-reset level each count once.
        #2;pll_locked=0;#1;pll_locked=1;#200;
        if(binary(gray[31:0])!=1)$fatal(1,"short PLL event missed");
        spi_reset_n=0;core_reset_n=0;#300;spi_reset_n=1;core_reset_n=1;#200;
        if(binary(gray[63:32])!=1 || binary(gray[127:96])!=1)$fatal(1,"long reset overcount/missed");
        #3;spi_reset_n=0;#1;spi_reset_n=1;#200;
        if(binary(gray[63:32])!=2)$fatal(1,"short SPI event missed");
        board_reset_n=0;#100;board_reset_n=1;#200;
        if(binary(gray[95:64])!=1 || binary(gray[31:0])!=1 || binary(gray[63:32])!=2)$fatal(1,"board reset erased retained trace");
        #1100000;
        if(binary(gray[159:128])<1)$fatal(1,"uptime did not advance");
        configuration_reset=1;#100;configuration_reset=0;#100;
        if(gray!==0)$fatal(1,"configuration did not clear trace");
        $display("PASS RESET TRACE short/long pulse, retention, uptime and clear checks");$finish;
    end
    initial begin #2000000;$fatal(1,"trace deadline");end
endmodule
