# TPM clock remains 50 MHz. SPI clock/pads/mailboxes are constrained separately.
create_clock -name board_clock -period 20.000 [get_ports CLOCK_50]
set spi_sck_port GPIO_1_2
set spi_mosi_port GPIO_1_3
set spi_cs_port GPIO_1_5
set spi_miso_port GPIO_1_4
# Complete TPM host contract is >=100 ns CS setup/hold/high. Check this
# GPIO board's asynchronous frame-reset route at a stricter 10 ns setup.
set spi_cs_setup_ns 10.0
set_max_delay 20.000 -to [get_ports {GPIO_1_7 LEDR[*]}]
set_min_delay 0.000 -to [get_ports {GPIO_1_7 LEDR[*]}]
set_false_path -from [get_ports {RESET_N GPIO_1_6}]
