// Simulation only. Exercises PR #39's HMAC byte contract with input stalls.
// USE_PYTHON=1 hashes the bytes actually received using Python's hmac library.
// USE_PYTHON=0 retains the original toy digest for the older control tests.
`timescale 1ns/1ps
module hmac_stream_test_service #(parameter USE_PYTHON=0) (
    input wire clock_i, reset_n_i,
    input wire hmac_start_o,
    input wire [7:0] hmac_key_data_o, hmac_message_data_o,
    input wire hmac_key_valid_o, hmac_key_end_o,
    output wire hmac_key_ready_i,
    input wire hmac_message_valid_o, hmac_message_end_o,
    output wire hmac_message_ready_i, hmac_busy_i,
    output reg [255:0] hmac_digest_i,
    output wire hmac_digest_valid_i,
    input wire hmac_digest_ready_o
);
    localparam IDLE=0, KEY=1, MESSAGE=2, COMPUTE=3, RESULT=4;
    integer state=IDLE, cycle=0, key_count=0, message_count=0, delay_count=0;
    reg [1023:0] key_buffer;
    reg [1119:0] message_buffer;
    string python_exe, service_script, command, key_hex, message_hex;
    integer fd, status, scanned, i;
    reg [255:0] returned_digest;
    reg stalled_key, stalled_message;
    reg [9:0] held_key, held_message;
    initial if (USE_PYTHON &&
        (!$value$plusargs("PYTHON=%s",python_exe) || !$value$plusargs("HMAC_SERVICE=%s",service_script)))
        $fatal(1,"Python HMAC configuration missing");
    assign hmac_busy_i = state != IDLE;
    assign hmac_key_ready_i = reset_n_i && state == KEY && cycle%3 != 0;
    assign hmac_message_ready_i = reset_n_i && state == MESSAGE && cycle%4 != 0;
    assign hmac_digest_valid_i = reset_n_i && state == RESULT;
    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            state <= IDLE;
            cycle = 0;
            key_count = 0;
            message_count = 0;
            key_buffer = 0;
            message_buffer = 0;
            hmac_digest_i <= 0;
            stalled_key = 0;
            stalled_message = 0;
        end else begin
            if (stalled_key && {hmac_key_valid_o,hmac_key_end_o,hmac_key_data_o} !== held_key)
                $fatal(1,"Key changed while stalled");
            if (stalled_message && {hmac_message_valid_o,hmac_message_end_o,hmac_message_data_o} !== held_message)
                $fatal(1,"Message changed while stalled");
            stalled_key = (hmac_key_valid_o || hmac_key_end_o) && !hmac_key_ready_i;
            stalled_message = (hmac_message_valid_o || hmac_message_end_o) && !hmac_message_ready_i;
            held_key = {hmac_key_valid_o,hmac_key_end_o,hmac_key_data_o};
            held_message = {hmac_message_valid_o,hmac_message_end_o,hmac_message_data_o};
            case (state)
                IDLE: if (hmac_start_o) begin
                    key_count = 0;
                    message_count = 0;
                    key_buffer = 0;
                    message_buffer = 0;
                    state <= KEY;
                end
                KEY: if (hmac_key_ready_i) begin
                    if (hmac_key_valid_o) begin
                        if (key_count >= 128) $fatal(1,"Oversize key");
                        key_buffer[(128-key_count)*8-1 -: 8] = hmac_key_data_o;
                        key_count = key_count+1;
                    end
                    if (hmac_key_end_o) state <= MESSAGE;
                end
                MESSAGE: if (hmac_message_ready_i) begin
                    if (hmac_message_valid_o) begin
                        if (message_count >= 140) $fatal(1,"Oversize message");
                        message_buffer[(140-message_count)*8-1 -: 8] = hmac_message_data_o;
                        message_count = message_count+1;
                    end
                    if (hmac_message_end_o) begin
                        delay_count = 5;
                        state <= COMPUTE;
                    end
                end
                COMPUTE: if (delay_count != 0) delay_count = delay_count-1;
                else begin
                    if (USE_PYTHON) begin
                        fd = $fopen("hmac_request.txt","w");
                        if (!fd) $fatal(1,"Cannot write HMAC request");
                        for (i=0; i<key_count; i=i+1) $fwrite(fd,"%02h",key_buffer[(128-i)*8-1 -: 8]);
                        $fwrite(fd,"\n");
                        for (i=0; i<message_count; i=i+1) $fwrite(fd,"%02h",message_buffer[(140-i)*8-1 -: 8]);
                        $fwrite(fd,"\n");
                        $fclose(fd);
                        command = $sformatf("\"\"%s\" \"%s\" hmac_request.txt hmac_response.txt\"",python_exe,service_script);
                        status = $system(command);
                        if (status != 0) $fatal(1,"Python HMAC service failed");
                        fd = $fopen("hmac_response.txt","r");
                        scanned = $fscanf(fd,"%h",returned_digest);
                        $fclose(fd);
                        if (scanned != 1) $fatal(1,"Bad HMAC response");
                        key_hex="";
                        message_hex="";
                        for (i=0; i<key_count; i=i+1)
                            key_hex={key_hex,$sformatf("%02h",key_buffer[(128-i)*8-1 -: 8])};
                        for (i=0; i<message_count; i=i+1)
                            message_hex={message_hex,$sformatf("%02h",message_buffer[(140-i)*8-1 -: 8])};
                        $display("HMAC|%s|%s|%064h",key_hex,message_hex,returned_digest);
                        hmac_digest_i <= returned_digest;
                    end else hmac_digest_i <= message_buffer[1119 -: 256];
                    state <= RESULT;
                end
                RESULT: if (hmac_digest_ready_o) begin
                    hmac_digest_i <= 0;
                    key_buffer = 0;
                    message_buffer = 0;
                    state <= IDLE;
                end
            endcase
            cycle <= cycle+1;
        end
    end
endmodule
