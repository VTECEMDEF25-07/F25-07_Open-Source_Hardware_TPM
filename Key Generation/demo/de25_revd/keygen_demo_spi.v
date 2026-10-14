// Filename: keygen_demo_spi.v
// Modules: keygen_demo_spi
// Authors: Project contributors; see Git history.
// Date: 2026-10-13
// General Description: Implements the demonstration SPI register interface and bounded operation handshakes.
// AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

// Fixed eight-byte mode-0 frames. Writes publish only after all 64 bits arrive.
module keygen_demo_spi (
    input clock_i, input reset_n_i,
    input spi_clock_i, input spi_cs_n_i, input spi_mosi_i,
    output spi_miso_o,
    output [7:0] read_address_o, input [31:0] read_data_i,
    output write_valid_o, output [7:0] write_address_o, output [31:0] write_data_o
);
    reg [2:0] clock_sync_reg, select_sync_reg;
    reg [1:0] mosi_sync_reg;
    reg [7:0] receive_reg, transmit_reg, operation_reg, address_reg;
    reg [31:0] read_snapshot_reg, write_reg;
    reg [3:0] byte_reg;
    reg [2:0] bit_reg;
    reg header_good_reg, write_valid_reg;
    wire [7:0] received_byte = {receive_reg[6:0], mosi_sync_reg[1]};
    wire clock_rise = clock_sync_reg[2:1] == 2'b01;
    wire clock_fall = clock_sync_reg[2:1] == 2'b10;
    assign spi_miso_o = select_sync_reg[1] ? 1'b1 : transmit_reg[7];
    assign read_address_o = address_reg;
    assign write_valid_o = write_valid_reg;
    assign write_address_o = address_reg;
    assign write_data_o = write_reg;
    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            clock_sync_reg <= 0; select_sync_reg <= 3'b111; mosi_sync_reg <= 0;
            receive_reg <= 0; transmit_reg <= 8'ha5; operation_reg <= 0; address_reg <= 0;
            read_snapshot_reg <= 0; write_reg <= 0; byte_reg <= 0; bit_reg <= 0;
            header_good_reg <= 1; write_valid_reg <= 0;
        end else begin
            clock_sync_reg <= {clock_sync_reg[1:0], spi_clock_i};
            select_sync_reg <= {select_sync_reg[1:0], spi_cs_n_i};
            mosi_sync_reg <= {mosi_sync_reg[0], spi_mosi_i};
            write_valid_reg <= 0;
            if (select_sync_reg[1]) begin
                receive_reg <= 0; transmit_reg <= 8'ha5; operation_reg <= 0; address_reg <= 0;
                read_snapshot_reg <= 0; write_reg <= 0; byte_reg <= 0; bit_reg <= 0; header_good_reg <= 1;
            end else if (byte_reg < 8) begin
                if (clock_rise) begin
                    receive_reg <= received_byte;
                    if (bit_reg == 7) begin
                        bit_reg <= 0; byte_reg <= byte_reg + 1'b1;
                        case (byte_reg)
                            0: operation_reg <= received_byte;
                            1: address_reg <= received_byte;
                            2: if (received_byte != 0) header_good_reg <= 0;
                            3: begin
                                if (received_byte != 0) header_good_reg <= 0;
                                read_snapshot_reg <= operation_reg == 1 ? read_data_i : 0;
                            end
                            4,5,6: write_reg <= {write_reg[23:0], received_byte};
                            7: begin
                                write_reg <= {write_reg[23:0], received_byte};
                                if (operation_reg == 2 && header_good_reg) write_valid_reg <= 1;
                            end
                            default: begin end
                        endcase
                    end else bit_reg <= bit_reg + 1'b1;
                end
                if (clock_fall) begin
                    if (bit_reg == 0) begin
                        case (byte_reg)
                            4: transmit_reg <= read_snapshot_reg[31:24];
                            5: transmit_reg <= read_snapshot_reg[23:16];
                            6: transmit_reg <= read_snapshot_reg[15:8];
                            7: transmit_reg <= read_snapshot_reg[7:0];
                            default: transmit_reg <= 0;
                        endcase
                    end else transmit_reg <= {transmit_reg[6:0], 1'b0};
                end
            end
        end
    end
endmodule
