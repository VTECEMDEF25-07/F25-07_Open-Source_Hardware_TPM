// Filename: tb_tpm_ip_type.sv
// Authors: Aaron Grossman; Project contributors; see Git history.
// Date: 2026-11-08
// General Description: Check TPM-level backend propagation and inactive placeholder admission.
// AI Disclosure: Codex assisted with coding and verification.
`timescale 1ns/1ps
// IP_TYPE: 0 = Generic, 1 = Altera, 2 = reserved Xilinx (unsupported).
module tb_tpm_ip_type;
    reg clock_50=0, clock_100=0, reset_n=0;
    always #10 clock_50=~clock_50;
    always #5 clock_100=~clock_100;
    genvar backend;
    generate for (backend=0; backend<3; backend=backend+1) begin : configurations
        localparam SELECTED_IP = backend == 0 ? 0 : 1;
        localparam SELECTED_FAMILY = backend == 2 ? "Cyclone V" : "Agilex 5";
        TPM_TOP #(.IP_TYPE(SELECTED_IP), .DEVICE_FAMILY(SELECTED_FAMILY)) dut (
            .CLOCK_50(clock_50), .CLOCK_100(clock_100), .RESET_n(reset_n),
            .SPI_CLOCK(1'b0), .SPI_CS_n(1'b1), .SPI_RST_n(reset_n),
            .SPI_MOSI(1'b0), .SPI_MISO(), .SPI_PIRQ_n()
        );
        initial begin
            if (dut.keygen_placeholder.IP_TYPE != SELECTED_IP ||
                dut.keygen_placeholder.engine.IP_TYPE != SELECTED_IP ||
                dut.keygen_placeholder.engine.math.multiply.IP_TYPE != SELECTED_IP ||
                dut.keygen_placeholder.engine.math.scratch.IP_TYPE != SELECTED_IP ||
                dut.keygen_placeholder.engine.pair_check.multiplier.IP_TYPE != SELECTED_IP ||
                dut.keygen_placeholder.engine.pair_check.private_ram.IP_TYPE != SELECTED_IP)
                $fatal(1,"TPM IP_TYPE did not reach all keygen resources");
            if (dut.rng_placeholder.IP_TYPE != SELECTED_IP ||
                dut.rng_placeholder.u_entropy_source.IP_TYPE != SELECTED_IP ||
                dut.rng_placeholder.u_entropy_source.u_ro0.IP_TYPE != SELECTED_IP ||
                dut.rng_placeholder.u_entropy_source.u_ro1.IP_TYPE != SELECTED_IP ||
                dut.rng_placeholder.u_entropy_source.u_ro2.IP_TYPE != SELECTED_IP ||
                dut.rng_placeholder.u_entropy_source.u_ro3.IP_TYPE != SELECTED_IP)
                $fatal(1,"TPM IP_TYPE did not reach all RNG oscillators");
            if (dut.keygen_placeholder.engine.math.scratch.DEVICE_FAMILY != SELECTED_FAMILY ||
                dut.keygen_placeholder.engine.pair_check.private_ram.DEVICE_FAMILY != SELECTED_FAMILY)
                $fatal(1,"Board family did not reach both private memories");
        end
        if (backend != 0) begin : check_vendor_memory
            initial begin
                if (dut.keygen_placeholder.engine.math.scratch.altera_ip.implementation.DEVICE_FAMILY != SELECTED_FAMILY ||
                    dut.keygen_placeholder.engine.math.scratch.altera_ip.implementation.RAM_BLOCK_TYPE !=
                    (backend == 2 ? "M10K" : "M20K"))
                    $fatal(1,"Incorrect vendor RAM family/block selection");
            end
        end
        always @(posedge clock_50) if (reset_n) begin
            #1;
            if ({dut.keygen_placeholder.request_valid_i, dut.keygen_placeholder.request_ready_o,
                 dut.keygen_placeholder.generation_valid_i, dut.keygen_placeholder.result_valid_o,
                 dut.keygen_placeholder.status_valid_o} !== 5'b0)
                $fatal(1,"Inactive TPM keygen placeholder admitted work");
            if (dut.rng_placeholder.enable !== 1'b0 ||
                dut.rng_placeholder.cmd_valid !== 1'b0 ||
                dut.rng_placeholder.rsp_valid !== 1'b0 ||
                dut.rng_placeholder.u_entropy_source.entropy_valid !== 1'b0)
                $fatal(1,"Inactive TPM RNG placeholder admitted work");
        end
    end endgenerate
    initial begin
        repeat(4) @(negedge clock_50);
        reset_n=1;
        repeat(6000) @(negedge clock_50);
        $display("PASS TPM_IP_TYPE backends=2 families=2 rng_rings=4 inactive_cycles=6000");
        $finish;
    end
endmodule
