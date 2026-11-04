# Run from repo root: quartus_sta -t Boards/verify_spi_timing.tcl DE1|DE25
# Checks every available timing corner and the three SPI synchronizer chains.
package require ::quartus::project
package require ::quartus::sta
set board [lindex $argv 0]
if {$board ni {DE1 DE25}} {error "Expected DE1 or DE25"}
cd [file join [file dirname [info script]] $board]
project_open [string tolower $board]_soc_top
create_timing_netlist
read_sdc
update_timing_netlist
set failures 0
set report_dir spi_timing_reports
file mkdir $report_dir
report_clocks -file "$report_dir/clocks.rpt"
if {$board eq "DE25"} {
    report_exceptions -ignored -file "$report_dir/ignored.rpt"
} else {
    # Lite 24.1 reports all exceptions; Pro's -ignored option is unavailable.
    report_exceptions -file "$report_dir/exceptions.rpt"
}
if {[llength [info commands report_asynch_cdc]]} {
    report_asynch_cdc -detail full -nentries 100 -file "$report_dir/cdc.rpt"
} else {
    puts "INFO: Structural CDC report unavailable in this edition; interstage timing and metastability reports remain required."
}
set corners [get_available_operating_conditions]
if {[llength $corners] == 0} {error "No operating corners available"}
foreach corner $corners {
    set_operating_conditions $corner
    update_timing_netlist
    puts "CORNER $corner"
    report_min_pulse_width -nworst 5 -file "$report_dir/${corner}_pulse_width.rpt"
    set pulses [get_min_pulse_width -nworst 1]
    if {[llength $pulses] == 0} {error "No pulse-width timing paths"}
    set pulse_slack [lindex [lindex $pulses 0] 0]
    puts "pulse width slack $pulse_slack"
    if {$pulse_slack < 0} {incr failures}
    foreach check {setup hold recovery removal} {
        set paths [get_timing_paths -$check -npaths 1]
        foreach_in_collection path $paths {
            set slack [get_path_info -slack $path]
            puts "$check slack $slack"
            if {$slack < 0} {incr failures}
        }
        report_timing -$check -npaths 5 -detail full_path -file "$report_dir/${corner}_${check}.rpt"
    }
    foreach signal {spi_clock spi_mosi chip_select} {
        set prefix {tpm|io|spi_serializer|}
        set first [get_registers "${prefix}${signal}_meta_reg"]
        set second [get_registers "${prefix}${signal}_sync_reg"]
        if {[get_collection_size $first] != 1 || [get_collection_size $second] != 1} {
            error "Missing SPI synchronizer chain: $signal"
        }
        set paths [get_timing_paths -setup -from $first -to $second -npaths 1]
        if {[get_collection_size $paths] != 1} {error "Untimed synchronizer interstage: $signal"}
        foreach_in_collection path $paths {
            set slack [get_path_info -slack $path]
            puts "$signal interstage setup slack $slack"
            if {$slack < 0} {incr failures}
        }
    }
}
if {[get_collection_size [get_registers -nowarn {*det_ff* *TX_temp*}]] != 0} {
    error "Legacy logic-clocked SPI serializer remains in the netlist"
}
report_metastability -file "$report_dir/metastability.rpt"
report_ucp -file "$report_dir/unconstrained.rpt"
delete_timing_netlist
project_close
if {$failures} {error "SPI timing audit failed: $failures negative margins"}
puts "PASS SPI TIMING AUDIT"
