# Run from any directory with Questa: do {<repo>/Testing/Simulation/Execution Engine/run_tpm2_hash_command.do}
onerror {quit -force -code 1}
onbreak {resume}
set bench_dir [file dirname [file normalize [status file]]]
set repo [file normalize [file join $bench_dir .. .. ..]]
set io_dir [file join $repo {Source Code} {IO Interface}]
set board_dir [file join $repo Project DE1]
set qsf_file [open [file join $board_dir de1_soc_top.qsf] r]
set qsf [read $qsf_file]
close $qsf_file
set rtl {}
foreach {match path} [regexp -all -inline -- {-name VERILOG_FILE "([^"]+)"} $qsf] {
    lappend rtl [file normalize [file join $board_dir $path]]
}
set build_dir [file join [file normalize $::env(TEMP)] "tpm_hash_[pid]_[clock clicks]"]
file mkdir $build_dir
cd $build_dir
vlib work
vlog -vlog01compat "+incdir+$io_dir" {*}$rtl
set sym_dir [file join $repo {Source Code} {Symmetric Module}]
set sym_bench [file join $repo Testing Simulation {Symmetric Module}]
vlog -vlog01compat {*}[glob -directory [file join $sym_dir AES] *.v] {*}[glob -directory [file join $sym_dir Controllers] *.v] [file join $sym_dir symmetric_top.v]
vlog -sv [file join $sym_bench symmetric_test_ram.sv] [file join $bench_dir tb_keygen_encryptdecrypt2.sv] [file join $bench_dir tb_tpm2_hash_command.sv] [file join $bench_dir tb_tpm2_hash_spi.sv]
foreach top {tb_tpm2_hash_command tb_tpm2_hash_spi tb_keygen_encryptdecrypt2} {
    vsim -voptargs=+acc -onfinish stop work.$top
    run -all
    if {[examine -radix unsigned sim:/$top/passed] != 1} {
        error "$top did not pass"
    }
    quit -sim
}
vsim -voptargs=+acc -gENABLE_AES_TEST=1 -onfinish stop work.tb_tpm2_hash_spi
run -all
if {[examine -radix unsigned sim:/tb_tpm2_hash_spi/passed] != 1} {
    error "SPI EncryptDecrypt2 did not pass"
}
# Preserve the original host-command behavior as well as the new paths.
# The inherited bench uses $error/$stop, so check its counter and final
# entry explicitly instead of treating simulator exit zero as success.
quit -sim
vlog -sv [file join $repo Testing Simulation {IO Interface} tb_test.v]
vsim -L altera_mf_ver -L lpm_ver -voptargs=+acc -onfinish stop work.tb_test
run 2 ms
if {[examine -radix unsigned sim:/tb_test/errors] != 0 ||
    [examine -radix unsigned sim:/tb_test/genEntry] != 240} {
    error "Original SPI command regression failed or did not finish"
}
echo "TPM_LEGACY_SPI_PASS"
quit -force -code 0
