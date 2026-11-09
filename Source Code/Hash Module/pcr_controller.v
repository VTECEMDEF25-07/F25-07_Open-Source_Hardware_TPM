// Filename: pcr_controller.v
// Author: Makeda Solomon; refactor assisted by Codex
// Date: November 09, 2026
// Description: Hash the current PCR and new measurement, then store the digest.
`default_nettype none
module pcr_controller #(
    parameter integer PCR_COUNT = 24,
    parameter integer INDEX_WIDTH = 5
) (
    input wire clk, reset_n, extend_start,
    input wire [INDEX_WIDTH-1:0] extend_index,
    input wire [255:0] measurement, old_pcr,
    output wire busy,
    output reg done, error,
    output wire write_enable,
    output reg [INDEX_WIDTH-1:0] write_index,
    output wire [255:0] write_data,
    output wire request_valid,
    input wire request_grant,
    output wire [7:0] hash_data,
    output wire hash_data_valid, hash_message_end,
    input wire hash_data_ready,
    input wire [255:0] hash_digest,
    input wire hash_digest_valid,
    output wire hash_digest_ready
);
    localparam [1:0] IDLE = 0, REQUEST = 1, STREAM = 2, DIGEST = 3;
    reg [1:0] state;
    reg [511:0] extend_bytes;
    reg [5:0] byte_index;

    assign busy = state != IDLE;
    assign request_valid = reset_n && state == REQUEST;
    assign hash_data_valid = reset_n && state == STREAM;
    assign hash_data = hash_data_valid ? extend_bytes[511 - byte_index*8 -: 8] : 8'b0;
    assign hash_message_end = hash_data_valid && byte_index == 63;
    assign hash_digest_ready = reset_n && state == DIGEST;
    assign write_enable = hash_digest_valid && hash_digest_ready;
    assign write_data = hash_digest;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= IDLE;
            extend_bytes <= 0;
            byte_index <= 0;
            write_index <= 0;
            done <= 0;
            error <= 0;
        end else begin
            done <= 0;
            error <= 0;
            case (state)
                IDLE: if (extend_start) begin
                    if (extend_index < PCR_COUNT) begin
                        extend_bytes <= {old_pcr, measurement};
                        write_index <= extend_index;
                        byte_index <= 0;
                        state <= REQUEST;
                    end else begin
                        done <= 1;
                        error <= 1;
                    end
                end
                REQUEST: if (request_grant) state <= STREAM;
                STREAM: if (hash_data_ready) begin
                    if (hash_message_end) begin
                        extend_bytes <= 0;
                        state <= DIGEST;
                    end else byte_index <= byte_index + 1'b1;
                end
                DIGEST: if (hash_digest_valid) begin
                    done <= 1;
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
`default_nettype wire
