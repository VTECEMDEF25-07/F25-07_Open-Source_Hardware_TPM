// Test-only board adapters for the original generated SPI transaction bench.
module test0_top (
    input CLOCK_50, RESET_N,
    input GPIO_1_2, GPIO_1_3, GPIO_1_5, GPIO_1_6,
    output GPIO_1_4, GPIO_1_7
);
    tri1 scl, sda;
    de25_soc_top dut (
        .clock_i(CLOCK_50), .board_reset_n_i(RESET_N),
        .spi_clock_i(GPIO_1_2), .spi_mosi_i(GPIO_1_3),
        .spi_cs_n_i(GPIO_1_5), .spi_reset_n_i(GPIO_1_6),
        .spi_miso_o(GPIO_1_4), .interrupt_n_o(GPIO_1_7),
        .fan_i2c_scl(scl), .fan_i2c_sda(sda)
    );
    initial begin
        #1000000000;
        $fatal(1, "PHASE1 SIMULATION DEADLINE");
    end
endmodule

module altera_s10_user_rst_clkgate (output reg ninit_done = 1);
    initial #35 ninit_done = 0;
endmodule

module BOARD_MANAGEMENT (
    input clk_50, reset_n, Auto_Fan_Speed, BUSY_GO_HI,
    input [15:0] Set_Fan_Speed,
    output [15:0] FPGA_Temperature, Board_Temperature, Fan_Speed,
    output I2C_READY, TEMP_VALID, FAN_FAILSAFE,
    inout I2C_SCL, I2C_SDA
);
    assign I2C_SCL = 1'bz;
    assign I2C_SDA = 1'bz;
    assign FPGA_Temperature = 16'd30;
    assign Board_Temperature = 16'd25;
    assign Fan_Speed = 16'd4000;
    assign I2C_READY = reset_n;
    assign TEMP_VALID = reset_n;
    assign FAN_FAILSAFE = !reset_n;
endmodule
