# ===========================================================================
# DE25_entropy_test_pins.tcl
#
# Pin assignments for entropy_test_top on the Terasic DE25-Standard
# (Agilex 5 A5ED013BB32A). Pin numbers are from the DE25-Standard user
# manual (tables 3-9, 3-12, 3-13, 3-16).
#
# Use it either way
#   - Quartus Tools  Tcl Scripts..., select this file, Run.
#   - Or paste the set_location_assignment  set_instance_assignment lines
#     into your project's .qsf file.
#
# IO standard names if Quartus rejects one, open Terasic's DE25-Standard
# Golden Top (System CD) .qsf, find the same pin, and copy its exact
# IO_STANDARD string.
#
# Written by Jungyeon Won with the help of generative AI
# ===========================================================================
 
# 50 MHz clock (CLOCK_50)
set_location_assignment PIN_D8    -to clk
set_instance_assignment -name IO_STANDARD 3.3-V LVCMOS -to clk
 
# Reset = KEY[0], low when pressed
set_location_assignment PIN_BW59  -to rst_n
set_instance_assignment -name IO_STANDARD 1.2 V -to rst_n
 
# UART on the 3.3 V DE-GPIO header (USB-UART adapter, 3.3 V logic)
#   GPIO[0] - adapter TX      GPIO[1] - adapter RX      + connect GND
set_location_assignment PIN_BK31  -to uart_rx
set_instance_assignment -name IO_STANDARD 3.3-V LVCMOS -to uart_rx
set_location_assignment PIN_BE43  -to uart_tx
set_instance_assignment -name IO_STANDARD 3.3-V LVCMOS -to uart_tx
 
# Busy LED = LEDR[0], lights when driven low
set_location_assignment PIN_CC71  -to led_busy_n
set_instance_assignment -name IO_STANDARD 1.2 V -to led_busy_n
 
# Write the assignments into the .qsf when run from Tools  Tcl Scripts.
catch { export_assignments }