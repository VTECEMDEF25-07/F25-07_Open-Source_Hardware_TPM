`timescale 1ns/1ps
// Models isolate the top-level reset boundary. Real core/SPI and fan have separate regressions.
module altera_s10_user_rst_clkgate(output reg ninit_done=1);
endmodule
module keygen_demo_system #(parameter RSA_SOFTCORE=0,ROM_FILE="",parameter [255:0] BUILD_FINGERPRINT=0)(
    input clock_i,reset_n_i,spi_clock_i,spi_cs_n_i,spi_mosi_i,
    input [31:0] temperatures_i,fan_status_i,output spi_miso_o,interrupt_n_o);
    assign spi_miso_o=reset_n_i;
    assign interrupt_n_o=reset_n_i;
endmodule
module BOARD_MANAGEMENT(input clk_50,reset_n,input Auto_Fan_Speed,input [15:0] Set_Fan_Speed,
    input BUSY_GO_HI,inout I2C_SCL,I2C_SDA,output [15:0] FPGA_Temperature,Board_Temperature,Fan_Speed,
    output FAN_FAILSAFE,output [7:0] ALARM,output I2C_READY,TEMP_VALID);
    assign FPGA_Temperature=reset_n?16'd42:16'd0;
    assign Board_Temperature=reset_n?16'd32:16'd0;
    assign Fan_Speed=reset_n?16'd4000:16'd0;
    assign FAN_FAILSAFE=!reset_n;
    assign ALARM=0;
    assign I2C_READY=reset_n;
    assign TEMP_VALID=reset_n;
    assign I2C_SCL=1'bz;assign I2C_SDA=1'bz;
endmodule
module tb_keygen_top_reset;
    reg clock_i=0;always #10 clock_i=~clock_i;
    reg board_reset_n_i=1,spi_reset_n_i=1;
    reg spi_clock_i=0,spi_cs_n_i=1,spi_mosi_i=0;
    wire spi_miso_o,interrupt_n_o;
    wire fan_i2c_scl,fan_i2c_sda;
    keygen_de25_top dut(.*);
    task tick;begin @(posedge clock_i);#1;end endtask
    task ready;begin repeat(6)tick();if(!interrupt_n_o||dut.telemetry_sync_reg[15:0]!=32)$fatal(1,"release/telemetry");end endtask
    initial begin
        #1;if(interrupt_n_o)$fatal(1,"configuration reset not asserted");
        #2;dut.config_reset_source.ninit_done=0;
        tick();if(dut.board_release_reg[1]||dut.telemetry_sync_reg)$fatal(1,"early board release");
        tick();if(!dut.board_release_reg[1]||dut.telemetry_sync_reg)$fatal(1,"telemetry release not synchronized");
        ready();
        #3;spi_reset_n_i=0;#1;
        if(interrupt_n_o||!dut.fan_control.reset_n||dut.telemetry_sync_reg[15:0]!=32)$fatal(1,"gray reset disturbed fan");
        #2;spi_reset_n_i=1;
        tick();if(interrupt_n_o)$fatal(1,"gray reset released early");
        tick();if(!interrupt_n_o)$fatal(1,"gray reset failed release");
        #3;board_reset_n_i=0;#1;
        if(interrupt_n_o||dut.fan_control.reset_n||dut.telemetry_sync_reg)$fatal(1,"board assertion");
        #2;board_reset_n_i=1;
        tick();if(dut.board_release_reg[1]||dut.telemetry_sync_reg)$fatal(1,"board release too early");
        tick();if(dut.telemetry_sync_reg)$fatal(1,"telemetry sampling on reset-release edge");
        ready();
        #3;dut.config_reset_source.ninit_done=1;#1;
        if(interrupt_n_o||dut.fan_control.reset_n||dut.telemetry_sync_reg)$fatal(1,"configuration reassertion");
        #2;dut.config_reset_source.ninit_done=0;ready();
        $display("PASS TOP_RESET: configuration/board assert, synchronous telemetry release, independent gray reset");$finish;
    end
    initial begin #10000;$fatal(1,"timeout");end
endmodule
