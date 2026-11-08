// Filename: ring_osc.v
// Authors: Jungyeon Won (original oscillator); Aaron Grossman (project selection).
// AI Disclosure: Original source used generative AI; Codex assisted with selection and verification.
// Date: 2026-11-08
// Gated entropy oscillator. IP_TYPE comes from the project top, never a local
// vendor define. The functional simulation model establishes no entropy quality.
`timescale 1ns/1ps
`include "ip_types.vh"

module ro_inv #(parameter IP_TYPE = `IP_GENERIC) (
    input wire i, output wire o
);
    generate if (IP_TYPE == `IP_ALTERA) begin : altera_ip
        (* keep *) wire inverted_input = ~i;
        lcell cell_i (.in(inverted_input), .out(o));
    end else begin : invalid_ip
`ifdef VERILATOR
        initial begin $display("RNG_UNSUPPORTED_CELL_BACKEND"); $stop; end
`else
        RNG_UNSUPPORTED_CELL_BACKEND invalid_selection ();
`endif
    end endgenerate
endmodule

module ro_nand #(parameter IP_TYPE = `IP_GENERIC) (
    input wire a, input wire b, output wire o
);
    generate if (IP_TYPE == `IP_ALTERA) begin : altera_ip
        (* keep *) wire gated_input = ~(a & b);
        lcell cell_i (.in(gated_input), .out(o));
    end else begin : invalid_ip
`ifdef VERILATOR
        initial begin $display("RNG_UNSUPPORTED_CELL_BACKEND"); $stop; end
`else
        RNG_UNSUPPORTED_CELL_BACKEND invalid_selection ();
`endif
    end endgenerate
endmodule

module ring_osc #(
    parameter integer STAGES = 5,
    parameter IP_TYPE = `IP_GENERIC
) (
    input wire enable, output wire out
);
    // Synthesis sees zero; simulators see one. No global macro is defined and
    // the behavioral model cannot bypass validation of the selected backend.
    localparam SIMULATION_BUILD = 0
    // synthesis translate_off
        + 1
    // synthesis translate_on
        ;
    // Old per-RNG build flags must not be silently ignored after migration.
    localparam LEGACY_VENDOR_DEFINE = 0
`ifdef RO_INTEL
        + 1
`endif
`ifdef RO_XILINX
        + 1
`endif
`ifdef RO_ICE40
        + 1
`endif
        ;
    generate
        if (LEGACY_VENDOR_DEFINE != 0) begin : legacy_vendor_define
`ifdef VERILATOR
            initial begin $display("RNG_LEGACY_VENDOR_DEFINE: select top-level IP_TYPE instead"); $stop; end
`else
            RNG_LEGACY_VENDOR_DEFINE__USE_TOP_LEVEL_IP_TYPE invalid_selection ();
`endif
        end
        if (IP_TYPE != `IP_ALTERA && !(SIMULATION_BUILD && IP_TYPE == `IP_GENERIC)) begin : invalid_ip
`ifdef VERILATOR
            initial begin $display("RNG_UNSUPPORTED_IP_TYPE: Generic is simulation-only; hardware requires Altera"); $stop; end
`else
            RNG_UNSUPPORTED_IP_TYPE__GENERIC_SIMULATION_ONLY invalid_selection ();
`endif
        end
        if (STAGES < 3 || (STAGES % 2) == 0) begin : invalid_stages
`ifdef VERILATOR
            initial begin $display("RNG_INVALID_STAGES: use an odd number at least three"); $stop; end
`else
            RNG_INVALID_STAGES__MUST_BE_ODD_AND_AT_LEAST_THREE invalid_selection ();
`endif
        end
        if (SIMULATION_BUILD) begin : simulation_model
            // synthesis translate_off
            reg oscillator_reg = 1'b0;
            always begin
                wait (enable === 1'b1);
                #(STAGES * 0.1 + ({$random} % 3) * 0.01);
                oscillator_reg = enable ? ~oscillator_reg : 1'b0;
            end
            assign out = oscillator_reg;
            // synthesis translate_on
        end else begin : hardware_ring
            (* keep = "true" *) wire [STAGES-1:0] node;
            ro_nand #(.IP_TYPE(IP_TYPE)) first_stage (
                .a(enable), .b(node[STAGES-1]), .o(node[0])
            );
            genvar stage;
            for (stage=1; stage<STAGES; stage=stage+1) begin : inverter_stages
                ro_inv #(.IP_TYPE(IP_TYPE)) inverter (.i(node[stage-1]), .o(node[stage]));
            end
            assign out = node[STAGES-1];
        end
    endgenerate
endmodule

// Board constraints must exclude asynchronous ring-to-synchronizer paths.
// Preserve/check synthesized ring cells before physical entropy validation.
