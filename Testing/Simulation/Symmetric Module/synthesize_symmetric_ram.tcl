# Standalone analysis/synthesis only; no pinout, fitter, timing or bitstream claim.
# Usage: quartus_sh -t synthesize_symmetric_ram.tcl <scratch-directory> ?capacity? ?address-width?
load_package flow
if {$argc < 1 || $argc > 3} {error {Expected scratch-directory, optional capacity and address width}}
set source_root [file normalize [file join [file dirname [info script]] .. .. .. {Source Code} {Symmetric Module}]]
set output_root [file normalize [lindex $argv 0]]
set capacity 1024
set address_width 12
if {$argc >= 2} {set capacity [lindex $argv 1]}
if {$argc >= 3} {set address_width [lindex $argv 2]}
if {![string is integer -strict $capacity] || $capacity < 1 || $capacity > 65535 ||
    ![string is integer -strict $address_width] || $address_width < 1 || $address_width > 32} {
    error {Invalid capacity or address width}
}
file mkdir $output_root
cd $output_root
project_new symmetric_ram -overwrite
set_global_assignment -name FAMILY {Cyclone V}
set_global_assignment -name DEVICE 5CSEMA5F31C6
set_global_assignment -name TOP_LEVEL_ENTITY symmetric_ram_top
set_global_assignment -name VERILOG_INPUT_VERSION VERILOG_2001
set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files
set_global_assignment -name NUM_PARALLEL_PROCESSORS 2
set_parameter -name MAX_SYM_DATA_BYTES $capacity
set_parameter -name RAM_ADDR_WIDTH $address_width
# Apply virtual pins only to actual top ports, never to internal nets.
foreach port {clock_i reset_n_i start_i decrypt_i busy_o done_o error_o ram_req_valid_o ram_req_ready_i ram_req_write_o ram_rsp_valid_i ram_rsp_ready_o ram_rsp_error_i {key_i[*]} {iv_i[*]} {input_base_i[*]} {output_base_i[*]} {data_length_i[*]} {tpm_rc_o[*]} {final_iv_o[*]} {completed_length_o[*]} {ram_req_addr_o[*]} {ram_req_data_o[*]} {ram_rsp_data_i[*]}} {
    set_instance_assignment -name VIRTUAL_PIN ON -to $port
}
foreach name {aes_sbox.v aes_inv_sbox.v aes_key_mem.v aes_encipher_block.v aes_decipher_block.v aes_core.v aes.v cfb_block.v encrypt_decrypt2_ram_controller.v symmetric_ram_top.v} {
    set_global_assignment -name VERILOG_FILE [file join $source_root $name]
}
execute_module -tool map
project_close
