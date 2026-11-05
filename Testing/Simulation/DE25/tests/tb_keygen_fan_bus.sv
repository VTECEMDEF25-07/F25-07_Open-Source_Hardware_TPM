// Author: Aaron Grossman
// Serial I2C normal-operation test for the unmodified Terasic example.
`timescale 1ns/1ps
module tb_keygen_fan_bus;
    reg clock_i=0;always #5 clock_i=~clock_i;
    reg reset_n_i=1;
    tri1 scl,sda;
    reg slave_low=0;assign sda=slave_low?1'b0:1'bz;
    wire ready,valid;wire signed [15:0] fpga_temp,board_temp,board2_temp;
    wire [15:0] rpm;
    BOARD_MANAGEMENT #(.SEC(32)) dut(
        .clk_50(clock_i),.reset_n(reset_n_i),.I2C_SCL(scl),.I2C_SDA(sda),
        .Auto_Fan_Speed(1'b1),.Set_Fan_Speed(16'd4000),.BUSY_GO_HI(1'b0),
        .I2C_READY(ready),.TEMP_VALID(valid),.FPGA_Temperature(fpga_temp),
        .Board_Temperature(board_temp),.Board2_Temperature(board2_temp),.Fan_Speed(rpm));
    localparam RX=0,ACK_SETUP=1,ACK_HIGH=2,ACK_DONE=3,TX=4,MASTER_ACK=5,IDLE=6;
    integer state=IDLE,bits=0,byte_index=0,address=0;
    reg active=0,read_direction=0,ack_byte=0;
    reg [7:0] shift=0,tx_byte=0,pointer_t=0,pointer_f=0;
    reg old_scl=1,old_sda=1;
    reg [7:0] config1=8'hff,config2=0,fan_mode=0,speed=0;
    integer config_writes=0,speed_writes=0;
    task automatic prepare_read;
        if(address==7'h4c)case(pointer_t)
            8'h00:tx_byte=30;8'h01:tx_byte=40;8'h02:tx_byte=35;
            8'hfe:tx_byte=8'h55;8'hff:tx_byte=8'h42;default:tx_byte=0;
        endcase
        else case(pointer_f)
            8'h0c,8'h0e:tx_byte=60;8'h02:tx_byte=fan_mode;default:tx_byte=0;
        endcase
    endtask
    task automatic received_byte(input [7:0] value);
        ack_byte=1;
        if(byte_index==0)begin
            address=value[7:1];read_direction=value[0];
            ack_byte=(address==7'h4c || address==7'h48);
            if(read_direction && ack_byte)prepare_read();
        end else if(byte_index==1)begin
            if(address==7'h4c)pointer_t=value;else pointer_f=value;
        end else if(byte_index==2)begin
            if(address==7'h4c)case(pointer_t)
                8'h09:config1=value;8'h0a:config2=value;
            endcase
            else case(pointer_f)
                8'h02:begin fan_mode=value;config_writes=config_writes+1;end
                8'h00:begin speed=value;speed_writes=speed_writes+1;end
            endcase
        end
        byte_index=byte_index+1;
    endtask
    always @(negedge clock_i)begin
        if(!reset_n_i)begin
            active=0;state=IDLE;slave_low=0;old_scl=1;old_sda=1;
        end else begin
            if(old_sda && !sda && scl && old_scl)begin
                active=1;state=RX;bits=0;byte_index=0;shift=0;slave_low=0;
            end else if(!old_sda && sda && scl && old_scl)begin
                active=0;state=IDLE;slave_low=0;
            end else if(active && !old_scl && scl)begin
                case(state)
                    RX:begin
                        shift={shift[6:0],sda};bits=bits+1;
                        if(bits==8)begin received_byte(shift);state=ACK_SETUP;end
                    end
                    ACK_HIGH:state=ACK_DONE;
                    TX:bits=bits+1;
                    MASTER_ACK:state=IDLE;
                endcase
            end else if(active && old_scl && !scl)begin
                case(state)
                    ACK_SETUP:begin slave_low=ack_byte;state=ACK_HIGH;end
                    ACK_DONE:begin
                        bits=0;shift=0;
                        if(read_direction && byte_index==1 && ack_byte)begin state=TX;slave_low=!tx_byte[7];end
                        else begin state=RX;slave_low=0;end
                    end
                    TX:begin
                        if(bits==8)begin slave_low=0;state=MASTER_ACK;end
                        else slave_low=!tx_byte[7-bits];
                    end
                endcase
            end
            old_scl=scl;old_sda=sda;
        end
    end


    initial begin
        #1;reset_n_i=0;repeat(300)@(negedge clock_i);reset_n_i=1;
        wait(ready && valid);@(negedge clock_i);
        if(fpga_temp!==16'sd40 || board_temp!==16'sd30 || board2_temp!==16'sd35 || rpm!==16'd3600)
            $fatal(1,"vendor telemetry mismatch: %0d %0d %0d %0d",fpga_temp,board_temp,board2_temp,rpm);
        wait(speed_writes>=2);@(negedge clock_i);
        if(config1!==0 || config2!==8'h3c || fan_mode!==8'h29 || config_writes<2)
            $fatal(1,"vendor continuous-conversion/closed-loop setup mismatch");
        if(speed!==8'd30)$fatal(1,"vendor low-temperature speed: %0d",speed);
        $display("PASS VENDOR_FAN_BUS: serial configuration, continuous temperature reads, RPM and fan speed writes");$finish;
    end
    initial begin #200000000;$fatal(1,"vendor I2C timeout state=%0d count=%0d",dut.ST,dut.CNT);end
endmodule
