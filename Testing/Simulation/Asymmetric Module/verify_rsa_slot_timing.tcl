# Quartus Pro 26.1. Run against a routed rsa_slot_synthesis project.
package require ::quartus::project
package require ::quartus::sta
if {[llength $argv] != 1} {error "Expected the enabled subsystem build directory"}
cd [lindex $argv 0]
project_open consumer
create_timing_netlist
read_sdc
update_timing_netlist
set clocks [get_clocks core_clock]
if {[get_collection_size $clocks] != 1} {error "Missing consumer clock"}
foreach_in_collection clk $clocks {
    if {abs([get_clock_info -period $clk] - 20.0) > 0.001} {error "Expected 50 MHz"}
}
set corners [get_available_operating_conditions]
if {[llength $corners] != 4} {error "Expected all four Agilex 5 timing models"}
set dir rsa_timing_reports
file mkdir $dir
set f [open [file join $dir corners.tsv] w]
puts $f "corner\tcheck\tworst_slack_ns"
set failures 0
foreach corner $corners {
    set_operating_conditions $corner
    update_timing_netlist
    foreach check {setup hold recovery removal} {
        set paths [get_timing_paths -$check -npaths 1]
        if {[get_collection_size $paths] == 0} {
            if {$check in {setup hold}} {error "Empty $check check at $corner"}
            puts $f "$corner\t$check\tno paths"
        } else {
            foreach_in_collection path $paths {
                set slack [get_path_info -slack $path]
                puts $f "$corner\t$check\t$slack"
                if {$slack < 0} {incr failures}
            }
            report_timing -$check -npaths 5 -detail full_path -file [file join $dir ${corner}_${check}.rpt]
        }
    }
    set pulse [get_min_pulse_width -nworst 1]
    if {![llength $pulse]} {error "Empty pulse-width check at $corner"}
    set slack [lindex [lindex $pulse 0] 0]
    puts $f "$corner\tpulse_width\t$slack"
    if {$slack < 0} {incr failures}
}
close $f
report_ucp -file [file join $dir unconstrained.rpt]
project_close
if {$failures} {error "$failures failing corner checks, see $dir"}
puts "RSA_SUBSYSTEM_TIMING_PASS corners=4 clock_mhz=50"
