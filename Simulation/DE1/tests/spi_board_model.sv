`timescale 1ns/1ps
module test0_top(input CLOCK_50,RESET_N,GPIO_1_2,GPIO_1_3,GPIO_1_5,GPIO_1_6,
                 output GPIO_1_4,GPIO_1_7);
    wire [9:0] leds;
    de1_soc_top dut(.CLOCK_50(CLOCK_50),.RESET_N(RESET_N),.LEDR(leds),
       .GPIO_1_2(GPIO_1_2),.GPIO_1_3(GPIO_1_3),.GPIO_1_4(GPIO_1_4),
       .GPIO_1_5(GPIO_1_5),.GPIO_1_6(GPIO_1_6),.GPIO_1_7(GPIO_1_7));
endmodule
