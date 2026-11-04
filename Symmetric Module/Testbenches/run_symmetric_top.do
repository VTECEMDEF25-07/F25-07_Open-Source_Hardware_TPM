# Practice integration uses fake HMAC and real AES. It does not validate HMAC.
# GUI: keep waveforms open. Batch: report failures through the process exit code.
if {[batch_mode]} {onerror {quit -force -code 1}} else {onerror {abort}}
onbreak {resume}
set project_root {C:/MDE/F25-07_Open-Source_Hardware_TPM}
if {[info exists env(TPM_PROJECT_ROOT)]} {set project_root $env(TPM_PROJECT_ROOT)}
set sym_root [file join $project_root {Symmetric Module}]
set run_base {C:/MDE/review_work/symmetric_integration_20261012}
if {[info exists env(TPM_TEST_RUN_ROOT)]} {set run_base [file join $env(TPM_TEST_RUN_ROOT) symmetric_top]}
set run_root [file join $run_base "run_[clock clicks]_[pid]"]
file mkdir $run_root
cd $run_root
transcript file [file join $run_root transcript.log]
vlib work_symmetric
foreach name {aes_sbox.v aes_inv_sbox.v aes_key_mem.v aes_encipher_block.v aes_decipher_block.v aes_core.v aes.v kdfa_control.v hmac_sha256_placeholder.v cfb_block.v session_parameter_controller.v encrypt_decrypt2_controller.v symmetric_top.v symmetric_demo_top.v} {
    vlog -work work_symmetric [file join $sym_root $name]
}
vlog -sv -work work_symmetric [file join $sym_root Testbenches tb_symmetric_top.sv]
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
