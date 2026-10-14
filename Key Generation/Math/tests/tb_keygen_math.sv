// Filename: tb_keygen_math.sv
// Modules: tb_keygen_math
// Authors: Project contributors; see Git history.
// Date: 2026-10-13
// General Description: Checks keygen math behavior and reports failures.
// AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

`timescale 1ns/1ps
module tb_keygen_math;
    reg clock_reg=0; always #5 clock_reg=~clock_reg;
    reg reset_n_reg=0, cmd_valid_reg=0, rsp_ready_reg=0;
    reg [7:0] op_reg=0;
    reg [31:0] arg0_reg=0,arg1_reg=0,arg2_reg=0,arg3_reg=0;
    wire cmd_ready,rsp_valid; wire [7:0] status;
    reg write_en_reg=0,read_en_reg=0;
    reg [11:0] address_reg=0; reg [31:0] data_reg=0;
    wire mem_ready,read_valid; wire [31:0] read_data;
`ifdef KEYGEN_MATH_SMALL
    keygen_math #(.MAX_LIMBS(32)) dut(
`else
    keygen_math dut(
`endif
        .clock_i(clock_reg),.reset_n_i(reset_n_reg),
        .cmd_valid_i(cmd_valid_reg),.cmd_ready_o(cmd_ready),.cmd_op_i(op_reg),
        .cmd_arg0_i(arg0_reg),.cmd_arg1_i(arg1_reg),.cmd_arg2_i(arg2_reg),.cmd_arg3_i(arg3_reg),
        .rsp_valid_o(rsp_valid),.rsp_ready_i(rsp_ready_reg),.rsp_status_o(status),
        .mem_write_en_i(write_en_reg),.mem_read_en_i(read_en_reg),
        .mem_address_i(address_reg),.mem_write_data_i(data_reg),.mem_ready_o(mem_ready),
        .mem_read_valid_o(read_valid),.mem_read_data_o(read_data)
    );
    task write_word(input integer address,input reg[31:0] value);
        begin
            while(!mem_ready) @(negedge clock_reg);
            address_reg=address;data_reg=value;write_en_reg=1;
            @(negedge clock_reg);write_en_reg=0;
        end
    endtask
    task read_word(input integer address,output reg[31:0] value);
        begin
            while(!mem_ready) @(negedge clock_reg);
            address_reg=address;read_en_reg=1;
            @(negedge clock_reg);
            if(!read_valid) $fatal(1,"Missing private read response");
            value=read_data;read_en_reg=0;
        end
    endtask
    task command(input reg[7:0] op,input integer a0,a1,a2,a3,input reg[7:0] expected_status);
        integer cycles;
        begin
            while(!cmd_ready) @(negedge clock_reg);
            op_reg=op;arg0_reg=a0;arg1_reg=a1;arg2_reg=a2;arg3_reg=a3;cmd_valid_reg=1;
            @(negedge clock_reg);cmd_valid_reg=0;cycles=0;
            while(!rsp_valid) begin
                @(negedge clock_reg);cycles=cycles+1;
                if(cycles>40000000) $fatal(1,"Timeout opcode=%h",op);
            end
            if(status!==expected_status) $fatal(1,"Status op=%h got=%h expected=%h",op,status,expected_status);
            repeat(3) begin
                @(negedge clock_reg);
                if(!rsp_valid || status!==expected_status || cmd_ready || mem_ready)
                    $fatal(1,"Response must hold until accepted");
            end
            rsp_ready_reg=1;@(negedge clock_reg);rsp_ready_reg=0;
            $display("COMMAND op=%h words=%0d cycles=%0d",op,a3,cycles);
        end
    endtask
    integer fd,scan,cases,c,kind,n,en,i,count;
    reg[31:0] value,expected;
    initial begin
        repeat(2) @(negedge clock_reg);reset_n_reg=1;
        while(!cmd_ready) @(negedge clock_reg);
        if(read_data!==0)$fatal(1,"RAM output latch was not refreshed after scrub");
        read_word(4095,value);if(value!==0)$fatal(1,"Reset sweep incomplete");
        command(8'hff,0,0,0,1,1);
        command(8'h01,4095,0,0,2,2);
        command(8'h12,384,128,256,0,4);
        write_word(128,32'hffffffff);write_word(129,32'h7fffffff);
        write_word(256,1);write_word(257,32'h80000000);
        command(8'h03,384,128,256,2,8'h10);
        command(8'h04,384,128,256,2,0);
        read_word(384,value);if(value!==0)$fatal(1,"ADD low carry");
        read_word(385,value);if(value!==0)$fatal(1,"ADD modulo overflow");
        command(8'h05,384,128,256,2,0);
        read_word(384,value);if(value!==32'hfffffffe)$fatal(1,"SUB low");
        read_word(385,value);if(value!==32'hffffffff)$fatal(1,"SUB borrow");
        command(8'h06,384,128,0,2,0);
        read_word(384,value);if(value!==32'hffffffff)$fatal(1,"SHIFT low");
        read_word(385,value);if(value!==32'h3fffffff)$fatal(1,"SHIFT high");
        command(8'h01,129,128,0,2,0);
        read_word(129,value);if(value!==32'hffffffff)$fatal(1,"Overlapping COPY low");
        read_word(130,value);if(value!==32'h7fffffff)$fatal(1,"Overlapping COPY high");
        command(8'h02,129,0,0,2,0);
        read_word(129,value);if(value!==0)$fatal(1,"ZERO low");
        read_word(130,value);if(value!==0)$fatal(1,"ZERO high");
        command(8'h11,0,0,2,0,3);
        write_word(0,2);command(8'h11,0,1024,1,0,4);
        fd=$fopen("vectors.txt","r");if(!fd)$fatal(1,"Missing vector file");
        scan=$fscanf(fd,"%d",cases);
        for(c=0;c<cases;c=c+1)begin
            scan=$fscanf(fd,"%d %d %d",kind,n,en);
            for(i=0;i<n;i=i+1)begin scan=$fscanf(fd,"%h",value);write_word(i,value);end
            for(i=0;i<n;i=i+1)begin scan=$fscanf(fd,"%h",value);write_word(128+i,value);end
            for(i=0;i<(kind==1?en:n);i=i+1)begin scan=$fscanf(fd,"%h",value);write_word(256+i,value);end
            if(kind!=2)command(8'h11,0,1024,n,0,0);
            if(kind==0)command(8'h12,384,128,256,0,0);
            else if(kind==1)command(8'h13,384,128,256,en,0);
            else command(8'h10,384,128,256,n,0);
            count=kind==2?2*n:n;
            for(i=0;i<count;i=i+1)begin
                scan=$fscanf(fd,"%h",expected);read_word(384+i,value);
                if(value!==expected)$fatal(1,"Case=%0d kind=%0d n=%0d limb=%0d expected=%h actual=%h",c,kind,n,i,expected,value);
            end
            $display("PASS case %0d kind=%0d limbs=%0d",c,kind,n);
        end
        $fclose(fd);
        // A normal base equal to the modulus is rejected before result writes.
        command(8'h01,128,0,0,n,0);
        write_word(384,32'hacced123);
        command(8'h13,384,128,256,1,4);
        read_word(384,value);if(value!==32'hacced123)$fatal(1,"Rejected command wrote destination");
        command(8'h02,128,0,0,n,0);
        // Reset during a live operation must sweep old operands before ready.
        op_reg=8'h13;arg0_reg=384;arg1_reg=128;arg2_reg=256;arg3_reg=1;cmd_valid_reg=1;
        @(negedge clock_reg);cmd_valid_reg=0;repeat(20)@(negedge clock_reg);
        reset_n_reg=0;@(negedge clock_reg);reset_n_reg=1;
        while(!cmd_ready)@(negedge clock_reg);
        if(read_data!==0)$fatal(1,"Reset left old RAM output latch value");
        for(i=0;i<4096;i=i+1)begin read_word(i,value);if(value!==0)$fatal(1,"Scrub failed address=%0d",i);end
        command(8'h12,384,128,256,0,4);
        $display("PASS math: %0d independent bigint cases and full reset scrub",cases);$finish;
    end
endmodule
