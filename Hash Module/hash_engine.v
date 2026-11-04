// Shared SHA-256 engine. Requester i owns data_in[i*8 +: 8],
// data_valid[i], message_end[i], data_ready[i], and digest_valid[i].
// REQUESTERS must be >= 1. Index assignments (HMAC/PCR/host/etc.) are
// chosen by the integrating design; this module does not hard-code them.
//
// Hold request_valid[i] until request_grant[i] is sampled high at a rising
// edge, then deassert it. Only the granted requester may stream a message.
// Transfer bytes on data_valid[i] && data_ready[i]. message_end[i] is
// accepted when data_ready[i], with the last byte or alone (empty message).
// Hold stalled data/end stable. Consume digest_out only when
// digest_valid[i] && digest_ready[i]. The digest bus is shared, with a
// one-hot destination valid vector. One message/result is outstanding.
// Fixed priority: lower requester indices win simultaneous requests.
// reset_n aborts all work and clears buffered results; requesters must retry.
module hash_engine #(
    parameter integer REQUESTERS = 4
) (
    input  wire                       clk,
    input  wire                       reset_n,
    input  wire [REQUESTERS-1:0]      request_valid,
    output wire [REQUESTERS-1:0]      request_grant,
    input  wire [REQUESTERS*8-1:0]    data_in,
    input  wire [REQUESTERS-1:0]      data_valid,
    input  wire [REQUESTERS-1:0]      message_end,
    output reg  [REQUESTERS-1:0]      data_ready,
    output wire [255:0]               digest_out,
    output wire [REQUESTERS-1:0]      digest_valid,
    input  wire [REQUESTERS-1:0]      digest_ready,
    // Includes waiting for input and waiting for digest consumption.
    output wire                       busy
);
    localparam integer OWNER_WIDTH = (REQUESTERS > 1) ? $clog2(REQUESTERS) : 1;
    wire [OWNER_WIDTH-1:0] owner;
    wire owner_valid, hash_start, hash_busy, hash_valid, hash_data_ready;
    wire [255:0] hash_digest;
    reg [7:0] selected_data;
    reg selected_valid, selected_end;

    assign busy = owner_valid || hash_busy;
    always @* begin
        selected_data = 8'b0;
        selected_valid = 1'b0;
        selected_end = 1'b0;
        data_ready = {REQUESTERS{1'b0}};
        if (reset_n && owner_valid) begin
            selected_data = data_in[owner*8 +: 8];
            selected_valid = data_valid[owner];
            selected_end = message_end[owner];
            data_ready[owner] = hash_data_ready;
        end
    end

    hash_arbiter #(.REQUESTERS(REQUESTERS), .OWNER_WIDTH(OWNER_WIDTH)) u_arbiter (
        .clk(clk), .reset_n(reset_n),
        .request_valid(request_valid), .request_grant(request_grant),
        .owner(owner), .owner_valid(owner_valid),
        .hash_busy(hash_busy), .hash_start(hash_start),
        .hash_digest(hash_digest), .hash_valid(hash_valid),
        .digest_out(digest_out), .digest_valid(digest_valid),
        .digest_ready(digest_ready)
    );
    sha_256 u_sha_256 (
        .clk(clk), .reset_n(reset_n), .start(hash_start),
        .data_in(selected_data), .data_valid(selected_valid),
        .message_end(selected_end), .data_ready(hash_data_ready),
        .busy(hash_busy), .hash_out(hash_digest), .hash_valid(hash_valid)
    );
endmodule
