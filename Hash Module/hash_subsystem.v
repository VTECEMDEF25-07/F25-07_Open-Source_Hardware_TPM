// Shared SHA-256, HMAC-SHA256 and PCR bank integration.
// Requester priority: PCR (0), HMAC (1), raw hash (2).
// Starts are one-cycle pulses accepted only while the respective busy is
// low. Raw requests use request/grant. HMAC key/message streams use ready.
// PCR reads show the previous value until an extend commits (done pulse).
module hash_subsystem #(
    parameter integer PCR_COUNT=24,
    parameter integer PCR_INDEX_WIDTH=(PCR_COUNT > 1) ? $clog2(PCR_COUNT) : 1
) (
    input wire clk, reset_n,
    input wire raw_request,
    output wire raw_grant,
    input wire [7:0] raw_data,
    input wire raw_valid, raw_end,
    output wire raw_ready,
    output wire [255:0] raw_digest,
    output wire raw_digest_valid,
    input wire raw_digest_ready,

    input wire hmac_start,
    input wire [7:0] hmac_key_data,
    input wire hmac_key_valid, hmac_key_end,
    output wire hmac_key_ready,
    input wire [7:0] hmac_message_data,
    input wire hmac_message_valid, hmac_message_end,
    output wire hmac_message_ready,
    output wire hmac_busy,
    output wire [255:0] hmac_digest,
    output wire hmac_digest_valid,
    input wire hmac_digest_ready,

    input wire pcr_extend_start,
    input wire [PCR_INDEX_WIDTH-1:0] pcr_extend_index,
    input wire [255:0] pcr_measurement,
    output wire pcr_busy, pcr_done, pcr_error,
    input wire [PCR_INDEX_WIDTH-1:0] pcr_read_index,
    output wire [255:0] pcr_read_data,
    output wire pcr_read_valid,
    output wire busy
);
    wire [2:0] request, grant, data_valid, message_end, data_ready;
    wire [2:0] digest_valid, digest_ready;
    wire [23:0] data;
    wire [255:0] digest, old_pcr, pcr_write_data;
    wire pcr_write_enable, engine_busy;
    wire [PCR_INDEX_WIDTH-1:0] pcr_write_index;

    assign request[2] = raw_request;
    assign raw_grant = grant[2];
    assign data[23:16] = raw_data;
    assign data_valid[2] = raw_valid;
    assign message_end[2] = raw_end;
    assign raw_ready = data_ready[2];
    // Only expose a raw digest during that requester's result transaction.
    assign raw_digest = digest_valid[2] ? digest : 256'b0;
    assign raw_digest_valid = digest_valid[2];
    assign digest_ready[2] = raw_digest_ready;
    assign busy = engine_busy || hmac_busy || pcr_busy;

    hash_engine #(.REQUESTERS(3)) u_engine (
        .clk(clk), .reset_n(reset_n), .request_valid(request),
        .request_grant(grant), .data_in(data), .data_valid(data_valid),
        .message_end(message_end), .data_ready(data_ready),
        .digest_out(digest), .digest_valid(digest_valid),
        .digest_ready(digest_ready), .busy(engine_busy)
    );
    hmac_sha256 u_hmac (
        .clk(clk), .reset_n(reset_n), .start(hmac_start),
        .key_data(hmac_key_data), .key_valid(hmac_key_valid),
        .key_end(hmac_key_end), .key_ready(hmac_key_ready),
        .message_data(hmac_message_data), .message_valid(hmac_message_valid),
        .message_end(hmac_message_end), .message_ready(hmac_message_ready),
        .busy(hmac_busy), .digest_out(hmac_digest),
        .digest_valid(hmac_digest_valid), .digest_ready(hmac_digest_ready),
        .request_valid(request[1]), .request_grant(grant[1]),
        .hash_data(data[15:8]), .hash_data_valid(data_valid[1]),
        .hash_message_end(message_end[1]), .hash_data_ready(data_ready[1]),
        .hash_digest(digest), .hash_digest_valid(digest_valid[1]),
        .hash_digest_ready(digest_ready[1])
    );
    pcr_controller #(.PCR_COUNT(PCR_COUNT), .INDEX_WIDTH(PCR_INDEX_WIDTH)) u_pcr_controller (
        .clk(clk), .reset_n(reset_n), .extend_start(pcr_extend_start),
        .extend_index(pcr_extend_index), .measurement(pcr_measurement),
        .old_pcr(old_pcr), .busy(pcr_busy), .done(pcr_done), .error(pcr_error),
        .write_enable(pcr_write_enable), .write_index(pcr_write_index),
        .write_data(pcr_write_data),
        .request_valid(request[0]), .request_grant(grant[0]),
        .hash_data(data[7:0]), .hash_data_valid(data_valid[0]),
        .hash_message_end(message_end[0]), .hash_data_ready(data_ready[0]),
        .hash_digest(digest), .hash_digest_valid(digest_valid[0]),
        .hash_digest_ready(digest_ready[0])
    );
    pcr_registers #(.PCR_COUNT(PCR_COUNT), .INDEX_WIDTH(PCR_INDEX_WIDTH)) u_pcr_registers (
        .clk(clk), .reset_n(reset_n), .read_index(pcr_read_index),
        .extend_index(pcr_extend_index), .read_data(pcr_read_data),
        .extend_data(old_pcr), .read_valid(pcr_read_valid),
        .write_enable(pcr_write_enable), .write_index(pcr_write_index),
        .write_data(pcr_write_data)
    );
endmodule
