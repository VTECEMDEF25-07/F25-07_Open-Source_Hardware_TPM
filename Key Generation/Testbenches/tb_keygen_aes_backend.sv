// AI-authored controller regression. Synthetic words; no payload logs/waves.
`timescale 1ns/1ps
module tb_keygen_aes_backend;
    reg clock=0; always #5 clock=~clock;
    reg reset_n=0, req_valid=0, cancel_valid=0, rsp_ready=0;
    reg [31:0] req_id=7,req_context=11,req_destination=12,req_exponent=0,cancel_id=7;
    reg [1:0] req_alg=1,req_mode=0;
    reg [11:0] req_bits=128;
    wire req_ready,cancel_ready,rsp_valid,rsp_fail,busy,health_fault;
    wire [31:0] rsp_id,rsp_code,rsp_object;
    wire [7:0] health_status;
    reg [31:0] rng_data=0;
    reg rng_valid=0,rng_error=0,store_available=1,store_error=0;
    wire rng_ready,store_begin_valid,store_data_valid,store_data_last;
    reg store_begin_ready=0,store_data_ready=0,store_finish_ready=0;
    wire [31:0] store_begin_id,store_begin_context,store_begin_destination;
    wire [1:0] store_begin_alg;
    wire [11:0] store_begin_key_bits,store_data_bits;
    wire [31:0] store_data_id,store_data_word,store_finish_id;
    wire [3:0] store_data_component;
    wire [6:0] store_data_index;
    wire store_finish_valid,store_finish_abort,store_rsp_ready;
    reg store_rsp_valid=0;
    reg [31:0] store_rsp_id=7,store_rsp_object=0;
    reg [7:0] store_rsp_status=0;
    keygen_aes_backend dut(.*);

    // Test-only staged sink. No commit becomes visible before accepted ack.
    reg [255:0] staged=0, committed=0;
    integer count=0, begins=0, finishes=0, rng_count=0;
    reg transaction=0, finalizing=0, model_abort=0;
    integer manifest_words=0;
    always @(posedge clock or negedge reset_n) begin
        if(!reset_n) begin
            staged<=0; committed<=0; count<=0; begins<=0; finishes<=0;
            transaction<=0; finalizing<=0; model_abort<=0; rng_count<=0;
        end else begin
            if(rng_valid && rng_ready) rng_count<=rng_count+1;
            if(store_begin_valid && store_begin_ready) begin
                if(transaction)$fatal(1,"duplicate store begin");
                transaction<=1; begins<=begins+1; count<=0; staged<=0;
                manifest_words<=store_begin_key_bits/32;
                if(store_begin_id!==7 || store_begin_context!==11 ||
                   store_begin_destination!==12 || store_begin_alg!==1)
                    $fatal(1,"store descriptor not captured");
            end
            if(store_data_valid && store_data_ready) begin
                if(!transaction || finalizing || store_data_index!==count ||
                   store_data_component!==1 || store_data_id!==7 ||
                   store_data_bits/32!=manifest_words ||
                   store_data_last!==(count==manifest_words-1) ||
                   store_data_word!==(32'h01234560+count))
                    $fatal(1,"staged manifest/order mismatch");
                staged<={staged[223:0],store_data_word}; count<=count+1;
            end
            if(store_finish_valid && store_finish_ready) begin
                if(!transaction || finalizing)$fatal(1,"invalid store finish");
                if(!store_finish_abort && count!=manifest_words)$fatal(1,"partial key commit");
                if(dut.worker.key_material!==0)$fatal(1,"finish before worker clearing");
                finishes<=finishes+1; finalizing<=1; model_abort<=store_finish_abort;
            end
            if(store_rsp_valid && store_rsp_ready && finalizing) begin
                // A failed/malformed acknowledgment intentionally proves no outcome.
                if(store_rsp_id==7 && store_rsp_status==0) begin
                    if(!model_abort) committed<=staged;
                    staged<=0; transaction<=0; finalizing<=0;
                end
            end
        end
    end
    task tick; begin @(posedge clock); #1; end endtask
    task reset; begin
        reset_n=0; req_valid=0;cancel_valid=0;rsp_ready=0;rng_valid=0;rng_error=0;
        store_available=1;store_error=0;store_begin_ready=0;store_data_ready=0;
        store_finish_ready=0;store_rsp_valid=0;store_rsp_id=7;
        store_rsp_status=0;store_rsp_object=0;req_id=7;req_alg=1;req_mode=0;
        req_context=11;req_destination=12;req_exponent=0;cancel_id=7;
        tick;reset_n=1;tick;
    end endtask
    task launch(input integer bits); begin
        req_bits=bits;req_valid=1;#1;if(!req_ready)$fatal(1,"backend not ready");tick;
        if(!store_begin_valid || rng_ready)$fatal(1,"begin/launch order");
    end endtask
    task open_store; begin
        repeat(2)tick;store_begin_ready=1;tick;store_begin_ready=0;tick;
        if(!rng_ready)$fatal(1,"worker not launched after store begin");
    end endtask
    task words(input integer n);integer i;begin
        for(i=0;i<n;i=i+1)begin
            rng_data=32'h01234560+i;rng_valid=1;
            if(!rng_ready)$fatal(1,"RNG count/readiness");tick;rng_valid=0;
            if(i<n-1)tick;
        end
    end endtask
    task data(input integer n);integer i;reg [31:0] held;begin
        for(i=0;i<n;i=i+1)begin
            if(!store_data_valid)$fatal(1,"missing data");held=store_data_word;
            repeat(2)begin tick;if(store_data_word!==held)$fatal(1,"stalled data changed");end
            store_data_ready=1;tick;store_data_ready=0;
        end
        tick;if(!store_finish_valid)$fatal(1,"no finish after worker cleanup");
    end endtask
    task finish(input bit abort_expected);begin
        if(!store_finish_valid || store_finish_abort!==abort_expected)$fatal(1,"wrong finish disposition");
        repeat(2)tick;if(rsp_valid)$fatal(1,"result before finalize accepted");
        store_finish_ready=1;tick;store_finish_ready=0;
        repeat(3)tick;if(rsp_valid)$fatal(1,"result before store acknowledgment");
    end endtask
    task ack(input bit fail_expected,input integer status,input integer object_ref);begin
        store_rsp_status=status;store_rsp_object=object_ref;store_rsp_valid=1;tick;store_rsp_valid=0;
        if(!rsp_valid || rsp_fail!==fail_expected || rsp_id!==7 ||
           (fail_expected && (rsp_code==0 || rsp_object!=0)) ||
           (!fail_expected && (rsp_code!=0 || rsp_object!=object_ref)))$fatal(1,"backend terminal mismatch");
        if(dut.worker.key_material!==0)$fatal(1,"terminal local material remains");
    end endtask
    task cancel;begin cancel_valid=1;#1;if(!cancel_ready)$fatal(1,"cancel not accepted");tick;cancel_valid=0;end endtask
    task await_finish;integer n;begin
        n=0;while(!store_finish_valid && n<10)begin tick;n=n+1;end
        if(!store_finish_valid)$fatal(1,"cleanup timeout");
    end endtask
    integer j;
    initial begin
        reset;launch(128);open_store;words(4);data(4);finish(0);ack(0,0,32'h55);
        if(rng_count!=4 || count!=4 || committed==0 || staged!=0)$fatal(1,"AES128 commit accounting");
        // Published success is immutable, independent late health prevents reuse.
        rng_error=1;tick;if(rsp_fail || rsp_object!=32'h55 || !health_fault)$fatal(1,"late health rewrote success");
        rsp_ready=1;tick;rsp_ready=0;req_valid=0;rng_error=0;tick;
        if(req_ready)$fatal(1,"health quarantine bypassed");
        reset;launch(256);req_bits=128;req_context=99;req_destination=99;req_id=99;
        open_store;words(8);data(8);finish(0);ack(0,0,32'h66);
        rsp_ready=1;tick;rsp_ready=0;repeat(3)tick;
        if(req_ready||begins!=1)$fatal(1,"held request retriggered");
        req_valid=0;tick;req_id=7;req_context=11;req_destination=12;
        launch(128);open_store;words(4);data(4);finish(0);ack(0,0,32'h77);
        if(committed[255:128]!==0 || begins!=2)$fatal(1,"256 to128 stale padding");
        $display("PASS AES128/256 transaction counts/order/latching/stalls/commit/rearm/health");

        reset;launch(128);cancel;
        if(!rsp_valid || !rsp_fail || begins!=0 || rng_count!=0)$fatal(1,"cancel before begin made side effect");
        reset;launch(128);store_begin_ready=1;tick;store_begin_ready=0;cancel;
        await_finish;finish(1);ack(1,0,0);
        if(rng_count!=0||staged!=0||transaction)$fatal(1,"preworker abort cleanup");
        for(j=0;j<3;j=j+1)begin
            reset;launch(128);open_store;
            if(j==0)words(2); else words(4);
            if(j==2)begin store_data_ready=1;tick;store_data_ready=0;end
            cancel;await_finish;finish(1);ack(1,0,0);
            if(staged!=0 || committed!=0 || transaction || health_fault)$fatal(1,"cancel rollback not acknowledged");
        end
        $display("PASS cancel before begin/work, collect/output and partial staged rollback");

        reset;launch(128);open_store;words(4);data(4);
        // Cancellation on offered commit converts to abort before acceptance.
        cancel_valid=1;store_finish_ready=1;#1;
        if(!store_finish_abort)$fatal(1,"cancel-edge commit survived");tick;
        cancel_valid=0;store_finish_ready=0;ack(1,0,0);
        reset;launch(128);open_store;words(4);data(4);finish(0);
        cancel_valid=1;#1;if(cancel_ready)$fatal(1,"cancel after commit promised rollback");
        ack(0,0,32'h88);cancel_valid=0;
        $display("PASS commit/cancel boundary and defined too-late cancellation");

        reset;launch(128);open_store;words(3);rng_error=1;rng_valid=1;#1;
        if(rng_ready||store_data_valid)$fatal(1,"fault-edge transfer");tick;rng_valid=0;
        await_finish;finish(1);ack(1,0,0);
        if(!health_fault||staged!=0)$fatal(1,"RNG fault cleanup/quarantine");
        reset;launch(128);open_store;words(4);store_data_ready=1;tick;store_data_ready=0;
        store_error=1;tick;await_finish;finish(1);ack(1,0,0);
        if(staged!=0||!health_fault)$fatal(1,"store fault rollback");
        reset;launch(128);open_store;words(4);data(4);finish(0);ack(1,1,0);
        if(!health_fault)$fatal(1,"failed commit not quarantined");
        reset;launch(128);open_store;words(4);data(4);finish(0);store_rsp_id=99;ack(1,0,32'h99);
        if(!health_fault)$fatal(1,"wrong ID not quarantined");
        reset;launch(128);open_store;words(4);data(4);finish(0);rng_error=1;ack(1,0,32'haa);
        if(!health_fault || committed==0)$fatal(1,"postcommit fault falsely implied rollback");
        $display("PASS RNG/store faults, failed/mismatched commit and uncertain durable outcome");

        reset;req_bits=2048;req_alg=2;req_exponent=65537;req_valid=1;tick;
        if(!rsp_valid||!rsp_fail||rsp_code!==32'h143||begins!=0||rng_count!=0)$fatal(1,"RSA routed to AES");
        reset;store_available=0;req_valid=1;repeat(3)tick;
        if(req_ready||busy||begins)$fatal(1,"unreconciled store launched");
        reset;launch(128);open_store;words(4);store_data_ready=1;tick;store_data_ready=0;
        reset_n=0;#1;if(store_data_valid||store_data_word!=0||rsp_valid||rng_ready)$fatal(1,"reset transfer");
        tick;reset_n=1;req_valid=1;store_available=0;repeat(2)tick;
        if(staged!=0||dut.worker.key_material!=0||req_ready)$fatal(1,"reset clearing/reconciliation");
        store_available=1;repeat(2)tick;if(req_ready||busy)$fatal(1,"held request replayed across reset");
        reset;req_id=32'hxxxxxxxx;req_bits=128;req_valid=1;tick;
        if(!rsp_valid||rsp_id!==0||!rsp_fail||begins||rng_count)$fatal(1,"unknown metadata accepted");
        reset;launch(128);store_begin_ready=1;store_rsp_valid=1;tick;store_rsp_valid=0;
        if(!rsp_valid||!health_fault||begins||rng_count)$fatal(1,"early acknowledgment satisfied begin");
        // Reset invalidates collect, pending commit, and accepted-commit wait.
        for(j=0;j<3;j=j+1)begin
            reset;launch(128);open_store;
            if(j==0)words(2);else begin words(4);data(4);end
            if(j==2)finish(0);
            reset_n=0;#1;tick;reset_n=1;store_available=0;repeat(2)tick;
            if(rsp_valid||rng_ready||store_data_valid||store_finish_valid||staged!=0||
               dut.worker.key_material!=0)$fatal(1,"reset phase invalidation failed");
            store_available=1;repeat(2)tick;
            if(req_ready||busy)$fatal(1,"reset replay across phase");
        end
        $display("PASS unsupported/unknown metadata, premature ack, recovery and phase resets");
        $display("PASS ALL AES backend controller tests (test-only store/RNG)");$finish;
    end
    initial begin #30000;$fatal(1,"global timeout");end
endmodule
