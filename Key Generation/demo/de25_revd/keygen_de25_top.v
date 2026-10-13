// DE25 RevD demo wrapper. Gray SPI reset never resets temperature/fan control.
module keygen_de25_top #(
    parameter RSA_SOFTCORE=0, parameter ROM_FILE="rsa_control.hex",
    parameter [255:0] BUILD_FINGERPRINT=256'b0
) (
    input clock_i, input board_reset_n_i,
    input spi_clock_i, input spi_cs_n_i, input spi_mosi_i, input spi_reset_n_i,
    output spi_miso_o, output interrupt_n_o,
    inout fan_i2c_scl, inout fan_i2c_sda
);
    wire config_reset;
    wire [15:0] fpga_temperature, board_temperature, fan_speed;
    wire [7:0] fan_alarm;
    wire fan_ready, temperature_valid, fan_fail_safe;
    reg [63:0] telemetry_meta_reg, telemetry_sync_reg;
    // Read-only diagnostic synchronization; fan protection remains in vendor logic.
    always @(posedge clock_i or negedge board_release_reg[1]) begin
        if (!board_release_reg[1]) begin telemetry_meta_reg<=0;telemetry_sync_reg<=0;end
        else begin
            telemetry_meta_reg <= {5'b0,fan_fail_safe,temperature_valid,fan_ready,fan_alarm,fan_speed,fpga_temperature,board_temperature};
            telemetry_sync_reg <= telemetry_meta_reg;
        end
    end
    wire board_reset_n = board_reset_n_i && !config_reset;
    reg [1:0] board_release_reg, spi_release_reg;
    // Both raw reset causes assert asynchronously; each chain releases locally.
    // Do not feed one chain's clocked output into another chain's async clear.
    wire spi_reset_n = board_reset_n && spi_reset_n_i;
    altera_s10_user_rst_clkgate config_reset_source (.ninit_done(config_reset));
    always @(posedge clock_i or negedge board_reset_n) begin
        if (!board_reset_n) board_release_reg<=0;
        else board_release_reg<={board_release_reg[0],1'b1};
    end
    always @(posedge clock_i or negedge spi_reset_n) begin
        if (!spi_reset_n) spi_release_reg<=0;
        else spi_release_reg<={spi_release_reg[0],1'b1};
    end
    keygen_demo_system #(.RSA_SOFTCORE(RSA_SOFTCORE),.ROM_FILE(ROM_FILE),.BUILD_FINGERPRINT(BUILD_FINGERPRINT)) system (
        .clock_i(clock_i),.reset_n_i(spi_release_reg[1]),.spi_clock_i(spi_clock_i),
        .spi_cs_n_i(spi_cs_n_i),.spi_mosi_i(spi_mosi_i),.spi_miso_o(spi_miso_o),.interrupt_n_o(interrupt_n_o),
        .temperatures_i(telemetry_sync_reg[31:0]),.fan_status_i(telemetry_sync_reg[63:32])
    );
    BOARD_MANAGEMENT fan_control (
        .clk_50(clock_i),.reset_n(board_release_reg[1]),.I2C_SCL(fan_i2c_scl),.I2C_SDA(fan_i2c_sda),
        .FPGA_Temperature(fpga_temperature),.Board_Temperature(board_temperature),.Fan_Speed(fan_speed),
        .FAN_FAILSAFE(fan_fail_safe),.ALARM(fan_alarm),.I2C_READY(fan_ready),.TEMP_VALID(temperature_valid),
        .Auto_Fan_Speed(1'b1),.Set_Fan_Speed(16'd4000),.BUSY_GO_HI(1'b0)
    );
endmodule
