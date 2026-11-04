// Filename: tb_keygen_fan.sv
// Modules: tb_keygen_fan
// Authors: Project contributors; see Git history.
// Date: 2026-10-13
// General Description: Checks keygen fan behavior and reports failures.
// AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

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
    BOARD_MANAGEMENT #(.CONVERSION_TIMEOUT_TICKS(8192),.SENSOR_STALE_TICKS(65536),.MANAGEMENT_SECOND_TICKS(32),.MANAGEMENT_CLOCK_DIVIDE(1)) dut (
        .clk_50(clock_i),.reset_n(reset_n_i),.I2C_SCL(scl),.I2C_SDA(sda),
        .Auto_Fan_Speed(1'b1),.Set_Fan_Speed(16'd4000),.BUSY_GO_HI(1'b0),.FAN_FAILSAFE(fail_safe)
    );
    // Accelerate the management clock only in this bench. Device pin timing is not modeled.

    always @* begin
        case(dut.CNT)
            4:sensor_byte=mode==8 ? 8'h54:8'h55;
            5:sensor_byte=mode==3 ? 8'h41 : 8'h42;
            6:sensor_byte=mode==10 ? 0 : (mode==5 || !dut.conversion_seen_reg ? 8'h80:0);
            7:sensor_byte=30;
            8:sensor_byte=mode==4 ? 8'h02:0;
            9:sensor_byte=mode==7 ? 8'hc0:40;
            10:sensor_byte=mode==2 ? 8'h01:0;
            11:sensor_byte=35;
            12:sensor_byte=mode==9 ? 8'h01:0;
            13:sensor_byte=mode==11 ? 8'h00 : 8'h40;
            14:sensor_byte=8'h3c;
            15:sensor_byte=mode==12 ? 8'h80:0;
            default:sensor_byte=60;
        endcase
    end
    reg [7:0] preceding_pointer=8'hff;
    always @(posedge dut.CLK_400K) if(dut.ST==9 && dut.R_END) begin
        if(dut.W_POINTER_REG==8'h10 && preceding_pointer!=0)$fatal(1,"local pair not adjacent");
        if(dut.W_POINTER_REG==8'h11 && preceding_pointer!=1)$fatal(1,"remote1 pair not adjacent");
        if(dut.W_POINTER_REG==8'h12 && preceding_pointer!=2)$fatal(1,"remote2 pair not adjacent");
        preceding_pointer=dut.W_POINTER_REG;
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
        
        mode=1;sample();if(fail_safe)sample();if(fail_safe || !dut.I2C_READY)$fatal(1,"valid sensor recovery reason=%h cfg=%h/%h pre=%b shot=%b write=%b good=%b seen=%b timeout=%b ticks=%d",dut.FAN_DIAGNOSTIC,dut.config1_reg,dut.config2_reg,dut.preflight_error_reg,dut.shot_error_reg,dut.write_error_reg,dut.conversion_good_reg,dut.conversion_seen_reg,dut.conversion_timeout_reg,dut.conversion_ticks_reg);
        check_mode(8'h29);
        mode=6;sample();if(!fail_safe)$fatal(1,"lost ACK ignored");
        mode=1;sample();if(fail_safe)sample();if(fail_safe)$fatal(1,"ACK recovery");
        mode=2;sample();if(!fail_safe)$fatal(1,"OPEN ignored");check_mode(8'h09);
        mode=3;sample();if(!fail_safe)$fatal(1,"device ID ignored");
        mode=4;sample();if(!fail_safe)$fatal(1,"nPVLD ignored");
        mode=5;sample();if(!fail_safe)$fatal(1,"BUSY accepted as fresh");
        mode=10;sample();if(!fail_safe || !dut.conversion_timeout_reg)$fatal(1,"missing BUSY accepted");
        mode=11;sample();if(!fail_safe || !dut.preflight_error_reg)$fatal(1,"shutdown configuration ignored");
        mode=12;sample();if(!fail_safe || !dut.preflight_error_reg)$fatal(1,"startup BUSY bound ignored");
        mode=7;sample();if(!fail_safe)$fatal(1,"shorted diode sentinel ignored");
        mode=8;sample();if(!fail_safe)$fatal(1,"manufacturer ID ignored");
        mode=9;sample();if(!fail_safe)$fatal(1,"remote2 OPEN ignored");
        mode=1;sample();if(fail_safe)sample();if(fail_safe)$fatal(1,"fault recovery");
        force dut.ST=36;force dut.DELY=0;
        ticks(262160);if(!fail_safe)$fatal(1,"stale data accepted");
        release dut.ST;release dut.DELY;
        sample();if(fail_safe)$fatal(1,"stale recovery");
        reset_n_i=0;ticks(2);if(!fail_safe)$fatal(1,"reset must be safe");
        $display("PASS FAN_GUARD: startup, unresponsive I2C, full-on/closed-loop commands, ID/OPEN/nPVLD, staleness and recovery");
        $finish;
    end
    initial begin #30000000;$fatal(1,"timeout");end
endmodule
