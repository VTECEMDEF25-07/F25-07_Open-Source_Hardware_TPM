# Filename: de25_soc_top.sdc
# Author: Aaron Grossman
# Date: 2026-10-14
# General Description: Connects the TPM to DE25 pins, related clocks, reset and independent cooling.

# SPI shifts on external SCK; TPM processing remains at 50 MHz.
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
# release-register output and the related core reset recovery/removal stay timed.
set pll_lock_source [get_registers {clocks|clock_multiplier|fp_sm_iopll_inst|tennm_ph2_iopll~pll_ctrl_reg}]
set tpm_release_clear [get_pins -compatibility_mode {tpm_release_reg[0]|clrn tpm_release_reg[1]|clrn}]
if {[get_collection_size $pll_lock_source] != 1 || [get_collection_size $tpm_release_clear] != 2} { error "Expected PLL lock source and exactly two TPM release CLR pins" }
set_false_path -from $pll_lock_source -to $tpm_release_clear
create_generated_clock -name fan_clock -divide_by 128 -source [get_ports clock_i] [get_registers {*fan_control*CLOCKMEM_inst2*CK_1HZ}]

# Reset release is synchronous to the core but asynchronous to external SCK.
# Host contract: keep CS high and SCK low through reset and for >=1 us after
# release, then meet the timed CS-to-SCK setup/hold. No SPI transfer occurs
# during this startup interval. Except only SCK-domain asynchronous clear pins;
# never cut the core release paths, mailbox data, CS framing or clocked logic.
set spi_reset_patterns {}
foreach name {rx_bit_count_reg rx_shift_reg rx_mailbox_reg rx_toggle_reg tx_bit_count_reg tx_shift_reg tx_pending_reg tx_pending_valid_reg offer_meta_reg offer_sync_reg offer_seen_reg request_toggle_reg tx_ack_reg} {
    lappend spi_reset_patterns "tpm|io|spi_serializer|${name}*|clrn"
}
set spi_reset_clear [get_pins -compatibility_mode $spi_reset_patterns]
if {[get_collection_size $spi_reset_clear] < 40} {error "Missing SCK-domain asynchronous reset pins"}
set_false_path -from [get_registers {tpm_release_reg[1]}] -to $spi_reset_clear

# Demo recovery also resets the SCK domain while the host holds CS high/SCK low.
# Except only these supervisor controls into SCK asynchronous clear pins. Core
# reset recovery/removal and synchronizer interstage data remain fully timed.
set demo_reset_sources [get_registers -nowarn {*supervisor*release_sync* *supervisor*reset_count*}]
if {[get_collection_size $demo_reset_sources] > 0} {
    set_false_path -from $demo_reset_sources -to $spi_reset_clear
}

# SPI uses its own external clock and held-data CDC mailboxes.
set spi_sck_port spi_clock_i
set spi_mosi_port spi_mosi_i
set spi_cs_port spi_cs_n_i
set spi_miso_port spi_miso_o

# Bound output routing only; these are NOT external SPI setup/hold guarantees.
set_max_delay 20.000 -to [get_ports interrupt_n_o]
set_min_delay 0.000 -to [get_ports interrupt_n_o]
# Raw asynchronous board/reset inputs; internal registered release paths remain.
# SPI CS is excepted only into its first synchronizer stage above.
set_false_path -from [get_ports {board_reset_n_i spi_reset_n_i}]
# Existing autonomous slow management I2C interface, independent of TPM SPI.
set_false_path -from [get_ports {fan_i2c_scl fan_i2c_sda}]
set_false_path -to [get_ports {fan_i2c_scl fan_i2c_sda}]

derive_clock_uncertainty

# Experimental physical RNG: the four free-running RO outputs feed an XOR and
# the first sampling D asynchronously. Except only this verified single D pin.
# Stage0 Q -> stage1 D and both asynchronous-clear recovery/removal stay timed.
# TEST excludes this hierarchy and has no RNG timing exception.
set demo_rng_sampler [get_registers -nowarn {*g_fresh.u_entropy|sample_sync*}]
if {[get_collection_size $demo_rng_sampler] > 0} {
    if {[get_collection_size $demo_rng_sampler] != 2} {error "Expected exactly two fresh RNG sampling registers"}
    set demo_rng_first_d [get_pins -compatibility_mode -nowarn {*u_operation|u_source|g_fresh.u_entropy|sample_sync[0]|d}]
    if {[get_collection_size $demo_rng_first_d] != 1} {error "Expected exactly one fresh RNG first-stage D pin"}
    set_false_path -to $demo_rng_first_d
}
