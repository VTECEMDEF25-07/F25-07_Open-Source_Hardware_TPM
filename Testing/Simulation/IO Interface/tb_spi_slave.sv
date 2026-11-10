`timescale 1ns/1ps
module tb_spi_slave;
    reg clock=0; always #10 clock=~clock;
    reg reset_n=0, sck=0, cs_n=1, mosi=0;
    wire miso, selected_n, rx_valid, tx_request, tx_received;
    wire [7:0] rx_data;
    reg tx_valid=0;
    reg [7:0] tx_data=0;
    realtime half_period=500;
    integer requests=0, received=0, delay_count=0;
    integer expected_count=0, ack_count=0, byte_index, rate, phase;
    reg [7:0] expected_rx[0:1023];
    reg [7:0] observed;
    reg previous_rx_valid=0;
    spi_slave dut (
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
        begin cs_n=1;sck=0;#207;received=0;@(negedge clock);#(phase);cs_n=0;#207;end
    endtask
    // Exact PTP CS setup/hold/high minima, without the slow bring-up gaps.
    task transfer_short(input [7:0] value, output [7:0] result, input bit first_byte);
        integer index;
        begin
            for(index=7;index>=0;index=index-1)begin
                mosi=value[index];
                if(first_byte && index==7) #5; else #(half_period);
                sck=1;#1;result[index]=miso;#(half_period-1);sck=0;
            end
        end
    endtask
    task end_frame;
        begin
            #100;cs_n=1;#207;
            if(rx_valid || tx_received || tx_request || !selected_n || miso!==1'bz)
                $fatal(1,"deselect did not return clean idle");
        end
    endtask
    initial begin #100000000;$fatal(1,"serializer timeout");end
    initial begin
        #47;reset_n=1;#200;
        for(rate=0;rate<7;rate=rate+1)begin
          for(phase=0;phase<(rate>=2?20:1);phase=phase+1)begin
            #(phase+1);
            case(rate)
              0:half_period=5000;1:half_period=1000;2:half_period=500;
              3:half_period=50;4:half_period=33.333333;
              5:half_period=20.833333;6:half_period=16.666667;
            endcase
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
        end
        // Tight consecutive frames: final RX bytes must survive immediate CS
        // release and the next frame's first header. Keep a cumulative queue
        // because last-byte CDC delivery can overlap the following CS gap.
        expected_count=0;received=0;cs_n=1;sck=0;#500;
        for(rate=0;rate<2;rate=rate+1)begin
            half_period=rate==0?20.833333:16.666667;
            for(byte_index=0;byte_index<16;byte_index=byte_index+1)begin
                expected_rx[expected_count]=8'h53+byte_index;
                expected_rx[expected_count+1]=8'hb0-byte_index;
                expected_count=expected_count+2;
                cs_n=0;
                transfer_short(expected_rx[expected_count-2],observed,1);
                if(observed!==0)$fatal(1,"short-CS first TX byte");
                transfer_short(expected_rx[expected_count-1],observed,0);
                if(observed!==reply(0))$fatal(1,"short-CS reply rate=%0d data=%h",rate,observed);
                #5;cs_n=1;#50;
            end
        end
        #300;if(received!=expected_count)$fatal(1,"short-CS last byte lost");
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
        $display("PASS COMMON SPI: mode0 100k/500k/1M/10M/15M/24M/30MHz, 20 asynchronous phase offsets, full duplex, back-to-back bytes, delayed TX ack, high-clock pause, CS partial abort, mid-bit reset and replay");
        $finish;
    end
endmodule
