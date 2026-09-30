// ===========================================================================
// entropy_source.v
//
// Collects random bits from four ring oscillators and outputs them as one
// 256-bit block, with a one-clock-cycle "valid" pulse when a block is ready.
//
// This is only the raw noise-source stage of the TPM RNG. Its output still
// needs health tests, conditioning (e.g. SHA-256) and a DRBG before it's
// safe to use for keys.
//
// Requires ring_osc.v in the same project.
// ===========================================================================
 
// Simulation time units (ignored by synthesis).
`timescale 1ns/1ps
 
module entropy_source (
    input  wire         clk,             // system clock; sets the sampling rate
    input  wire         rst_n,           // active-low reset (0 = reset)
    input  wire         enable,          // 1 = run the rings and collect bits
    output reg  [255:0] entropy_output,  // latest completed 256-bit block
    output reg          entropy_valid    // pulses high for 1 cycle per new block
);
 
    // -----------------------------------------------------------------------
    // Four ring oscillators with different odd lengths.
    // Different lengths give different frequencies, so the rings are less
    // likely to lock onto each other through the shared power supply.
    // -----------------------------------------------------------------------
    wire [3:0] ro_out;  // one output bit per ring
    ring_osc #(.STAGES(5))  u_ro0 (.enable(enable), .out(ro_out[0]));
    ring_osc #(.STAGES(7))  u_ro1 (.enable(enable), .out(ro_out[1]));
    ring_osc #(.STAGES(11)) u_ro2 (.enable(enable), .out(ro_out[2]));
    ring_osc #(.STAGES(13)) u_ro3 (.enable(enable), .out(ro_out[3]));
 
    // -----------------------------------------------------------------------
    // Combine the rings by XORing their outputs together.
    // The result is only predictable if EVERY ring is predictable at the
    // same moment, so this concentrates the randomness into one bit.
    // (^ro_out is Verilog shorthand for ro_out[0]^ro_out[1]^ro_out[2]^ro_out[3].)
    // -----------------------------------------------------------------------
    wire raw_bit = ^ro_out;
 
    // -----------------------------------------------------------------------
    // Two-flop synchronizer.
    // raw_bit changes at random times relative to clk, so the first flop
    // (sample_sync[0]) can go metastable: briefly stuck between 0 and 1.
    // The second flop gives it a full clock cycle to settle before the rest
    // of the design uses it. The attribute tells Quartus this is a
    // synchronizer so it treats it correctly during timing analysis.
    // -----------------------------------------------------------------------
    (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED" *)
    reg [1:0] sample_sync;
 
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) sample_sync <= 2'b00;                       // clear on reset
        else        sample_sync <= {sample_sync[0], raw_bit};   // shift raw bit in
    end
 
    // The clean, synchronized random bit used by everything below.
    wire sampled_bit = sample_sync[1];
 
    // -----------------------------------------------------------------------
    // Storage for collecting bits.
    // sipo_shift_register: "serial in, parallel out" - bits enter one at a
    //   time and the whole 256-bit block is read out at once.
    // sample_count: counts 0 to 255 so we know when 256 bits are collected.
    // -----------------------------------------------------------------------
    reg [255:0] sipo_shift_register;
    reg [7:0]   sample_count;
 
    // -----------------------------------------------------------------------
    // Main collection logic. Runs on every rising clock edge.
    // -----------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset: clear all state.
            sipo_shift_register <= 256'b0;
            sample_count        <= 8'b0;
            entropy_output      <= 256'b0;
            entropy_valid       <= 1'b0;
        end else begin
            // Default: valid is low. It only goes high for the single cycle
            // when a block finishes (set below), which makes it a pulse.
            entropy_valid <= 1'b0;
 
            if (enable) begin
                // Shift the register left by one and put the new bit at the
                // bottom. The oldest bit falls off the top.
                sipo_shift_register <= {sipo_shift_register[254:0], sampled_bit};
 
                if (sample_count == 8'hFF) begin
                    // This is the 256th bit: publish the full block.
                    // Built the same way as the shift above, so the block
                    // includes the bit that arrived this cycle.
                    entropy_output <= {sipo_shift_register[254:0], sampled_bit};
                    entropy_valid  <= 1'b1;   // signal that a new block is ready
                    sample_count   <= 8'b0;   // start counting the next block
                end else begin
                    // Not done yet: count this bit and keep collecting.
                    sample_count <= sample_count + 8'b1;
                end
            end
            // If enable is 0, nothing changes: the count and partial block
            // are kept, and collection resumes where it left off.
        end
    end
 
endmodule