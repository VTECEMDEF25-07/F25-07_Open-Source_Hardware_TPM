# Practice tests use a fake HMAC, so passing does not validate cryptography.
# Run from any directory; every run gets a fresh library and transcript.
# In the GUI, leave the simulation and waveforms open after the tests finish.
if {[batch_mode]} {onerror {quit -force -code 1}} else {onerror {abort}}
onbreak {resume}
set project_root {C:/MDE/F25-07_Open-Source_Hardware_TPM}
if {[info exists env(TPM_PROJECT_ROOT)]} {set project_root $env(TPM_PROJECT_ROOT)}
set sym_root [file join $project_root {Symmetric Module}]
set bench_root [file join $sym_root Testbenches]
set run_base {C:/MDE/review_work/kdfa_practice_20261001}
if {[info exists env(TPM_TEST_RUN_ROOT)]} {set run_base [file join $env(TPM_TEST_RUN_ROOT) kdfa_practice]}
set run_root [file join $run_base "run_[clock clicks]_[pid]"]
file mkdir $run_root
cd $run_root
transcript file [file join $run_root transcript.log]
vlib work_practice
vlog -work work_practice [file join $sym_root kdfa_control.v] [file join $sym_root hmac_sha256_placeholder.v]
vlog -sv -work work_practice [file join $bench_root tb_kdfa_control.sv]
vsim -voptargs=+acc -onfinish stop -wlf [file join $run_root vsim.wlf] -lib work_practice tb_kdfa_control
# Preserve handshakes, message counters, and digests in this run's vsim.wlf.
log -r sim:/tb_kdfa_control/*

# Each group follows one part of the journey through the two modules.
if {![batch_mode]} {view wave}
add wave -group {Test and clock} -radix unsigned sim:/tb_kdfa_control/test_case
add wave -group {Test and clock} sim:/tb_kdfa_control/clk_i sim:/tb_kdfa_control/reset_n_i
add wave -group {Caller to KDFa} sim:/tb_kdfa_control/req_valid_i sim:/tb_kdfa_control/req_ready_o
add wave -group {Caller to KDFa} sim:/tb_kdfa_control/rsp_valid_o sim:/tb_kdfa_control/rsp_ready_i sim:/tb_kdfa_control/error_o
add wave -group {Caller inputs} -radix hexadecimal sim:/tb_kdfa_control/session_value_i sim:/tb_kdfa_control/label_i sim:/tb_kdfa_control/context_u_i sim:/tb_kdfa_control/context_v_i
add wave -group {KDFa to HMAC request} sim:/tb_kdfa_control/hmac_req_valid_o sim:/tb_kdfa_control/hmac_req_ready_i
add wave -group {KDFa to HMAC request} -radix unsigned sim:/tb_kdfa_control/message_counter
add wave -group {KDFa to HMAC request} -radix hexadecimal sim:/tb_kdfa_control/hmac_key_o sim:/tb_kdfa_control/hmac_message_o
add wave -group {HMAC to KDFa result} sim:/tb_kdfa_control/hmac_rsp_valid_i sim:/tb_kdfa_control/hmac_rsp_ready_o sim:/tb_kdfa_control/hmac_error_i
add wave -group {HMAC to KDFa result} -radix hexadecimal sim:/tb_kdfa_control/hmac_digest_i
add wave -group {Final key and IV} -radix hexadecimal sim:/tb_kdfa_control/aes_key_o sim:/tb_kdfa_control/aes_iv_o
add wave -group {KDFa state} -radix unsigned sim:/tb_kdfa_control/dut/state_r
add wave -group {Test controls} sim:/tb_kdfa_control/accept_hmac sim:/tb_kdfa_control/inject_second_error
if {![batch_mode]} {
    configure wave -namecolwidth 230 -valuecolwidth 260 -timelineunits ns
}

run -all
if {[examine -radix unsigned sim:/tb_kdfa_control/successfully_completed] != 1} {
    error {Practice test ended without successful completion}
}
set count [examine -radix unsigned sim:/tb_kdfa_control/case_count]
if {$count != 6} {error "Expected 6 practice cases, got $count"}
puts "KDFA_PRACTICE_SUITE_PASS ($count cases)"
puts "Waveform recording: [file join $run_root vsim.wlf]"
puts {KDFa states: 0=IDLE, 1=SEND, 2=WAIT_DIGEST, 3=DONE. Fake HMAC holds its result while rsp_valid_o=1.}
if {[batch_mode]} {
    quit -force -code 0
} else {
    # Start with only the first successful transaction visible; Zoom Full shows all 6.
    wave zoom range 0ns 200ns
    puts {The Wave window is showing case 1. Use Zoom Full to inspect the other cases.}
}
