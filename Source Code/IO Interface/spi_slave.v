// Portable mode-0 SPI agent. SCK clocks the pins; held-data byte mailboxes
// cross to the 50 MHz TPM clock with synchronized request/acknowledge toggles.
module spi_slave (
    input clock_i, input reset_n_i,
    output reg rx_valid_o, output reg [7:0] rx_data_o,
    input tx_valid_i, input [7:0] tx_data_i,
    output reg tx_request_o, output reg tx_received_o,
    input spi_clock_i, input spi_mosi_i, input spi_cs_n_i,
    output spi_miso_o, output chip_select_n_o
);
    wire frame_reset_n = reset_n_i && !spi_cs_n_i;
    reg [2:0] rx_bit_count_reg, tx_bit_count_reg;
    reg [7:0] rx_shift_reg, rx_mailbox_reg;
    reg rx_toggle_reg, request_toggle_reg;
    reg [7:0] tx_shift_reg, tx_pending_reg;
    reg tx_pending_valid_reg;
    reg offer_meta_reg, offer_sync_reg, offer_seen_reg, tx_ack_reg;
    reg chip_select_meta_reg, chip_select_sync_reg;
    reg [7:0] chip_select_delay_reg;
    reg rx_meta_reg, rx_sync_reg, rx_seen_reg;
    reg request_meta_reg, request_sync_reg, request_seen_reg;
    reg ack_meta_reg, ack_sync_reg;
    reg [7:0] tx_mailbox_reg;
    reg tx_toggle_reg, tx_valid_seen_reg;
    wire new_offer = offer_sync_reg != offer_seen_reg;
    assign spi_miso_o = spi_cs_n_i ? 1'bz : tx_shift_reg[7];
    // Let the 50 MHz transaction FSM finish its final byte before it sees
    // deselect. The identical delay on both CS edges preserves frame gaps;
    // the next frame's first complete byte arrives well after its delayed CS.
    assign chip_select_n_o = chip_select_delay_reg[7];

    always @(posedge spi_clock_i or negedge frame_reset_n) begin
        if (!frame_reset_n) begin
            rx_bit_count_reg <= 0; rx_shift_reg <= 0;
        end else begin
            rx_shift_reg <= {rx_shift_reg[6:0], spi_mosi_i};
            rx_bit_count_reg <= rx_bit_count_reg + 3'd1;
        end
    end
    // Capture the completed word on the following falling edge. MOSI now
    // fans out to exactly one input register, allowing physical I/O packing
    // or hold-route balancing without duplicating the external sampling path.
    always @(negedge spi_clock_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            rx_mailbox_reg <= 0; rx_toggle_reg <= 0;
        end else begin
            if (!spi_cs_n_i && rx_bit_count_reg == 0) begin
                rx_mailbox_reg <= rx_shift_reg;
                rx_toggle_reg <= !rx_toggle_reg;
            end
        end
    end
    always @(negedge spi_clock_i or negedge frame_reset_n) begin
        if (!frame_reset_n) begin offer_meta_reg <= 0; offer_sync_reg <= 0; end
        else begin offer_meta_reg <= tx_toggle_reg; offer_sync_reg <= offer_meta_reg; end
    end
    always @(negedge spi_clock_i or negedge frame_reset_n) begin
        if (!frame_reset_n) begin
            tx_bit_count_reg <= 0; tx_shift_reg <= 0; tx_pending_reg <= 0;
            tx_pending_valid_reg <= 0;
            offer_seen_reg <= 0; request_toggle_reg <= 0; tx_ack_reg <= 0;
        end else begin
            tx_bit_count_reg <= tx_bit_count_reg + 3'd1;
            if (tx_bit_count_reg == 0) request_toggle_reg <= !request_toggle_reg;
            if (new_offer) begin
                tx_pending_reg <= tx_mailbox_reg; tx_pending_valid_reg <= 1;
                offer_seen_reg <= offer_sync_reg;
            end
            if (tx_bit_count_reg == 7) begin
                // Forward an offer arriving on the boundary, otherwise use
                // the pending byte. Acknowledge only actual consumption.
                tx_shift_reg <= new_offer ? tx_mailbox_reg :
                                tx_pending_valid_reg ? tx_pending_reg : 8'd0;
                if (new_offer || tx_pending_valid_reg)
                    tx_ack_reg <= new_offer ? offer_sync_reg : offer_seen_reg;
                tx_pending_valid_reg <= 0;
            end else tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
        end
    end
    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            chip_select_meta_reg <= 1; chip_select_sync_reg <= 1;
            chip_select_delay_reg <= 8'hff;
            rx_meta_reg <= 0; rx_sync_reg <= 0;
            request_meta_reg <= 0; request_sync_reg <= 0;
            ack_meta_reg <= 0; ack_sync_reg <= 0;
        end else begin
            chip_select_meta_reg <= spi_cs_n_i; chip_select_sync_reg <= chip_select_meta_reg;
            chip_select_delay_reg <= {chip_select_delay_reg[6:0], chip_select_sync_reg};
            rx_meta_reg <= rx_toggle_reg; rx_sync_reg <= rx_meta_reg;
            request_meta_reg <= request_toggle_reg; request_sync_reg <= request_meta_reg;
            ack_meta_reg <= tx_ack_reg; ack_sync_reg <= ack_meta_reg;
        end
    end
    always @(posedge clock_i or negedge reset_n_i) begin
        if (!reset_n_i) begin
            rx_seen_reg <= 0; request_seen_reg <= 0;
            tx_mailbox_reg <= 0; tx_toggle_reg <= 0; tx_valid_seen_reg <= 0;
            rx_data_o <= 0; rx_valid_o <= 0; tx_request_o <= 0; tx_received_o <= 0;
        end else begin
            rx_valid_o <= 0; tx_request_o <= 0; tx_received_o <= 0;
            // A last-byte event remains valid after external CS rises. Its
            // mailbox is not cleared by CS and the transaction CS is delayed.
            if (rx_sync_reg != rx_seen_reg) begin
                rx_data_o <= rx_mailbox_reg; rx_valid_o <= 1; rx_seen_reg <= rx_sync_reg;
            end
            if (chip_select_sync_reg) begin
                request_seen_reg <= request_sync_reg;
                tx_mailbox_reg <= 0; tx_toggle_reg <= 0; tx_valid_seen_reg <= 0;
            end else begin
                if (request_sync_reg != request_seen_reg) begin
                    tx_request_o <= 1; request_seen_reg <= request_sync_reg;
                end
                if (!tx_valid_i) tx_valid_seen_reg <= 0;
                // One outstanding offer. The payload remains stable until
                // the SPI domain consumes it and its ack returns here.
                if (tx_valid_i && !tx_valid_seen_reg && tx_toggle_reg == ack_sync_reg) begin
                    tx_mailbox_reg <= tx_data_i; tx_toggle_reg <= !tx_toggle_reg;
                    tx_valid_seen_reg <= 1; tx_received_o <= 1;
                end
            end
        end
    end
endmodule
