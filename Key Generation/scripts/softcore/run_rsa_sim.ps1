param([Parameter(Mandatory=$true)][string]$Toolchain,[string]$QuestaBin='C:/intelFPGA_lite/24.1std/questa_fse/win64',[string]$Python='C:/Python314/python.exe')
$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path "$PSScriptRoot/../..").Path
$taskBuild=Join-Path $taskRoot 'build/softcore'
& $Python "$PSScriptRoot/build_rsa.py" --toolchain $Toolchain --output $taskBuild
if($LASTEXITCODE -ne 0 -or !(Test-Path "$taskBuild/rsa_control.hex")){throw 'RSA firmware build failed'}
Push-Location $taskBuild
try {
    if(!(Test-Path work)){& "$QuestaBin/vlib.exe" work; if($LASTEXITCODE -ne 0){throw 'vlib failed'}}
    & "$QuestaBin/vlog.exe" -vlog01compat "$taskRoot/IP/third_party/picorv32/picorv32.v" "$taskRoot/rtl/rsa_softcore/keygen_softcore_control.v" "$taskRoot/rtl/rsa_softcore/keygen_rsa_softcore.v"
    if($LASTEXITCODE -ne 0){throw 'Verilog compile failed'}
    & "$QuestaBin/vlog.exe" -sv "$taskRoot/testbench/softcore/tb_rsa_firmware.sv"
    if($LASTEXITCODE -ne 0){throw 'Testbench compile failed'}
    $taskOutput=& "$QuestaBin/vsim.exe" -c -voptargs=+acc work.tb_rsa_firmware -do 'onerror {quit -code 1}; onbreak {quit -code 1}; run -all; quit -code 0' 2>&1
    $taskResult=$LASTEXITCODE;$taskOutput | Tee-Object -FilePath rsa_firmware_simulation.log
    if($taskResult -ne 0 -or !($taskOutput -match 'PASS RSA firmware control:')){throw 'RSA firmware simulation failed or missing PASS marker'}
} finally {Pop-Location}
