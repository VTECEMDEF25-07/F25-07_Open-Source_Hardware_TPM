// Filename: tb_keygen_full.sv
// Modules: tb_keygen_full
// Authors: Project contributors; see Git history.
// Date: 2026-10-13
// General Description: Checks keygen full behavior and reports failures.
// AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

`timescale 1ns/1ps
module tb_keygen_full;
`ifdef KEYGEN_SOFTCORE
    localparam SOFTCORE=1;
`else
    localparam SOFTCORE=0;
`endif
    reg clock_i=0; always #10 clock_i=~clock_i;
    reg reset_n_i=0,peers_ready_i=1,request_valid_i=0;
    wire request_ready_o;
    reg [1:0] request_profile_i=2;
    reg [31:0] request_id_i=32'h543210ab;
    wire generation_valid_i,generation_ready_o;
    wire [31:0] generation_data_i;
    wire generation_failed_i;
    wire result_valid_o;
    reg result_ready_i=1;
    wire [31:0] result_data_o,result_id_o;
    wire [2:0] result_component_o;
    wire [6:0] result_index_o;
    wire result_component_last_o,result_last_o;
    reg ownership_valid_i=0,ownership_accept_i=1;
    wire ownership_ready_o,result_discard_o,status_valid_o;
    reg status_ready_i=0;
    wire [3:0] status_code_o;
    wire [31:0] status_id_o;
    reg source_start=0;wire source_ready;
    reg [255:0] seed=1;
    reg directed=0;
    reg stalls=0;
    reg offered_reg=0;
    reg [31:0] directed_words[0:383];
    integer directed_index=0;
    wire source_valid,source_failed;
    wire [31:0] source_data;
    reg [31:0] expected[0:128];
    integer received=0,words=0,seed_id=1,expected_count=0;
    reg [63:0] cycles=0,start_cycle=0;
    reg result_stalled_reg=0,source_stalled_reg=0;
    reg [75:0] stalled_result_reg=0;
    reg [31:0] stalled_source_reg=0;
    string expected_file;
    string stimulus_file;
    wire offer_en=!stalls || offered_reg;
    assign generation_valid_i=offer_en && (directed ? (directed_index<384) : source_valid);
    assign generation_data_i=directed ? directed_words[directed_index] : source_data;
    assign generation_failed_i=directed ? 1'b0 : source_failed;
    keygen_core #(.RSA_SOFTCORE(SOFTCORE)) dut(.*);
    keygen_test_source source(
        .clock_i(clock_i),.reset_n_i(reset_n_i),.start_valid_i(source_start),.start_ready_o(source_ready),
        .seed_i(seed),.word_valid_o(source_valid),.word_ready_i(generation_ready_o && !directed && offer_en),
        .data_o(source_data),.failed_o(source_failed));
    always @(negedge clock_i) if(stalls) result_ready_i=(cycles%7<4);
    always @(posedge clock_i) begin
        cycles<=cycles+1;
        if(reset_n_i)begin
            if(result_stalled_reg && (!result_valid_o ||
               {result_data_o,result_component_o,result_index_o,result_component_last_o,result_last_o,result_id_o}!==stalled_result_reg))
                $fatal(1,"result changed under backpressure");
            if(source_stalled_reg && (!generation_valid_i || generation_data_i!==stalled_source_reg))
                $fatal(1,"test source violated ready/valid hold");
        end
        result_stalled_reg<=reset_n_i && result_valid_o && !result_ready_i;
        source_stalled_reg<=reset_n_i && generation_valid_i && !generation_ready_o;
        stalled_result_reg<={result_data_o,result_component_o,result_index_o,result_component_last_o,result_last_o,result_id_o};
        stalled_source_reg<=generation_data_i;
        // Delay a new offer, but never withdraw valid while the core stalls.
        if(!reset_n_i) offered_reg<=0;
        else if(generation_valid_i && generation_ready_o) offered_reg<=0;
        else if(!offered_reg && cycles%11<7) offered_reg<=1;
        if(generation_valid_i&&generation_ready_o)begin
            words<=words+1;
            if(directed)directed_index<=directed_index+1;
        end
        if(result_valid_o&&result_ready_i)begin
            if(received>=129 || result_data_o!==expected[received])
                $fatal(1,"key mismatch word%0d got%h expected%h",received,result_data_o,expected[received]);
            if(result_id_o!==32'h543210ab)$fatal(1,"operation ID not captured");
            if(result_component_o!==((received<64)?2:((received==64)?3:((received<97)?4:5))))
                $fatal(1,"component mismatch");
            if(result_index_o!==((received<64)?received:((received==64)?0:((received<97)?received-65:received-97))))
                $fatal(1,"index mismatch");
            if(result_last_o!==(received==128))$fatal(1,"last mismatch");
            if(result_component_last_o!==((received==63)||(received==64)||(received==96)||(received==128)))
                $fatal(1,"component last mismatch");
            received<=received+1;
        end
        if(cycles%10000000==0 && cycles>0)begin
            $display("PROGRESS cycles=%0d words=%0d received=%0d state=%0d",cycles,words,received,dut.state_reg);
            $fflush();
        end
        if(status_valid_o && status_code_o!=0)$fatal(1,"core error%0d words=%0d",status_code_o,words);
        if(cycles>64'd9000000000)$fatal(1,"180second hardware deadline exceeded");
    end
    task tick;@(posedge clock_i);#1;endtask
    initial begin
        if($value$plusargs("SEED=%d",seed_id))begin end
        stalls=$test$plusargs("STALLS");
        if(!$value$plusargs("EXPECTED=%s",expected_file))$fatal(1,"expected fixture required");
        if(!$value$plusargs("WORDS=%d",expected_count))$fatal(1,"word count required");
        if($test$plusargs("DIRECTED"))begin
            directed=1;
            if(!$value$plusargs("STIMULUS=%s",stimulus_file))$fatal(1,"directed stimulus required");
            $readmemh(stimulus_file,directed_words);
        end
        seed=seed_id;$readmemh(expected_file,expected);
        repeat(3)tick();@(negedge clock_i);reset_n_i=1;
        wait(source_ready);@(negedge clock_i);source_start=1;tick();@(negedge clock_i);source_start=0;
        wait(request_ready_o);@(negedge clock_i);request_valid_i=1;start_cycle=cycles;
        tick();@(negedge clock_i);request_valid_i=0;request_id_i=0;request_profile_i=3;
        wait(received==129);repeat(stalls ? 37 : 3)tick();
        if(status_valid_o)$fatal(1,"success before ownership");
        wait(ownership_ready_o);@(negedge clock_i);ownership_valid_i=1;
        tick();@(negedge clock_i);ownership_valid_i=0;
        wait(status_valid_o);#1;
        if(words!=expected_count)$fatal(1,"stream consumption differs %0d expected%0d",words,expected_count);
        if(status_id_o!==32'h543210ab)$fatal(1,"status ID");
        repeat(3)tick();if(!status_valid_o)$fatal(1,"status not held");
        $display("PASS FULL_RSA seed=%0d softcore=%0d words=%0d cycles=%0d",seed_id,SOFTCORE,words,cycles-start_cycle);
        @(negedge clock_i);status_ready_i=1;tick();
        if(!request_ready_o)$fatal(1,"not reusable after cleanup");
        $finish;
    end
endmodule
