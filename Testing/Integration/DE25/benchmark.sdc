create_clock -name board_clock -period 20.000 [get_ports clock_i]
set core_output [get_registers {clocks|clock_multiplier|fp_sm_iopll_inst|tennm_ph2_iopll~c0cntr_reg}]
if {[get_collection_size $core_output] != 1} {error "Missing fitted core PLL output"}
create_generated_clock -name core_clock -source [get_ports clock_i] -multiply_by 32 -divide_by 30 $core_output
create_generated_clock -name fan_clock -divide_by 128 -source [get_ports clock_i] [get_registers {*fan_control*CLOCKMEM_inst2*CK_1HZ}]
set reset_clear [get_pins -compatibility_mode {spi_release_reg[0]|clrn spi_release_reg[1]|clrn}]
set lock_source [get_registers {clocks|clock_multiplier|fp_sm_iopll_inst|tennm_ph2_iopll~pll_ctrl_reg}]
if {[get_collection_size $reset_clear] != 2 || [get_collection_size $lock_source] != 1} {error "Missing PLL/reset synchronizer"}
set_false_path -from $lock_source -to $reset_clear
set telemetry_first [get_registers {*telemetry_meta_reg*}]
if {[get_collection_size $telemetry_first] == 0} {error "Missing telemetry synchronizer"}
set_false_path -to $telemetry_first
derive_clock_uncertainty
# Existing 100 kHz diagnostic SPI receiver, unrelated to the production TPM SPI.
set_false_path -from [get_ports {spi_clock_i spi_cs_n_i spi_mosi_i board_reset_n_i spi_reset_n_i fan_i2c_scl fan_i2c_sda}]
set_false_path -to [get_ports {fan_i2c_scl fan_i2c_sda}]
set_max_delay 20.000 -to [get_ports {spi_miso_o interrupt_n_o}]
set_min_delay 0.000 -to [get_ports {spi_miso_o interrupt_n_o}]

# Only the asynchronous pulse-capture SET/CLR pin is excepted. Data paths,
# event acknowledgements, Gray counters and second-stage synchronizers stay timed.
set capture_pins [get_pins -compatibility_mode {trace|pll_events|pending_reg*|clrn trace|pll_events|pending_reg*|prn}]
if {[get_collection_size $capture_pins] < 1} {error "Missing PLL event-capture asynchronous pin"}
set_false_path -from $lock_source -to $capture_pins
set reset_first [get_registers {*reset_meta_reg*}]
if {[get_collection_size $reset_first] < 1} {error "Missing reset-trace synchronizer"}
set_false_path -to $reset_first
