`timescale 1ns/1ps
// Real controller/engine. Only ready is held low to expose admission skew.
module rsa_admission_case #(parameter PRIVATE=0)(output reg done=0);
    reg clk=0; always #5 clk=~clk;
    reg rst=0,request=0,failed=0,status_ready=0;
    wire ready,gready,status_valid;
    wire [3:0] status;
    integer k,cycles;
    keygen_core #(.PRIVATE_RSA_ENABLE(PRIVATE)) dut(
        .clock_i(clk),.reset_n_i(rst),.peers_ready_i(1'b1),
        .request_valid_i(request),.request_ready_o(ready),.request_profile_i(2'd2),.request_id_i(32'd99),
        .generation_valid_i(1'b0),.generation_ready_o(gready),.generation_data_i(32'd0),.generation_failed_i(failed),
        .result_ready_i(1'b0),.ownership_valid_i(1'b0),.ownership_accept_i(1'b0),
        .status_valid_o(status_valid),.status_ready_i(status_ready),.status_code_o(status),
        .private_open_valid_i(1'b0),.private_cmd_valid_i(1'b0),.private_cmd_op_i(8'd0),
        .private_cmd_arg0_i(32'd0),.private_cmd_arg1_i(32'd0),.private_cmd_arg2_i(32'd0),.private_cmd_arg3_i(32'd0),
        .private_rsp_ready_i(1'b0),.private_mem_write_en_i(1'b0),.private_mem_read_en_i(1'b0),
        .private_mem_address_i(12'd0),.private_mem_write_data_i(32'd0),
        .private_close_valid_i(1'b0),.private_close_rsp_ready_i(1'b0));
    initial begin
        repeat(4) @(negedge clk); rst=1;
        for(k=0;k<4;k=k+1) begin
            wait(ready); repeat(k) @(negedge clk);
            @(negedge clk); force dut.engine_ready=1'b0; request=1;
            @(negedge clk); request=0;
            if(dut.state_reg!=4) $fatal(1,"not RSA_START");
            repeat(4) begin
                @(posedge clk); #1;
                if(dut.state_reg!=4 || !dut.work_ready)
                    $fatal(1,"controller admitted before engine: private=%0d state=%0d work_ready=%0d",PRIVATE,dut.state_reg,dut.work_ready);
            end
            @(negedge clk); release dut.engine_ready;
            cycles=0;
            while(!gready && cycles<100) begin @(negedge clk); cycles=cycles+1; end
            if(!gready || dut.state_reg!=5) $fatal(1,"RSA admission deadlock");
            failed=1; wait(status_valid);
            if(status!=2) $fatal(1,"fault cleanup");
            @(negedge clk); failed=0; status_ready=1;
            @(negedge clk); status_ready=0;
        end
        wait(ready);
        $display("PASS RSA_ADMISSION private=%0d phase_cases=4",PRIVATE); done=1;
    end
endmodule
module tb_rsa_admission;
    wire a,b;
    rsa_admission_case legacy(a);
    rsa_admission_case #(.PRIVATE(1)) compact(b);
    initial begin wait(a && b); $display("PASS RSA_ADMISSION_ALL"); $finish; end
    initial begin #1000000; $fatal(1,"timeout"); end
endmodule
