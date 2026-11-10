`timescale 1ns/1ps
module tb_demo_lcd_status;
    reg clock_i=0;
    always #10 clock_i=~clock_i; // actual 50 MHz status domain
    reg reset_n_i=0, status_valid_i=0;
    reg [3:0] status_code_i=0;
    reg [7:0] status_detail_i=0;
    reg [31:0] operation_id_i=0;
    reg [1:0] provider_mode_i=0;
    wire [31:0] status_word_o,operation_id_o,sequence_o;
    demo_lcd_status dut(.*);
    integer checks=0, transitions=0, k;
    reg [31:0] before_word,before_id,before_seq;
    task tick; begin @(posedge clock_i); #1; end endtask
    task ck(input bit condition,input string why);
        begin checks++; if(!condition) $fatal(1,"FAIL %s",why); end
    endtask
    task check_snapshot;
        begin
            ck(status_word_o=={8'h01,status_detail_i,8'd0,1'b1,(status_code_i>=9),provider_mode_i,status_code_i},"atomic encoded status");
            ck(operation_id_o==operation_id_i,"atomic operation ID");
        end
    endtask
    initial begin
        tick; ck(status_word_o==32'h01000020 && sequence_o==0 && operation_id_o==0,"reset no invented ready");
        reset_n_i=1; repeat(3) tick;
        for(k=0;k<16;k++) begin
            status_valid_i=1; status_code_i=k[3:0]; status_detail_i=k[7:0]*8'd7;
            operation_id_i=32'hbad00000+k; provider_mode_i=2'(k%3);
            before_seq=sequence_o; tick; transitions++;
            check_snapshot; ck(sequence_o==before_seq+1,"one sequence per real change");
            repeat(4) begin tick; check_snapshot; ck(sequence_o==before_seq+1,"no timer progress/duplicate increment"); end
            before_word=status_word_o; before_id=operation_id_o;
            status_valid_i=0; status_code_i=~status_code_i; status_detail_i=~status_detail_i;
            operation_id_i=~operation_id_i; provider_mode_i=3;
            repeat(3) begin tick; ck(status_word_o==before_word && operation_id_o==before_id && sequence_o==before_seq+1,"invalid event ignored, tuple retained"); end
        end
        status_valid_i=1; status_code_i=9; status_detail_i=8'hfe; operation_id_i=42; provider_mode_i=0;
        tick; check_snapshot; ck(status_word_o[6],"actual error flag");
        before_seq=sequence_o; operation_id_i=43; tick;
        ck(sequence_o==before_seq+1 && operation_id_o==43,"ID-only real change captured");
        before_seq=sequence_o; provider_mode_i=1; tick;
        ck(sequence_o==before_seq+1 && status_word_o[5:4]==1,"provider provenance change");
        reset_n_i=0; #1;
        ck(status_word_o==32'h01000020 && sequence_o==0 && operation_id_o==0,"async reset removes stale done/error");
        reset_n_i=1; status_code_i=8; tick;
        ck(!status_word_o[7],"synchronized release prevents early status");
        tick; ck(!status_word_o[7],"second release edge still no capture");
        tick; check_snapshot;
        $display("PASS LCD_STATUS checks=%0d transitions=%0d clock=50MHz",checks,transitions);
        $finish;
    end
    initial begin #100000; $fatal(1,"status bench watchdog"); end
endmodule
