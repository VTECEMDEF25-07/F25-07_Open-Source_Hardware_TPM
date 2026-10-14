# Minimal DE25 port: original spi_slave is preserved, with related 50/100 MHz.
# This is NOT complete signoff for the inherited asynchronous serializer.
create_clock -name board_clock -period 20.000 [get_ports clock_i]
# Both TPM clocks use the same physical PLL compensation network.
# C0=64 produces50MHz; C1=32 produces100MHz from50MHz*N(1)^-1*M(64).
# PHASE_SHIFT0/1=0. Normal compensation targets output0. Fitted clock delays
# remain modeled; no manually invented PLL latency or phase offset is applied.
set pll_output_50 [get_registers {clocks|clock_multiplier|fp_sm_iopll_inst|tennm_ph2_iopll~c0cntr_reg}]
set pll_output_100 [get_registers {clocks|clock_multiplier|fp_sm_iopll_inst|tennm_ph2_iopll~c1cntr_reg}]
if {[get_collection_size $pll_output_50] != 1 || [get_collection_size $pll_output_100] != 1} { error "Expected exactly one fitted PLL C0 and C1 output" }
create_generated_clock -name pll_clock_50 -source [get_ports clock_i] -divide_by 1 $pll_output_50
create_generated_clock -name pll_clock_100 -source [get_ports clock_i] -multiply_by 2 $pll_output_100
# PLL lock asynchronously asserts the two-stage TPM release synchronizer.
# Exact source and CLR pins verified in the v3 fitted netlist. Scope the
# asynchronous reset exception ONLY to these two clear inputs: interstage D,
# release-register output and all downstream reset recovery/removal stay timed.
set pll_lock_source [get_registers {clocks|clock_multiplier|fp_sm_iopll_inst|tennm_ph2_iopll~pll_ctrl_reg}]
set tpm_release_clear [get_pins -compatibility_mode {tpm_release_reg[0]|clrn tpm_release_reg[1]|clrn}]
if {[get_collection_size $pll_lock_source] != 1 || [get_collection_size $tpm_release_clear] != 2} { error "Expected PLL lock source and exactly two TPM release CLR pins" }
set_false_path -from $pll_lock_source -to $tpm_release_clear
create_generated_clock -name fan_clock -divide_by 128 -source [get_ports clock_i] [get_registers {*fan_control*CLOCKMEM_inst2*CK_1HZ}]

# External SPI operating envelope for empirical tests: mode 0, <=1 MHz.
# This clock constrains directly clocked RX registers and falling-edge TX_counter.
create_clock -name spi_clock -period 1000.000 -waveform {0.000 500.000} [get_ports spi_clock_i]
# Deliberately no blanket asynchronous clock groups or raw-SPI input false paths:
# RX_done1 feeds functional logic, TX_counter is a binary bus crossing, and raw
# chip select drives 50 MHz logic. Cutting these paths would hide existing risks.
# MOSI/CS input windows and MISO host setup/hold are NOT signed off here: an
# adapter-specific min/max delay budget and physical measurement remain needed.
# Do not interpret optimistic phase-related SPI/board paths as CDC correctness.

# det_clock = det_clock0 & ~det_clock1 pulses after a sampled SPI RISING edge.
# Its phase depends on asynchronous sampling by dual-edge 100 MHz registers.
# No fictitious fixed divide/phase generated clock is assigned: report its
# unclocked TX_temp endpoints as an explicit inherited limitation. Functional
# tests cannot prove clock-pulse/glitch safety or metastability immunity.
# All PLL/board half-cycle paths and internal reset recovery/removal stay timed.

# Bound output routing only; these are NOT external SPI setup/hold guarantees.
set_max_delay 20.000 -to [get_ports spi_miso_o]
set_min_delay 0.000 -to [get_ports spi_miso_o]
set_max_delay 20.000 -to [get_ports interrupt_n_o]
set_min_delay 0.000 -to [get_ports interrupt_n_o]
# Raw asynchronous board/reset inputs; internal registered release paths remain.
# SPI_CS_n is intentionally NOT included: it also has functional data fanout.
set_false_path -from [get_ports {board_reset_n_i spi_reset_n_i}]
# Existing autonomous slow management I2C interface, independent of TPM SPI.
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
