module keygen_ram32 #(parameter ADDRESS_WIDTH = 8) (
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
`ifdef KEYGEN_ALTERA
    keygen_ram32_altera #(.ADDRESS_WIDTH(ADDRESS_WIDTH)) implementation (
`else
    keygen_ram32_generic #(.ADDRESS_WIDTH(ADDRESS_WIDTH)) implementation (
`endif
        .clock_i(clock_i), .reset_n_i(reset_n_i), .clock_en_i(clock_en_i),
        .write_en_i(write_en_i), .write_address_i(write_address_i),
        .write_data_i(write_data_i), .read_en_i(read_en_i),
        .read_address_i(read_address_i), .read_valid_o(read_valid_o),
        .read_data_o(read_data_o)
    );
endmodule
