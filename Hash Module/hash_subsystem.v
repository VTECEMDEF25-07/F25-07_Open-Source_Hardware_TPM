// Shared SHA-256, HMAC-SHA256 and PCR bank integration.
// Requester priority: PCR (0), HMAC (1), raw hash (2).
// Starts are one-cycle pulses accepted only while the respective busy_o is
// low. Raw requests use request/grant. HMAC key/message streams use ready.
// PCR reads show the previous value until an extend commits (done pulse).
module hash_subsystem #(
    parameter integer PCR_COUNT=24,
    parameter integer PCR_INDEX_WIDTH=(PCR_COUNT > 1) ? $clog2(PCR_COUNT) : 1
) (
    input wire clk_i, reset_n_i,
    input wire raw_request_i,
    output wire raw_grant_o,
    input wire [7:0] raw_data_i,
    input wire raw_valid_i, raw_end_i,
    output wire raw_ready_o,
    output wire [255:0] raw_digest_o,
    output wire raw_digest_valid_o,
    input wire raw_digest_ready_i,

    input wire hmac_start_en_i,
    input wire [7:0] hmac_key_data_i,
    input wire hmac_key_valid_i, hmac_key_end_i,
    output wire hmac_key_ready_o,
    input wire [7:0] hmac_message_data_i,
    input wire hmac_message_valid_i, hmac_message_end_i,
    output wire hmac_message_ready_o,
    output wire hmac_busy_o,
    output wire [255:0] hmac_digest_o,
    output wire hmac_digest_valid_o,
    input wire hmac_digest_ready_i,

    input wire pcr_extend_start_en_i,
    input wire [PCR_INDEX_WIDTH-1:0] pcr_extend_index_i,
    input wire [255:0] pcr_measurement_i,
    output wire pcr_busy_o, pcr_done_o, pcr_error_o,
    input wire [PCR_INDEX_WIDTH-1:0] pcr_read_index_i,
    output wire [255:0] pcr_read_data_o,
    output wire pcr_read_valid_o,
    output wire busy_o
);
    wire [2:0] request, grant, data_valid, message_end, data_ready;
    wire [2:0] digest_valid, digest_ready;
    wire [23:0] data;
    wire [255:0] digest, old_pcr, pcr_write_data;
    wire pcr_write_en, engine_busy;
    wire [PCR_INDEX_WIDTH-1:0] pcr_write_index;

    assign request[2] = raw_request_i;
    assign raw_grant_o = grant[2];
    assign data[23:16] = raw_data_i;
    assign data_valid[2] = raw_valid_i;
    assign message_end[2] = raw_end_i;
    assign raw_ready_o = data_ready[2];
    // Only expose a raw digest during that requester's result transaction.
    assign raw_digest_o = digest_valid[2] ? digest : 256'b0;
    assign raw_digest_valid_o = digest_valid[2];
    assign digest_ready[2] = raw_digest_ready_i;
    assign busy_o = engine_busy || hmac_busy_o || pcr_busy_o;

    hash_engine #(.REQUESTERS(3)) u_engine (
        .clk_i(clk_i), .reset_n_i(reset_n_i), .request_valid_i(request),
        .request_grant_o(grant), .data_in_i(data), .data_valid_i(data_valid),
        .message_end_i(message_end), .data_ready_o(data_ready),
        .digest_out_o(digest), .digest_valid_o(digest_valid),
        .digest_ready_i(digest_ready), .busy_o(engine_busy)
    );
    hmac_sha256 u_hmac (
        .clk(clk_i), .reset_n(reset_n_i), .start(hmac_start_en_i),
        .key_data(hmac_key_data_i), .key_valid(hmac_key_valid_i),
        .key_end(hmac_key_end_i), .key_ready(hmac_key_ready_o),
        .message_data(hmac_message_data_i), .message_valid(hmac_message_valid_i),
        .message_end(hmac_message_end_i), .message_ready(hmac_message_ready_o),
        .busy(hmac_busy_o), .digest_out(hmac_digest_o),
        .digest_valid(hmac_digest_valid_o), .digest_ready(hmac_digest_ready_i),
        .request_valid(request[1]), .request_grant(grant[1]),
        .hash_data(data[15:8]), .hash_data_valid(data_valid[1]),
        .hash_message_end(message_end[1]), .hash_data_ready(data_ready[1]),
        .hash_digest(digest), .hash_digest_valid(digest_valid[1]),
        .hash_digest_ready(digest_ready[1])
    );
    pcr_controller #(.PCR_COUNT(PCR_COUNT), .INDEX_WIDTH(PCR_INDEX_WIDTH)) u_pcr_controller (
        .clk(clk_i), .reset_n(reset_n_i), .extend_start(pcr_extend_start_en_i),
        .extend_index(pcr_extend_index_i), .measurement(pcr_measurement_i),
        .old_pcr(old_pcr), .busy(pcr_busy_o), .done(pcr_done_o), .error(pcr_error_o),
        .write_enable(pcr_write_en), .write_index(pcr_write_index),
        .write_data(pcr_write_data),
        .request_valid(request[0]), .request_grant(grant[0]),
        .hash_data(data[7:0]), .hash_data_valid(data_valid[0]),
        .hash_message_end(message_end[0]), .hash_data_ready(data_ready[0]),
        .hash_digest(digest), .hash_digest_valid(digest_valid[0]),
        .hash_digest_ready(digest_ready[0])
    );
    pcr_registers #(.PCR_COUNT(PCR_COUNT), .INDEX_WIDTH(PCR_INDEX_WIDTH)) u_pcr_registers (
        .clk(clk_i), .reset_n(reset_n_i), .read_index(pcr_read_index_i),
        .extend_index(pcr_extend_index_i), .read_data(pcr_read_data_o),
        .extend_data(old_pcr), .read_valid(pcr_read_valid_o),
        .write_enable(pcr_write_en), .write_index(pcr_write_index),
        .write_data(pcr_write_data)
    );
endmodule
