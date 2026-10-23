// Filename: tb_keygen_fan_bus.sv
// Modules: tb_keygen_fan_bus
// Authors: Project contributors; see Git history.
// Date: 2026-10-13
// General Description: Checks keygen fan bus behavior and reports failures.
// AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

`timescale 1ns/1ps
// Independent pin-level TMP442/MAX6650 model. No forced DUT signals or decoded
// read-data injection: every register byte travels over open-drain SDA/SCL.
module tb_keygen_fan_bus;
    reg clock_i=0; always #5 clock_i=~clock_i;
    reg reset_n_i=0;
    tri1 scl,sda;
    reg slave_low=0;
    assign sda=slave_low ? 1'b0 : 1'bz;
    wire fail_safe;
    BOARD_MANAGEMENT #(.CONVERSION_TIMEOUT_TICKS(16000),
        .SENSOR_STALE_TICKS(80000),.MANAGEMENT_SECOND_TICKS(32),
        .MANAGEMENT_CLOCK_DIVIDE(1)) dut (
        .clk_50(clock_i),.reset_n(reset_n_i),.I2C_SCL(scl),.I2C_SDA(sda),
        .Auto_Fan_Speed(1'b1),.Set_Fan_Speed(16'd4000),
        .BUSY_GO_HI(1'b0),.FAN_FAILSAFE(fail_safe));

    localparam RX=0,ACK_SETUP=1,ACK_HIGH=2,ACK_DONE=3,TX=4,MASTER_ACK=5,IDLE=6;
    integer state=IDLE,bits=0,byte_index=0,address=0;
    reg active=0,read_direction=0,ack_byte=0;
    reg [7:0] shift=0,tx_byte=0,pointer_t=0,pointer_f=0;
    reg old_scl=1,old_sda=1;
    reg [7:0] config1=0,config2=8'h3c,fan_mode=8'h09;
    integer fault=0,conversion_left=0,shot_count=0,completed_shots=0;
    integer previous_temp_read=-1,pair_count=0,sample_count=0;
    integer startup_busy_reads=0,busy_reads=0,idle_reads=0;
    integer ticks_since_shot=0,first_status_delay=0,max_status_delay=0;
    reg shot_running=0;

    function automatic [7:0] sensor_read(input [7:0] ptr);
        case(ptr)
            8'h00:sensor_read=30;
            8'h10:sensor_read=fault==3 ? 2:0;
            8'h01:sensor_read=40;
            8'h11:sensor_read=fault==2 ? 1:0;
            8'h02:sensor_read=35;
            8'h12:sensor_read=0;
            8'h08:sensor_read=conversion_left>0 ? 8'h80:0;
            8'h09:sensor_read=fault==7 ? 0:config1;
            8'h0a:sensor_read=config2;
            8'hfe:sensor_read=8'h55;
            8'hff:sensor_read=fault==4 ? 8'h41:8'h42;
            default:sensor_read=0;
        endcase
    endfunction

    task automatic prepare_read;
        begin
            if(address==7'h4c) begin
                tx_byte=sensor_read(pointer_t);
                if(pointer_t==8'h10 || pointer_t==8'h11 || pointer_t==8'h12) begin
                    if(previous_temp_read != pointer_t-16)
                        $fatal(1,"TMP442 high/low reads separated: previous=%h low=%h",previous_temp_read,pointer_t);
                    pair_count=pair_count+1;
                end
                previous_temp_read=pointer_t;
                if(pointer_t==8'h08) begin
                    if(conversion_left>0) busy_reads=busy_reads+1;
                    else idle_reads=idle_reads+1;
                    if(!shot_running && conversion_left>0) startup_busy_reads=startup_busy_reads+1;
                    if(shot_running && first_status_delay==0) begin
                        first_status_delay=ticks_since_shot;
                        if(first_status_delay>max_status_delay)max_status_delay=first_status_delay;
                    end
                end
                if(pointer_t<=2 && fault==0 && shot_count>0 && conversion_left>0)
                    $fatal(1,"temperature fetched before conversion completed");
            end else begin
                case(pointer_f)
                    8'h0c,8'h0e:tx_byte=60;
                    8'h02:tx_byte=fan_mode;
                    default:tx_byte=0;
                endcase
            end
        end
    endtask

    task automatic received_byte(input [7:0] value);
        begin
            ack_byte=1;
            if(byte_index==0) begin
                address=value[7:1];read_direction=value[0];
                ack_byte=(address==7'h4c || address==7'h48) && !(address==7'h4c && fault==1);
                if(read_direction && ack_byte)prepare_read();
            end else if(address==7'h4c && fault==1)begin
                ack_byte=0;
            end else if(byte_index==1) begin
                if(address==7'h4c)pointer_t=value;else pointer_f=value;
            end else if(byte_index==2) begin
                if(address==7'h4c) begin
                    if(fault==8)ack_byte=0;
                    else case(pointer_t)
                        8'hfc:begin config1=0;config2=8'h3c;conversion_left=40000;shot_running=0;end
                        8'h09:config1=value;
                        8'h0a:config2=value;
                        8'h0f:begin
                            if(conversion_left!=0 && fault==0)$fatal(1,"one-shot issued before prior conversion became idle");
                            if(config1!=8'h40 || config2!=8'h3c)$fatal(1,"one-shot without configured shutdown/channels");
                            // TMP442 ignores a trigger while already converting.
                            if(conversion_left==0)begin
                                shot_count=shot_count+1;shot_running=1;ticks_since_shot=0;first_status_delay=0;
                                if(fault!=6)conversion_left=24000;
                            end
                        end
                    endcase
                end else if(pointer_f==8'h02)fan_mode=value;
            end
            byte_index=byte_index+1;
        end
    endtask

    // Sample between DUT clock edges, avoiding delta-cycle ordering assumptions.
    always @(negedge clock_i) begin
        if(conversion_left>0 && !(fault==5 && shot_running)) begin
            conversion_left=conversion_left-1;
            if(conversion_left==0 && shot_running)completed_shots=completed_shots+1;
        end
        if(shot_running)ticks_since_shot=ticks_since_shot+1;
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

    always @(posedge dut.CLK_400K)
        if(reset_n_i && dut.sensor_sample)sample_count=sample_count+1;
    task automatic samples(input integer count);
        integer target,limit;
        begin
            target=sample_count+count;limit=0;
            while(sample_count<target && limit<1000000)begin @(posedge clock_i);limit=limit+1;end
            repeat(16)@(posedge clock_i);
            if(sample_count<target)$fatal(1,"sample deadline fault=%d state=%d count=%d",fault,dut.ST,dut.CNT);
        end
    endtask
    task automatic fault_and_recover(input integer code);
        begin
            fault=code;samples(2);
            if(!fail_safe)$fatal(1,"fault %0d accepted",code);
            fault=0;conversion_left=0;samples(2);
            if(fail_safe)$fatal(1,"fault %0d recovery failed reasons=%h",code,dut.sample_reason_reg);
            $display("PASS bus fault/recovery %0d",code);
        end
    endtask
    initial begin
        repeat(4)@(posedge clock_i);reset_n_i=1;
        samples(2);
        if(fail_safe || completed_shots<1 || pair_count<6 || startup_busy_reads<1)
            $fatal(1,"startup/fresh sample failure safe=%b complete=%d pairs=%d startupbusy=%d reason=%h",fail_safe,completed_shots,pair_count,startup_busy_reads,dut.sample_reason_reg);
        fault_and_recover(1);fault_and_recover(2);fault_and_recover(3);
        fault_and_recover(4);fault_and_recover(5);fault_and_recover(6);
        fault_and_recover(7);fault_and_recover(8);
        if(busy_reads<2 || idle_reads<2)$fatal(1,"missing observed conversion transitions");
        $display("PASS FAN_BUS: serial startup, paired reads, fresh completion, 8 faults/recovery; shots=%0d pairs=%0d maximum first-status delay=%0d clocks",shot_count,pair_count,max_status_delay);
        $finish;
    end
    initial begin #100000000;$fatal(1,"global timeout");end
endmodule
