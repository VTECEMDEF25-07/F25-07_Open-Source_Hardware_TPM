`timescale 1ns/1ps
// Public fixtures only: directly validate the new optional checked-math port.
module tb_protected_d #(parameter IP_TYPE=0);
    reg clk=0;always #5 clk=~clk;
    reg rst=0,start=0,d_ready=0,result_ready=0;
    reg [1023:0] p=0,q=0;
    wire ready,valid,d_valid;wire [3:0] status;wire [2047:0] n,d;
    reg [31:0] slot[0:128],ram[0:511];
    reg [2047:0] oracle[0:1];
    integer cycles=0,checks=0;
    keygen_pair_check #(.IP_TYPE(IP_TYPE),.PROTECTED_D_HANDOFF(1)) dut (
        .clock_i(clk),.reset_n_i(rst),.start_valid_i(start),.start_ready_o(ready),
        .p_i(p),.q_i(q),.result_valid_o(valid),.result_ready_i(result_ready),.n_o(n),.status_o(status),
        .private_d_valid_o(d_valid),.private_d_ready_i(d_ready),.private_d_o(d));
    always @(posedge clk)if(rst)begin
        cycles<=cycles+1;
        if(dut.ram_write_en)ram[dut.ram_write_address]=dut.ram_write_data;
        if(!d_valid && d!==0)$fatal(1,"d visible outside protected handoff");
        if(d_valid && (valid || n!==0))$fatal(1,"terminal before protected handoff cleanup");
    end
    task tick;@(posedge clk);#1;endtask
    task assert_clean;
        if(d!==0 || dut.private_d_reg!==0 || dut.ram_read_data!==0 || dut.mult_product!==0)
            $fatal(1,"protected exponent copy/output latch not cleared");
        for(integer j=0;j<512;j++)if(ram[j]!==0)$fatal(1,"derivation RAM survived cleanup %0d",j);
    endtask
    task reset_all;
        @(negedge clk);rst=0;start=0;d_ready=0;result_ready=0;
        #1;if(d_valid || valid || d!==0 || n!==0 || ready)$fatal(1,"reset leaked protected result");
        repeat(3)tick();@(negedge clk);rst=1;wait(ready);#1;assert_clean();
    endtask
    task launch;
        wait(ready);p=0;q=0;
        for(integer j=0;j<32;j++)begin p={p[991:0],slot[65+j]};q={q[991:0],slot[97+j]};end
        @(negedge clk);start=1;tick();@(negedge clk);start=0;p=0;q=0;
    endtask
    initial begin
        $readmemh("slot.hex",slot);$readmemh("protected_d.hex",oracle);
        reset_all();launch();wait(d_valid);#1;
        if(d!==oracle[1])$fatal(1,"independent canonical d mismatch");
        repeat(113)begin tick();if(!d_valid || d!==oracle[1] || ready || valid)$fatal(1,"protected handoff changed under backpressure");end
        @(negedge clk);d_ready=1;tick();@(negedge clk);d_ready=0;
        if(d_valid || d!==0 || valid)$fatal(1,"handoff did not erase before terminal");
        wait(valid);#1;if(status!==0 || n!==oracle[0])$fatal(1,"protected derivation n/status");
        assert_clean();repeat(17)begin tick();if(!valid || n!==oracle[0] || status!==0)$fatal(1,"derivation terminal not held");end
        @(negedge clk);result_ready=1;tick();@(negedge clk);result_ready=0;wait(ready);checks=checks+1;
        launch();wait(d_valid);reset_all();checks=checks+1;
        launch();wait(dut.state_reg==67);reset_all();checks=checks+1;
        launch();wait(d_valid);@(negedge clk);d_ready=1;tick();@(negedge clk);d_ready=0;
        wait(valid);assert_clean();checks=checks+1;
        $display("RSA_PROTECTED_D_PASS backend=%0d checks=%0d cycles=%0d",IP_TYPE,checks,cycles);$finish;
    end
    initial begin #(64'd500000000);$fatal(1,"protected handoff deadline");end
endmodule
