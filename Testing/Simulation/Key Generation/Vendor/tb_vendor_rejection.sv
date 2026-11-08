// Authors: Aaron Grossman; Codex assisted with verification.
// Unsupported keygen choices must fail even with all request inputs inactive.
`timescale 1ns/1ps
// IP_TYPE: 0 = Generic, 1 = Altera, 2 = reserved Xilinx (unsupported).
module tb_vendor_rejection #(
    parameter SCENARIO = 0,
    parameter IP_TYPE = 2
);
    generate
        if (SCENARIO == 0) begin : tpm_case
            TPM_TOP #(.IP_TYPE(IP_TYPE)) dut (
                .CLOCK_50(1'b0), .CLOCK_100(1'b0), .RESET_n(1'b0),
                .SPI_CLOCK(1'b0), .SPI_CS_n(1'b1), .SPI_RST_n(1'b0),
                .SPI_MOSI(1'b0), .SPI_MISO(), .SPI_PIRQ_n()
            );
        end else if (SCENARIO == 2) begin : memory_case
            keygen_ram32 #(.IP_TYPE(1), .DEVICE_FAMILY("unsupported")) dut ();

        end
    endgenerate
    initial begin
        #1;
        $fatal(1,"UNEXPECTED_ACCEPTANCE: invalid configuration reached simulation");
    end
endmodule
