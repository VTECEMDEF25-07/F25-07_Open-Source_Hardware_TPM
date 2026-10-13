`timescale 1ns/1ps
module tb_keygen_demo;
    reg clock_i=0; always #10 clock_i=~clock_i;
    reg reset_n_i=0,spi_clock_i=0,spi_cs_n_i=1,spi_mosi_i=0;
    wire spi_miso_o,interrupt_n_o;
    reg [63:0] response;
    reg [31:0] value, meta;
    integer i, polls;
    keygen_demo_system dut (.temperatures_i(32'h002a0020),.fan_status_i(32'h03000fa0),.*);
    task frame(input [63:0] command,input integer bits,output [63:0] answer);
        integer b;
        begin
            answer=0;spi_cs_n_i=0;#200;
            for(b=63;b>=64-bits;b=b-1) begin
                spi_mosi_i=command[b];#250;spi_clock_i=1;
                #100;answer={answer[62:0],spi_miso_o};#400;spi_clock_i=0;#250;
            end
            spi_cs_n_i=1;#200;
        end
    endtask
    task write_reg(input [7:0] address,input [31:0] data);
        begin frame({8'd2,address,16'd0,data},64,response);if(response[63:56]!==8'ha5)$fatal(1,"signature");end
    endtask
    task read_reg(input [7:0] address,output [31:0] data);
        begin frame({8'd1,address,48'd0},64,response);if(response[63:32]!==32'ha5000000)$fatal(1,"read signature %h",response);data=response[31:0];end
    endtask
    task ready;
        begin
            polls=0;read_reg(3,value);
            while(!value[0] && polls<100) begin read_reg(3,value);polls=polls+1;end
            if(!value[0])$fatal(1,"ready timeout");
        end
    endtask
    task done;
        begin
            polls=0;read_reg(3,value);
            while(!value[3] && polls<100) begin read_reg(3,value);polls=polls+1;end
            if(!value[3])$fatal(1,"status timeout");
        end
    endtask
    initial begin
        #100;reset_n_i=1;ready();
        read_reg(13,value);if(value!==32'h002a0020)$fatal(1,"temperatures");
        read_reg(14,value);if(value!==4000)$fatal(1,"fan RPM");
        read_reg(15,value);if(value!==32'h0300)$fatal(1,"fan status");
        read_reg(0,value);if(value!==32'h4b473031)$fatal(1,"identity %h",value);
        read_reg(1,value);if(value!==4)$fatal(1,"config");
        write_reg(63,32'h12345678);read_reg(63,value);if(value!==32'h12345678)$fatal(1,"scratch");
        frame({8'd2,8'd63,16'd0,32'hffffffff},47,response);
        read_reg(63,value);if(value!==32'h12345678)$fatal(1,"partial frame mutated register");
        frame({8'd2,8'd63,16'd1,32'hffffffff},64,response);
        read_reg(63,value);if(value!==32'h12345678)$fatal(1,"malformed header mutated register");
        write_reg(23,1);write_reg(4,1);write_reg(5,32'h1234);write_reg(11,4);write_reg(2,1);
        // Complete receiver must not bypass deliberately held ownership.
        repeat(3)read_reg(3,value);
        if(!value[2] || value[3])$fatal(1,"ownership hold");
        write_reg(5,32'h8765);write_reg(23,20);write_reg(2,1);
        if(dut.core.id_reg!==32'h1234)$fatal(1,"captured operation changed");
        write_reg(11,0);done();if(value[11:8]!==0 || interrupt_n_o!==0)$fatal(1,"success status");
        for(i=0;i<8;i=i+1)begin
            write_reg(8,i);read_reg(9,value);read_reg(10,meta);
            if(value!==dut.core.data_reg[i] || meta[31]!==1 || meta[2:0]!==1 || meta[9:3]!==i)
                $fatal(1,"AES receiver record");
        end
        write_reg(2,2);ready();read_reg(9,value);if(value!==0)$fatal(1,"ack failed to hide data");
        for(i=0;i<129;i=i+1)if(dut.receiver_data_reg[i]!==0 || dut.receiver_meta_reg[i]!==0)$fatal(1,"receiver scrub");
        write_reg(4,2);write_reg(2,1);done();
        for(i=0;i<129;i=i+1)begin
            write_reg(8,i);read_reg(9,value);read_reg(10,meta);
            if(value!==32'hca000000+i || !meta[31] || meta[11]!=(i==128))$fatal(1,"129-word receiver");
        end
        write_reg(2,2);ready();write_reg(11,1);write_reg(2,1);
        read_reg(3,value);if(!value[1] || value[2] || value[3])$fatal(1,"generation hold");
        write_reg(11,8);done();if(value[11:8]!==2 || value[2])$fatal(1,"failure discard");
        write_reg(2,2);ready();write_reg(11,2);write_reg(4,0);write_reg(2,1);
        read_reg(3,value);if(!value[1] || value[2])$fatal(1,"result hold");
        reset_n_i=0;#100;reset_n_i=1;ready();
        read_reg(63,value);if(value!==0)$fatal(1,"reset registers");
        $display("PASS demo SPI/receiver: identity, framing, capture, 129-word result, holds, discard, scrub and reset (model core only)");
        $finish;
    end
    initial begin #100000000;$fatal(1,"global timeout");end
endmodule
