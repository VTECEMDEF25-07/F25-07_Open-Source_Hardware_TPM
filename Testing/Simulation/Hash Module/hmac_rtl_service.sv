// Test-only port wrapper so the existing session regression uses hardware HMAC.
module hmac_stream_test_service #(parameter USE_PYTHON=0) (
    input wire clock_i, reset_n_i, hmac_start_o,
    input wire [7:0] hmac_key_data_o, hmac_message_data_o,
    input wire hmac_key_valid_o, hmac_key_end_o,
    output wire hmac_key_ready_i,
    input wire hmac_message_valid_o, hmac_message_end_o,
    output wire hmac_message_ready_i, hmac_busy_i,
    output wire [255:0] hmac_digest_i,
    output wire hmac_digest_valid_i,
    input wire hmac_digest_ready_o
);
    wire request, grant, valid, message_end, ready, digest_valid, digest_ready;
    wire [7:0] data;
    wire [255:0] digest;
    hmac_sha256 hmac (
        .clk(clock_i), .reset_n(reset_n_i), .start(hmac_start_o),
        .key_data(hmac_key_data_o), .key_valid(hmac_key_valid_o), .key_end(hmac_key_end_o), .key_ready(hmac_key_ready_i),
        .message_data(hmac_message_data_o), .message_valid(hmac_message_valid_o),
        .message_end(hmac_message_end_o), .message_ready(hmac_message_ready_i),
        .busy(hmac_busy_i), .digest_out(hmac_digest_i), .digest_valid(hmac_digest_valid_i), .digest_ready(hmac_digest_ready_o),
        .request_valid(request), .request_grant(grant), .hash_data(data), .hash_data_valid(valid),
        .hash_message_end(message_end), .hash_data_ready(ready),
        .hash_digest(digest), .hash_digest_valid(digest_valid), .hash_digest_ready(digest_ready)
    );
    hash_engine #(.REQUESTERS(1)) engine (
        .clk(clock_i), .reset_n(reset_n_i), .request_valid(request), .request_grant(grant),
        .data_in(data), .data_valid(valid), .message_end(message_end), .data_ready(ready),
        .digest_out(digest), .digest_valid(digest_valid), .digest_ready(digest_ready), .busy()
    );
endmodule
