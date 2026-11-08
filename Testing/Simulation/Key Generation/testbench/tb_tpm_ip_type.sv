// Filename: tb_tpm_ip_type.sv
// Authors: Aaron Grossman; Project contributors; see Git history.
// Date: 2026-11-08
// General Description: Check TPM-level backend propagation and inactive placeholder admission.
// AI Disclosure: Codex assisted with coding and verification.
`timescale 1ns/1ps
`include "keygen_ip_types.vh"
module tb_tpm_ip_type;
    reg clock_50=0, clock_100=0, reset_n=0;
    always #10 clock_50=~clock_50;
    always #5 clock_100=~clock_100;
    genvar backend;
    generate for (backend=0; backend<2; backend=backend+1) begin : configurations
        TPM_TOP #(.IP_TYPE(backend)) dut (
            .CLOCK_50(clock_50), .CLOCK_100(clock_100), .RESET_n(reset_n),
            .SPI_CLOCK(1'b0), .SPI_CS_n(1'b1), .SPI_RST_n(reset_n),
            .SPI_MOSI(1'b0), .SPI_MISO(), .SPI_PIRQ_n()
        );
        initial begin
            if (dut.keygen_placeholder.IP_TYPE != backend ||
                dut.keygen_placeholder.engine.IP_TYPE != backend ||
                dut.keygen_placeholder.engine.math.multiply.IP_TYPE != backend ||
                dut.keygen_placeholder.engine.math.scratch.IP_TYPE != backend ||
                dut.keygen_placeholder.engine.pair_check.multiplier.IP_TYPE != backend ||
                dut.keygen_placeholder.engine.pair_check.private_ram.IP_TYPE != backend)
                $fatal(1,"TPM IP_TYPE did not reach all keygen resources");
        end
        always @(posedge clock_50) if (reset_n) begin
            #1;
            if ({dut.keygen_placeholder.request_valid_i, dut.keygen_placeholder.request_ready_o,
                 dut.keygen_placeholder.generation_valid_i, dut.keygen_placeholder.result_valid_o,
                 dut.keygen_placeholder.status_valid_o} !== 5'b0)
                $fatal(1,"Inactive TPM keygen placeholder admitted work");
        end
    end endgenerate
    initial begin
        repeat(4) @(negedge clock_50);
        reset_n=1;
        repeat(6000) @(negedge clock_50);
        $display("PASS TPM_IP_TYPE backends=2 inactive_cycles=6000");
        $finish;
    end
endmodule
