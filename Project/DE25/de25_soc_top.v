// Filename: de25_soc_top.v
// Modules: de25_soc_top
// Author: Aaron Grossman
// Date: 2026-10-14
// General Description: Connects the TPM to DE25 pins, related clocks, reset and independent cooling.

// TPM board wrapper for the DE25 Standard RevD.
// This top preserves TPM_TOP's command path; resource placeholders remain inactive.

// Select the implementation here for this board. This default propagates through
// TPM_TOP to keygen and its RAM/multiplier wrappers.
// 0 = Generic, 1 = Altera, 2 = Xilinx (not implemented).
`define FPGA_IP_TYPE 1

module de25_soc_top #(parameter IP_TYPE = `FPGA_IP_TYPE,
    parameter ENABLE_DEMO_COMMANDS=0, DEMO_PROVIDER_MODE=1, DEMO_MODEXP_WIDTH=2048,
    parameter CUSTOMER_DEMO_ENABLE=0, DEMO_AES_EXPORT_ENABLE=0) (
    input clock_i,
    input board_reset_n_i,
    input spi_clock_i,
    input spi_cs_n_i,
    input spi_mosi_i,
    input spi_reset_n_i,
    output spi_miso_o,
    output interrupt_n_o,
    input hps_osc_clk25_i,
    input hps_uart1_rx_i,
    output hps_uart1_tx_o,
    output hps_spim0_clk_o,
    output hps_spim0_mosi_o,
    output hps_spim0_ss0_n_o,
    inout hps_gpio34_io,
    inout hps_gpio35_io,
    inout hps_gpio42_io,
    inout fan_i2c_scl,
    inout fan_i2c_sda
);
    wire clock_50, clock_100, clock_locked;
    wire configuration_reset;
    wire board_reset_n;
    wire tpm_reset_n;
    reg [1:0] board_release_reg;
    reg [1:0] tpm_release_reg;
    reg [1:0] crypto_release_reg;

    assign board_reset_n = board_reset_n_i && !configuration_reset;
    assign tpm_reset_n = board_reset_n && spi_reset_n_i && clock_locked;

    altera_s10_user_rst_clkgate configuration_reset_source (
        .ninit_done(configuration_reset)
    );

    // Supply the original 50/100 MHz pair from one PLL; cooling keeps raw 50 MHz.
    de25_clock clocks (
        .clock_i(clock_i), .reset_i(!board_reset_n),
        .clock_50_o(clock_50), .clock_100_o(clock_100), .locked_o(clock_locked)
    );

    always @(posedge clock_i or negedge board_reset_n) begin
        if (!board_reset_n)
            board_release_reg <= 2'b00;
        else
            board_release_reg <= {board_release_reg[0], 1'b1};
    end

    // Keep the original TPM reset interface; hold it reset until PLL lock.
    // Falling-edge release leaves margin to the related 50/100 MHz edges.
    always @(negedge clock_100 or negedge tpm_reset_n) begin
        if (!tpm_reset_n)
            tpm_release_reg <= 2'b00;
        else
            tpm_release_reg <= {tpm_release_reg[0], 1'b1};
    end

    // Retain the related 100MHz release chain, then release 50MHz consumers
    // on their falling edge. Assertion still propagates asynchronously.
    always @(negedge clock_50 or negedge tpm_release_reg[1]) begin
        if (!tpm_release_reg[1])
            crypto_release_reg <= 2'b00;
        else
            crypto_release_reg <= {crypto_release_reg[0], 1'b1};
    end

    // Select the FPGA resource backend at the TPM boundary.
    TPM_TOP #(.IP_TYPE(IP_TYPE), .DEVICE_FAMILY("Agilex 5"),
        .ENABLE_DEMO_COMMANDS(ENABLE_DEMO_COMMANDS),.DEMO_PROVIDER_MODE(DEMO_PROVIDER_MODE),
        .DEMO_MODEXP_WIDTH(DEMO_MODEXP_WIDTH),.CUSTOMER_DEMO_ENABLE(CUSTOMER_DEMO_ENABLE),
        .DEMO_AES_EXPORT_ENABLE(DEMO_AES_EXPORT_ENABLE)) tpm (
        .CLOCK_50(clock_50),
        .RESET_n(crypto_release_reg[1]),
        .SPI_CLOCK(spi_clock_i),
        .SPI_CS_n(spi_cs_n_i),
        .SPI_RST_n(crypto_release_reg[1]),
        .SPI_MOSI(spi_mosi_i),
        .SPI_MISO(spi_miso_o),
        .SPI_PIRQ_n(interrupt_n_o)
    );

    // Dedicated HPS-only LCD island: no fabric bridge, clock or TPM/fan reset coupling.
    hps_lcd_island lcd_hps (
        .hps_osc_clk25_i(hps_osc_clk25_i),.hps_uart1_rx_i(hps_uart1_rx_i),
        .hps_uart1_tx_o(hps_uart1_tx_o),.hps_spim0_clk_o(hps_spim0_clk_o),
        .hps_spim0_mosi_o(hps_spim0_mosi_o),.hps_spim0_ss0_n_o(hps_spim0_ss0_n_o),
        .hps_gpio34_io(hps_gpio34_io),.hps_gpio35_io(hps_gpio35_io),.hps_gpio42_io(hps_gpio42_io)
    );

    // Cooling remains autonomous during SPI reset.
    // Use the unmodified Terasic Board_Info_RTL management example.
    BOARD_MANAGEMENT fan_control (
        .clk_50(clock_i),
        .reset_n(board_release_reg[1]),
        .I2C_SCL(fan_i2c_scl),
        .I2C_SDA(fan_i2c_sda),
        .Auto_Fan_Speed(1'b1),
        .Set_Fan_Speed(16'd4000),
        .BUSY_GO_HI(1'b0)
    );

endmodule

// Keep this board default local to this source file.
`undef FPGA_IP_TYPE
