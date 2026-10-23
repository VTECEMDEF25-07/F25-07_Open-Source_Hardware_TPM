// Filename: tb_keygen_demo_real.sv
// Modules: tb_keygen_demo_real
// Authors: Project contributors; see Git history.
// Date: 2026-10-13
// General Description: Checks keygen demo real behavior and reports failures.
// AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

`timescale 1ns/1ps
// Real portable core + real SHA source + SPI + receiver. No keygen_core model.
module tb_keygen_demo_real;
    reg clock_i=0;always #10 clock_i=~clock_i;
    reg reset_n_i=0,spi_clock_i=0,spi_cs_n_i=1,spi_mosi_i=0;
    wire spi_miso_o,interrupt_n_o;
    reg [63:0] response;
    reg [31:0] value,meta,held_word;
    reg [31:0] expected [0:7];
    string expected_path;
    integer i,polls;
    localparam [255:0] FINGERPRINT={4{64'h0123456789abcdef}};
    keygen_demo_system #(.BUILD_FINGERPRINT(FINGERPRINT)) dut (
        .fan_diagnostic_i(96'h123456789abcdef001234567),.temperatures_i(32'h002a0020),.fan_status_i(32'h07000fa0),.*
    );
    always @(negedge clock_i) if(reset_n_i) begin
        if(dut.source_reset_n !== (dut.state_reg!=0 && dut.state_reg!=1))
            $fatal(1,"source reset lifetime differs from accepted request lifetime");
    end
    reg generation_stalled_reg=0;
    reg [31:0] generation_word_reg;
    always @(posedge clock_i) begin
        if (!reset_n_i || !dut.source_reset_n) generation_stalled_reg<=0;
        else begin
            // The final result handshake puts both core and receiver into
            // ownership on the same edge; only an explicit fault can cancel it.
            if (dut.ownership_valid && !dut.core_ownership_ready && !dut.core_discard &&
                !dut.source_failed && !dut.test_control_reg[3] && !dut.receiver_scrub_reg)
                $fatal(1,"ownership offer stalled without a cancellation fault");
            if (generation_stalled_reg && (!dut.generation_valid || dut.source_data!==generation_word_reg))
                $fatal(1,"source offer withdrawn/changed before acceptance");
            generation_stalled_reg<=dut.generation_valid && !dut.core_generation_ready;
            generation_word_reg<=dut.source_data;
        end
    end
    task frame(input [63:0] command,output [63:0] answer);
        integer b;
        begin
            answer=0;spi_cs_n_i=0;#200;
            for(b=63;b>=0;b=b-1)begin
                spi_mosi_i=command[b];#250;spi_clock_i=1;
                #100;answer={answer[62:0],spi_miso_o};#400;spi_clock_i=0;#250;
            end
            spi_cs_n_i=1;#200;
        end
    endtask
    task write_reg(input [7:0] address,input [31:0] data);
        begin frame({8'd2,address,16'd0,data},response);if(response[63:32]!==32'ha5000000)$fatal(1,"write framing");end
    endtask
    task read_reg(input [7:0] address,output [31:0] data);
        begin frame({8'd1,address,48'd0},response);if(response[63:32]!==32'ha5000000)$fatal(1,"read framing");data=response[31:0];end
    endtask
    task await_status(input [31:0] mask);
        begin
            polls=0;read_reg(3,value);
            while((value&mask)==0 && polls<200)begin read_reg(3,value);polls=polls+1;end
            if((value&mask)==0)$fatal(1,"status timeout mask=%h got=%h",mask,value);
        end
    endtask
    task start_key(input [1:0] profile,input [3:0] controls);
        begin
            await_status(1);write_reg(23,1);write_reg(4,{30'b0,profile});
            write_reg(5,32'h12345678);write_reg(11,{28'b0,controls});write_reg(2,1);
        end
    endtask
    task check_aes(input integer count);
        begin
            for(i=0;i<count;i=i+1)begin
                write_reg(8,i);read_reg(9,value);read_reg(10,meta);
                if(value!==expected[i])$fatal(1,"independent AES oracle word%0d got%h expected%h",i,value,expected[i]);
                if(meta!== (32'h80000001|(i<<3)|((i==count-1)?32'hc00:0)))$fatal(1,"AES metadata %h",meta);
            end
        end
    endtask
    task acknowledge;
        begin
            write_reg(2,2);await_status(1);
            read_reg(9,value);read_reg(10,meta);
            if(value!==0 || meta!==0)$fatal(1,"ack exposed old result");
            for(i=0;i<129;i=i+1)if(dut.receiver_data_reg[i]!==0 || dut.receiver_meta_reg[i]!==0)$fatal(1,"receiver not scrubbed");
        end
    endtask
    task gray_reset;
        begin
            reset_n_i=0;#200;reset_n_i=1;await_status(1);
            read_reg(9,value);read_reg(10,meta);if(value!==0 || meta!==0)$fatal(1,"reset exposed old result");
            read_reg(23,value);if(value!==0)$fatal(1,"reset seed not cleared");
        end
    endtask
    task successful(input integer count);
        begin
            await_status(8);if(value[11:8]!==0 || !value[2] || interrupt_n_o!==0)$fatal(1,"success status %h",value);
            check_aes(count);acknowledge();
        end
    endtask
    initial begin
        if(!$value$plusargs("EXPECTED=%s",expected_path))$fatal(1,"missing independent expected data");
        $readmemh(expected_path,expected);
        #100;reset_n_i=1;await_status(1);
        read_reg(0,value);if(value!==32'h4b473031)$fatal(1,"ID");
        read_reg(1,value);if(value!==4)$fatal(1,"controller config");
        read_reg(32,value);if(value!==32'h01234567)$fatal(1,"fan diagnostic32");
        read_reg(33,value);if(value!==32'h9abcdef0)$fatal(1,"fan diagnostic33");
        read_reg(34,value);if(value!==32'h12345678)$fatal(1,"fan diagnostic34");
        read_reg(15,value);if(value!==32'h700)$fatal(1,"fan failsafe bit10 mapping");
        for(i=0;i<8;i=i+1)begin
            read_reg(24+i,value);if(value!==FINGERPRINT[255-i*32 -:32])$fatal(1,"build fingerprint word");
        end
        start_key(0,1);await_status(2);
        repeat(3)read_reg(3,value);
        if(value[3:2]!==0)$fatal(1,"generation stall bypassed");
        write_reg(11,0);successful(4);
        start_key(1,6);polls=0;read_reg(12,value);
        while(!value[3] && polls<200)begin read_reg(12,value);polls=polls+1;end
        if(!value[3])$fatal(1,"result stall not reached");
        held_word=dut.core_result_data;
        repeat(3)begin read_reg(3,value);if(!dut.core_result_valid || dut.core_result_data!==held_word || value[3:2]!==0)$fatal(1,"result hold unstable");end
        // Shadow writes and a second START must not alter the captured key request.
        write_reg(4,0);write_reg(23,20);write_reg(5,32'hbad);write_reg(2,1);
        write_reg(11,4);await_status(4);if(value[3])$fatal(1,"ownership bypassed");
        check_aes(8);write_reg(11,0);await_status(8);
        if(dut.core_status_id!==32'h12345678)$fatal(1,"captured request ID changed");
        successful(8);
        start_key(0,1);await_status(2);write_reg(11,9);await_status(8);
        if(value[11:8]!==2 || value[2])$fatal(1,"AES source failure %h",value);
        acknowledge();start_key(0,0);successful(4);
        start_key(1,2);await_status(2);gray_reset();start_key(0,0);successful(4);
        // Exercise actual RTL RSA request/abort path without an expensive key search.
        start_key(2,0);await_status(2);
        repeat(4)begin write_reg(11,1);read_reg(3,value);write_reg(11,0);end
        gray_reset();
        start_key(2,1);await_status(2);write_reg(11,9);await_status(8);
        if(value[11:8]!==2 || value[2])$fatal(1,"RSA source failure %h",value);
        acknowledge();start_key(1,0);successful(8);
        $display("PASS REAL_SPI_CORE controller=rtl: hashlib AES128/AES256, source/result/ownership stalls, capture, error, reset and RSA abort/recovery");
        $finish;
    end
    initial begin #200000000;$fatal(1,"global timeout");end
endmodule
