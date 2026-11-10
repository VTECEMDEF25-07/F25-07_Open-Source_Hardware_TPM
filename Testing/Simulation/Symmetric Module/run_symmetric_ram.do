# Source files compile separately in Verilog-2001 compatibility mode.
if {[batch_mode]} {onerror {quit -force -code 1}} else {onerror {abort}}
onbreak {resume}
set runner_root [file dirname [file normalize [status file]]]
set project_root [file normalize [file join $runner_root .. .. ..]]
if {[info exists env(TPM_PROJECT_ROOT)]} {set project_root $env(TPM_PROJECT_ROOT)}
set run_base [file join $project_root build symmetric-module ram]
if {[info exists env(TPM_TEST_RUN_ROOT)]} {set run_base [file join $env(TPM_TEST_RUN_ROOT) ram]}
set run_root [file join $run_base "run_[clock clicks]_[pid]"]
file mkdir $run_root
cd $run_root
vlib work_ram
set sym_root [file join $project_root {Source Code} {Symmetric Module}]
foreach name {AES/aes_sbox.v AES/aes_inv_sbox.v AES/aes_key_mem.v AES/aes_encipher_block.v AES/aes_decipher_block.v AES/aes_core.v AES/aes.v Controllers/cfb_block.v Controllers/primitive_controller.v Controllers/session_parameter_controller.v Controllers/kdfa_control.v symmetric_top.v} {
    vlog -vlog01compat -work work_ram [file join $sym_root $name]
}
vlog -sv -work work_ram [file join $runner_root symmetric_test_ram.sv] [file join $runner_root tb_symmetric_ram.sv]
vsim -voptargs=+acc -onfinish stop -lib work_ram tb_symmetric_ram -gMAX_SYM_DATA_BYTES=$env(TPM_RAM_CAPACITY) -gRAM_ADDR_WIDTH=$env(TPM_RAM_ADDR_WIDTH) "+VECTORS=$env(TPM_RAM_VECTORS)"
run -all
if {[examine -radix unsigned sim:/tb_symmetric_ram/successfully_completed] != 1} {error {RAM suite did not complete successfully}}
if {[batch_mode]} {quit -force -code 0}
