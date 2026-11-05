// Hash Arbiter Module
// Routes each SHA-256 result back to the requester that owns the operation.
// Requester indices are 0..REQUESTERS-1; lower indices have priority.
// Hold request_valid until request_grant. A grant and hash_start are the
// same transaction. The granted module must then supply the SHA byte stream
// using sha_256.data_ready. owner identifies that module until completion.
// There is one outstanding operation/result. No new request is granted
// until the previous digest is consumed. Reset aborts ownership/results;
// connect reset_n to the SHA engine's reset_n as well.

module hash_arbiter #(
    parameter integer REQUESTERS = 4,
    parameter integer OWNER_WIDTH = (REQUESTERS > 1) ? $clog2(REQUESTERS) : 1
) (
    input  wire                       clk,
    input  wire                       reset_n,
    input  wire [REQUESTERS-1:0]      request_valid,
    output reg  [REQUESTERS-1:0]      request_grant,
    output reg  [OWNER_WIDTH-1:0]     owner,
    output reg                        owner_valid,

    input  wire                       hash_busy,
    output wire                       hash_start,
    input  wire [255:0]               hash_digest,
    input  wire                       hash_valid,

    // Shared digest bus; only the port with digest_valid asserted may
    // consume it. Transfer occurs on digest_valid[i] && digest_ready[i].
    output reg  [255:0]               digest_out,
    output reg  [REQUESTERS-1:0]      digest_valid,
    input  wire [REQUESTERS-1:0]      digest_ready
);
    reg result_pending;
    reg [OWNER_WIDTH-1:0] selected;
    reg found;
    integer i;

    always @* begin
        request_grant = {REQUESTERS{1'b0}};
        selected = {OWNER_WIDTH{1'b0}};
        found = 1'b0;
        if (reset_n && !hash_busy && !owner_valid && !result_pending) begin
            for (i = 0; i < REQUESTERS; i = i + 1) begin
                if (request_valid[i] && !found) begin
                    request_grant[i] = 1'b1;
                    selected = i;
                    found = 1'b1;
                end
            end
        end
    end
    assign hash_start = |request_grant;

    always @* begin
        digest_valid = {REQUESTERS{1'b0}};
        if (reset_n && result_pending) digest_valid[owner] = 1'b1;
    end

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            owner <= 0;
            owner_valid <= 1'b0;
            result_pending <= 1'b0;
            digest_out <= 256'b0;
        end else begin
            if (hash_start) begin
                owner <= selected;
                owner_valid <= 1'b1;
            end
            if (hash_valid && owner_valid && !result_pending) begin
                digest_out <= hash_digest;
                result_pending <= 1'b1;
            end
            if (result_pending && digest_ready[owner]) begin
                result_pending <= 1'b0;
                owner_valid <= 1'b0;
            end
        end
    end
endmodule
