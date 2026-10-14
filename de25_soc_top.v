// Phase 1 TPM board wrapper for the DE25 Standard RevD.
// This top preserves tpm_top's command path; it does not instantiate keygen.
module de25_soc_top (
    input clock_i,
    input board_reset_n_i,
    input spi_clock_i,
    input spi_cs_n_i,
    input spi_mosi_i,
    input spi_reset_n_i,
    output spi_miso_o,
    output interrupt_n_o,
    inout fan_i2c_scl,
    inout fan_i2c_sda
);
    wire configuration_reset;
    wire board_reset_n;
    wire tpm_reset_n;
    reg [1:0] board_release_reg;
    reg [1:0] tpm_release_reg;
    wire [15:0] fpga_temperature, board_temperature, fan_speed;
    wire fan_ready, temperature_valid, fan_fail_safe;

    assign board_reset_n = board_reset_n_i && !configuration_reset;
    assign tpm_reset_n = board_reset_n && spi_reset_n_i;

    altera_s10_user_rst_clkgate configuration_reset_source (
        .ninit_done(configuration_reset)
    );

    always @(posedge clock_i or negedge board_reset_n) begin
        if (!board_reset_n)
            board_release_reg <= 2'b00;
        else
            board_release_reg <= {board_release_reg[0], 1'b1};
    end

    // The DE25 serializer and remaining Phase 1 logic run at 50 MHz.
    // Assertion is asynchronous; release uses two local clock edges.
    always @(posedge clock_i or negedge tpm_reset_n) begin
        if (!tpm_reset_n)
            tpm_release_reg <= 2'b00;
        else
            tpm_release_reg <= {tpm_release_reg[0], 1'b1};
    end

    // DE25_SPI=1 does not consume CLOCK_100; keep the inherited port tied.
    tpm_top #(.DE25_SPI(1)) tpm (
        .CLOCK_50(clock_i),
        .CLOCK_100(clock_i),
        .RESET_n(tpm_release_reg[1]),
        .SPI_CLOCK(spi_clock_i),
        .SPI_CS_n(spi_cs_n_i),
        .SPI_RST_n(tpm_release_reg[1]),
        .SPI_MOSI(spi_mosi_i),
        .SPI_MISO(spi_miso_o),
        .SPI_PIRQ_n(interrupt_n_o)
    );

    // Cooling remains autonomous during SPI reset.
    // Reuse the verified board-management implementation and its failsafe.
    BOARD_MANAGEMENT fan_control (
        .clk_50(clock_i),
        .reset_n(board_release_reg[1]),
        .I2C_SCL(fan_i2c_scl),
        .I2C_SDA(fan_i2c_sda),
        .FPGA_Temperature(fpga_temperature),
        .Board_Temperature(board_temperature),
        .Fan_Speed(fan_speed),
        .I2C_READY(fan_ready),
        .TEMP_VALID(temperature_valid),
        .FAN_FAILSAFE(fan_fail_safe),
        .Auto_Fan_Speed(1'b1),
        .Set_Fan_Speed(16'd4000),
        .BUSY_GO_HI(1'b0)
    );

`ifdef DE25_PHASE1_DIAGNOSTICS
    // Read-only JTAG telemetry leaves the original TPM SPI protocol untouched.
    // No probe/source bit can control cooling, reset, or TPM state.
    reg [55:0] fan_meta_reg, fan_sync_reg;
    always @(posedge clock_i or negedge board_release_reg[1]) begin
        if (!board_release_reg[1]) begin
            fan_meta_reg <= 56'b0;
            fan_sync_reg <= 56'b0;
        end else begin
            fan_meta_reg <= {5'b0, fan_fail_safe, temperature_valid, fan_ready,
                            fan_speed, fpga_temperature, board_temperature};
            fan_sync_reg <= fan_meta_reg;
        end
    end
    altsource_probe #(
        .probe_width(96), .source_width(1), .instance_id("P1TP"),
        .source_initial_value("0"), .sld_auto_instance_index("YES")
    ) phase1_monitor (
        .probe({32'h50315450, fan_sync_reg, 5'b0,
                1'b1, tpm_release_reg[1], board_release_reg[1]}),
        .source(), .source_clk(clock_i), .source_ena(1'b0)
    );
`endif
endmodule
