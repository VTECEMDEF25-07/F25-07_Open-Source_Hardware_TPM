// Filename: keygen_fan_diagnostic_system.v
// Modules: keygen_demo_system
// Authors: Project contributors; see Git history.
// Date: 2026-10-13
// General Description: Provides keygen fan diagnostic system support for the key-generation implementation and verification.
// AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

// Fan/SPI diagnostic image only. No key generation or private-key registers.
module keygen_demo_system #(
    parameter [255:0] BUILD_FINGERPRINT=256'b0
)(
    input clock_i, reset_n_i, spi_clock_i, spi_cs_n_i, spi_mosi_i,
    input [31:0] temperatures_i, fan_status_i,
    input [95:0] fan_diagnostic_i,
    output spi_miso_o, interrupt_n_o
);
    wire [7:0] read_address;
    reg [31:0] read_data;
    assign interrupt_n_o = !fan_status_i[26];
    always @* begin
        case(read_address)
            0: read_data=32'h46414e31; // FAN1, deliberately distinct from KG01.
            13: read_data=temperatures_i;
            14: read_data={16'b0,fan_status_i[15:0]};
            15: read_data={16'b0,fan_status_i[31:16]};
            24,25,26,27,28,29,30,31: read_data=BUILD_FINGERPRINT[255-(read_address-24)*32 -:32];
            32: read_data=fan_diagnostic_i[31:0];
            33: read_data=fan_diagnostic_i[63:32];
            34: read_data=fan_diagnostic_i[95:64];
            default: read_data=0;
        endcase
    end
    keygen_demo_spi transport (
        .clock_i(clock_i),.reset_n_i(reset_n_i),.spi_clock_i(spi_clock_i),
        .spi_cs_n_i(spi_cs_n_i),.spi_mosi_i(spi_mosi_i),.spi_miso_o(spi_miso_o),
        .read_address_o(read_address),.read_data_i(read_data),
        .write_valid_o(),.write_address_o(),.write_data_o()
    );
endmodule
