// Filename: tb_hash_subsystem.sv
// Description: Verify shared SHA request routing and digest backpressure.
`timescale 1ns/1ps
module tb_hash_subsystem;
    localparam [255:0] RAW_ABC = 256'hba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad;
    localparam [255:0] RAW_EMPTY = 256'he3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855;
    localparam [255:0] HMAC_ABC = 256'h9c196e32dc0175f86f4b1cb89289d6619de6bee699e4c378e68309ed97a1a6ab;
    localparam [255:0] PCR_EXTENDED = 256'hbb2275c49f28ad52cae6d55e34a974a58c7a3ba26f976e8ecbbe7a536918dc73;

    reg clk_i=0;
    always #5 clk_i=~clk_i;
    reg reset_n_i=0;
    reg raw_request_i=0, raw_valid_i=0, raw_end_i=0, raw_digest_ready_i=0;
    reg [7:0] raw_data_i=0;
    wire raw_grant_o, raw_ready_o, raw_digest_valid_o;
    wire [255:0] raw_digest_o;

    reg hmac_start_en_i=0, hmac_key_valid_i=0, hmac_key_end_i=0;
    reg hmac_message_valid_i=0, hmac_message_end_i=0, hmac_digest_ready_i=0;
    reg [7:0] hmac_key_data_i=0, hmac_message_data_i=0;
    wire hmac_key_ready_o, hmac_message_ready_o, hmac_busy_o, hmac_digest_valid_o;
    wire [255:0] hmac_digest_o;

    reg pcr_extend_start_en_i=0;
    wire [4:0] pcr_extend_index_i=5'd3, pcr_read_index_i=5'd3;
    wire [255:0] pcr_measurement_i=256'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f;
    wire pcr_busy_o, pcr_done_o, pcr_error_o, pcr_read_valid_o, busy_o;
    wire [255:0] pcr_read_data_o;
    integer pcr_completions=0;

    hash_subsystem dut (.*);

    always @(posedge clk_i) begin
        if (reset_n_i && pcr_done_o) begin
            if (pcr_error_o || !pcr_read_valid_o || pcr_read_data_o !== PCR_EXTENDED)
                $fatal(1, "PCR extend committed the wrong value");
            pcr_completions <= pcr_completions + 1;
        end
    end

    task automatic raw_byte(input [7:0] data, input bit valid, last);
        @(negedge clk_i);
        raw_data_i=data; raw_valid_i=valid; raw_end_i=last;
        do @(posedge clk_i); while (!raw_ready_o);
        @(negedge clk_i);
        raw_valid_i=0; raw_end_i=0;
    endtask

    task automatic key_byte(input [7:0] data, input bit last);
        @(negedge clk_i);
        hmac_key_data_i=data; hmac_key_valid_i=1; hmac_key_end_i=last;
        do @(posedge clk_i); while (!hmac_key_ready_o);
        @(negedge clk_i);
        hmac_key_valid_i=0; hmac_key_end_i=0;
    endtask

    task automatic message_byte(input [7:0] data, input bit last);
        @(negedge clk_i);
        hmac_message_data_i=data; hmac_message_valid_i=1; hmac_message_end_i=last;
        do @(posedge clk_i); while (!hmac_message_ready_o);
        @(negedge clk_i);
        hmac_message_valid_i=0; hmac_message_end_i=0;
    endtask

    initial begin
        repeat (3) @(negedge clk_i);
        reset_n_i=1;
        raw_request_i=1;
        do @(posedge clk_i); while (!raw_grant_o);
        @(negedge clk_i); raw_request_i=0;
        raw_byte("a",1,0);
        raw_byte("b",1,0);
        raw_byte("c",1,1);
        while (!raw_digest_valid_o) @(negedge clk_i);

        // Leave the raw digest unaccepted and queue the other two callers.
        hmac_start_en_i=1;
        pcr_extend_start_en_i=1;
        @(negedge clk_i);
        hmac_start_en_i=0;
        pcr_extend_start_en_i=0;
        key_byte("k",0);
        key_byte("e",0);
        key_byte("y",1);
        repeat (8) begin
            @(negedge clk_i);
            if (!raw_digest_valid_o || raw_digest_o !== RAW_ABC || !busy_o ||
                !pcr_busy_o || pcr_done_o || pcr_read_data_o !== 256'b0 ||
                !hmac_busy_o || hmac_message_ready_o || hmac_digest_valid_o)
                $fatal(1, "Stalled raw result was lost or another caller advanced");
        end

        raw_digest_ready_i=1;
        @(negedge clk_i);
        raw_digest_ready_i=0;
        fork
            begin
                message_byte("a",0);
                message_byte("b",0);
                message_byte("c",1);
            end
            begin
                @(negedge clk_i); raw_request_i=1;
                do @(posedge clk_i); while (!raw_grant_o);
                @(negedge clk_i); raw_request_i=0;
                raw_byte(0,0,1);
            end
        join

        // A completed HMAC result stays in the HMAC client. The shared
        // engine can finish another raw job before that result is accepted.
        while (!hmac_digest_valid_o || !raw_digest_valid_o) @(negedge clk_i);
        repeat (4) begin
            if (hmac_digest_o !== HMAC_ABC || !hmac_digest_valid_o ||
                raw_digest_o !== RAW_EMPTY || !raw_digest_valid_o ||
                pcr_read_data_o !== PCR_EXTENDED || pcr_completions != 1)
                $fatal(1, "Incorrect result routing or digest retention");
            @(negedge clk_i);
        end
        hmac_digest_ready_i=1;
        raw_digest_ready_i=1;
        @(negedge clk_i);
        if (busy_o || hmac_digest_valid_o || raw_digest_valid_o || pcr_busy_o)
            $fatal(1, "Subsystem remained busy after all results were accepted");
        $display("HASH_SUBSYSTEM_SHARED_PASS");
        $finish;
    end

    initial begin
        #200000;
        $fatal(1, "Timed out waiting for a shared hash requester");
    end
endmodule
