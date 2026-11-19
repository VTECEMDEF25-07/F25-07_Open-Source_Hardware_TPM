`timescale 1ns/1ps
// Adapter-only directed tests. This slot model is NOT generated-key acceptance.
// Full-width independent public fixtures; never production keys or host exports.
module tb_rsa_adapter #(parameter TEST_CASE=0, IP_TYPE=0);
    reg clk=0; always #5 clk=~clk;
    reg rst=0, req=0, allow=1, iv=0, il=0, rr=0, ca=0;
    reg [1:0] op=0, kind=2;
    reg [31:0] id=32'h12345678, din=0;
    reg live=1, reserved=0, reply=0;
    reg [3:0] acode=0;
    reg [7:0] words=129;
    wire rq, ir, rv, rl, cv, av, aa, ar, cr;
    wire [3:0] code; wire [31:0] dout,cid;
    wire [1:0] at; wire [7:0] aw, address;
    reg [31:0] fixture[0:128], slot[0:130];
    reg [2047:0] vectors[0:3];
    reg [2047:0] observed, expected_result, representative;
    reg [31:0] tracked_ram[0:511];
    reg [31:0] random_reg=32'h73a8d2e1;
    integer cycles=0, checks=0, launches=0, derivations=0;
    reg stall=1, inject_error=0;
    wire [31:0] key_data=live && address<words && address<129?slot[address]:32'd0;
    wire acq_ready=!reserved && !reply;
    execution_engine_rsa #(.ENABLE(1),.IP_TYPE(IP_TYPE),
        .WAIT_LIMIT(TEST_CASE==1?20000:100000000),.TERMINAL_LIMIT(5000)) dut (
        .clock_i(clk),.reset_n_i(rst),.request_valid_i(req),.request_ready_o(rq),
        .request_id_i(id),.request_allow_i(allow),.operation_i(op),
        .operand_valid_i(iv),.operand_ready_o(ir),.operand_data_i(din),.operand_last_i(il),
        .result_valid_o(rv),.result_ready_i(rr),.result_data_o(dout),.result_last_o(rl),
        .completion_valid_o(cv),.completion_ready_i(ca),.completion_code_o(code),.completion_id_o(cid),
        .acquire_valid_o(av),.acquire_ready_i(acq_ready),.acquire_allow_o(aa),
        .acquire_type_o(at),.acquire_words_o(aw),.acquire_reply_valid_i(reply),
        .acquire_reply_ready_o(ar),.acquire_code_i(acode),.consumer_release_o(cr),
        .reserved_i(reserved),.slot_valid_i(live),.slot_type_i(kind),.slot_words_i(words),
        .private_address_o(address),.private_data_i(key_data));
    always @(posedge clk)begin
        if(!rst)begin reserved<=0;reply<=0;acode<=0;end
        else begin
            if(reply && ar)reply<=0;
            if(cr)reserved<=0;
            if(av && acq_ready)begin
                reply<=1;
                if(!aa)acode<=9;
                else if(!live)acode<=1;
                else if(kind!=at || words!=aw)acode<=4;
                else begin acode<=0;reserved<=1;end
            end
        end
        if(rst)begin
            cycles<=cycles+1;
            random_reg<={random_reg[30:0],random_reg[31]^random_reg[21]^random_reg[1]^random_reg[0]};
            if(dut.enabled.state_reg==8)launches<=launches+1;
            if(dut.enabled.state_reg==6 && dut.enabled.pair_ready)derivations<=derivations+1;
            if(address>128)$fatal(1,"private address escaped slot bounds");
            if(!rv && dout!==0)$fatal(1,"result visible outside publication");
            if(rv && !reserved)$fatal(1,"result without lease");
            if(cv && code==0 && !reserved)$fatal(1,"success lost terminal ownership");
            if(slot[129]!==32'hcafef00d || slot[130]!==32'hace51234)$fatal(1,"slot guards changed");
            if(dut.enabled.protected_derivation.ram_write_en)
                tracked_ram[dut.enabled.protected_derivation.ram_write_address]=dut.enabled.protected_derivation.ram_write_data;
            if(cycles>0 && cycles%1000000==0)begin
                $display("RSA_ADAPTER_PROGRESS case=%0d cycles=%0d state=%0d",TEST_CASE,cycles,dut.enabled.state_reg);$fflush();
            end
        end
    end
    task tick; @(posedge clk);#1; endtask
    task check_clean;
        if((dut.enabled.modulus_reg|dut.enabled.representative_reg|dut.enabled.exponent_reg|
            dut.enabled.p_reg|dut.enabled.q_reg|dut.enabled.public_exponent_reg)!==0)
            $fatal(1,"adapter key/operand copy survived cleanup");
        if(dut.enabled.arithmetic.result_o!==0 ||
           dut.enabled.arithmetic.modexp_engine.exponent_reg!==0 ||
           dut.enabled.arithmetic.modexp_engine.base_reg!==0 ||
           dut.enabled.arithmetic.modexp_engine.n_reg!==0 ||
           dut.enabled.arithmetic.modexp_engine.montgomery_core.a_reg!==0 ||
           dut.enabled.arithmetic.modexp_engine.montgomery_core.b_reg!==0 ||
           dut.enabled.arithmetic.modexp_engine.montgomery_core.n_reg!==0 ||
           dut.enabled.arithmetic.modexp_engine.montgomery_core.t_reg!==0 ||
           dut.enabled.arithmetic.modexp_engine.montgomery_core.intermediate_reg!==0 ||
           dut.enabled.arithmetic.modexp_engine.montgomery_core.result_o!==0)
            $fatal(1,"arithmetic key/operand/result survived cleanup");
        if(dut.enabled.protected_derivation.private_d_reg!==0 ||
           dut.enabled.protected_derivation.ram_read_data!==0 ||
           dut.enabled.protected_derivation.mult_product!==0)
            $fatal(1,"derivation secret copy survived cleanup");
        for(integer j=0;j<512;j++)if(tracked_ram[j]!==0)$fatal(1,"private RAM not scrubbed %0d",j);
    endtask
    task reset_all;
        @(negedge clk);rst=0;req=0;iv=0;rr=0;ca=0;il=0;
        #1;if(rq || ir || rv || cv || av || cr || dout!==0)$fatal(1,"reset visibility");
        repeat(3)tick();@(negedge clk);rst=1;wait(rq);#1;
        check_clean();if(reserved || cv || rv)$fatal(1,"reset stale lease/result");
        for(integer j=0;j<129;j++)slot[j]=fixture[j];
        live=1;kind=2;words=129;allow=1;op=0;id=32'h12345678;
    endtask
    task launch(input [1:0] operation_value);
        wait(rq);@(negedge clk);op=operation_value;req=1;tick();
        @(negedge clk);req=0;op=3;id=32'hffffffff;
    endtask
    task send_operand(input [2047:0] value,input integer short_at=-1);
        for(integer j=0;j<64;j++)begin
            @(negedge clk);
            while(!ir)@(negedge clk);
            repeat(random_reg[2:0])@(negedge clk);
            din=value[2047-j*32 -:32];iv=1;il=(j==63 || j==short_at);
            tick();@(negedge clk);iv=0;din=0;il=0;
            if(j==short_at)break;
        end
    endtask
    task accept_terminal(input [3:0] expected_code,input [31:0] expected_id=32'h12345678);
        wait(cv);#1;
        if(code!==expected_code || cid!==expected_id || rv)$fatal(1,"terminal mismatch code=%0d expected=%0d id=%h",code,expected_code,cid);
        check_clean();
        repeat(17)begin tick();if(!cv || code!==expected_code || cid!==expected_id)$fatal(1,"held terminal changed");end
        @(negedge clk);ca=1;tick();@(negedge clk);ca=0;wait(rq);#1;
        if(reserved || cv || dut.enabled.result_reg!==0)$fatal(1,"terminal release/erasure");
        checks=checks+1;
    endtask
    task receive_result(input [2047:0] expected_value);
        observed=0;
        for(integer j=0;j<64;j++)begin
            wait(rv);@(negedge clk);rr=0;
            begin reg [31:0] held;held=dout;
                repeat(random_reg[2:0]+1)begin tick();if(!rv || dout!==held || rl!==(j==63))$fatal(1,"result backpressure instability");end
            end
            check_clean();
            @(negedge clk);rr=1;observed={observed[2015:0],dout};tick();@(negedge clk);rr=0;
        end
        if(observed!==expected_value)$fatal(1,"independent full RSA2048 result mismatch");
        accept_terminal(0);
        for(integer j=0;j<129;j++)if(slot[j]!==fixture[j])$fatal(1,"committed slot changed at %0d",j);
    endtask
    initial begin
        $readmemh("slot.hex",fixture);$readmemh("rsa_vectors.hex",vectors);
        slot[129]=32'hcafef00d;slot[130]=32'hace51234;
        reset_all();
        if(TEST_CASE==0)begin
            launch(0);send_operand(vectors[0]);receive_result(vectors[1]);
            reset_all();launch(1);send_operand(vectors[2]);receive_result(vectors[3]);
            if(launches!=2 || derivations!=1)$fatal(1,"unexpected core/derivation dispatch");
        end else if(TEST_CASE==1)begin
            allow=0;launch(1);accept_terminal(9);
            reset_all();launch(2);accept_terminal(10);
            reset_all();live=0;launch(1);accept_terminal(1);
            reset_all();kind=0;words=4;launch(1);accept_terminal(4);
            reset_all();kind=1;words=8;launch(0);accept_terminal(4);
            reset_all();words=128;launch(1);accept_terminal(4);
            reset_all();slot[64]=3;launch(1);send_operand(vectors[0]);accept_terminal(4);
            reset_all();slot[63]=slot[63]&32'hfffffffe;launch(1);send_operand(vectors[0]);accept_terminal(4);
            reset_all();launch(1);send_operand({fixture[0],fixture[1],fixture[2],fixture[3],fixture[4],fixture[5],fixture[6],fixture[7],
                fixture[8],fixture[9],fixture[10],fixture[11],fixture[12],fixture[13],fixture[14],fixture[15],
                fixture[16],fixture[17],fixture[18],fixture[19],fixture[20],fixture[21],fixture[22],fixture[23],
                fixture[24],fixture[25],fixture[26],fixture[27],fixture[28],fixture[29],fixture[30],fixture[31],
                fixture[32],fixture[33],fixture[34],fixture[35],fixture[36],fixture[37],fixture[38],fixture[39],
                fixture[40],fixture[41],fixture[42],fixture[43],fixture[44],fixture[45],fixture[46],fixture[47],
                fixture[48],fixture[49],fixture[50],fixture[51],fixture[52],fixture[53],fixture[54],fixture[55],
                fixture[56],fixture[57],fixture[58],fixture[59],fixture[60],fixture[61],fixture[62],fixture[63]});accept_terminal(12);
            reset_all();launch(0);send_operand(vectors[0],3);accept_terminal(12);
            reset_all();launch(0);wait(ir);accept_terminal(7);
            reset_all();slot[0]=0;launch(1);send_operand(vectors[0]);accept_terminal(4);
            reset_all();launch(0);send_operand({2048{1'b1}});accept_terminal(12);
            reset_all();launch(1);send_operand(vectors[0]);accept_terminal(7);
            reset_all();launch(0);send_operand(vectors[0]);accept_terminal(7);
            if(launches!=1 || derivations!=1)$fatal(1,"unexpected rejection/timeout dispatch");
        end else if(TEST_CASE==2)begin
            for(integer phase=0;phase<6;phase++)begin
                reset_all();launch(phase>=4?0:1);
                if(phase==0)wait(dut.enabled.state_reg==3);
                else if(phase==1)begin
                    wait(ir);
                    for(integer j=0;j<7;j++)begin @(negedge clk);iv=1;din=vectors[0][2047-j*32 -:32];tick();end
                end
                else if(phase==2)begin send_operand(vectors[0]);wait(dut.enabled.protected_derivation.state_reg==37);end
                else if(phase==3)begin send_operand(vectors[0]);wait(dut.enabled.state_reg==9);end
                else begin
                    send_operand(vectors[0]);wait(rv);
                    if(phase==5)begin
                        @(negedge clk);rr=1;repeat(64)tick();@(negedge clk);rr=0;wait(cv);
                    end
                end
                reset_all();checks=checks+1;
            end
        end else if(TEST_CASE==3)begin
            launch(0);send_operand(vectors[0]);wait(dut.enabled.state_reg==9);
            force dut.enabled.core_error=1'b1;
            accept_terminal(11);release dut.enabled.core_error;
            reset_all();slot[1]=slot[1]^32'h100;launch(1);send_operand(vectors[0]);accept_terminal(11);
            reset_all();slot[96]=slot[96]&32'hfffffffe;launch(1);send_operand(vectors[0]);accept_terminal(11);
            // An unacknowledged terminal has a finite ownership lifetime and
            // is withdrawn without a second completion; retry must be clean.
            reset_all();allow=0;id=0;launch(1);wait(cv);#1;
            if(code!==9 || cid!==0)$fatal(1,"zero request ID lost");
            wait(rq);if(cv || reserved)$fatal(1,"terminal expiry did not abandon");
            id=32'h12345678;launch(1);accept_terminal(9);
            checks=checks+1;
        end
        $display("RSA_ADAPTER_PASS case=%0d backend=%0d checks=%0d cycles=%0d",TEST_CASE,IP_TYPE,checks,cycles);$finish;
    end
    initial begin #(64'd3000000000);$fatal(1,"adapter test deadline");end
endmodule
