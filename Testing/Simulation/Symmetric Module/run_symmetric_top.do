# Practice integration uses fake HMAC and real AES. It does not validate HMAC.
# GUI: keep waveforms open. Batch: report failures through the process exit code.
if {[batch_mode]} {onerror {quit -force -code 1}} else {onerror {abort}}
onbreak {resume}
set runner_root [file dirname [file normalize [status file]]]
set project_root [file normalize [file join $runner_root .. .. ..]]
if {[info exists env(TPM_PROJECT_ROOT)]} {set project_root $env(TPM_PROJECT_ROOT)}
set sym_root [file join $project_root {Source Code} {Symmetric Module}]
set bench_root [file join $project_root Testing Simulation {Symmetric Module}]
set run_base [file join $project_root build symmetric-module symmetric_top]
if {[info exists env(TPM_TEST_RUN_ROOT)]} {set run_base [file join $env(TPM_TEST_RUN_ROOT) symmetric_top]}
set run_root [file join $run_base "run_[clock clicks]_[pid]"]
file mkdir $run_root
cd $run_root
transcript file [file join $run_root transcript.log]
vlib work_symmetric
foreach name {aes_sbox.v aes_inv_sbox.v aes_key_mem.v aes_encipher_block.v aes_decipher_block.v aes_core.v aes.v kdfa_control.v cfb_block.v session_parameter_controller.v encrypt_decrypt2_controller.v symmetric_top.v} {
    vlog -vlog01compat -work work_symmetric [file join $sym_root $name]
}
vlog -vlog01compat -work work_symmetric [file join $project_root Project DE1 {Symmetric Demo} symmetric_demo_top.v]
vlog -sv -work work_symmetric [file join $bench_root hmac_stream_test_service.sv] [file join $bench_root tb_symmetric_top.sv]
vsim -voptargs=+acc -onfinish stop -wlf [file join $run_root vsim.wlf] -lib work_symmetric tb_symmetric_top
log -r sim:/tb_symmetric_top/*

# Hierarchy reflects the split controllers and shared CFB worker.
if {![batch_mode]} {
 view wave
 add wave -r sim:/tb_symmetric_top/dut/*
}

run -all
if {[examine -radix unsigned sim:/tb_symmetric_top/successfully_completed] != 1} {
    error {Symmetric-top test ended without successful completion}
}
set count [examine -radix unsigned sim:/tb_symmetric_top/case_count]
if {$count != 14} {error "Expected 14 symmetric-top cases, got $count"}
puts "SYMMETRIC_TOP_SUITE_PASS ($count cases)"
puts "Waveform recording: [file join $run_root vsim.wlf]"
puts {SESSION_CONTROLLER derives material; CFB_BLOCK executes AES. XOR bypasses CFB_BLOCK.}
if {[batch_mode]} {
    quit -force -code 0
} else {
    wave zoom range 0ns 1400ns
    puts {The Wave window starts with session encryption. Use Zoom Full for all fourteen cases.}
}
