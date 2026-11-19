# Bounded Platform Designer generation only. No fit or programming.
# qsys-script --quartus-project=hps_lcd_subsys.qpf --script=generate_hps_lcd.tcl
package require -exact qsys 26.1
create_system hps_lcd_subsys
set_project_property DEVICE_FAMILY "Agilex 5"
set_project_property DEVICE A5ED013BB32AE4SCS
add_instance agilex_hps intel_agilex_5_soc 14.0.0

# Nine dedicated HPS IOs. Positions come from the DE25 RevD vendor48-entry list.
# No copying of the vendor's Ethernet/USB/SD/I2C/DDR/fan integration.
set lcd_io {}
for {set i 0} {$i < 48} {incr i} { lappend lcd_io NONE }
foreach {index function} {
    27 HCLK:HPS_OSC_CLK
    34 GPIO1:IO10
    35 GPIO1:IO11
    38 UART1:TX
    39 UART1:RX
    42 GPIO1:IO18
    43 SPIM0:SS0_N
    44 SPIM0:CLK
    45 SPIM0:MOSI
} { set lcd_io [lreplace $lcd_io $index $index $function] }
set_instance_parameter_value agilex_hps HPS_IO_Enable $lcd_io
foreach {name value} {
    H2F_Width 0
    LWH2F_Width 32
    f2s_data_width 0
    f2sdram_data_width 0
    EMIF_AXI_Enable false
    ATB_Enable false
    MPU_Events_Enable false
    F2H_IRQ_Enable false
    Rst_hps_warm_en false
    Rst_h2f_cold_en true
    Rst_watchdog_en false
    UART1_PinMuxing IO
    UART1_Mode No_flow_control
    SPIM0_PinMuxing IO
    SPIM0_Mode Single_slave_selects
    eosc1_clk_mhz 25.0

    MPLL_Clock_Source 0
    MPLL_Override true
    MPLL_VCO_Override_mhz 3200.0
    MPLL_C0_Override_mhz 800.0
    MPLL_C1_Override_mhz 800.0
    MPLL_C2_Override_mhz 533.33
    MPLL_C3_Override_mhz 400.0
    PPLL_Clock_Source 0
    PPLL_Override true
    PPLL_VCO_Override_mhz 3000.0
    PPLL_C0_Override_mhz 600.0
    PPLL_C1_Override_mhz 600.0
    PPLL_C2_Override_mhz 24.0
    PPLL_C3_Override_mhz 500.0
    MPU_clk_override true
    MPU_clk_src_override 2
    MPU_clk_freq_override_mhz 533.33
    MPU_core01_src_override 1
    MPU_core01_freq_override_mhz 800.0
    MPU_core23_src_override 0
    MPU_core2_freq_override_mhz 800.0
    MPU_core3_freq_override_mhz 800.0
    NOC_clk_src_select 3
    NOC_clk_free_l4_div 4
    NOC_clk_periph_l4_div 2
    NOC_clk_slow_l4_div 4
    NOC_clk_phy_div 4
    NOC_clk_cs_div 1
    NOC_clk_cs_debug_div 4
    NOC_clk_cs_trace_div 4
    Pwr_boot_core_sel 0
    Pwr_cpu_app_select 0
} { set_instance_parameter_value agilex_hps $name $value }

add_instance fabric_clock clock_source
set_instance_parameter_value fabric_clock clockFrequency 50000000
add_interface fabric_clock clock sink
set_interface_property fabric_clock EXPORT_OF fabric_clock.clk_in
add_interface fabric_reset reset sink
set_interface_property fabric_reset EXPORT_OF fabric_clock.clk_in_reset
add_instance display_regs altera_avalon_mm_bridge
set_instance_parameter_value display_regs DATA_WIDTH 32
set_instance_parameter_value display_regs ADDRESS_WIDTH 8
set_instance_parameter_value display_regs USE_AUTO_ADDRESS_WIDTH 0
add_connection fabric_clock.clk agilex_hps.lwhps2fpga_axi_clock
add_connection fabric_clock.clk display_regs.clk
add_connection agilex_hps.h2f_reset agilex_hps.lwhps2fpga_axi_reset
add_connection fabric_clock.clk_reset display_regs.reset
add_connection agilex_hps.lwhps2fpga display_regs.s0
set_connection_parameter_value agilex_hps.lwhps2fpga/display_regs.s0 baseAddress 0x0000
add_interface display avalon master
set_interface_property display EXPORT_OF display_regs.m0
add_interface hps_io conduit end
set_interface_property hps_io EXPORT_OF agilex_hps.hps_io
# Capture actual derived values; do not assume the firmware library's recipe.
set report [open hps_lcd_derived.txt w]
foreach p [get_instance_parameters agilex_hps] {
    if {[regexp {^(HPS_|REG_|OPT_|MPFE_|MPLL_|PPLL_|MPU_|NOC_|JAVA_|device_|EMIF_|H2F_Width|LWH2F_Width|f2s.*data_width)} $p]} {
        puts $report "$p = [get_instance_parameter_value agilex_hps $p]"
    }
}
puts $report "INTERFACES = [get_instance_interfaces agilex_hps]"
close $report
save_system hps_lcd_subsys.qsys
