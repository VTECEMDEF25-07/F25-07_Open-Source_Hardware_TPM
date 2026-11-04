# Common SPI timing, sourced after the board defines spi_*_port variables.
# 30 MHz closes a faster clock than the required 10--24 MHz operating range.
set spi_period 33.333333
set spi_half [expr {$spi_period / 2.0}]
create_clock -name spi_clock -period $spi_period [get_ports $spi_sck_port]
# Host MOSI setup >=2 ns and hold >=3 ns at the TPM pads (PTP electrical table).
set_input_delay -clock spi_clock -clock_fall -max [expr {$spi_half-2.0}] [get_ports $spi_mosi_port]
set_input_delay -clock spi_clock -clock_fall -min [expr {3.0-$spi_half}] [get_ports $spi_mosi_port]
# CS setup/hold >=5 ns. CS is both framing reset in the SPI domain and data
# into the system-domain synchronizer; only the latter path is excepted.
set_input_delay -clock spi_clock -max [expr {$spi_period-5.0}] [get_ports $spi_cs_port]
set_input_delay -clock spi_clock -clock_fall -min 5.0 [get_ports $spi_cs_port]
# MISO changes on falling SCK and is captured on rising SCK. Budget its
# clock-to-pad validity at <=0.7 of the half-period, with nonnegative hold.
set_output_delay -clock spi_clock -max [expr {0.3*$spi_half}] [get_ports $spi_miso_port]
set_output_delay -clock spi_clock -clock_fall -min 0.0 [get_ports $spi_miso_port]

set spi_prefix {tpm|io|spi_serializer|}
foreach name {rx request ack offer} {
    set first [get_registers "${spi_prefix}${name}_meta_reg"]
    set second [get_registers "${spi_prefix}${name}_sync_reg"]
    if {[get_collection_size $first]!=1 || [get_collection_size $second]!=1} {error "Missing SPI toggle synchronizer: $name"}
    switch $name {
        rx {set source rx_toggle_reg}
        request {set source request_toggle_reg}
        ack {set source tx_ack_reg}
        offer {set source tx_toggle_reg}
    }
    set_false_path -from [get_registers "${spi_prefix}${source}"] -to $first
}
set cs_first [get_registers "${spi_prefix}chip_select_meta_reg"]
if {[get_collection_size $cs_first]!=1} {error "Missing CS synchronizer"}
set_false_path -from [get_ports $spi_cs_port] -to $cs_first

# Bundled-data mailboxes are stable before the corresponding synchronized
# toggle enables capture. Source TX data is held until the returned boundary
# acknowledgement; RX data stays held for a complete SPI byte. Bound bus routes
# rather than inventing a phase relation between unrelated SCK and core clocks.
set rx_source [get_registers [format {%srx_mailbox_reg[*]} $spi_prefix]]
set rx_destination [get_registers [format {%srx_data_o[*]} $spi_prefix]]
set tx_source [get_registers [format {%stx_mailbox_reg[*]} $spi_prefix]]
set tx_destination [get_registers [list [format {%stx_pending_reg[*]} $spi_prefix] [format {%stx_shift_reg[*]} $spi_prefix]]]
if {[get_collection_size $rx_source]!=8 || [get_collection_size $rx_destination]!=8 || [get_collection_size $tx_source]!=8 || [get_collection_size $tx_destination]!=16} {error "Unexpected SPI mailbox bus width"}
set_max_delay 20.000 -from $rx_source -to $rx_destination
set_min_delay 0.000 -from $rx_source -to $rx_destination
set_max_delay 20.000 -from $tx_source -to $tx_destination
set_min_delay 0.000 -from $tx_source -to $tx_destination
# Raw CS drives only the MISO tri-state enable here. A separate 20 ns OE route
# bound does not relax falling-SCK-to-MISO data timing or claim a host budget.
set_max_delay 20.000 -from [get_ports $spi_cs_port] -to [get_ports $spi_miso_port]
set_min_delay 0.000 -from [get_ports $spi_cs_port] -to [get_ports $spi_miso_port]
derive_clock_uncertainty
