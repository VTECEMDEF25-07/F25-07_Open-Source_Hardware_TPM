// Author: Aaron Grossman
// Normal-behavior checks for the unmodified Terasic AutoFan example.
`timescale 1ns/1ps
module tb_keygen_fan;
    reg clk=0; always #5 clk=~clk;
    reg reset_n=1, invalid=0;
    reg signed [7:0] temperature=20;
    wire [7:0] setting;
    AutoFan dut(.clk(clk),.reset_n(reset_n),.temp_fpga(temperature),
                .fan_ktach(setting),.invalid_temp(invalid));
    task check(input integer temp,input integer expected);
        @(negedge clk);temperature=temp;
        repeat(5)@(negedge clk);
        if(setting!==expected[7:0])$fatal(1,"temp=%0d setting=%0d expected=%0d",temp,setting,expected);
    endtask
    initial begin
        #1;reset_n=0;#1;
        // Original example starts at Speed4, approximately 4900 RPM.
        if(setting!==8'd23)$fatal(1,"vendor reset speed");
        @(negedge clk);reset_n=1;
        check(20,33);check(80,19);check(20,33);
        @(negedge clk);invalid=1;
        repeat(3)@(negedge clk);
        if(setting!==8'd19)$fatal(1,"vendor invalid-temperature input");
        $display("PASS VENDOR_FAN: reset speed, cold/hot ramp, invalid input");$finish;
    end
    initial begin #10000;$fatal(1,"timeout");end
endmodule
