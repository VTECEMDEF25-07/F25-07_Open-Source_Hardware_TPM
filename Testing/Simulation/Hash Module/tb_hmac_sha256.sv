`timescale 1ns/1ps
module tb_hmac_sha256;
    reg clk=0;
    always #5 clk=~clk;
    reg reset_n=0, start=0;
    reg [7:0] key_data=0, message_data=0;
    reg key_valid=0, key_end=0, message_valid=0, message_end=0, digest_ready=0;
    wire key_ready, message_ready, busy, digest_valid;
    wire [255:0] digest_out;
    wire request_valid, request_grant, hash_data_valid, hash_message_end, hash_data_ready;
    wire [7:0] hash_data;
    wire [255:0] hash_digest;
    wire hash_digest_valid, hash_digest_ready;
    hmac_sha256 dut(.*);

    reg [1:0] request;
    wire [1:0] grant, ready, valid;
    wire [255:0] shared_digest;
    reg raw_request=0, raw_active=0;
    reg [1:0] raw_index=0;
    integer cycles=0, raw_results=0, sha_calls=0, cases=0;
    wire [7:0] raw_data = raw_index==0 ? 8'h61 : raw_index==1 ? 8'h62 : 8'h63;
    // A higher-priority raw client competes with each stage of HMAC.
    always @* request = {request_valid && cycles%5 != 0,raw_request};
    assign request_grant = grant[1];
    assign hash_data_ready = ready[1];
    assign hash_digest = shared_digest;
    assign hash_digest_valid = valid[1];
    hash_engine #(.REQUESTERS(2)) engine (
        .clk(clk), .reset_n(reset_n), .request_valid(request), .request_grant(grant),
        .data_in({hash_data,raw_data}), .data_valid({hash_data_valid,raw_active}),
        .message_end({hash_message_end,raw_active && raw_index==2}), .data_ready(ready),
        .digest_out(shared_digest), .digest_valid(valid),
        .digest_ready({hash_digest_ready,1'b1}), .busy()
    );
    reg held=0;
    reg [9:0] held_stream;
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            cycles <= 0;
            raw_request <= 0;
            raw_active <= 0;
            raw_index <= 0;
            held <= 0;
        end else begin
            cycles <= cycles+1;
            if (cycles%701 == 0 && !raw_request && !raw_active && !valid[0]) raw_request <= 1;
            if (grant[0]) begin raw_request <= 0; raw_active <= 1; raw_index <= 0; end
            if (raw_active && ready[0]) begin
                if (raw_index==2) raw_active <= 0;
                else raw_index <= raw_index+1'b1;
            end
            if (valid[0]) begin
                if (shared_digest !== 256'hba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad)
                    $fatal(1,"Raw SHA result corrupted by HMAC interleaving");
                raw_results=raw_results+1;
            end
            if (request_grant) sha_calls=sha_calls+1;
            if (held && {hash_data_valid,hash_message_end,hash_data} !== held_stream)
                $fatal(1,"HMAC changed its SHA stream while stalled");
            held <= (hash_data_valid || hash_message_end) && !hash_data_ready;
            held_stream <= {hash_data_valid,hash_message_end,hash_data};
        end
    end

    reg [16383:0] key_blob, message_blob;
    integer key_length, message_length;
    reg separate_end;
    reg [255:0] expected_digest;
    task send_key;
        integer i;
        begin
            for (i=0; i<key_length; i++) begin
                repeat(i%3) @(negedge clk);
                @(negedge clk);
                key_data=key_blob[16383-i*8 -: 8];
                key_valid=1;
                key_end=!separate_end && i+1==key_length;
                do @(posedge clk); while (!key_ready);
                @(negedge clk); key_valid=0; key_end=0;
            end
            if (separate_end || key_length==0) begin
                @(negedge clk); key_end=1;
                do @(posedge clk); while (!key_ready);
                @(negedge clk); key_end=0;
            end
        end
    endtask
    task send_message;
        integer i;
        begin
            for (i=0; i<message_length; i++) begin
                repeat(i%4) @(negedge clk);
                @(negedge clk);
                message_data=message_blob[16383-i*8 -: 8];
                message_valid=1;
                message_end=!separate_end && i+1==message_length;
                do @(posedge clk); while (!message_ready);
                @(negedge clk); message_valid=0; message_end=0;
            end
            if (separate_end || message_length==0) begin
                @(negedge clk); message_end=1;
                do @(posedge clk); while (!message_ready);
                @(negedge clk); message_end=0;
            end
        end
    endtask
    task run_job;
        integer waited;
        begin
            @(negedge clk);
            if (busy) $fatal(1,"HMAC busy at admission");
            sha_calls=0;
            start=1;
            @(negedge clk); start=0;
            send_key();
            send_message();
            waited=0;
            while (!digest_valid && waited<200000) begin @(negedge clk); waited++; end
            if (!digest_valid || digest_out !== expected_digest || sha_calls != (key_length>64 ? 3 : 2))
                $fatal(1,"Case %0d wrong HMAC: got %h expected %h, SHA calls %0d",cases+1,digest_out,expected_digest,sha_calls);
            repeat(9) begin
                @(negedge clk);
                if (!busy || !digest_valid || digest_out !== expected_digest || key_ready || message_ready)
                    $fatal(1,"Digest backpressure did not retain ownership");
            end
            if (dut.key_block !== 0 || dut.inner_digest !== 0) $fatal(1,"HMAC retained secret intermediates");
            digest_ready=1;
            @(negedge clk); digest_ready=0;
            if (busy || digest_valid || digest_out !== 0) $fatal(1,"HMAC did not release result");
            cases++;
            $display("PASS HMAC case %0d (key=%0d message=%0d)",cases,key_length,message_length);
        end
    endtask
    integer phase;
    integer reset_states[0:12]='{1,2,3,4,5,7,8,9,10,11,12,13,14};
    initial begin
        repeat(3) @(negedge clk); reset_n=1;
        `include "hmac_vectors.svh"
        for (phase=0; phase<13; phase++) begin
            `include "hmac_reset_vector.svh"
            fork
                run_job();
                begin
                    wait(dut.state==reset_states[phase]);
                    @(negedge clk); reset_n=0;
                end
            join_any
            disable fork;
            start=0; key_valid=0; key_end=0; message_valid=0; message_end=0; digest_ready=0;
            repeat(3) @(negedge clk); reset_n=1;
            repeat(5) @(negedge clk);
            if (busy || digest_valid || request_valid || hash_data_valid || digest_out !== 0)
                $fatal(1,"Stale HMAC work after reset state %0d",reset_states[phase]);
            `include "hmac_recovery_vector.svh"
            run_job();
        end
        if (raw_results==0) $fatal(1,"No raw SHA arbitration coverage");
        $display("HMAC_SHA256_PASS (%0d cases, 13 reset phases, %0d raw SHA results)",cases,raw_results);
        $finish;
    end
    initial begin #100000000; $fatal(1,"HMAC regression timed out"); end
endmodule
