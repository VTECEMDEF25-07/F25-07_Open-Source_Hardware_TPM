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
foreach name {aes_sbox.v aes_inv_sbox.v aes_key_mem.v aes_encipher_block.v aes_decipher_block.v aes_core.v aes.v kdfa_control.v hmac_sha256_placeholder.v symmetric_top.v symmetric_demo_top.v} {
    vlog -work work_symmetric [file join $sym_root $name]
}
vlog -sv -work work_symmetric [file join $sym_root Testbenches tb_symmetric_top.sv]
vsim -voptargs=+acc -onfinish stop -wlf [file join $run_root vsim.wlf] -lib work_symmetric tb_symmetric_top
log -r sim:/tb_symmetric_top/*

# Follow the request from the caller, through KDFa/HMAC, and into AES.
if {![batch_mode]} {view wave}
add wave -group {Test and clock} -radix unsigned sim:/tb_symmetric_top/test_case
add wave -group {Test and clock} sim:/tb_symmetric_top/clock_i sim:/tb_symmetric_top/reset_n_i
add wave -group {Caller} sim:/tb_symmetric_top/start_i sim:/tb_symmetric_top/wait_o sim:/tb_symmetric_top/done_o
add wave -group {Caller} sim:/tb_symmetric_top/session_protect_i sim:/tb_symmetric_top/session_decrypt_i sim:/tb_symmetric_top/session_encrypt_i
add wave -group {Caller} -radix hexadecimal sim:/tb_symmetric_top/session_value_i sim:/tb_symmetric_top/nonce_newer_i sim:/tb_symmetric_top/nonce_older_i sim:/tb_symmetric_top/data_in_i
add wave -group {KDFa request} sim:/tb_symmetric_top/dut/kdfa_req_valid_w sim:/tb_symmetric_top/dut/kdfa_req_ready_w
add wave -group {HMAC request} sim:/tb_symmetric_top/dut/hmac_req_valid_w sim:/tb_symmetric_top/dut/hmac_req_ready_w
add wave -group {HMAC request} -radix unsigned sim:/tb_symmetric_top/message_counter
add wave -group {HMAC request} -radix hexadecimal sim:/tb_symmetric_top/dut/hmac_key_w sim:/tb_symmetric_top/dut/hmac_message_w
add wave -group {HMAC result} sim:/tb_symmetric_top/dut/hmac_rsp_valid_w sim:/tb_symmetric_top/dut/hmac_rsp_ready_w sim:/tb_symmetric_top/dut/hmac_error_w
add wave -group {HMAC result} -radix hexadecimal sim:/tb_symmetric_top/dut/hmac_digest_w
add wave -group {Derived key and IV} sim:/tb_symmetric_top/dut/kdfa_rsp_valid_w sim:/tb_symmetric_top/dut/kdfa_rsp_ready_w sim:/tb_symmetric_top/dut/kdfa_error_w
add wave -group {Derived key and IV} -radix hexadecimal sim:/tb_symmetric_top/dut/kdfa_key_w sim:/tb_symmetric_top/dut/kdfa_iv_w
add wave -group {AES} sim:/tb_symmetric_top/dut/aes_init_r sim:/tb_symmetric_top/dut/aes_next_r sim:/tb_symmetric_top/dut/aes_ready_w sim:/tb_symmetric_top/dut/aes_result_valid_w
add wave -group {AES} -radix hexadecimal sim:/tb_symmetric_top/dut/aes_key_r sim:/tb_symmetric_top/dut/aes_feedback_r sim:/tb_symmetric_top/dut/cipher_stream_block_w
add wave -group {Final result} -radix hexadecimal sim:/tb_symmetric_top/tpm_rc_o sim:/tb_symmetric_top/data_out_o sim:/tb_symmetric_top/iv_out_o
add wave -group {Top state} -radix unsigned sim:/tb_symmetric_top/dut/state_r
if {![batch_mode]} {configure wave -namecolwidth 230 -valuecolwidth 260 -timelineunits ns}

run -all
if {[examine -radix unsigned sim:/tb_symmetric_top/successfully_completed] != 1} {
    error {Symmetric-top test ended without successful completion}
}
set count [examine -radix unsigned sim:/tb_symmetric_top/case_count]
if {$count != 10} {error "Expected 10 symmetric-top cases, got $count"}
puts "SYMMETRIC_TOP_SUITE_PASS ($count cases)"
puts "Waveform recording: [file join $run_root vsim.wlf]"
puts {Top state 8 waits for KDFa; state 1 then starts execution using the returned key and IV.}
if {[batch_mode]} {
    quit -force -code 0
} else {
    wave zoom range 0ns 1400ns
    puts {The Wave window starts with session encryption. Use Zoom Full for all ten cases.}
}
