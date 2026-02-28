## Generated SDC file "de1_soc_top.sdc"

## Copyright (C) 2025  Altera Corporation. All rights reserved.
## Your use of Altera Corporation's design tools, logic functions 
## and other software and tools, and any partner logic 
## functions, and any output files from any of the foregoing 
## (including device programming or simulation files), and any 
## associated documentation or information are expressly subject 
## to the terms and conditions of the Altera Program License 
## Subscription Agreement, the Altera Quartus Prime License Agreement,
## the Altera IP License Agreement, or other applicable license
## agreement, including, without limitation, that your use is for
## the sole purpose of programming logic devices manufactured by
## Altera and sold by Altera or its authorized distributors.  Please
## refer to the Altera Software License Subscription Agreements 
## on the Quartus Prime software download page.


## VENDOR  "Altera"
## PROGRAM "Quartus Prime"
## VERSION "Version 24.1std.0 Build 1077 03/04/2025 SC Lite Edition"

## DATE    "Wed Feb 25 15:02:29 2026"

##
## DEVICE  "5CSEMA5F31C6"
##


#**************************************************************
# Time Information
#**************************************************************

set_time_format -unit ns -decimal_places 3



#**************************************************************
# Create Clock
#**************************************************************

create_clock -name {CLOCK_50} -period 10.000 -waveform { 0.000 5.000 } [get_ports {CLOCK_50}]
create_clock -name {GPIO_1_2} -period 33.333 -waveform { 0.000 16.667 } [get_ports {GPIO_1_2}]
create_clock -name {TPM_TOP:tpm|TPM_IO:io|SPI_SLAVE:spi_serialzier|DET_FF:det_ff0|n} -period 33.333 -waveform { 0.000 16.667 } [get_registers {TPM_TOP:tpm|TPM_IO:io|SPI_SLAVE:spi_serialzier|DET_FF:det_ff0|n}]


#**************************************************************
# Create Generated Clock
#**************************************************************

create_generated_clock -name {PLL0|pll_100_inst|altera_pll_i|general[0].gpll~FRACTIONAL_PLL|vcoph[0]} -source [get_pins {PLL0|pll_100_inst|altera_pll_i|general[0].gpll~FRACTIONAL_PLL|refclkin}] -duty_cycle 50/1 -multiply_by 6 -divide_by 2 -master_clock {CLOCK_50} [get_pins {PLL0|pll_100_inst|altera_pll_i|general[0].gpll~FRACTIONAL_PLL|vcoph[0]}] 
create_generated_clock -name {PLL0|pll_100_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk} -source [get_pins {PLL0|pll_100_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|vco0ph[0]}] -duty_cycle 50/1 -multiply_by 1 -divide_by 6 -master_clock {PLL0|pll_100_inst|altera_pll_i|general[0].gpll~FRACTIONAL_PLL|vcoph[0]} [get_pins {PLL0|pll_100_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] 


#**************************************************************
# Set Clock Latency
#**************************************************************



#**************************************************************
# Set Clock Uncertainty
#**************************************************************

set_clock_uncertainty -rise_from [get_clocks {CLOCK_50}] -rise_to [get_clocks {CLOCK_50}] -setup 0.170  
set_clock_uncertainty -rise_from [get_clocks {CLOCK_50}] -rise_to [get_clocks {CLOCK_50}] -hold 0.060  
set_clock_uncertainty -rise_from [get_clocks {CLOCK_50}] -fall_to [get_clocks {CLOCK_50}] -setup 0.170  
set_clock_uncertainty -rise_from [get_clocks {CLOCK_50}] -fall_to [get_clocks {CLOCK_50}] -hold 0.060  
set_clock_uncertainty -rise_from [get_clocks {CLOCK_50}] -rise_to [get_clocks {TPM_TOP:tpm|TPM_IO:io|SPI_SLAVE:spi_serialzier|DET_FF:det_ff0|n}]  0.220  
set_clock_uncertainty -rise_from [get_clocks {CLOCK_50}] -fall_to [get_clocks {TPM_TOP:tpm|TPM_IO:io|SPI_SLAVE:spi_serialzier|DET_FF:det_ff0|n}]  0.220  
set_clock_uncertainty -fall_from [get_clocks {CLOCK_50}] -rise_to [get_clocks {CLOCK_50}] -setup 0.170  
set_clock_uncertainty -fall_from [get_clocks {CLOCK_50}] -rise_to [get_clocks {CLOCK_50}] -hold 0.060  
set_clock_uncertainty -fall_from [get_clocks {CLOCK_50}] -fall_to [get_clocks {CLOCK_50}] -setup 0.170  
set_clock_uncertainty -fall_from [get_clocks {CLOCK_50}] -fall_to [get_clocks {CLOCK_50}] -hold 0.060  
set_clock_uncertainty -fall_from [get_clocks {CLOCK_50}] -rise_to [get_clocks {TPM_TOP:tpm|TPM_IO:io|SPI_SLAVE:spi_serialzier|DET_FF:det_ff0|n}]  0.220  
set_clock_uncertainty -fall_from [get_clocks {CLOCK_50}] -fall_to [get_clocks {TPM_TOP:tpm|TPM_IO:io|SPI_SLAVE:spi_serialzier|DET_FF:det_ff0|n}]  0.220  
set_clock_uncertainty -rise_from [get_clocks {PLL0|pll_100_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -rise_to [get_clocks {PLL0|pll_100_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -setup 0.070  
set_clock_uncertainty -rise_from [get_clocks {PLL0|pll_100_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -rise_to [get_clocks {PLL0|pll_100_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -hold 0.060  
set_clock_uncertainty -rise_from [get_clocks {PLL0|pll_100_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -fall_to [get_clocks {PLL0|pll_100_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -setup 0.070  
set_clock_uncertainty -rise_from [get_clocks {PLL0|pll_100_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -fall_to [get_clocks {PLL0|pll_100_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -hold 0.060  
set_clock_uncertainty -rise_from [get_clocks {PLL0|pll_100_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -rise_to [get_clocks {TPM_TOP:tpm|TPM_IO:io|SPI_SLAVE:spi_serialzier|DET_FF:det_ff0|n}]  0.240  
set_clock_uncertainty -rise_from [get_clocks {PLL0|pll_100_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -fall_to [get_clocks {TPM_TOP:tpm|TPM_IO:io|SPI_SLAVE:spi_serialzier|DET_FF:det_ff0|n}]  0.240  
set_clock_uncertainty -fall_from [get_clocks {PLL0|pll_100_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -rise_to [get_clocks {PLL0|pll_100_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -setup 0.070  
set_clock_uncertainty -fall_from [get_clocks {PLL0|pll_100_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -rise_to [get_clocks {PLL0|pll_100_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -hold 0.060  
set_clock_uncertainty -fall_from [get_clocks {PLL0|pll_100_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -fall_to [get_clocks {PLL0|pll_100_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -setup 0.070  
set_clock_uncertainty -fall_from [get_clocks {PLL0|pll_100_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -fall_to [get_clocks {PLL0|pll_100_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -hold 0.060  
set_clock_uncertainty -fall_from [get_clocks {PLL0|pll_100_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -rise_to [get_clocks {TPM_TOP:tpm|TPM_IO:io|SPI_SLAVE:spi_serialzier|DET_FF:det_ff0|n}]  0.240  
set_clock_uncertainty -fall_from [get_clocks {PLL0|pll_100_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -fall_to [get_clocks {TPM_TOP:tpm|TPM_IO:io|SPI_SLAVE:spi_serialzier|DET_FF:det_ff0|n}]  0.240  
set_clock_uncertainty -rise_from [get_clocks {GPIO_1_2}] -rise_to [get_clocks {CLOCK_50}]  0.170  
set_clock_uncertainty -rise_from [get_clocks {GPIO_1_2}] -fall_to [get_clocks {CLOCK_50}]  0.170  
set_clock_uncertainty -rise_from [get_clocks {GPIO_1_2}] -rise_to [get_clocks {PLL0|pll_100_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]  0.190  
set_clock_uncertainty -rise_from [get_clocks {GPIO_1_2}] -fall_to [get_clocks {PLL0|pll_100_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]  0.190  
set_clock_uncertainty -rise_from [get_clocks {GPIO_1_2}] -rise_to [get_clocks {GPIO_1_2}] -setup 0.170  
set_clock_uncertainty -rise_from [get_clocks {GPIO_1_2}] -rise_to [get_clocks {GPIO_1_2}] -hold 0.060  
set_clock_uncertainty -rise_from [get_clocks {GPIO_1_2}] -fall_to [get_clocks {GPIO_1_2}] -setup 0.170  
set_clock_uncertainty -rise_from [get_clocks {GPIO_1_2}] -fall_to [get_clocks {GPIO_1_2}] -hold 0.060  
set_clock_uncertainty -rise_from [get_clocks {GPIO_1_2}] -rise_to [get_clocks {TPM_TOP:tpm|TPM_IO:io|SPI_SLAVE:spi_serialzier|DET_FF:det_ff0|n}]  0.220  
set_clock_uncertainty -rise_from [get_clocks {GPIO_1_2}] -fall_to [get_clocks {TPM_TOP:tpm|TPM_IO:io|SPI_SLAVE:spi_serialzier|DET_FF:det_ff0|n}]  0.220  
set_clock_uncertainty -fall_from [get_clocks {GPIO_1_2}] -rise_to [get_clocks {CLOCK_50}]  0.170  
set_clock_uncertainty -fall_from [get_clocks {GPIO_1_2}] -fall_to [get_clocks {CLOCK_50}]  0.170  
set_clock_uncertainty -fall_from [get_clocks {GPIO_1_2}] -rise_to [get_clocks {PLL0|pll_100_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]  0.190  
set_clock_uncertainty -fall_from [get_clocks {GPIO_1_2}] -fall_to [get_clocks {PLL0|pll_100_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]  0.190  
set_clock_uncertainty -fall_from [get_clocks {GPIO_1_2}] -rise_to [get_clocks {GPIO_1_2}] -setup 0.170  
set_clock_uncertainty -fall_from [get_clocks {GPIO_1_2}] -rise_to [get_clocks {GPIO_1_2}] -hold 0.060  
set_clock_uncertainty -fall_from [get_clocks {GPIO_1_2}] -fall_to [get_clocks {GPIO_1_2}] -setup 0.170  
set_clock_uncertainty -fall_from [get_clocks {GPIO_1_2}] -fall_to [get_clocks {GPIO_1_2}] -hold 0.060  
set_clock_uncertainty -fall_from [get_clocks {GPIO_1_2}] -rise_to [get_clocks {TPM_TOP:tpm|TPM_IO:io|SPI_SLAVE:spi_serialzier|DET_FF:det_ff0|n}]  0.220  
set_clock_uncertainty -fall_from [get_clocks {GPIO_1_2}] -fall_to [get_clocks {TPM_TOP:tpm|TPM_IO:io|SPI_SLAVE:spi_serialzier|DET_FF:det_ff0|n}]  0.220  
set_clock_uncertainty -rise_from [get_clocks {TPM_TOP:tpm|TPM_IO:io|SPI_SLAVE:spi_serialzier|DET_FF:det_ff0|n}] -rise_to [get_clocks {PLL0|pll_100_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]  0.240  
set_clock_uncertainty -rise_from [get_clocks {TPM_TOP:tpm|TPM_IO:io|SPI_SLAVE:spi_serialzier|DET_FF:det_ff0|n}] -fall_to [get_clocks {PLL0|pll_100_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]  0.240  
set_clock_uncertainty -rise_from [get_clocks {TPM_TOP:tpm|TPM_IO:io|SPI_SLAVE:spi_serialzier|DET_FF:det_ff0|n}] -rise_to [get_clocks {TPM_TOP:tpm|TPM_IO:io|SPI_SLAVE:spi_serialzier|DET_FF:det_ff0|n}]  0.270  
set_clock_uncertainty -rise_from [get_clocks {TPM_TOP:tpm|TPM_IO:io|SPI_SLAVE:spi_serialzier|DET_FF:det_ff0|n}] -fall_to [get_clocks {TPM_TOP:tpm|TPM_IO:io|SPI_SLAVE:spi_serialzier|DET_FF:det_ff0|n}]  0.270  
set_clock_uncertainty -fall_from [get_clocks {TPM_TOP:tpm|TPM_IO:io|SPI_SLAVE:spi_serialzier|DET_FF:det_ff0|n}] -rise_to [get_clocks {PLL0|pll_100_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]  0.240  
set_clock_uncertainty -fall_from [get_clocks {TPM_TOP:tpm|TPM_IO:io|SPI_SLAVE:spi_serialzier|DET_FF:det_ff0|n}] -fall_to [get_clocks {PLL0|pll_100_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]  0.240  
set_clock_uncertainty -fall_from [get_clocks {TPM_TOP:tpm|TPM_IO:io|SPI_SLAVE:spi_serialzier|DET_FF:det_ff0|n}] -rise_to [get_clocks {TPM_TOP:tpm|TPM_IO:io|SPI_SLAVE:spi_serialzier|DET_FF:det_ff0|n}]  0.270  
set_clock_uncertainty -fall_from [get_clocks {TPM_TOP:tpm|TPM_IO:io|SPI_SLAVE:spi_serialzier|DET_FF:det_ff0|n}] -fall_to [get_clocks {TPM_TOP:tpm|TPM_IO:io|SPI_SLAVE:spi_serialzier|DET_FF:det_ff0|n}]  0.270  


#**************************************************************
# Set Input Delay
#**************************************************************



#**************************************************************
# Set Output Delay
#**************************************************************



#**************************************************************
# Set Clock Groups
#**************************************************************

# Treat SPI_CLOCK domain as asynchronous to synchronous clocks
set_clock_groups -asynchronous -group [get_clocks {GPIO_1_2}] -group [get_clocks {CLOCK_50}]
set_clock_groups -asynchronous -group [get_clocks {GPIO_1_2}] -group [get_clocks {PLL0|pll_100_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]

#**************************************************************
# Set False Path
#**************************************************************

# Break timing paths from DET_FF flip-flop to CLOCK_50 and PLL (these are async synchronizer outputs)
set_false_path -from [get_registers {TPM_TOP:tpm|TPM_IO:io|SPI_SLAVE:spi_serialzier|DET_FF:det_ff0|*}] -to [get_clocks {CLOCK_50}]
set_false_path -from [get_registers {TPM_TOP:tpm|TPM_IO:io|SPI_SLAVE:spi_serialzier|DET_FF:det_ff0|*}] -to [get_clocks {PLL0|pll_100_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]
set_false_path -from [get_registers {TPM_TOP:tpm|TPM_IO:io|SPI_SLAVE:spi_serialzier|DET_FF:det_ff1|*}] -to [get_clocks {CLOCK_50}]
set_false_path -from [get_registers {TPM_TOP:tpm|TPM_IO:io|SPI_SLAVE:spi_serialzier|DET_FF:det_ff1|*}] -to [get_clocks {PLL0|pll_100_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]

# Break paths for TX_counter which is clocked by SPI_CLOCK and synced to CLOCK_50
set_false_path -from [get_registers {TPM_TOP:tpm|TPM_IO:io|SPI_SLAVE:spi_serialzier|TX_counter*}] -to [get_clocks {CLOCK_50}]
set_false_path -from [get_registers {TPM_TOP:tpm|TPM_IO:io|SPI_SLAVE:spi_serialzier|sync*TX_counter*}] -to [get_clocks {PLL0|pll_100_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]



#**************************************************************
# Set Multicycle Path
#**************************************************************



#**************************************************************
# Set Maximum Delay
#**************************************************************



#**************************************************************
# Set Minimum Delay
#**************************************************************



#**************************************************************
# Set Input Transition
#**************************************************************

