// Filename: tb_keygen_aes_core.sv
// Modules: tb_keygen_aes_core
// Authors: Project contributors; see Git history.
// Date: 2026-10-13
// General Description: Checks keygen aes core behavior and reports failures.
// AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

`timescale 1ns/1ps
module tb_keygen_aes_core;
    reg clock_i=0; always #10 clock_i=~clock_i;
    reg reset_n_i=0, peers_ready_i=1, request_valid_i=0;
    wire request_ready_o;
    reg [1:0] request_profile_i=0;
    reg [31:0] request_id_i=0;
    reg generation_valid_i=0, generation_failed_i=0;
    reg [31:0] generation_data_i=0;
    wire generation_ready_o, result_valid_o;
    reg result_ready_i=0;
    wire [31:0] result_data_o, result_id_o;
    wire [2:0] result_component_o;
    wire [6:0] result_index_o;
    wire result_component_last_o, result_last_o;
    reg ownership_valid_i=0, ownership_accept_i=1;
    wire ownership_ready_o, result_discard_o, status_valid_o;
    reg status_ready_i=0;
    wire [3:0] status_code_o;
    wire [31:0] status_id_o;
    integer operations=0;
    reg [31:0] expected [0:7];
    keygen_aes_core dut (.*);

    task tick; @(posedge clock_i); #1; endtask
    task reset_core;
        @(negedge clock_i); reset_n_i=0;
        request_valid_i=0; generation_valid_i=0; generation_failed_i=0;
        result_ready_i=0; ownership_valid_i=0; status_ready_i=0; peers_ready_i=1;
        #1;
        if(request_ready_o || result_valid_o || status_valid_o || ownership_ready_o)
            $fatal(1,"transfer during reset");
        repeat(2) tick();
        @(negedge clock_i); reset_n_i=1;
        repeat(2) begin tick(); if(request_ready_o) $fatal(1,"early reset ready"); end
        wait(request_ready_o); #1;
        for(integer j=0;j<8;j++) if(dut.key_words_reg[j]!==0) $fatal(1,"reset scrub incomplete");
    endtask
    task start(input [1:0] profile, input [31:0] id);
        wait(request_ready_o);
        @(negedge clock_i); request_valid_i=1; request_profile_i=profile; request_id_i=id;
        tick();
        @(negedge clock_i); request_valid_i=0; request_id_i=~id; request_profile_i=3;
    endtask
    task send_words(input integer count, input bit equal_words);
        for(integer j=0;j<count;j++) begin
            repeat($urandom_range(0,3)) tick();
            @(negedge clock_i);
            expected[j]=equal_words ? 32'h01020304 : (32'h01234567 ^ (32'h10203040*j));
            generation_data_i=expected[j]; generation_valid_i=1;
            if(!generation_ready_o) $fatal(1,"not ready for word %0d",j);
            tick();
            @(negedge clock_i); generation_valid_i=0;
        end
        if(generation_ready_o) $fatal(1,"extra generation word accepted");
    endtask
    task drain(input integer count, input [31:0] id);
        for(integer j=0;j<count;j++) begin
            wait(result_valid_o);
            repeat($urandom_range(1,4)) begin
                tick();
                if(!result_valid_o || result_data_o!==expected[j] || result_index_o!==j ||
                   result_component_o!==1 || result_id_o!==id ||
                   result_last_o!==(j==count-1) || result_component_last_o!==result_last_o)
                    $fatal(1,"result mismatch/stall instability at%0d",j);
                if(status_valid_o || ownership_ready_o) $fatal(1,"early completion");
            end
            @(negedge clock_i); result_ready_i=1;
            tick();
            @(negedge clock_i); result_ready_i=0;
        end
        if(result_valid_o || !ownership_ready_o || status_valid_o) $fatal(1,"handoff state");
    endtask
    task finish(input bit accept, input [3:0] code, input [31:0] id);
        repeat(3) begin tick(); if(status_valid_o) $fatal(1,"status before ownership"); end
        @(negedge clock_i); ownership_valid_i=1; ownership_accept_i=accept;
        tick();
        @(negedge clock_i); ownership_valid_i=0;
        wait(status_valid_o); #1;
        check_status(code,id);
    endtask
    task check_status(input [3:0] code, input [31:0] id);
        if(status_code_o!==code || status_id_o!==id) $fatal(1,"status mismatch %0d expected%0d",status_code_o,code);
        for(integer j=0;j<8;j++) if(dut.key_words_reg[j]!==0) $fatal(1,"secret survives terminal");
        repeat(3) begin
            tick();
            if(!status_valid_o || status_code_o!==code || status_id_o!==id || request_ready_o)
                $fatal(1,"terminal not held");
        end
        @(negedge clock_i); status_ready_i=1;
        tick();
        @(negedge clock_i); status_ready_i=0; generation_failed_i=0; peers_ready_i=1;
        operations=operations+1;
    endtask
    task full_job(input bit size256, input [31:0] id);
        start(size256 ? 1:0,id);
        send_words(size256 ? 8:4,id[0]);
        drain(size256 ? 8:4,id);
        finish(1,0,id);
    endtask
    initial begin
        reset_core();
        for(integer j=0;j<40;j++) full_job(j[0],j+1);
        start(0,101); send_words(4,0); drain(4,101); finish(0,5,101);
        start(3,102); wait(status_valid_o); #1; check_status(1,102);
        start(0,103);
        @(negedge clock_i); generation_failed_i=1; generation_valid_i=1;
        #1; if(generation_ready_o) $fatal(1,"accepted word with failure");
        tick(); generation_valid_i=0;
        wait(status_valid_o); #1; if(!result_discard_o) $fatal(1,"missing discard");
        check_status(2,103);
        start(0,104); send_words(4,0);
        @(negedge clock_i); peers_ready_i=0;
        #1; if(result_valid_o) $fatal(1,"result transferred on peer failure");
        wait(status_valid_o); #1; check_status(8,104);
        // Generation failure wins over simultaneous ownership acceptance.
        start(0,105); send_words(4,0); drain(4,105);
        @(negedge clock_i); ownership_valid_i=1; ownership_accept_i=1; generation_failed_i=1;
        #1; if(ownership_ready_o) $fatal(1,"ownership transferred on source failure");
        tick(); ownership_valid_i=0; wait(status_valid_o); #1; check_status(2,105);
        // Failures after accepted ownership cannot revoke successful completion.
        start(0,106); send_words(4,0); drain(4,106);
        @(negedge clock_i); ownership_valid_i=1; ownership_accept_i=1;
        tick(); @(negedge clock_i); ownership_valid_i=0; generation_failed_i=1; peers_ready_i=0;
        wait(status_valid_o); #1; check_status(0,106);
        // Reset in collect, transfer, decision, scrub, and held status.
        for(integer phase=0;phase<5;phase++) begin
            start(1,200+phase);
            if(phase>0) send_words(8,0);
            if(phase>1) drain(8,200+phase);
            if(phase>2) begin
                @(negedge clock_i); ownership_valid_i=1; ownership_accept_i=1;
                tick(); @(negedge clock_i); ownership_valid_i=0;
            end
            if(phase>3) wait(status_valid_o);
            reset_core(); full_job(0,300+phase);
        end
        @(negedge clock_i); peers_ready_i=0;
        #1; if(request_ready_o) $fatal(1,"admitted without peers");
        $display("PASS AES_CORE operations=%0d reset_phases=5 ordering/gaps/stalls/ownership/faults/scrub",operations);
        $finish;
    end
    initial begin #1000000; $fatal(1,"AES test timeout"); end
endmodule
