// Filename: tb_keygen_math_small.sv
// Modules: tb_keygen_math_small
// Authors: Project contributors; see Git history.
// Date: 2026-10-13
// General Description: Checks keygen math small behavior and reports failures.
// AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

`timescale 1ns/1ps
module tb_keygen_math_small;
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

        end
    endtask
    localparam CASES=10771;
    reg [175:0] vectors[0:CASES-1];
    integer cases,c,kind,i;
    reg [31:0] modulus,a,b,expected_low,expected_high,value;
    reg [7:0] expected_status;
    initial begin
        repeat(2)@(negedge clock_reg);reset_n_reg=1;
        while(!cmd_ready)@(negedge clock_reg);
        // Carry/borrow must propagate between real32-bit limbs.
        write_word(128,32'hffffffff);write_word(129,32'hffffffff);
        write_word(256,1);write_word(257,0);
        command(8'h04,384,128,256,2,0);
        read_word(384,value);if(value!==0)$fatal(1,"ADD carry low");
        read_word(385,value);if(value!==0)$fatal(1,"ADD carry high overflow");
        write_word(128,0);write_word(129,0);
        command(8'h05,384,128,256,2,0);
        read_word(384,value);if(value!==32'hffffffff)$fatal(1,"SUB borrow low");
        read_word(385,value);if(value!==32'hffffffff)$fatal(1,"SUB borrow high");
        write_word(128,0);write_word(129,1);
        command(8'h06,384,128,0,2,0);
        read_word(384,value);if(value!==32'h80000000)$fatal(1,"SHR cross limb");
        read_word(385,value);if(value!==0)$fatal(1,"SHR high");
        $readmemh("small_vectors.hex",vectors);cases=CASES;
        for(c=0;c<cases;c++)begin
            if($isunknown(vectors[c]))$fatal(1,"missing vector%0d",c);
            {modulus,a,b,expected_low,expected_high,expected_status}=vectors[c][167:0];
            kind={24'd0,vectors[c][175:168]};
            write_word(0,modulus);write_word(128,a);write_word(256,b);
            write_word(384,32'hbadbad01);write_word(385,32'hbadbad02);
            if(kind<=1)command(8'h11,0,1024,1,0,0);
            case(kind)
                0:command(8'h12,384,128,256,0,expected_status);
                1:command(8'h13,384,128,256,1,expected_status);
                2:command(8'h10,384,128,256,1,expected_status);
                3:command(8'h04,384,128,256,1,expected_status);
                4:command(8'h05,384,128,256,1,expected_status);
                5:command(8'h03,384,128,256,1,expected_status);
                6:command(8'h06,384,128,0,1,expected_status);
                7:command(8'h01,384,128,0,1,expected_status);
                8:command(8'h02,384,0,0,1,expected_status);
                default:$fatal(1,"invalid kind");
            endcase
            read_word(384,value);if(value!==expected_low)$fatal(1,"case%0d kind%0d n%0d a%0d b%0d low got%h expected%h",c,kind,modulus,a,b,value,expected_low);
            read_word(385,value);if(value!==expected_high)$fatal(1,"case%0d high got%h expected%h",c,value,expected_high);
            if(c%1000==0)$display("SMALL progress case=%0d/%0d",c,cases);
        end

        // Reset destroys the last small-domain state including the output latch.
        reset_n_reg=0;@(negedge clock_reg);reset_n_reg=1;
        while(!cmd_ready)@(negedge clock_reg);
        if(read_data!==0)$fatal(1,"RAM output latch retained data");
        for(i=0;i<4096;i++)begin read_word(i,value);if(value!==0)$fatal(1,"RAM cleanup address%0d",i);end
        $display("PASS SMALL_MATH cases=%0d carry_borrow_shift=3 full_scrub=4096",cases);$finish;
    end
    initial begin #2000000000;$fatal(1,"small math timeout");end
endmodule
