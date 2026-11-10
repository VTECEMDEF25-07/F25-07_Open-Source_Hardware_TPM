`timescale 1ns/1ps
// Deterministic RO fixture: verifies control/cadence, never entropy quality.
module ring_osc #(parameter STAGES=5)(input enable, output out);
    assign out=enable && (STAGES==5);
endmodule

module entropy_profile_case #(parameter W=8,D=1)(output reg done=0);
    reg clk=0; always #5 clk=~clk;
    reg rst=0,ov=0,orr=0,wr=0,cv=0,crr=0;
    wire ready,orv,wv,cr,crv,sready,scrub,fault;
    wire [3:0] oe,ce; wire [31:0] wd;
    integer age=0,last_sample=-1,samples=0,blocks=0,words=0;
    reg stalled=0; reg [31:0] held;
    demo_generation_service #(.DEMO_PROVIDER_MODE(0),
        .ENTROPY_WARMUP_CYCLES(W),.ENTROPY_SAMPLE_DIV(D)) dut(
        .clock_i(clk),.reset_n_i(rst),.open_valid_i(ov),.open_ready_o(ready),
        .open_profile_i(2'd1),.open_id_i(32'd55),.open_mode_i(2'd0),
        .open_rsp_valid_o(orv),.open_rsp_ready_i(orr),.open_rsp_error_o(oe),
        .word_valid_o(wv),.word_ready_i(wr),.word_data_o(wd),
        .context_fault_o(fault),.context_fault_code_o(),
        .close_valid_i(cv),.close_ready_o(cr),.close_id_i(32'd55),.close_failed_i(1'b0),
        .close_rsp_valid_o(crv),.close_rsp_ready_i(crr),.close_rsp_error_o(ce),
        .service_ready_o(sready),.scrub_done_o(scrub));
    // Elaborate the complete operation and verify both forwarding levels.
    demo_keygen_operation #(.DEMO_PROVIDER_MODE(0),
        .ENTROPY_WARMUP_CYCLES(W),.ENTROPY_SAMPLE_DIV(D)) op(
        .clock_i(1'b0),.reset_n_i(1'b0),.job_valid_i(1'b0));
    always @(posedge clk) begin
        if(dut.provider_running) begin
            if(dut.g_fresh.u_entropy.raw_sample_valid) begin
                if(samples==0 && age!=W) $fatal(1,"warmup %0d expected %0d",age,W);
                if(samples!=0 && age-last_sample!=D) $fatal(1,"cadence");
                last_sample=age; samples=samples+1;
            end
            if(dut.g_fresh.entropy_valid && dut.g_fresh.entropy_needed) blocks=blocks+1;
            age=age+1;
        end
        if(fault) $fatal(1,"context fault");
        if(stalled && (!wv || wd!==held)) $fatal(1,"held word changed");
        stalled=wv && !wr; held=wd;
        if(wv && wr) words=words+1;
    end
    initial begin
        if(op.u_source.g_fresh.u_entropy.WARMUP_CYCLES!=W ||
           op.u_source.g_fresh.u_entropy.SAMPLE_DIV!=D) $fatal(1,"operation forwarding");
        if(dut.SEED_BLOCKS!=3 || dut.RESEED_BLOCKS!=2 || dut.RESEED_INTERVAL!=1024)
            $fatal(1,"seed defaults");
        repeat(4) @(negedge clk); rst=1;
        wait(ready); @(negedge clk); ov=1;
        @(negedge clk); ov=0;
        wait(orv); if(oe!=0 || blocks!=3) $fatal(1,"open/seed count");
        repeat(5) @(negedge clk);
        if(!orv) $fatal(1,"open response hold");
        orr=1; @(negedge clk); orr=0;
        wait(wv); repeat(7) @(negedge clk);
        wr=1; wait(words==8); @(negedge clk); wr=0; cv=1;
        @(negedge clk); cv=0;
        wait(crv); if(ce || !scrub || wv) $fatal(1,"close scrub");
        repeat(5) @(negedge clk);
        if(!crv || !scrub) $fatal(1,"close response hold");
        crr=1; @(negedge clk); crr=0;
        wait(sready); if(!scrub || wv) $fatal(1,"idle scrub");
        $display("PASS ENTROPY_PROFILE W=%0d D=%0d samples=%0d seedblocks=%0d words=%0d",W,D,samples,blocks,words);
        done=1;
    end
endmodule
module tb_entropy_profiles;
    wire a,b;
    demo_keygen_operation #(.DEMO_PROVIDER_MODE(0)) defaults(
        .clock_i(1'b0),.reset_n_i(1'b0),.job_valid_i(1'b0));
    initial begin
        if(defaults.u_source.g_fresh.u_entropy.WARMUP_CYCLES!=8 ||
           defaults.u_source.g_fresh.u_entropy.SAMPLE_DIV!=1) $fatal(1,"legacy defaults");
    end
    entropy_profile_case legacy(a);
    entropy_profile_case #(.W(4096),.D(1024)) promoted(b);
    initial begin wait(a && b); $display("PASS ENTROPY_PROFILES"); $finish; end
    initial begin #20000000; $fatal(1,"timeout"); end
endmodule
