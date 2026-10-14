# DE25_SPI=1 uses only the 50 MHz clock and synchronized external SPI inputs.
# Full fitted timing and crossing review are still required before acceptance.
create_clock -name board_clock -period 20.000 [get_ports clock_i]
create_generated_clock -name fan_clock -divide_by 128 -source [get_ports clock_i] [get_registers {*fan_control*CLOCKMEM_inst2*CK_1HZ}]
# Each input feeds only its first synchronizer stage; no raw SPI clocks logic.
set_false_path -from [get_ports {spi_clock_i spi_mosi_i spi_cs_n_i}]
# At <=1 MHz the host samples 500 ns after each falling edge. Synchronization
# and one processing edge consume <=80 ns, leaving margin for this output bound.
set_max_delay 20.000 -to [get_ports spi_miso_o]
set_min_delay 0.000 -to [get_ports spi_miso_o]
# Raw asynchronous reset sources. Internal release recovery/removal is retained.
set_false_path -from [get_ports {board_reset_n_i spi_reset_n_i}]
set_max_delay 20.000 -to [get_ports interrupt_n_o]
set_min_delay 0.000 -to [get_ports interrupt_n_o]
# Vendor open-drain slow management bus, autonomous and separate from SPI.
set_false_path -from [get_ports {fan_i2c_scl fan_i2c_sda}]
set_false_path -to [get_ports {fan_i2c_scl fan_i2c_sda}]

# JTAG diagnostic timing (DE25 RevD onboard USB-Blaster III, single FPGA chain).
# Operational gate: jtagconfig --getparam "DE25-Standard [USB-1]" JtagClock
# must report 15M before programming/diagnostic access. Faster TCK is not covered.
# Agilex5 JTAG uses VCCIO_SDM=1.8V (JTAG Boundary-Scan guide820038,section4).
# USB-BlasterIII guide864466,section5.4,table10 is TARGET-device perspective:
# available input setup TDI16.47ns/TMS16.79ns,hold16.49ns; target TCO<=5.95ns.
# Reserve1ns additional board skew; retain the30MHz minimum input windows even
# at15MHz, which is conservative. This budget is not a measured trace delay.
# https://docs.altera.com/r/docs/864466/current/usb-blaster-iii-fpga-development-cable-user-guide/jtag-timing-constraints-and-waveforms
# https://docs.altera.com/r/docs/683081/22.2/quartus-prime-timing-analyzer-cookbook/jtag-signals
if {[get_collection_size [get_ports -nowarn altera_reserved_tck]] > 0} {
    set jtag_period_ns 66.666
    create_clock -name altera_reserved_tck -period $jtag_period_ns [get_ports altera_reserved_tck]
    # The probe captures read-only diagnostic data asynchronously. It cannot
    # drive functional logic; arbitrary JTAG/board phase is not synchronous STA.
    set_clock_groups -asynchronous -group [get_clocks altera_reserved_tck]
    # Rising-edge-relative arrival windows enforce the available setup/hold.
    set_input_delay -clock altera_reserved_tck -max [expr {$jtag_period_ns - 15.47}] [get_ports altera_reserved_tdi]
    set_input_delay -clock altera_reserved_tck -min 15.49 [get_ports altera_reserved_tdi]
    set_input_delay -clock altera_reserved_tck -max [expr {$jtag_period_ns - 15.79}] [get_ports altera_reserved_tms]
    set_input_delay -clock altera_reserved_tck -min 15.49 [get_ports altera_reserved_tms]
    # Figure16 shows falling-TCK launch; Figure17 identifies FT2232H.
    # FT2232H datasheet4.6 divides CLKOUT internally for a lower rate:
    # https://ftdichip.com/wp-content/uploads/2024/09/DS_FT2232H.pdf
    # With unchanged driver sampling phase,15MHz gains at least half a cycle
    # versus30MHz (same-edge sampling gains more). Keep1ns board allowance:
    # permittedTCO=5.95+(66.666-33.334)/2-1=21.616ns.
    # This is an explicit operating assumption tied to divider-selected15M;
    # changing the adapter, chain, or sampling mode requires a new analysis.
    set jtag_tco_budget_ns [expr {5.95 + ($jtag_period_ns - 33.334)/2.0 - 1.0}]
    set_output_delay -clock altera_reserved_tck -clock_fall -max [expr {$jtag_period_ns - $jtag_tco_budget_ns}] [get_ports altera_reserved_tdo]
    set_output_delay -clock altera_reserved_tck -clock_fall -min 0.0 [get_ports altera_reserved_tdo]
    # Documented dedicated TAP/security bypasses do not traverse debug fabric.
    set_false_path -from [get_ports altera_reserved_tdi] -to [get_ports altera_reserved_tdo]
    if {[get_collection_size [get_registers -nowarn *~jtag_reg]] > 0} {
        set_false_path -from [get_registers *~jtag_reg] -to [get_ports altera_reserved_tdo]
    }
}

derive_clock_uncertainty
