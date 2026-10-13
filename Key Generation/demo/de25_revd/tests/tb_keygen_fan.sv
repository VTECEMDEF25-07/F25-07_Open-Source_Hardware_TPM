`timescale 1ns/1ps
module tb_keygen_fan;
    reg clock_i=0;always #5 clock_i=~clock_i;
    reg reset_n_i=0;
    tri1 scl,sda;
    wire fail_safe;
    integer mode=0, i, samples=0;
    reg [7:0] sensor_byte;
    // ACK-level model; decoded read bytes below provide the sensor register values.
    assign sda=(mode!=0 && mode!=6) ? 1'b0:1'bz;
    BOARD_MANAGEMENT #(.SENSOR_STALE_TICKS(8192),.MANAGEMENT_SECOND_TICKS(32),.MANAGEMENT_CLOCK_DIVIDE(1)) dut (
        .clk_50(clock_i),.reset_n(reset_n_i),.I2C_SCL(scl),.I2C_SDA(sda),
        .Auto_Fan_Speed(1'b1),.Set_Fan_Speed(16'd4000),.BUSY_GO_HI(1'b0),.FAN_FAILSAFE(fail_safe)
    );
    // Accelerate the management clock only in this bench. Device pin timing is not modeled.

    always @* begin
        case(dut.CNT)
            4:sensor_byte=mode==8 ? 8'h54:8'h55;
            5:sensor_byte=mode==3 ? 8'h41 : 8'h42;
            6:sensor_byte=mode==5 ? 8'h80:0;
            7:sensor_byte=30;
            8:sensor_byte=mode==7 ? 8'hc0:40;
            9:sensor_byte=35;
            10:sensor_byte=mode==4 ? 8'h02:0;
            11:sensor_byte=mode==2 ? 8'h01:0;
            12:sensor_byte=mode==9 ? 8'h01:0;
            default:sensor_byte=60;
        endcase
    end
    always @(negedge clock_i) if(mode!=0) force dut.R_DATA=sensor_byte;
    task ticks(input integer count);repeat(count)@(negedge clock_i);endtask
    task sample;
        integer limit;
        begin
            limit=0;
            while(!(dut.ST==10 && dut.CNT==13) && limit<100000)begin ticks(1);limit=limit+1;end
            if(limit==100000)$fatal(1,"sample timeout ST=%d CNT=%d WCNT=%d TACH=%h CLK=%b",dut.ST,dut.CNT,dut.WCNT,dut.TACH0,dut.CLK_400K);
            ticks(8);samples=samples+1;
        end
    endtask
    task check_mode(input [7:0] expected);
        integer limit;
        begin
            limit=0;
            while(!(dut.ST==31 && dut.WCNT==7) && limit<100000)begin ticks(1);limit=limit+1;end
            if(limit==100000)$fatal(1,"mode update timeout");
            ticks(4);
            if(dut.W_POINTER_REG!==8'h02 || dut.W_WORD_DATA!==expected)$fatal(1,"fan mode %h expected %h",dut.W_WORD_DATA,expected);
        end
    endtask
    initial begin
        ticks(2);if(!fail_safe)$fatal(1,"startup must be safe");
        reset_n_i=1;
        // Real vendor I2C engines see an unresponsive pulled-up bus.
        sample();if(!fail_safe || !dut.cycle_error_reg)$fatal(1,"no response not rejected");
        check_mode(8'h09);
        // Inject decoded sensor bytes at the controller boundary; no changes to production logic.
        
        mode=1;sample();if(fail_safe || !dut.I2C_READY)$fatal(1,"valid sensor recovery");
        check_mode(8'h29);
        mode=6;sample();if(!fail_safe)$fatal(1,"lost ACK ignored");
        mode=1;sample();if(fail_safe)$fatal(1,"ACK recovery");
        mode=2;sample();if(!fail_safe)$fatal(1,"OPEN ignored");check_mode(8'h09);
        mode=3;sample();if(!fail_safe)$fatal(1,"device ID ignored");
        mode=4;sample();if(!fail_safe)$fatal(1,"nPVLD ignored");
        mode=5;sample();if(!fail_safe)$fatal(1,"BUSY accepted as fresh");
        mode=7;sample();if(!fail_safe)$fatal(1,"shorted diode sentinel ignored");
        mode=8;sample();if(!fail_safe)$fatal(1,"manufacturer ID ignored");
        mode=9;sample();if(!fail_safe)$fatal(1,"remote2 OPEN ignored");
        mode=1;sample();if(fail_safe)$fatal(1,"fault recovery");
        force dut.ST=36;force dut.DELY=0;
        ticks(32780);if(!fail_safe)$fatal(1,"stale data accepted");
        release dut.ST;release dut.DELY;
        sample();if(fail_safe)$fatal(1,"stale recovery");
        reset_n_i=0;ticks(2);if(!fail_safe)$fatal(1,"reset must be safe");
        $display("PASS FAN_GUARD: startup, unresponsive I2C, full-on/closed-loop commands, ID/OPEN/nPVLD, staleness and recovery");
        $finish;
    end
    initial begin #10000000;$fatal(1,"timeout");end
endmodule
