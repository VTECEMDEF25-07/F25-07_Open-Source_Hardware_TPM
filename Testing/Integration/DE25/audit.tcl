package require ::quartus::project
package require ::quartus::sta
project_open benchmark
create_timing_netlist
read_sdc
update_timing_netlist
file mkdir timing_audit
report_clocks -file timing_audit/clocks.rpt
set failures 0
set corners [get_available_operating_conditions]
if {[llength $corners] == 0} {error "No operating corners"}
foreach corner $corners {
    set_operating_conditions $corner
    update_timing_netlist
    puts "CORNER $corner"
    foreach check {setup hold recovery removal} {
        set paths [get_timing_paths -$check -npaths 1]
        if {[get_collection_size $paths] == 0} {error "Empty $check timing collection"}
        foreach_in_collection path $paths {
            set slack [get_path_info -slack $path]
            puts "$check slack $slack"
            if {$slack < 0} {incr failures}
        }
        report_timing -$check -npaths 3 -detail full_path -file "timing_audit/${corner}_${check}.rpt"
    }
    report_min_pulse_width -nworst 5 -file "timing_audit/${corner}_pulse_width.rpt"
    set pulses [get_min_pulse_width -nworst 1]
    if {[llength $pulses] == 0} {error "No pulse-width timing paths"}
    set pulse [lindex [lindex $pulses 0] 0]
    puts "pulse width slack $pulse"
    if {$pulse < 0} {incr failures}
}
report_ucp -file timing_audit/unconstrained.rpt
report_metastability -file timing_audit/metastability.rpt
set handle [open timing_audit/unconstrained.rpt r]
set text [read $handle];close $handle
set rows 0
foreach line [split $text "\n"] {
    if {[regexp {^;\s*([^;]+);\s*([0-9]+)\s*;\s*([0-9]+)\s*;} $line -> property setup hold]} {
        incr rows
        if {$setup != 0 || $hold != 0} {error "Unconstrained: [string trim $property] $setup/$hold"}
    }
}
if {$rows != 6} {error "Unrecognized unconstrained-path summary"}
delete_timing_netlist
project_close
if {$failures} {error "RSA timing audit failed: $failures negative margins"}
puts "PASS RSA TIMING AUDIT"
