// hash_engine.v
// modules:
//	hash_engine
//
// Authors:
//	Kyra Warncke
//
// Date: 11/4/26
//
// General Description:
// Shared SHA-256 engine. Requester i owns data_in_i[i*8 +: 8],
// data_valid_i[i], message_end_i[i], data_ready_o[i], and digest_valid_o[i].
// REQUESTERS must be >= 1. Index assignments (HMAC/PCR/host/etc.) are
// chosen by the integrating design; this module does not hard-code them.
//
// Hold request_valid_i[i] until request_grant_o[i] is sampled high at a rising
// edge, then deassert it. Only the granted requester may stream a message.
// Transfer bytes on data_valid_i[i] && data_ready_o[i]. message_end_i[i] is
// accepted when data_ready_o[i], with the last byte or alone (empty message).
// Hold stalled data/end stable. Consume digest_out_o only when
// digest_valid_o[i] && digest_ready_i[i]. The digest bus is shared, with a
// one-hot destination valid vector. One message/result is outstanding.
// Fixed priority: lower requester indices win simultaneous requests.
// reset_n_i aborts all work and clears buffered results; requesters must retry.
module hash_engine #(
    parameter integer REQUESTERS = 4
) (
    input  wire                       clk_i,
    input  wire                       reset_n_i,
    input  wire [REQUESTERS-1:0]      request_valid_i,
    output wire [REQUESTERS-1:0]      request_grant_o,
    input  wire [REQUESTERS*8-1:0]    data_in_i,
    input  wire [REQUESTERS-1:0]      data_valid_i,
    input  wire [REQUESTERS-1:0]      message_end_i,
    output reg  [REQUESTERS-1:0]      data_ready_o,
    output wire [255:0]               digest_out_o,
    output wire [REQUESTERS-1:0]      digest_valid_o,
    input  wire [REQUESTERS-1:0]      digest_ready_i,
    // Includes waiting for input and waiting for digest consumption.
    output wire                       busy_o
);
    localparam integer OWNER_WIDTH = (REQUESTERS > 1) ? $clog2(REQUESTERS) : 1;
    wire [OWNER_WIDTH-1:0] owner;
    wire owner_valid, hash_start_en, hash_busy, hash_valid, hash_data_ready;
    wire [255:0] hash_digest;
    reg [7:0] selected_data;
    reg selected_valid, selected_end;

    assign busy_o = owner_valid || hash_busy;
    always @* begin
        selected_data = 8'b0;
        selected_valid = 1'b0;
        selected_end = 1'b0;
        data_ready_o = {REQUESTERS{1'b0}};
        if (reset_n_i && owner_valid) begin
            selected_data = data_in_i[owner*8 +: 8];
            selected_valid = data_valid_i[owner];
            selected_end = message_end_i[owner];
            data_ready_o[owner] = hash_data_ready;
        end
    end

    hash_arbiter #(.REQUESTERS(REQUESTERS), .OWNER_WIDTH(OWNER_WIDTH)) u_arbiter (
        .clk_i(clk_i), .reset_n_i(reset_n_i),
        .request_valid_i(request_valid_i), .request_grant_o(request_grant_o),
        .owner_reg_o(owner), .owner_valid_reg_o(owner_valid),
        .hash_busy_i(hash_busy), .hash_start_en_o(hash_start_en),
        .hash_digest_i(hash_digest), .hash_valid_i(hash_valid),
        .digest_out_reg_o(digest_out_o), .digest_valid_o(digest_valid_o),
        .digest_ready_i(digest_ready_i)
    );
    sha_256 u_sha_256 (
        .clk_i(clk_i), .reset_n_i(reset_n_i), .start_en_i(hash_start_en),
        .data_in_i(selected_data), .data_valid_i(selected_valid),
        .message_end_i(selected_end), .data_ready_o(hash_data_ready),
        .busy_o(hash_busy), .hash_out_reg_o(hash_digest), .hash_valid_o(hash_valid)
    );
endmodule
