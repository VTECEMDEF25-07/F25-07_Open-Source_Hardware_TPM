# Common SPI timing, sourced after the board defines spi_*_port variables.
# 30 MHz SCK also covers the original FTDI tester's integer-divider setting.
# Required PTP operating range remains 10--24 MHz.
set spi_period 33.333333
set spi_half [expr {$spi_period / 2.0}]
create_clock -name spi_clock -period $spi_period [get_ports $spi_sck_port]
# Host MOSI setup >=2 ns and hold >=3 ns at the TPM pads (PTP electrical table).
set_input_delay -clock spi_clock -clock_fall -max [expr {$spi_half-2.0}] [get_ports $spi_mosi_port]
set_input_delay -clock spi_clock -clock_fall -min [expr {3.0-$spi_half}] [get_ports $spi_mosi_port]
# Model frame start before the first rising SCK. The full TPM host contract
# retains >=100 ns CS setup/hold/high; pad checks use 5 ns, or a documented
# board override (DE1:10 ns) for its asynchronous frame-reset route.
# A phase-shifted virtual clock represents this event without incorrectly
# applying a next-rising-edge input arrival to the intervening falling edge.
# SCK is held low between frames, CS high >=50 ns; no earlier SCK edge lies
# in the real reset-release/removal window. CS rises >=5 ns after final fall.
if {![info exists spi_cs_setup_ns]} {set spi_cs_setup_ns 5.0}
set frame_start [expr {$spi_period - $spi_cs_setup_ns}]
create_clock -name spi_frame_start -period $spi_period -waveform [list $frame_start [expr {$frame_start+$spi_half}]]
set_input_delay -clock spi_frame_start -max 0.0 [get_ports $spi_cs_port]
set_input_delay -clock spi_frame_start -min 0.0 [get_ports $spi_cs_port]
# MISO changes on falling SCK and is captured on rising SCK. Reserve 30%
# of the half-period for host capture setup (5 ns at the tester's 30 MHz),
# meeting the required <=0.7 half-period output-valid limit through 24 MHz.
set_output_delay -clock spi_clock -max [expr {0.3*$spi_half}] [get_ports $spi_miso_port]
set_output_delay -clock spi_clock -min 0.0 [get_ports $spi_miso_port]

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
# Hold checks between these unrelated clocks do not describe a sampling event;
# the handshake holds each payload through its actual destination capture.
# Include physical duplicate registers introduced by the fitter. Verify every
# logical bit rather than requiring a physical register count of exactly eight.
proc spi_bus {prefix names} {
    set patterns {}
    foreach name $names {
        lappend patterns "${prefix}${name}*"
        for {set bit 0} {$bit < 8} {incr bit} {
            set bit_pattern [format {%s%s[%d]*} $prefix $name $bit]
            if {[get_collection_size [get_registers -nowarn $bit_pattern]] < 1} {
                error "Missing SPI mailbox bit: $name bit $bit"
            }
        }
    }
    return [get_registers $patterns]
}
set rx_source [spi_bus $spi_prefix {rx_mailbox_reg}]
set rx_destination [spi_bus $spi_prefix {rx_data_o}]
set tx_source [spi_bus $spi_prefix {tx_mailbox_reg}]
set tx_destination [spi_bus $spi_prefix {tx_pending_reg tx_shift_reg}]
set_max_delay 20.000 -from $rx_source -to $rx_destination
set_false_path -hold -from $rx_source -to $rx_destination
set_max_delay 20.000 -from $tx_source -to $tx_destination
set_false_path -hold -from $tx_source -to $tx_destination
# Raw CS drives only the MISO tri-state enable here. A separate 20 ns OE route
# bound does not relax falling-SCK-to-MISO data timing or claim a host budget.
set_max_delay 20.000 -from [get_ports $spi_cs_port] -to [get_ports $spi_miso_port]
set_min_delay 0.000 -from [get_ports $spi_cs_port] -to [get_ports $spi_miso_port]
derive_clock_uncertainty
