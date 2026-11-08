# Filename: de25_soc_top.sdc
# Author: Aaron Grossman
# Date: 2026-10-14
# General Description: Connects the TPM to DE25 pins, related clocks, reset and independent cooling.

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

derive_clock_uncertainty
