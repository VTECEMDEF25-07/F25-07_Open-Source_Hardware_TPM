# Common SPI/TPM state runs at the board 50 MHz clock; no PLL is needed.
# SCK is asynchronous data, never a clock for internal state.
create_clock -name board_clock -period 20.000 [get_ports CLOCK_50]
derive_clock_uncertainty
foreach {port first_stage} {
    GPIO_1_2 spi_clock_meta_reg
    GPIO_1_3 spi_mosi_meta_reg
    GPIO_1_5 chip_select_meta_reg
} {
    set stage [get_registers "tpm|io|spi_serializer|$first_stage"]
    if {[get_collection_size $stage] != 1} {error "Expected one SPI first stage: $first_stage"}
    set_false_path -from [get_ports $port] -to $stage
}
# All interstage and functional paths remain timed. Mode 0, <=1 MHz,
# SCK high/low >=500 ns; CS setup/hold/high >=100 ns.
# Output routing bounds are not a measured physical-host setup/hold guarantee.
set_max_delay 20.000 -to [get_ports {GPIO_1_4 GPIO_1_7 LEDR[*]}]
set_min_delay 0.000 -to [get_ports {GPIO_1_4 GPIO_1_7 LEDR[*]}]
set_false_path -from [get_ports {RESET_N GPIO_1_6}]
