`timescale 1ns/1ps
// Adapter fixture test, NOT generated-slot acceptance. A private derivation
// failure must erase its copies and permit an exact successful retry WITHOUT
// a system reset. Independent public test key/results only.
module tb_rsa_retry;
    reg clk=0;always #5 clk=~clk;
    reg rst=0,request=0,input_valid=0,last=0,ack=0,lease=0,reply=0;
    reg [31:0] input_data=0,id=32'h7e7;
    wire ready,input_ready,result_valid,result_last,complete,acquire,reply_ready,relinquish;
    wire [31:0] result_data,complete_id;wire [3:0] code;wire [7:0] address;
    reg [31:0] slot[0:128],scratch[0:511];reg [2047:0] vectors[0:3],observed=0;
    integer count=0,cycles=0,starts=0,completions=0;
    execution_engine_rsa #(.ENABLE(1)) dut (
        .clock_i(clk),.reset_n_i(rst),.request_valid_i(request),.request_ready_o(ready),
        .request_id_i(id),.request_allow_i(1'b1),.operation_i(2'd1),
        .operand_valid_i(input_valid),.operand_ready_o(input_ready),.operand_data_i(input_data),.operand_last_i(last),
        .result_valid_o(result_valid),.result_ready_i(1'b1),.result_data_o(result_data),.result_last_o(result_last),
        .completion_valid_o(complete),.completion_ready_i(ack),.completion_code_o(code),.completion_id_o(complete_id),
        .acquire_valid_o(acquire),.acquire_ready_i(!lease && !reply),.acquire_allow_o(),.acquire_type_o(),.acquire_words_o(),
        .acquire_reply_valid_i(reply),.acquire_reply_ready_o(reply_ready),.acquire_code_i(4'd0),
        .consumer_release_o(relinquish),.reserved_i(lease),.slot_valid_i(1'b1),.slot_type_i(2'd2),.slot_words_i(8'd129),
        .private_address_o(address),.private_data_i(address<129?slot[address]:32'd0));
    always @(posedge clk)begin
        if(!rst)begin lease<=0;reply<=0;end
        else begin
            cycles<=cycles+1;
            if(reply && reply_ready)reply<=0;
            if(relinquish)lease<=0;
            if(acquire && !lease && !reply)begin lease<=1;reply<=1;end
            if(dut.enabled.state_reg==8)starts<=starts+1;
            if(complete && ack)completions<=completions+1;
            if(dut.enabled.protected_derivation.ram_write_en)
                scratch[dut.enabled.protected_derivation.ram_write_address]=dut.enabled.protected_derivation.ram_write_data;
            if(result_valid)begin
                if(count>=64 || result_last!==(count==63) || !lease)$fatal(1,"retry output bounds/lease");
                observed<={observed[2015:0],result_data};count<=count+1;
            end
        end
    end
    task clean;
        if((dut.enabled.modulus_reg|dut.enabled.p_reg|dut.enabled.q_reg|dut.enabled.exponent_reg|dut.enabled.representative_reg)!==0)
            $fatal(1,"failed derivation left adapter secrets");
        for(integer j=0;j<512;j++)if(scratch[j]!==0)$fatal(1,"failed derivation scratch survived %0d",j);
        if(dut.enabled.protected_derivation.private_d_reg!==0 || dut.enabled.protected_derivation.ram_read_data!==0)
            $fatal(1,"protected exponent copy/output survived");
    endtask
    task launch;
        wait(ready);@(negedge clk);request=1;@(negedge clk);request=0;wait(input_ready);
        for(integer j=0;j<64;j++)begin
            @(negedge clk);input_valid=1;input_data=vectors[2][2047-j*32 -:32];last=j==63;
            @(negedge clk);input_valid=0;last=0;
        end
    endtask
    task consume_status(input [3:0] expected);
        wait(complete);#1;if(code!==expected || complete_id!==id || !lease)$fatal(1,"retry terminal ownership/code");
        clean();repeat(11)@(negedge clk);ack=1;@(negedge clk);ack=0;wait(ready);#1;
        if(lease || complete)$fatal(1,"retry lease not released");
    endtask
    initial begin
        $readmemh("slot.hex",slot);$readmemh("rsa_vectors.hex",vectors);
        repeat(3)@(negedge clk);rst=1;wait(ready);
        slot[96]=slot[96]&32'hfffffffe;launch();consume_status(11);
        if(count!=0 || starts!=0)$fatal(1,"bad private pair dispatched arithmetic");
        // Repair ONLY the public test fixture after relinquish, with no reset.
        slot[96]=slot[96]|32'd1;id=id+1;launch();consume_status(0);
        if(observed!==vectors[3] || count!=64 || starts!=1 || completions!=2)$fatal(1,"independent successful private retry");
        repeat(13)@(negedge clk);if(complete || result_valid)$fatal(1,"double completion after retry");
        $display("RSA_NO_RESET_PRIVATE_RETRY_PASS exact_words=64 cycles=%0d",cycles);$finish;
    end
    initial begin #(64'd1000000000);$fatal(1,"retry test deadline");end
endmodule
