// Continuous raw-bit sanity tests; Codex assisted implementation.
// Engineering thresholds, NOT SP800-90B-qualified entropy estimates.
// Physical entropy on the integrated image remains unverified and requires
// later measurement; simulated detection does not establish entropy adequacy.
module entropy_health #(
    parameter integer REPETITION_LIMIT = 32,
    parameter integer WINDOW_BITS = 512,
    parameter integer MIN_ONES = 128,
    parameter integer MAX_ONES = 384
)(
    input wire clk, rst_n, sample_i, sample_valid_i,
    output reg fault_o, ready_o,
    output wire reject_sample_o
);
    reg previous, have_sample;
    reg [31:0] repetition, samples, ones;
    wire [31:0] next_ones = ones + (sample_i ? 32'd1 : 32'd0);
    // Qualify consumers at the edge that accepts a failing raw sample, rather
    // than one clock after fault_o is registered. Thresholds are unchanged.
    assign reject_sample_o = rst_n && sample_valid_i && !fault_o &&
        ((have_sample && sample_i == previous && repetition >= REPETITION_LIMIT-1) ||
         (samples == WINDOW_BITS-1 && (next_ones < MIN_ONES || next_ones > MAX_ONES)));
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            previous<=0; have_sample<=0; repetition<=0;
            samples<=0; ones<=0; fault_o<=0; ready_o<=0;
        end else if(sample_valid_i && !fault_o) begin
            have_sample<=1; previous<=sample_i;
            if(have_sample && sample_i == previous) begin
                repetition<=repetition+1'b1;
                if(repetition >= REPETITION_LIMIT-1) begin fault_o<=1; ready_o<=0; end
            end else repetition<=1;
            if(samples == WINDOW_BITS-1) begin
                samples<=0; ones<=0;
                if(next_ones < MIN_ONES || next_ones > MAX_ONES) begin
                    fault_o<=1; ready_o<=0;
                end else if(!(have_sample && sample_i == previous && repetition >= REPETITION_LIMIT-1))
                    ready_o<=1;
            end else begin samples<=samples+1'b1; ones<=next_ones; end
        end
    end
endmodule
