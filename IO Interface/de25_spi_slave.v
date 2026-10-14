// Mode-0, MSB-first SPI for a 50 MHz system clock and SPI clocks <= 1 MHz.
// All state is clocked by clock_i; SPI inputs are synchronized before use.
// Keep CS low/high and each SCK half-period for at least five system clocks.
module de25_spi_slave (
    input clock_i,
    input reset_n_i,
    output reg rx_valid_o,
    output reg [7:0] rx_data_o,
    input tx_valid_i,
    input [7:0] tx_data_i,
    output reg tx_request_o,
    output reg tx_received_o,
    input spi_clock_i,
    input spi_mosi_i,
    input spi_cs_n_i,
    output spi_miso_o,
    output chip_select_n_o
);
    reg spi_clock_meta_reg, spi_clock_sync_reg, spi_clock_previous_reg;
    reg spi_mosi_meta_reg, spi_mosi_sync_reg;
    reg chip_select_meta_reg, chip_select_sync_reg;
    reg [2:0] bit_count_reg;
    reg [7:0] rx_shift_reg, tx_shift_reg, tx_preload_reg;
    wire spi_rising;
    wire spi_falling;
    assign spi_rising = spi_clock_sync_reg && !spi_clock_previous_reg;
    assign spi_falling = !spi_clock_sync_reg && spi_clock_previous_reg;
    assign chip_select_n_o = chip_select_sync_reg;
    assign spi_miso_o = chip_select_sync_reg ? 1'b0 : tx_shift_reg[7];

    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            spi_clock_meta_reg <= 1'b0;
            spi_clock_sync_reg <= 1'b0;
            spi_clock_previous_reg <= 1'b0;
            spi_mosi_meta_reg <= 1'b0;
            spi_mosi_sync_reg <= 1'b0;
            chip_select_meta_reg <= 1'b1;
            chip_select_sync_reg <= 1'b1;
        end else begin
            spi_clock_meta_reg <= spi_clock_i;
            spi_clock_sync_reg <= spi_clock_meta_reg;
            spi_clock_previous_reg <= spi_clock_sync_reg;
            spi_mosi_meta_reg <= spi_mosi_i;
            spi_mosi_sync_reg <= spi_mosi_meta_reg;
            chip_select_meta_reg <= spi_cs_n_i;
            chip_select_sync_reg <= chip_select_meta_reg;
        end
    end

    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            bit_count_reg <= 3'd0;
            rx_shift_reg <= 8'd0;
            tx_shift_reg <= 8'd0;
            tx_preload_reg <= 8'd0;
            rx_data_o <= 8'd0;
            rx_valid_o <= 1'b0;
            tx_request_o <= 1'b0;
            tx_received_o <= 1'b0;
        end else begin
            rx_valid_o <= 1'b0;
            tx_request_o <= 1'b0;
            tx_received_o <= 1'b0;
            if (chip_select_sync_reg) begin
                bit_count_reg <= 3'd0;
                rx_shift_reg <= 8'd0;
                tx_shift_reg <= 8'd0;
                tx_preload_reg <= 8'd0;
                rx_data_o <= 8'd0;
            end else begin
                // Retain the existing level-valid/ack handshake. The producer
                // can hold valid until it sees received, with stable data.
                if (tx_valid_i) begin
                    tx_preload_reg <= tx_data_i;
                    tx_received_o <= 1'b1;
                end
                if (spi_rising) begin
                    rx_shift_reg <= {rx_shift_reg[6:0], spi_mosi_sync_reg};
                    bit_count_reg <= bit_count_reg + 3'd1;
                    if (bit_count_reg == 3'd7) begin
                        rx_data_o <= {rx_shift_reg[6:0], spi_mosi_sync_reg};
                        rx_valid_o <= 1'b1;
                    end
                end
                if (spi_falling) begin
                    // Legacy TX_request occurs after the first bit of each
                    // byte. Prepare the NEXT byte while this one shifts out.
                    if (bit_count_reg == 3'd1) tx_request_o <= 1'b1;
                    if (bit_count_reg == 3'd0)
                        tx_shift_reg <= tx_preload_reg;
                    else
                        tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                end
            end
        end
    end
endmodule
