// HMAC-SHA256 client for the shared hash_engine in PR #39.
// Pulse start while !busy. Stream the key, then the message, MSB byte first.
// Bytes transfer on valid && ready. End may accompany the last byte or occur
// alone, including for empty inputs. Hold unaccepted data/valid/end stable.
// Keys longer than 64 bytes are hashed before applying the HMAC pads.
// Construction follows RFC 2104. Known-answer vectors follow RFC 4231.
// digest_valid and digest_out are held until digest_ready. Reset this client
// and its shared SHA engine together to abort a transaction.
`default_nettype none
module hmac_sha256 (
    input wire clk, reset_n, start,
    input wire [7:0] key_data,
    input wire key_valid, key_end,
    output wire key_ready,
    input wire [7:0] message_data,
    input wire message_valid, message_end,
    output wire message_ready,
    output wire busy,
    output wire [255:0] digest_out,
    output wire digest_valid,
    input wire digest_ready,

    output wire request_valid,
    input wire request_grant,
    output reg [7:0] hash_data,
    output reg hash_data_valid, hash_message_end,
    input wire hash_data_ready,
    input wire [255:0] hash_digest,
    input wire hash_digest_valid,
    output wire hash_digest_ready
);
    localparam [3:0] IDLE=0, KEY=1, KEY_REQUEST=2, KEY_PREFIX=3,
        KEY_STREAM=4, KEY_DIGEST=5, INNER_REQUEST=6, INNER_PAD=7,
        MESSAGE=8, INNER_DIGEST=9, OUTER_REQUEST=10, OUTER_PAD=11,
        OUTER_HASH=12, OUTER_DIGEST=13, RESULT=14;
    reg [3:0] state;
    reg [511:0] key_block;
    reg [255:0] inner_digest, result;
    reg [6:0] key_bytes;
    reg [5:0] index;

    assign busy = state != IDLE;
    assign key_ready = reset_n &&
        ((state == KEY && (key_bytes < 64 || !key_valid)) ||
         (state == KEY_STREAM && hash_data_ready));
    assign message_ready = reset_n && state == MESSAGE && hash_data_ready;
    assign digest_valid = reset_n && state == RESULT;
    assign digest_out = digest_valid ? result : 256'd0;
    assign request_valid = reset_n &&
        (state == KEY_REQUEST || state == INNER_REQUEST || state == OUTER_REQUEST);
    assign hash_digest_ready = reset_n &&
        (state == KEY_DIGEST || state == INNER_DIGEST || state == OUTER_DIGEST);

    always @* begin
        hash_data = 0;
        hash_data_valid = 0;
        hash_message_end = 0;
        if (reset_n) case (state)
            KEY_PREFIX: begin
                hash_data = key_block[511-index*8 -: 8];
                hash_data_valid = 1;
            end
            KEY_STREAM: begin
                hash_data = key_data;
                hash_data_valid = key_valid;
                hash_message_end = key_end;
            end
            INNER_PAD: begin
                hash_data = key_block[511-index*8 -: 8] ^ 8'h36;
                hash_data_valid = 1;
            end
            MESSAGE: begin
                hash_data = message_data;
                hash_data_valid = message_valid;
                hash_message_end = message_end;
            end
            OUTER_PAD: begin
                hash_data = key_block[511-index*8 -: 8] ^ 8'h5c;
                hash_data_valid = 1;
            end
            OUTER_HASH: begin
                hash_data = inner_digest[255-index*8 -: 8];
                hash_data_valid = 1;
                hash_message_end = index == 31;
            end
            default: begin end
        endcase
    end

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= IDLE;
            key_block <= 0;
            key_bytes <= 0;
            inner_digest <= 0;
            result <= 0;
            index <= 0;
        end else case (state)
            IDLE: if (start) begin
                key_block <= 0;
                key_bytes <= 0;
                inner_digest <= 0;
                result <= 0;
                index <= 0;
                state <= KEY;
            end
            KEY: begin
                // Keep byte 65 at the caller until SHA accepts the saved prefix.
                if (key_bytes == 64 && key_valid) state <= KEY_REQUEST;
                else if (key_ready) begin
                    if (key_valid) begin
                        key_block[511-key_bytes*8 -: 8] <= key_data;
                        key_bytes <= key_bytes+1'b1;
                    end
                    if (key_end) state <= INNER_REQUEST;
                end
            end
            KEY_REQUEST: if (request_grant) begin
                index <= 0;
                state <= KEY_PREFIX;
            end
            KEY_PREFIX: if (hash_data_ready) begin
                if (index == 63) begin
                    index <= 0;
                    state <= KEY_STREAM;
                end else index <= index+1'b1;
            end
            KEY_STREAM: if (key_ready && key_end) state <= KEY_DIGEST;
            KEY_DIGEST: if (hash_digest_valid) begin
                key_block <= {hash_digest,256'd0};
                state <= INNER_REQUEST;
            end
            INNER_REQUEST: if (request_grant) begin
                index <= 0;
                state <= INNER_PAD;
            end
            INNER_PAD: if (hash_data_ready) begin
                if (index == 63) begin
                    index <= 0;
                    state <= MESSAGE;
                end else index <= index+1'b1;
            end
            MESSAGE: if (message_ready && message_end) state <= INNER_DIGEST;
            INNER_DIGEST: if (hash_digest_valid) begin
                inner_digest <= hash_digest;
                state <= OUTER_REQUEST;
            end
            OUTER_REQUEST: if (request_grant) begin
                index <= 0;
                state <= OUTER_PAD;
            end
            OUTER_PAD: if (hash_data_ready) begin
                if (index == 63) begin
                    index <= 0;
                    state <= OUTER_HASH;
                end else index <= index+1'b1;
            end
            OUTER_HASH: if (hash_data_ready) begin
                if (index == 31) state <= OUTER_DIGEST;
                else index <= index+1'b1;
            end
            OUTER_DIGEST: if (hash_digest_valid) begin
                result <= hash_digest;
                key_block <= 0;
                inner_digest <= 0;
                key_bytes <= 0;
                index <= 0;
                state <= RESULT;
            end
            RESULT: if (digest_ready) begin
                result <= 0;
                state <= IDLE;
            end
            default: begin
                key_block <= 0;
                inner_digest <= 0;
                result <= 0;
                key_bytes <= 0;
                index <= 0;
                state <= IDLE;
            end
        endcase
    end
endmodule
`default_nettype wire
