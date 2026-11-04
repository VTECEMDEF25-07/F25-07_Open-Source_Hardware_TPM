// Filename: de25_fan_guard.v
// Modules: de25_fan_guard
// Authors: Project contributors; see Git history.
// Date: 2026-10-13
// General Description: Monitors cooling telemetry and requests failsafe fan behavior when readings are invalid or stale.
// AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

// Read-only temperature freshness guard. Faults request the fan controller's full-on mode.
module de25_fan_guard #(parameter STALE_TICKS=1953125) (
    input clock_i, input reset_n_i, input sample_valid_i, input sample_good_i,
    output fail_safe_o
);
    reg [31:0] age_reg;
    reg good_reg;
    assign fail_safe_o = !reset_n_i || !good_reg || age_reg >= STALE_TICKS;
    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) begin age_reg<=STALE_TICKS;good_reg<=0;end
        else if (sample_valid_i) begin
            good_reg<=sample_good_i;
            if(sample_good_i) age_reg<=0;
            else age_reg<=STALE_TICKS;
        end else if(age_reg<STALE_TICKS) age_reg<=age_reg+1'b1;
    end
endmodule
