`timescale 1ns/1ps
// Real full-width keygen -> engine slot -> checked derivation -> team RSA.
// Reproducible public candidate/witness draws: directed correctness only.
module tb_rsa_generated #(parameter IP_TYPE=0);
    reg clk=0;always #5 clk=~clk;
    reg rst=0, kg_req=0,kg_ack=0,destroy=0, req=0,iv=0,il=0,rr=0,ca=0;
    reg [1:0] profile=2, operation=0;
    wire kg_ready,kg_done,slot_valid,rq,ir,rv,rl,cv,random_request;
    wire [3:0] kg_code,code;
    wire [31:0] dout,cid,private_data;
    reg [31:0] din=0;reg [7:0] address=0;
    reg [255:0] random_data=0;reg random_valid=0;
    reg [31:0] stimulus[0:383],expected[0:128];
    reg [2047:0] vectors[0:3],observed;
    integer cursor=0,delay_count=0,cycles=0,checks=0;
    reg [31:0] prng=32'h741cbea9;
    reg aes_req=0,aes_ack=0,aes_finish=0;
    wire aes_ready,aes_reply,aes_reserved;wire [31:0] aes_code;wire [255:0] aes_key;
    reg reuse=0;
    execution_engine #(.ENABLE_INTERNAL_KEYGEN(1),.ENABLE_RSA_SLOT_CONSUMER(1),
        .ENABLE_AES_SLOT_CONSUMER(1),.IP_TYPE(IP_TYPE),.KEYGEN_WAIT_LIMIT(900000000)) dut (
        .clock_i(clk),.reset_n_i(rst),.command_ready_i(1'b0),.command_done_i(1'b1),
        .command_tag_i(16'h8001),.command_code_i(32'd0),.command_size_i(32'd10),.op_state_i(3'd3),
        .command_byte_i(8'd0),.response_addr_i(12'd0),
        .random_i(random_data),.random_valid_i(random_valid),.random_request_o(random_request),.rng_fault_i(1'b0),
        .hash_grant_i(1'b0),.hash_ready_i(1'b0),.hash_digest_i(256'd0),.hash_digest_valid_i(1'b0),
        .keygen_request_i(kg_req),.keygen_ready_o(kg_ready),.keygen_profile_i(profile),.keygen_id_i(32'd42),.keygen_allow_i(1'b1),
        .keygen_completion_o(kg_done),.keygen_completion_ready_i(kg_ack),.keygen_code_o(kg_code),.keygen_release_i(destroy),
        .keygen_slot_valid_o(slot_valid),.keygen_private_address_i(address),.keygen_private_data_o(private_data),
        .keygen_result_enable_i(1'b1),.keygen_ownership_enable_i(1'b1),.keygen_terminal_enable_i(1'b1),
        .aes_slot_request_i(aes_req),.aes_slot_handle_i(32'h81000001),.aes_slot_allow_i(1'b1),
        .aes_slot_request_ready_o(aes_ready),.aes_slot_reply_o(aes_reply),.aes_slot_reply_ready_i(aes_ack),
        .aes_slot_key_o(aes_key),.aes_slot_code_o(aes_code),.aes_slot_release_i(aes_finish),.aes_slot_reserved_o(aes_reserved),
        .rsa_request_valid_i(req),.rsa_request_ready_o(rq),.rsa_request_id_i(32'hace01234),.rsa_allow_i(1'b1),.rsa_operation_i(operation),
        .rsa_operand_valid_i(iv),.rsa_operand_ready_o(ir),.rsa_operand_data_i(din),.rsa_operand_last_i(il),
        .rsa_result_valid_o(rv),.rsa_result_ready_i(rr),.rsa_result_data_o(dout),.rsa_result_last_o(rl),
        .rsa_completion_valid_o(cv),.rsa_completion_ready_i(ca),.rsa_completion_code_o(code),.rsa_completion_id_o(cid));
    always @(posedge clk)begin
        random_valid<=0;
        if(!rst)begin cursor<=0;delay_count<=0;end
        else begin
            cycles<=cycles+1;
            prng<={prng[30:0],prng[31]^prng[21]^prng[1]^prng[0]};
            if(random_request)begin
                if(delay_count==7)begin
                    if(!reuse && cursor>=384)$fatal(1,"public candidate fixture exhausted");
                    for(integer j=0;j<8;j++)random_data[255-j*32 -:32]<=reuse?32'hfedcba00+j:stimulus[cursor+j];
                    cursor<=cursor+8;random_valid<=1;delay_count<=0;
                end else delay_count<=delay_count+1;
            end else delay_count<=0;
            if(dut.kg_reserved && private_data!==0)$fatal(1,"engine fixture read leaked reserved key");
            if(dut.rsa_reserved && aes_reserved)$fatal(1,"dual engine lease");
            if(dut.rsa_reserved && dut.consumer_owner_reg!=2)$fatal(1,"RSA owner lost");
            if(cycles%10000000==0)begin
                $display("RSA_GENERATED_PROGRESS cycles=%0d inputs=%0d state=%0d",cycles,cursor,dut.protected_rsa.enabled.state_reg);$fflush();
            end
        end
    end
    task tick;@(posedge clk);#1;endtask
    task verify_slot;
        if(!slot_valid || kg_ready || dut.kg_reserved)$fatal(1,"slot validity/lifetime");
        for(integer j=0;j<129;j++)begin
            address=j;#1;if(private_data!==expected[j])$fatal(1,"exact generated slot mismatch word=%0d",j);
        end
        address=255;#1;if(private_data!==0)$fatal(1,"slot out-of-range guard");address=0;
        checks=checks+1;
    endtask
    task consume(input [1:0] selected_operation,input [2047:0] representative,input [2047:0] expected_result);
        wait(rq);@(negedge clk);operation=selected_operation;req=1;tick();@(negedge clk);req=0;operation=3;
        wait(ir);
        // Destroy and overwrite requests while reserved must be rejected,
        // without queuing a destructive operation behind terminal status.
        @(negedge clk);destroy=1;kg_req=1;profile=0;
        repeat(3)begin tick();if(!slot_valid || kg_ready || !dut.rsa_reserved)$fatal(1,"reserved slot overwritten/destroyed");end
        @(negedge clk);destroy=0;kg_req=0;
        for(integer j=0;j<64;j++)begin
            repeat(prng[2:0])@(negedge clk);
            @(negedge clk);iv=1;din=representative[2047-j*32 -:32];il=(j==63);tick();
            @(negedge clk);iv=0;din=0;il=0;
        end
        observed=0;
        for(integer j=0;j<64;j++)begin
            wait(rv);@(negedge clk);
            if(j==0)destroy=1;
            begin reg [31:0] held;held=dout;
                repeat(prng[2:0]+1)begin tick();if(!rv || dout!==held || rl!==(j==63) || !dut.rsa_reserved)$fatal(1,"held result/lease");end
            end
            @(negedge clk);observed={observed[2015:0],dout};rr=1;tick();@(negedge clk);rr=0;
            destroy=0;
        end
        if(observed!==expected_result)$fatal(1,"independent exact RSA2048 operation mismatch private=%0d",selected_operation);
        wait(cv);#1;if(code!==0 || cid!==32'hace01234)$fatal(1,"RSA terminal");
        @(negedge clk);destroy=1;
        repeat(23)begin tick();if(!cv || !dut.rsa_reserved || !slot_valid)$fatal(1,"terminal lease lost");end
        @(negedge clk);destroy=0;
        @(negedge clk);ca=1;tick();@(negedge clk);ca=0;wait(rq);#1;
        if(dut.kg_reserved || dut.consumer_owner_reg!=0)$fatal(1,"engine lease not relinquished");
        verify_slot();
    endtask
    initial begin
        $readmemh("stimulus.hex",stimulus);$readmemh("slot.hex",expected);$readmemh("rsa_vectors.hex",vectors);
        repeat(3)@(negedge clk);rst=1;wait(kg_ready);
        @(negedge clk);kg_req=1;@(negedge clk);kg_req=0;
        wait(kg_done);#1;if(kg_code!==0 || cursor!=384)$fatal(1,"full RSA generation failed");
        @(negedge clk);kg_ack=1;tick();@(negedge clk);kg_ack=0;verify_slot();
        // Simultaneous request arbitration: AES gets its denial reply before
        // RSA can acquire. Rejected AES must not lock or read the RSA slot.
        wait(aes_ready && rq);@(negedge clk);aes_req=1;req=1;operation=0;tick();
        @(negedge clk);aes_req=0;req=0;
        wait(aes_reply);#1;if(aes_code!=32'h18b || aes_key!==0 || aes_reserved)$fatal(1,"AES used RSA slot");
        @(negedge clk);aes_ack=1;tick();@(negedge clk);aes_ack=0;aes_finish=1;tick();@(negedge clk);aes_finish=0;
        // Complete the accepted public job on the genuine generated slot.
        wait(ir);
        for(integer j=0;j<64;j++)begin
            @(negedge clk);iv=1;din=vectors[0][2047-j*32 -:32];il=j==63;tick();@(negedge clk);iv=0;il=0;
        end
        observed=0;
        for(integer j=0;j<64;j++)begin wait(rv);@(negedge clk);observed={observed[2015:0],dout};rr=1;tick();@(negedge clk);rr=0;end
        if(observed!==vectors[1])$fatal(1,"composed public value");
        wait(cv);if(code!==0)$fatal(1,"composed public status");@(negedge clk);ca=1;tick();@(negedge clk);ca=0;wait(rq);verify_slot();
        consume(1,vectors[2],vectors[3]);
        @(negedge clk);destroy=1;#1;if(slot_valid || private_data!==0)$fatal(1,"destroy not immediately masked");tick();
        @(negedge clk);destroy=0;wait(kg_ready);#1;
        for(integer j=0;j<129;j++)if(dut.keygen_enabled.protected_keygen.slot[j]!==0)$fatal(1,"slot full erase %0d",j);
        reuse=1;profile=1;@(negedge clk);kg_req=1;tick();@(negedge clk);kg_req=0;
        wait(kg_done);#1;if(kg_code!==0 || !slot_valid)$fatal(1,"generate after full clear");
        for(integer j=0;j<8;j++)begin address=j;#1;if(private_data!==32'hfedcba00+j)$fatal(1,"fresh reuse data");end
        // The new AES slot must reject RSA before operand or arithmetic work.
        @(negedge clk);req=1;operation=1;tick();@(negedge clk);req=0;
        wait(cv);#1;if(code!==4 || ir || rv)$fatal(1,"RSA dispatched AES key");
        @(negedge clk);ca=1;tick();@(negedge clk);ca=0;wait(rq);
        $display("RSA_GENERATED_PASS backend=%0d exact_slot_words=129 source_words=384 operations=2 checks=%0d cycles=%0d",IP_TYPE,checks,cycles);$finish;
    end
    initial begin #(64'd9000000000);$fatal(1,"generated acceptance deadline");end
endmodule
