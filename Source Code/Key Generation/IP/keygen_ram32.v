// Filename: keygen_ram32.v
// Modules: keygen_ram32
// Authors: Aaron Grossman; Project contributors; see Git history.
// Date: 2026-10-13
// General Description: Selects the generic or Altera synchronous scratch-memory resource.
// AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

`include "ip_types.vh"

module keygen_ram32 #(parameter ADDRESS_WIDTH = 8, parameter IP_TYPE = `IP_GENERIC, parameter DEVICE_FAMILY = "Agilex 5") (
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
    generate
        if (IP_TYPE == `IP_GENERIC) begin : generic_ip
            keygen_ram32_generic #(.ADDRESS_WIDTH(ADDRESS_WIDTH)) implementation (
                .clock_i(clock_i), .reset_n_i(reset_n_i), .clock_en_i(clock_en_i),
                .write_en_i(write_en_i), .write_address_i(write_address_i),
                .write_data_i(write_data_i), .read_en_i(read_en_i),
                .read_address_i(read_address_i), .read_valid_o(read_valid_o),
                .read_data_o(read_data_o)
            );
        end else if (IP_TYPE == `IP_ALTERA) begin : altera_ip
            keygen_ram32_altera #(.ADDRESS_WIDTH(ADDRESS_WIDTH), .DEVICE_FAMILY(DEVICE_FAMILY)) implementation (
                .clock_i(clock_i), .reset_n_i(reset_n_i), .clock_en_i(clock_en_i),
                .write_en_i(write_en_i), .write_address_i(write_address_i),
                .write_data_i(write_data_i), .read_en_i(read_en_i),
                .read_address_i(read_address_i), .read_valid_o(read_valid_o),
                .read_data_o(read_data_o)
            );
        end else begin : invalid_ip
`ifdef VERILATOR
            // The installed Verilator 5.020 resolves unknown cells before pruning branches.
            // Stop before any transfers; runners must require their explicit PASS marker.
            initial begin
                $display("KEYGEN_INVALID_IP_TYPE: use IP_GENERIC or IP_ALTERA"); $stop;
            end
`else
            KEYGEN_INVALID_IP_TYPE__USE_IP_GENERIC_OR_IP_ALTERA invalid_selection ();
`endif
        end
    endgenerate
endmodule
