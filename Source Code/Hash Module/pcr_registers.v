// Filename: pcr_registers.v
// Author: Codex, Makeda Solomon
// Date: November 9, 2026
// Description: Store one SHA-256 PCR bank with two indexed reads and one write port.
// RESET_VALUES packs PCR 0 at the low end. The default models an empty
// bank for module tests. Platform startup and locality policy are upstream.
`default_nettype none
module pcr_registers #(
    parameter integer PCR_COUNT = 24,
    parameter integer INDEX_WIDTH = 5,
    parameter [PCR_COUNT*256-1:0] RESET_VALUES = {PCR_COUNT*256{1'b0}}
) (
    input wire clk, reset_n,
    input wire [INDEX_WIDTH-1:0] read_index, extend_index,
    output wire [255:0] read_data, extend_data,
    output wire read_valid,
    input wire write_enable,
    input wire [INDEX_WIDTH-1:0] write_index,
    input wire [255:0] write_data
);
    reg [255:0] bank [0:PCR_COUNT-1];
    integer i;

    assign read_valid = reset_n && read_index < PCR_COUNT;
    assign read_data = read_valid ? bank[read_index] : 256'b0;
    assign extend_data = reset_n && extend_index < PCR_COUNT ? bank[extend_index] : 256'b0;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            for (i = 0; i < PCR_COUNT; i = i + 1)
                bank[i] <= RESET_VALUES[i*256 +: 256];
        end else if (write_enable && write_index < PCR_COUNT)
            bank[write_index] <= write_data;
    end
endmodule
`default_nettype wire
