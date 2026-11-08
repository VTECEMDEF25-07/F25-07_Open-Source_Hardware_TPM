// Hash Arbiter Module
// Routes each SHA-256 result back to the requester that owns the operation.
// Requester indices are 0..REQUESTERS-1; lower indices have priority.
// Hold request_valid_i until request_grant_o. A grant and hash_start_en_o are the
// same transaction. The granted module must then supply the SHA byte stream
// using sha_256.data_ready_o. owner_reg_o identifies that module until completion.
// There is one outstanding operation/result. No new request is granted
// until the previous digest is consumed. Reset aborts ownership/results;
// connect reset_n_i to the SHA engine's reset_n_i as well.

module hash_arbiter #(
    parameter integer REQUESTERS = 4,
    parameter integer OWNER_WIDTH = (REQUESTERS > 1) ? $clog2(REQUESTERS) : 1
) (
    input  wire                       clk_i,
    input  wire                       reset_n_i,
    input  wire [REQUESTERS-1:0]      request_valid_i,
    output reg  [REQUESTERS-1:0]      request_grant_o,
    output reg  [OWNER_WIDTH-1:0]     owner_reg_o,
    output reg                        owner_valid_reg_o,

    input  wire                       hash_busy_i,
    output wire                       hash_start_en_o,
    input  wire [255:0]               hash_digest_i,
    input  wire                       hash_valid_i,

    // Shared digest bus; only the port with digest_valid_o asserted may
    // consume it. Transfer occurs on digest_valid_o[requester_index] && digest_ready_i[requester_index].
    output reg  [255:0]               digest_out_reg_o,
    output reg  [REQUESTERS-1:0]      digest_valid_o,
    input  wire [REQUESTERS-1:0]      digest_ready_i
);
    reg result_pending_reg;
    reg [OWNER_WIDTH-1:0] selected_owner;
    reg requester_found;
    integer requester_index;

    always @* begin
        request_grant_o = {REQUESTERS{1'b0}};
        selected_owner = {OWNER_WIDTH{1'b0}};
        requester_found = 1'b0;
        if (reset_n_i && !hash_busy_i && !owner_valid_reg_o && !result_pending_reg) begin
            for (requester_index = 0; requester_index < REQUESTERS; requester_index = requester_index + 1) begin
                if (request_valid_i[requester_index] && !requester_found) begin
                    request_grant_o[requester_index] = 1'b1;
                    selected_owner = requester_index;
                    requester_found = 1'b1;
                end
            end
        end
    end
    assign hash_start_en_o = |request_grant_o;

    always @* begin
        digest_valid_o = {REQUESTERS{1'b0}};
        if (reset_n_i && result_pending_reg) digest_valid_o[owner_reg_o] = 1'b1;
    end

    always @(posedge clk_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            owner_reg_o <= 0;
            owner_valid_reg_o <= 1'b0;
            result_pending_reg <= 1'b0;
            digest_out_reg_o <= 256'b0;
        end else begin
            if (hash_start_en_o) begin
                owner_reg_o <= selected_owner;
                owner_valid_reg_o <= 1'b1;
            end
            if (hash_valid_i && owner_valid_reg_o && !result_pending_reg) begin
                digest_out_reg_o <= hash_digest_i;
                result_pending_reg <= 1'b1;
            end
            if (result_pending_reg && digest_ready_i[owner_reg_o]) begin
                result_pending_reg <= 1'b0;
                owner_valid_reg_o <= 1'b0;
            end
        end
    end
endmodule
