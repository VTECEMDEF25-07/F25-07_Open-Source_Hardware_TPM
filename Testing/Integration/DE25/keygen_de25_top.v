// DE25 RevD demo wrapper. Gray SPI reset never resets temperature/fan control.
module keygen_de25_top #(
    parameter [255:0] BUILD_FINGERPRINT=256'b0
) (
    input clock_i, input board_reset_n_i,
    input spi_clock_i, input spi_cs_n_i, input spi_mosi_i, input spi_reset_n_i,
    output spi_miso_o, output interrupt_n_o,
    inout fan_i2c_scl, inout fan_i2c_sda
);
    wire config_reset, core_clock, pll_locked, board_reset_n, spi_reset_n;
    reg [1:0] board_release_reg, spi_release_reg;
    assign board_reset_n = board_reset_n_i && !config_reset;
    assign spi_reset_n = board_reset_n && spi_reset_n_i && pll_locked;
    wire [159:0] reset_gray_raw;
    reg [159:0] reset_meta_reg, reset_sync_reg;
    benchmark_reset_trace trace (
        .clock_i(clock_i),.configuration_reset_i(config_reset),
        .pll_locked_i(pll_locked),.spi_reset_n_i(spi_reset_n_i),
        .board_reset_n_i(board_reset_n_i),.core_reset_n_i(spi_reset_n),
        .gray_o(reset_gray_raw)
    );
    always @(posedge core_clock or negedge spi_release_reg[1]) begin
        if (!spi_release_reg[1]) begin reset_meta_reg<=0;reset_sync_reg<=0;end
        else begin reset_meta_reg<=reset_gray_raw;reset_sync_reg<=reset_meta_reg;end
    end
    wire [15:0] fpga_temperature, board_temperature, fan_speed;
    wire [7:0] fan_alarm;
    wire fan_ready, temperature_valid, fan_fail_safe;
    wire [95:0] fan_diagnostic=96'b0;assign fan_fail_safe=1'b0;
    reg [159:0] telemetry_meta_reg, telemetry_sync_reg;
    // Read-only diagnostic synchronization; fan protection remains in vendor logic.
    always @(posedge core_clock or negedge spi_release_reg[1]) begin
        if (!spi_release_reg[1]) begin telemetry_meta_reg<=0;telemetry_sync_reg<=0;end
        else begin
            telemetry_meta_reg <= {fan_diagnostic,5'b0,fan_fail_safe,(temperature_valid && !fan_fail_safe),(fan_ready && !fan_fail_safe),fan_alarm,fan_speed,fpga_temperature,board_temperature};
            telemetry_sync_reg <= telemetry_meta_reg;
        end
    end
    // Both raw reset causes assert asynchronously; each chain releases locally.
    // Do not feed one chain's clocked output into another chain's async clear.
    de25_clock clocks (.clock_i(clock_i),.reset_i(!board_reset_n),.clock_50_o(core_clock),.clock_100_o(),.locked_o(pll_locked));
    altera_s10_user_rst_clkgate config_reset_source (.ninit_done(config_reset));
    always @(posedge clock_i or negedge board_reset_n) begin
        if (!board_reset_n) board_release_reg<=0;
        else board_release_reg<={board_release_reg[0],1'b1};
    end
    always @(posedge core_clock or negedge spi_reset_n) begin
        if (!spi_reset_n) spi_release_reg<=0;
        else spi_release_reg<={spi_release_reg[0],1'b1};
    end
    keygen_demo_system #(.BUILD_FINGERPRINT(BUILD_FINGERPRINT)) system (
        .clock_i(core_clock),.reset_n_i(spi_release_reg[1]),.spi_clock_i(spi_clock_i),
        .spi_cs_n_i(spi_cs_n_i),.spi_mosi_i(spi_mosi_i),.spi_miso_o(spi_miso_o),.interrupt_n_o(interrupt_n_o),
        .reset_trace_gray_i(reset_sync_reg),.temperatures_i(telemetry_sync_reg[31:0]),.fan_status_i(telemetry_sync_reg[63:32]),.fan_diagnostic_i(telemetry_sync_reg[159:64])
    );
    BOARD_MANAGEMENT fan_control (
        .clk_50(clock_i),.reset_n(board_release_reg[1]),.I2C_SCL(fan_i2c_scl),.I2C_SDA(fan_i2c_sda),
        .FPGA_Temperature(fpga_temperature),.Board_Temperature(board_temperature),.Fan_Speed(fan_speed),
        .ALARM(fan_alarm),.I2C_READY(fan_ready),.TEMP_VALID(temperature_valid),
        .Auto_Fan_Speed(1'b1),.Set_Fan_Speed(16'd4000),.BUSY_GO_HI(1'b0)
    );
endmodule
