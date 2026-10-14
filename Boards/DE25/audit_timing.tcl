# quartus_sta -t audit_timing.tcl <build-directory> <fresh-report-directory> ?corrected-sdc?
# Collect evidence without changing the build snapshot or granting acceptance.
# The optional SDC is copied into the report directory; the original stays intact.
load_package sta
if {[llength $argv] < 2 || [llength $argv] > 3} {
    error "Expected build and report directories, with an optional corrected SDC"
}
set project_dir [file normalize [lindex $argv 0]]
set report_dir [file normalize [lindex $argv 1]]
set source_sdc [file join $project_dir de25_soc_top.sdc]
if {[llength $argv] == 3} {
    set source_sdc [file normalize [lindex $argv 2]]
}
if {![file isfile $source_sdc]} { error "SDC file does not exist: $source_sdc" }
if {[file exists $report_dir]} { error "Use a fresh report directory" }
file mkdir $report_dir
set audited_sdc [file join $report_dir audited_constraints.sdc]
file copy $source_sdc $audited_sdc
puts "AUDITED_SDC_SOURCE=$source_sdc"
puts "AUDITED_SDC_SNAPSHOT=$audited_sdc"
project_open -preserve_revision_order -revision de25_soc_top [file join $project_dir de25_soc_top]
create_timing_netlist
read_sdc $audited_sdc
update_timing_netlist
report_clocks -file [file join $report_dir clocks.rpt]
foreach kind {setup hold recovery removal} {
    report_timing -$kind -npaths 20 -detail full_path -file [file join $report_dir ${kind}.rpt]
}
report_min_pulse_width -nworst 5 -file [file join $report_dir pulse_width.rpt]
report_ucp -file [file join $report_dir unconstrained.rpt]
report_asynch_cdc -detail full -nentries 100 -file [file join $report_dir cdc.rpt]
report_asynch_cdc -reset_cdc -detail full -nentries 100 -file [file join $report_dir reset_cdc.rpt]
report_exceptions -ignored -file [file join $report_dir ignored.rpt]
# Enumerate every available corner (four for the reviewed DE25 device), using
# the same commands as the successful phase1-jtag-audit-v3 timing review.
set operating_conditions [get_available_operating_conditions]
if {[llength $operating_conditions] == 0} { error "No operating corners available" }
puts "OPERATING_CONDITIONS=$operating_conditions"
foreach op $operating_conditions {
    set_operating_conditions $op
    update_timing_netlist
    report_min_pulse_width -nworst 5 -file [file join $report_dir ${op}_pulse_width.rpt]
    foreach kind {setup hold recovery removal} {
        report_timing -$kind -npaths 5 -detail full_path -file [file join $report_dir ${op}_${kind}.rpt]
    }
}
delete_timing_netlist
project_close
puts "PHASE1_TIMING_REPORTS_COLLECTED; review still required"
