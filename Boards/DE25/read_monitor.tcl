# Read-only Phase 1 identity/cooling capture. Never writes a source register.
load_package insystem_source_probe
load_package jtag
set candidates {}
foreach name [get_hardware_names] {
    if {[string match "DE25-Standard*" $name]} { lappend candidates $name }
}
if {[llength $candidates] != 1} { error "Expected exactly one DE25 cable" }
set hardware [lindex $candidates 0]
set devices [get_device_names -hardware_name $hardware]
if {[llength $devices] != 1} { error "Expected exactly one device on DE25 chain" }
set device [lindex $devices 0]
set matches {}
foreach instance [get_insystem_source_probe_instance_info -hardware_name $hardware -device_name $device] {
    if {[lindex $instance 2] == 96} { lappend matches [lindex $instance 0] }
}
if {[llength $matches] != 1} { error "Expected one 96-bit Phase 1 monitor" }
set index [lindex $matches 0]
start_insystem_source_probe -hardware_name $hardware -device_name $device
for {set sample 0} {$sample < 10} {incr sample} {
    puts "PHASE1_MONITOR=[read_probe_data -instance_index $index -value_in_hex]"
    after 1000
}
end_insystem_source_probe
