`timescale 1ns/1ps
module tb_de25_spi;
    reg clock=0; always #10 clock=~clock;
    reg reset_n=0, sck=0, cs_n=1, mosi=0;
    wire miso, selected_n, rx_valid, tx_request, tx_received;
    wire [7:0] rx_data;
    reg tx_valid=0;
    reg [7:0] tx_data=0;
    integer half_period=500, requests=0, received=0, delay_count=0;
    integer expected_count=0, ack_count=0, byte_index, rate;
    reg [7:0] expected_rx[0:15];
    reg [7:0] observed;
    reg previous_rx_valid=0;
    de25_spi_slave dut (
        .clock_i(clock), .reset_n_i(reset_n),
        .rx_valid_o(rx_valid), .rx_data_o(rx_data),
        .tx_valid_i(tx_valid), .tx_data_i(tx_data),
        .tx_request_o(tx_request), .tx_received_o(tx_received),
        .spi_clock_i(sck), .spi_mosi_i(mosi), .spi_cs_n_i(cs_n),
        .spi_miso_o(miso), .chip_select_n_o(selected_n)
    );
    function [7:0] reply(input integer index);
        reply=8'ha5 ^ (index*37);
    endfunction
    // Deliberately delay the producer; then hold valid/data until acknowledged.
    always @(posedge clock) begin
        if(!reset_n || cs_n) begin
            tx_valid<=0;tx_data<=0;delay_count<=0;requests<=0;ack_count<=0;
        end else begin
            if(tx_request) begin
                if(tx_valid || delay_count) $fatal(1,"overlapping request");
                tx_data<=reply(requests);requests<=requests+1;delay_count<=3;
            end
            if(delay_count>0) begin
                delay_count<=delay_count-1;
                if(delay_count==1)tx_valid<=1;
            end
            if(tx_valid && tx_received)begin tx_valid<=0;ack_count<=ack_count+1;end
        end
        #1;
        if(rx_valid) begin
            if(previous_rx_valid)$fatal(1,"RX_valid must be one system clock");
            if(received>=expected_count || rx_data!==expected_rx[received])
                $fatal(1,"RX mismatch index=%0d data=%h",received,rx_data);
            received=received+1;
        end
        previous_rx_valid=rx_valid;
    end
    task transfer(input [7:0] value, output [7:0] result, input integer pause_bit);
        integer bit_index;
        begin
            for(bit_index=7;bit_index>=0;bit_index=bit_index-1)begin
                mosi=value[bit_index];#(half_period);sck=1;#1;
                result[bit_index]=miso;
                // A stopped high clock must not advance the shifter.
                if(bit_index==pause_bit)begin
                    #3400;if(miso!==result[bit_index])$fatal(1,"MISO changed with SCK stopped high");
                end
                #(half_period-1);sck=0;
            end
        end
    endtask
    task begin_frame;
        begin cs_n=1;sck=0;#207;received=0;cs_n=0;#207;end
    endtask
    task end_frame;
        begin
            #100;cs_n=1;#207;
            if(rx_valid || tx_received || tx_request || !selected_n || miso!==0)
                $fatal(1,"deselect did not return clean idle");
        end
    endtask
    initial begin #10000000;$fatal(1,"serializer timeout");end
    initial begin
        #47;reset_n=1;#200;
        for(rate=0;rate<3;rate=rate+1)begin
            half_period=rate==0?5000:rate==1?1000:500;
            expected_count=6;
            for(byte_index=0;byte_index<6;byte_index=byte_index+1)
                expected_rx[byte_index]=8'h36+byte_index*19;
            begin_frame();
            for(byte_index=0;byte_index<6;byte_index=byte_index+1)begin
                transfer(expected_rx[byte_index],observed,byte_index==2?4:-1);
                if(observed!==(byte_index==0?8'h00:reply(byte_index-1)))
                    $fatal(1,"TX byte phase rate=%0d index=%0d data=%h",rate,byte_index,observed);
            end
            #100;
            if(received!=6 || requests!=6 || ack_count!=6)$fatal(1,"byte/request/ack count");
            end_frame();
        end
        // Discard three partial bits, even when a next-byte reply was accepted.
        expected_count=0;begin_frame();
        repeat(3)begin mosi=1;#500;sck=1;#500;sck=0;end
        end_frame();if(received)$fatal(1,"partial byte leaked after CS abort");
        // Reset while SCK is high halfway through a byte.
        begin_frame();mosi=1;#500;sck=1;#170;reset_n=0;#71;
        if(rx_valid || tx_request || tx_received || miso!==0)$fatal(1,"reset outputs");
        cs_n=1;sck=0;#200;reset_n=1;#200;
        expected_count=2;expected_rx[0]=8'hc3;expected_rx[1]=8'h7e;begin_frame();
        transfer(8'hc3,observed,-1);if(observed!==0)$fatal(1,"stale TX after reset");
        transfer(8'h7e,observed,-1);if(observed!==reply(0))$fatal(1,"replay TX");
        #100;if(received!=2)$fatal(1,"reset replay RX count");end_frame();
        $display("PASS DE25 SPI: mode0 100k/500k/1MHz, full duplex, back-to-back bytes, delayed TX ack, high-clock pause, CS partial abort, mid-bit reset and replay");
        $finish;
    end
endmodule
