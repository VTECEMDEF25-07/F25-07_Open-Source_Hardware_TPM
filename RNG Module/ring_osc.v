// ===========================================================================
// ring_osc.v
//
// Portable ring oscillator for the TPM entropy source.
//
// A ring oscillator is an odd number of inverters wired in a loop. Because
// the count is odd, the signal can never settle: it keeps flipping forever.
// Tiny random timing variations (jitter) in each flip are the source of
// randomness that entropy_source.v samples.
//
// This file works in several FPGA toolchains. Define exactly ONE of these
// macros in your project settings (or as the first line of this file):
//   RO_INTEL   - Quartus (Cyclone, MAX 10, Arria, Stratix, Agilex)
//   RO_XILINX  - Vivado (7-series, UltraScale, UltraScale+)
//   RO_ICE40   - Yosys/nextpnr for Lattice iCE40
//   SIMULATION - behavioral model for ModelSim/Questa/Icarus/Verilator
// With none defined, a generic fallback is used (may not survive synthesis).
//
// Only the two small cells, ro_inv and ro_nand, differ between vendors.
// Everything above them is identical on every board.
// ===========================================================================
`define RO_INTEL

 
// Sets simulation time units: "#1" means 1 ns, with 1 ps precision.
// Synthesis ignores this; it only matters for the simulation model below.
`timescale 1ns/1ps
 
// ===========================================================================
// ro_inv: one inverter stage of the ring.
//
// Output is the opposite of the input (o = NOT i). Each vendor branch builds
// the inverter from that vendor's own LUT primitive so synthesis treats it as
// a real, separate logic cell and can't merge the ring's stages together.
// ===========================================================================
module ro_inv (
    input  wire i,   // signal from the previous stage
    output wire o    // inverted signal to the next stage
);
`ifdef RO_INTEL
    // Intel/Quartus: compute the inversion, then pass it through an LCELL
    // buffer. The LCELL forces its own logic cell, so the stage is kept.
    (* keep *) wire d = ~i;
    lcell u_lcell (.in(d), .out(o));
 
`elsif RO_XILINX
    // Xilinx/Vivado: a 1-input LUT programmed as an inverter.
    // INIT 2'b01 is the truth table: output 1 when input is 0, else 0.
    // DONT_TOUCH stops Vivado from optimizing it away.
    (* DONT_TOUCH = "TRUE" *)
    LUT1 #(.INIT(2'b01)) u_lut (.O(o), .I0(i));
 
`elsif RO_ICE40
    // Lattice iCE40: the chip's 4-input LUT with only input I0 used.
    // LUT_INIT 16'h5555 makes the output the inverse of I0.
    (* keep *)
    SB_LUT4 #(.LUT_INIT(16'h5555)) u_lut (
        .O(o), .I0(i), .I1(1'b0), .I2(1'b0), .I3(1'b0)
    );
 
`else
    // Generic fallback for other tools: plain logic with a keep attribute.
    // Some tools honor this and some don't, so check the synthesized
    // netlist to confirm every stage survived.
    (* keep = "true" *) wire d = ~i;
    assign o = d;
`endif
endmodule
 
// ===========================================================================
// ro_nand: the gated first stage of the ring.
//
// Output is NOT (a AND b). With a = enable and b = the ring's feedback:
//   enable = 1 -> the stage acts as an inverter and the ring oscillates
//   enable = 0 -> the output is stuck at 1 and the ring stops (saves power)
// Same vendor-specific structure as ro_inv.
// ===========================================================================
module ro_nand (
    input  wire a,   // enable signal
    input  wire b,   // feedback from the last stage of the ring
    output wire o    // NAND output, drives the next stage
);
`ifdef RO_INTEL
    // Intel/Quartus: NAND logic followed by an LCELL buffer.
    (* keep *) wire d = ~(a & b);
    lcell u_lcell (.in(d), .out(o));
 
`elsif RO_XILINX
    // Xilinx/Vivado: a 2-input LUT programmed as NAND.
    // INIT 4'b0111: output is 0 only when both inputs are 1.
    (* DONT_TOUCH = "TRUE" *)
    LUT2 #(.INIT(4'b0111)) u_lut (.O(o), .I0(a), .I1(b));
 
`elsif RO_ICE40
    // Lattice iCE40: 4-input LUT using only I0 and I1, programmed as NAND.
    (* keep *)
    SB_LUT4 #(.LUT_INIT(16'h7777)) u_lut (
        .O(o), .I0(a), .I1(b), .I2(1'b0), .I3(1'b0)
    );
 
`else
    // Generic fallback (same caveat as ro_inv).
    (* keep = "true" *) wire d = ~(a & b);
    assign o = d;
`endif
endmodule
 
// ===========================================================================
// ring_osc: a complete gated ring oscillator.
//
// Chains one ro_nand plus (STAGES - 1) ro_inv cells into a loop.
// Fewer stages = higher frequency. Use different stage counts for different
// rings so they don't lock onto each other.
// ===========================================================================
module ring_osc #(
    parameter integer STAGES = 5   // number of stages; must be odd and >= 3
) (
    input  wire enable,  // 1 = ring runs, 0 = ring stopped
    output wire out      // oscillating output, sampled by entropy_source
);
 
    // Compile-time safety check. An even number of stages would latch into
    // a fixed value instead of oscillating. If STAGES is invalid, this
    // instantiates a module that doesn't exist, so the build fails with an
    // error message that names the problem.
    generate
        if ((STAGES % 2) == 0 || STAGES < 3) begin : bad_param
            ERROR_ring_osc_STAGES_must_be_odd_and_at_least_3 u_err();
        end
    endgenerate
 
`ifdef SIMULATION
    // ---- Simulation model ----
    // A real combinational loop can't be simulated (it stays X forever or
    // hangs the simulator), so simulation uses this stand-in instead: a
    // register that toggles on a delay with a little random variation.
    // It only lets the rest of the design be tested; its "randomness" says
    // nothing about the real hardware.
    reg osc = 1'b0;
    always begin
        #(STAGES * 0.1 + ({$random} % 3) * 0.01);  // wait one half-period plus jitter
        osc = enable ? ~osc : 1'b0;                // toggle if enabled, else hold low
    end
    assign out = osc;
 
`else
    // ---- Real hardware ring ----
    // node[k] is the output of stage k. The keep attribute preserves the
    // net names so you can find the ring in netlist viewers and constraints.
    (* keep = "true" *) wire [STAGES-1:0] node;
 
    // Stage 0: the NAND gate. Its inputs are enable and the output of the
    // LAST stage, which is what closes the loop.
    ro_nand u_stage0 (.a(enable), .b(node[STAGES-1]), .o(node[0]));
 
    // Stages 1 to STAGES-1: a chain of inverters, each fed by the stage
    // before it. The generate loop creates one ro_inv per stage.
    genvar i;
    generate
        for (i = 1; i < STAGES; i = i + 1) begin : g_stage
            ro_inv u_inv (.i(node[i-1]), .o(node[i]));
        end
    endgenerate
 
    // The ring's output is taken from the last stage.
    assign out = node[STAGES-1];
`endif
endmodule
 
// ===========================================================================
// Setting the define per tool
// ---------------------------------------------------------------------------
// Quartus (.qsf):
//   set_global_assignment -name VERILOG_MACRO "RO_INTEL"
//
// Vivado (Tcl console or build script):
//   set_property verilog_define RO_XILINX [current_fileset]
//
// Yosys (iCE40):
//   read_verilog -DRO_ICE40 ring_osc_portable.v entropy_source.v
//
// Simulation:
//   vlog +define+SIMULATION ...        (ModelSim/Questa)
//   iverilog -DSIMULATION ...          (Icarus)
// ===========================================================================
 
// ===========================================================================
// Timing constraints per tool
// ---------------------------------------------------------------------------
// The ring is asynchronous to the system clock, so the timing analyzer must
// be told not to check the path from the ring into the first sampling flop.
//
// Quartus (.sdc):
//   set_false_path -to [get_registers {*sample_sync[0]}]
//
// Vivado (.xdc) -- the loop override is REQUIRED, otherwise DRC LUTLP-1
// blocks bitstream generation:
//   set_property ALLOW_COMBINATORIAL_LOOPS TRUE \
//       [get_nets -hierarchical -filter {NAME =~ *u_ro*/node*}]
//   set_false_path -to [get_cells -hierarchical \
//       -filter {NAME =~ *sample_sync_reg[0]*}]
//
// nextpnr (iCE40): combinational loops produce warnings, not errors.
// Mark sample_sync[0] as an asynchronous input in your timing flow.
// ===========================================================================