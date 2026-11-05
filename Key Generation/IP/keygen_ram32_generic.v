// Filename: keygen_ram32_generic.v
// Modules: keygen_ram32_generic
// Authors: Project contributors; see Git history.
// Date: 2026-10-13
// General Description: Implements portable synchronous scratch memory and the defined read/write contract.
// AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

// One enabled-edge read, new data on collision. Reset never clears memory.
module keygen_ram32_generic #(parameter ADDRESS_WIDTH = 8) (
    input clock_i,
    input reset_n_i,
    input clock_en_i,
    input write_en_i,
    input [ADDRESS_WIDTH-1:0] write_address_i,
    input [31:0] write_data_i,
    input read_en_i,
    input [ADDRESS_WIDTH-1:0] read_address_i,
    output read_valid_o,
    output [31:0] read_data_o
);
    reg read_valid_reg;
    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) read_valid_reg <= 1'b0;
        else if (clock_en_i) read_valid_reg <= read_en_i;
    end
    assign read_valid_o = read_valid_reg;
    reg [31:0] memory_reg [0:(1 << ADDRESS_WIDTH)-1];
    reg [31:0] read_data_reg;
    always @(posedge clock_i) begin
        if (reset_n_i && clock_en_i) begin
            if (write_en_i) memory_reg[write_address_i] <= write_data_i;
            if (read_en_i) begin
                if (write_en_i && write_address_i == read_address_i)
                    read_data_reg <= write_data_i;
                else read_data_reg <= memory_reg[read_address_i];
            end
        end
    end
    assign read_data_o = read_data_reg;
endmodule
