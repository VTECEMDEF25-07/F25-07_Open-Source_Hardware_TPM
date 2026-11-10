`timescale 1ns/1ps
module tb_demo_memory;
    reg clock_i=0;
    always #5 clock_i=~clock_i;
    reg reset_n_i=0;
    reg reserve_valid_i=0;
    wire reserve_ready_o;
    reg [1:0] reserve_profile_i=0, reserve_mode_i=1;
    reg [31:0] reserve_id_i=0;
    reg reserve_demo_use_i=1;
    wire receiver_ready_o, receiver_error_o, receiver_scrub_done_o;
    wire [3:0] receiver_error_code_o;
    reg abort_i=0, result_valid_i=0;
    wire result_ready_o;
    reg [31:0] result_data_i=0, result_id_i=0;
    reg [2:0] result_component_i=0;
    reg [6:0] result_index_i=0;
    reg result_component_last_i=0, result_last_i=0, result_discard_i=0;
    reg decision_valid_i=0, decision_accept_i=1, ownership_ready_i=0;
    wire decision_ready_o, ownership_valid_o, ownership_accept_o;
    wire commit_valid_o;
    reg commit_ready_i=0;
    wire [31:0] commit_handle_o, commit_id_o;
    wire [1:0] commit_mode_o;
    reg release_valid_i=0;
    wire release_ready_o;
    reg [31:0] release_handle_i=0;
    wire release_rsp_valid_o;
    reg release_rsp_ready_i=0;
    wire [31:0] release_rsp_code_o;
    reg key_request_i=0;
    wire key_request_ready_o;
    reg [31:0] key_handle_i=0;
    wire key_reply_valid_o;
    reg key_reply_ready_i=0;
    wire [255:0] resolved_key_o;
    wire [31:0] key_reply_code_o;
    reg use_allowed_i=1, client_active_i=0;
    demo_volatile_store store (.*);

    reg m_valid=0, m_write=0, m_rsp_ready=0, m_allowed=1;
    reg [11:0] m_addr=0;
    reg [7:0] m_wdata=0;
    wire m_ready, m_rsp_valid, m_error;
    wire [7:0] m_rdata;
    reg clear_valid=0, clear_done_ready=0;
    wire clear_ready, clear_done, ram_scrubbed;
    demo_byte_ram ram (
        .clock_i(clock_i), .reset_n_i(reset_n_i),
        .ram_req_valid_i(m_valid), .ram_req_ready_o(m_ready),
        .ram_req_write_i(m_write), .ram_req_addr_i(m_addr), .ram_req_wdata_i(m_wdata),
        .ram_rsp_valid_o(m_rsp_valid), .ram_rsp_ready_i(m_rsp_ready),
        .ram_rsp_rdata_o(m_rdata), .ram_rsp_error_o(m_error), .access_allowed_i(m_allowed),
        .clear_valid_i(clear_valid), .clear_ready_o(clear_ready),
        .clear_done_valid_o(clear_done), .clear_done_ready_i(clear_done_ready),
        .scrub_done_o(ram_scrubbed)
    );
    integer checks=0, transactions=0, cases=0, i, j, n, cycles, seed=1, random_init;
    reg [31:0] h, h2;
    reg [255:0] expected_key;
    reg [7:0] model [0:1023];
    task tick;
        begin @(posedge clock_i); #1; end
    endtask
    task ck(input bit condition, input string reason);
        begin
            checks=checks+1;
            if (!condition) $fatal(1,"FAIL %s time=%0t",reason,$time);
        end
    endtask
    task wait_empty;
        integer timeout;
        begin
            timeout=0;
            while (!reserve_ready_o && timeout<140) begin tick; timeout=timeout+1; end
            ck(reserve_ready_o,"store bounded readiness");
        end
    endtask
    task physical_store_zero;
        integer a;
        begin
            ck(receiver_scrub_done_o,"store scrub done");
            for (a=0;a<129;a=a+1) ck(store.words[a]===32'd0,"all protected slots zero");
            ck(store.key_reply_data===256'd0,"internal key reply latch zero");
        end
    endtask
    task reserve(input [1:0] p, input [31:0] id, input bit permission);
        begin
            wait_empty;
            reserve_profile_i=p; reserve_id_i=id; reserve_demo_use_i=permission;
            reserve_valid_i=1; tick; reserve_valid_i=0;
            ck(receiver_ready_o,"receiver prepared after reserve");
            ck(!key_request_ready_o,"no lookup during reservation");
        end
    endtask
    // Test stream is independently described by component lengths, not DUT counters.
    task stream(input integer p, input integer id, input integer bad_field);
        integer c,a,length_c,last_c;
        reg [31:0] d;
        begin
            last_c=(p==2)?5:1;
            for(c=(p==2?2:1);c<=last_c;c=c+1) begin
                if(p!=2) length_c=(p==0)?4:8;
                else case(c) 2:length_c=64; 3:length_c=1; default:length_c=32; endcase
                for(a=0;a<length_c;a=a+1) begin
                    repeat($urandom_range(0,2)) tick;
                    result_component_i=c; result_index_i=a;
                    result_component_last_i=a==length_c-1;
                    result_last_i=(c==last_c && a==length_c-1);
                    result_id_i=id;
                    d=(p==2 && c==3)?32'h00010001:(32'ha5000000 | (c<<12) | a);
                    result_data_i=d;
                    if(p==1) expected_key[255-a*32 -:32]=d;
                    // Inject on first word except exponent corruption.
                    if(c==(p==2?2:1) && a==0) begin
                        case(bad_field)
                            1:result_id_i=id+1;
                            2:result_component_i=7;
                            3:result_index_i=1;
                            4:result_component_last_i=1;
                            5:result_last_i=1;
                        endcase
                    end
                    if(bad_field==6 && c==3) result_data_i=32'd3;
                    if(bad_field==7 && c==last_c && a==length_c-1) result_last_i=0;
                    if(bad_field==8 && c==last_c && a==length_c-1) result_component_last_i=0;
                    result_valid_i=1;
                    ck(result_ready_o,"stream word ready");
                    tick; result_valid_i=0;
                    if(receiver_error_o) return;
                end
            end
            ck(!result_ready_o && receiver_ready_o,"complete stage still prepared");
            ck(!commit_valid_o && !key_request_ready_o,"complete stage not yet owned");
        end
    endtask
    task decide(input bit accept_it, output reg [31:0] got_handle);
        integer a;
        begin
            decision_accept_i=accept_it; decision_valid_i=1; ownership_ready_i=0;
            #1;
            for(a=0;a<4;a=a+1) begin
                ck(ownership_valid_o && !decision_ready_o,"ownership stalls, not lost"); tick;
            end
            ownership_ready_i=1; #1; ck(decision_ready_o,"ownership ready");
            tick; decision_valid_i=0; ownership_ready_i=0;
            if(accept_it) begin
                ck(commit_valid_o,"ownership creates commit");
                got_handle=commit_handle_o;
                ck(commit_id_o==reserve_id_i && commit_mode_o==reserve_mode_i,"commit metadata");
                for(a=0;a<4;a=a+1) begin
                    ck(commit_valid_o && commit_handle_o==got_handle,"commit held");
                    ck(!key_request_ready_o && !release_ready_o,"commit report blocks competing access"); tick;
                end
                commit_ready_i=1; tick; commit_ready_i=0;
            end else begin
                got_handle=0; ck(!commit_valid_o,"rejection has no commit");
                wait_empty; physical_store_zero;
            end
        end
    endtask
    task lookup(input [31:0] kh, input [31:0] code, input bit allowed);
        integer a;
        reg [255:0] saved;
        begin
            key_handle_i=kh; use_allowed_i=allowed; key_request_i=1;
            #1; ck(key_request_ready_o,"lookup admissible");
            tick; key_request_i=0;
            ck(key_reply_valid_o && key_reply_code_o==code,"registered lookup reply code");
            if(code==0) ck(resolved_key_o===expected_key,"AES MSW-first exact key");
            else ck(resolved_key_o===256'd0,"denied key zero");
            saved=resolved_key_o; key_handle_i=0; use_allowed_i=!allowed;
            for(a=0;a<5;a=a+1) begin
                ck(key_reply_valid_o && resolved_key_o===saved && key_reply_code_o==code,"lookup stable under stall");
                ck(!key_request_ready_o && !release_ready_o,"one outstanding lookup"); tick;
            end
            key_reply_ready_i=1; tick; key_reply_ready_i=0;
            ck(!key_reply_valid_o && resolved_key_o===0 && store.key_reply_data===0,"consumed key erased");
        end
    endtask
    task release_object(input [31:0] kh, input [31:0] code);
        integer a;
        begin
            release_handle_i=kh; release_valid_i=1;
            #1; ck(release_ready_o,"release admitted"); tick; release_valid_i=0;
            a=0;
            while(!release_rsp_valid_o && a<132) begin
                ck(!key_request_ready_o,"no lookup during release scrub"); tick; a=a+1;
            end
            ck(release_rsp_valid_o && release_rsp_code_o==code,"release reply bounded/code");
            if(code==0) physical_store_zero;
            repeat(3) begin tick; ck(release_rsp_valid_o && release_rsp_code_o==code,"release reply held"); end
            release_rsp_ready_i=1; tick; release_rsp_ready_i=0;
        end
    endtask
    task abort_stage;
        integer a;
        begin
            abort_i=1; result_discard_i=1; tick;
            a=0;
            while(!receiver_scrub_done_o && a<132) begin tick; a=a+1; end
            physical_store_zero;
            repeat(3) begin tick; ck(!reserve_ready_o && receiver_scrub_done_o,"scrub ack independent of held discard"); end
            ck(!commit_valid_o,"abort has no commit");
            abort_i=0; result_discard_i=0; wait_empty;
        end
    endtask
    task reset_all;
        begin
            reset_n_i=0; #1;
            ck(!reserve_ready_o && !result_ready_o && !ownership_valid_o && !commit_valid_o &&
                !key_reply_valid_o && resolved_key_o===0 && !m_ready && !m_rsp_valid && !clear_done,"reset suppresses all transfers");
            reserve_valid_i=0; result_valid_i=0; decision_valid_i=0; ownership_ready_i=0;
            commit_ready_i=0; key_request_i=0; key_reply_ready_i=0; release_valid_i=0;
            release_rsp_ready_i=0; client_active_i=0; abort_i=0; result_discard_i=0;
            m_valid=0; m_rsp_ready=0; clear_valid=0; clear_done_ready=0;
            repeat(3) tick;
            reset_n_i=1; wait_empty; physical_store_zero;
        end
    endtask
    task mem_transaction(input integer addr, input bit wr, input [7:0] data,
                         input bit permission, input integer stalls);
        integer a;
        reg [7:0] want;
        bit err;
        begin
            while(!m_ready) tick;
            m_valid=1; m_write=wr; m_addr=addr; m_wdata=data; m_allowed=permission;
            err=!permission || addr>=1024;
            want=(err || wr)?0:model[addr];
            tick; m_valid=0;
            ck(m_rsp_valid && m_error===err && m_rdata===want,"RAM registered response/reference");
            ck(ram.response_data===want,"physical synchronous read latch matches reply");
            if(!err && wr) model[addr]=data;
            // Permission/address may change after request, not response contents.
            m_allowed=!permission; m_addr=4095; m_wdata=~data;
            for(a=0;a<stalls;a=a+1) begin
                ck(!m_ready && !clear_ready,"RAM response blocks request and clear");
                tick; ck(m_rsp_valid && m_error===err && m_rdata===want,"RAM response stable");
                ck(ram.response_data===want,"physical read latch freezes under reply stall");
            end
            m_rsp_ready=1; tick; m_rsp_ready=0;
            ck(!m_rsp_valid && m_rdata===0 && ram.response_data===0,"RAM response latch erased");
            transactions=transactions+1;
        end
    endtask
    task clear_ram;
        integer a;
        begin
            while(!clear_ready) tick;
            clear_valid=1; m_valid=1; m_write=1; m_addr=0; m_wdata=8'hff; m_allowed=1;
            #1; ck(!m_ready && clear_ready,"clear wins concurrent byte request");
            tick; clear_valid=0; m_valid=0;
            a=0;
            while(!clear_done && a<1027) begin
                ck(!m_ready && !m_rsp_valid,"no traffic while clearing"); tick; a=a+1;
            end
            ck(clear_done && ram_scrubbed && a<=1026,"bounded byte sweep done");
            ck(ram.response_data===0 && ram.bytes[1024]===0,"clear physically refreshes read latch and zero sentinel");
            for(a=0;a<1024;a=a+1) begin
                ck(ram.bytes[a]===0,"all byte RAM physically zero"); model[a]=0;
            end
            repeat(3) begin tick; ck(clear_done && !m_ready,"clear completion held"); end
            clear_done_ready=1; tick; clear_done_ready=0;
        end
    endtask

    initial begin
        if ($value$plusargs("SEED=%d",seed)) begin end
        random_init=$urandom(seed);
        for(i=0;i<1024;i=i+1) model[i]=0;
        reset_all; cases=cases+1;
        lookup(32'h80000001,32'h18b,1);
        // Early decisions cannot accept partial staging.
        reserve(1,42,1); decision_valid_i=1; ownership_ready_i=1;
        repeat(3) begin tick; ck(!ownership_valid_o && !decision_ready_o,"early ownership withheld"); end
        decision_valid_i=0; ownership_ready_i=0;
        stream(1,42,0); decide(1,h); ck(h==32'h80000001,"first handle incarnation");
        lookup(h,0,1); lookup(h,32'h12f,0); lookup(h+1,32'h18b,1);
        release_object(h+1,32'h18b); lookup(h,0,1);
        // An owned object survives source discard/abort, until explicit release.
        abort_i=1; result_discard_i=1; repeat(3) tick; abort_i=0; result_discard_i=0;
        lookup(h,0,1);
        client_active_i=1; release_handle_i=h; release_valid_i=1; #1;
        repeat(4) begin ck(!release_ready_o,"lease prevents release"); tick; end
        release_valid_i=0; client_active_i=0;
        release_object(h,0); lookup(h,32'h18b,1); cases=cases+1;
        reserve(0,43,1); stream(0,43,0); decide(1,h2);
        ck(h2==h+1,"incarnation progresses"); lookup(h2,32'h12f,1); release_object(h2,0); cases=cases+1;
        reserve(1,44,0); stream(1,44,0); decide(1,h2);
        lookup(h2,32'h12f,1); release_object(h2,0); cases=cases+1;
        reserve(2,45,1); stream(2,45,0);
        ck(store.words[64]===32'h10001,"RSA exponent slot");
        ck(store.words[63]===32'ha500203f && store.words[65]===32'ha5004000 &&
           store.words[128]===32'ha500501f,"RSA component placements");
        decide(1,h2); lookup(h2,32'h12f,1); release_object(h2,0); cases=cases+1;
        reserve(1,46,1); stream(1,46,0); decide(0,h2); cases=cases+1;
        // Incomplete stage, final-word fault and decision-edge fault all discard.
        reserve(1,47,1); result_valid_i=1; result_id_i=47; result_component_i=1;
        result_index_i=0; result_component_last_i=0; result_last_i=0; tick; result_valid_i=0;
        abort_stage; cases=cases+1;
        reserve(1,48,1); stream(1,48,0);
        decision_valid_i=1; ownership_ready_i=1; abort_i=1; #1;
        ck(!ownership_valid_o && !decision_ready_o,"fault beats ownership same edge");
        tick; decision_valid_i=0; ownership_ready_i=0; abort_stage; cases=cases+1;
        reserve(0,49,1);
        for(i=0;i<3;i=i+1) begin
            result_valid_i=1; result_id_i=49; result_component_i=1; result_index_i=i;
            result_component_last_i=0; result_last_i=0; tick;
        end
        result_index_i=3; result_component_last_i=1; result_last_i=1; abort_i=1; #1;
        ck(!result_ready_o,"fault beats final result transfer"); tick; result_valid_i=0; abort_stage; cases=cases+1;
        for(j=1;j<=8;j=j+1) begin
            reserve(j==6?2:1,50+j,1); stream(j==6?2:1,50+j,j);
            ck(receiver_error_o && receiver_error_code_o==7,"malformed staging detected");
            abort_stage; cases=cases+1;
        end
        // Invalid reservation is accepted then reports an explicit bounded error.
        wait_empty; reserve_profile_i=3; reserve_valid_i=1; tick; reserve_valid_i=0;
        ck(receiver_error_o && receiver_error_code_o==1,"invalid profile error"); abort_stage;
        wait_empty; reserve_profile_i=1; reserve_mode_i=2; reserve_valid_i=1; tick; reserve_valid_i=0;
        ck(receiver_error_o,"invalid mode error"); reserve_mode_i=1; abort_stage; cases=cases+1;
        reserve(1,70,1); stream(1,70,0); decide(1,h);
        key_handle_i=h; use_allowed_i=1; key_request_i=1; tick; key_request_i=0;
        ck(key_reply_valid_o,"pre-reset held key"); reset_all; lookup(h,32'h18b,1); cases=cases+1;
        // Reset exactly on ownership edge suppresses commit; no numerical-handle persistence claim.
        reserve(1,71,1); stream(1,71,0); decision_valid_i=1; ownership_ready_i=1;
        reset_all; ck(!commit_valid_o,"reset at ownership has no commit"); cases=cases+1;
        reserve(1,72,1); stream(1,72,0); decision_valid_i=1; ownership_ready_i=1; tick;
        ck(commit_valid_o,"commit before reset"); reset_all; ck(!commit_valid_o,"full reset clears pending commit"); cases=cases+1;
        // Reserved versus lookup priority must not drop an acknowledged lookup.
        reserve_profile_i=1; reserve_id_i=73; reserve_valid_i=1; key_request_i=1; #1;
        ck(reserve_ready_o && !key_request_ready_o,"reserve lookup priority");
        tick; reserve_valid_i=0; key_request_i=0; abort_stage; cases=cases+1;
        // Exhaustion rejects readmission, never wraps a session handle.
        reserve(0,74,1); stream(0,74,0); store.incarnation=31'h7fffffff;
        decide(1,h); ck(h==32'hffffffff,"last incarnation"); release_object(h,0);
        repeat(3) tick; ck(!reserve_ready_o,"no handle wrap"); reset_all; cases=cases+1;

        while(!m_ready) tick;
        mem_transaction(0,1,8'h5a,1,5); mem_transaction(1023,1,8'ha5,1,0);
        mem_transaction(0,0,0,1,3); mem_transaction(1023,0,0,1,3);
        mem_transaction(1024,1,8'hcc,1,2); mem_transaction(4095,0,0,1,2);
        mem_transaction(0,1,8'hcc,0,4); mem_transaction(0,0,0,1,1);
        mem_transaction(1023,0,0,0,2);
        for(i=0;i<180;i=i+1) mem_transaction($urandom_range(0,1100),$urandom_range(0,1),
            $urandom,$urandom_range(0,4)!=0,$urandom_range(0,5));
        clear_ram; mem_transaction(0,0,0,1,0); mem_transaction(1023,0,0,1,0); cases=cases+1;
        // Reset outstanding byte response and restart full physical sweep.
        m_allowed=1; m_valid=1; m_write=1; m_addr=16; m_wdata=8'hfe; tick; m_valid=0;
        ck(m_rsp_valid,"pending RAM reply before reset"); reset_all;
        while(!m_ready) tick;
        for(i=0;i<1024;i=i+1) begin ck(ram.bytes[i]===0,"RAM zero after reset"); model[i]=0; end
        ck(!m_rsp_valid && ram.response_data===0,"no stale RAM reply after reset");
        mem_transaction(16,1,8'hfa,1,2);
        m_allowed=1; m_valid=1; m_write=0; m_addr=16; tick; m_valid=0;
        ck(m_rsp_valid && ram.response_data===8'hfa,"nonzero read latch before reset");
        reset_all; while(!m_ready) tick;
        ck(ram.response_data===0 && ram.bytes[1024]===0,"reset sweep physically refreshes retained RAM read latch");
        model[16]=0; cases=cases+1;
        clear_valid=1; tick; clear_valid=0; repeat(20) tick; reset_all;
        while(!m_ready) tick; ck(!clear_done,"reset aborts clear completion");
        mem_transaction(16,0,0,1,4); cases=cases+1;
        // Reset during incomplete staging, rejection scrub and pending release response.
        reserve(0,80,1); result_valid_i=1; result_id_i=80; result_component_i=1;
        result_index_i=0; result_component_last_i=0; result_last_i=0; tick; result_valid_i=0;
        reset_all; cases=cases+1;
        reserve(1,81,1); stream(1,81,0);
        decision_valid_i=1; decision_accept_i=0; ownership_ready_i=1; tick;
        decision_valid_i=0; ownership_ready_i=0; repeat(20) tick;
        reset_all; cases=cases+1;
        reserve(0,82,1); stream(0,82,0); decide(1,h);
        release_handle_i=h; release_valid_i=1; tick; release_valid_i=0;
        while(!release_rsp_valid_o) tick;
        reset_all; ck(!release_rsp_valid_o,"reset clears held release report"); cases=cases+1;
        // Storage preserves experimental-fresh provenance without asserting entropy quality.
        reserve_mode_i=0; reserve(1,83,1); stream(1,83,0); decide(1,h);
        ck(commit_mode_o==0,"fresh provenance retained"); release_object(h,0);
        reserve_mode_i=1; cases=cases+1;
        $display("PASS demo_memory cases=%0d checks=%0d byte_transactions=%0d",cases,checks,transactions);
        $finish;
    end
    initial begin #10000000; $fatal(1,"testbench watchdog"); end
endmodule
