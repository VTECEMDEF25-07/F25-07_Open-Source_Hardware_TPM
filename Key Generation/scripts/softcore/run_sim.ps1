param([ValidateSet("Generic","Altera")][string]$Backend="Generic",[string]$QuestaBin = 'C:/intelFPGA_lite/24.1std/questa_fse/win64', [string]$Python = 'C:/Python314/python.exe')
$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path "$PSScriptRoot/../..").Path
$taskBuild=Join-Path $taskRoot 'build/softcore'
New-Item -ItemType Directory -Force $taskBuild | Out-Null
& $Python "$PSScriptRoot/build_boot.py" --output $taskBuild
if($LASTEXITCODE -ne 0 -or !(Test-Path "$taskBuild/softcore_boot.hex")){throw 'Firmware build failed'}
Push-Location $taskBuild
try {
    & "$QuestaBin/vlib.exe" work
    if($LASTEXITCODE -ne 0){throw 'vlib failed'}
    $taskDefines=@()
    $taskLibraries=@()
    if($Backend -eq 'Altera') {
        $taskDefines=@('+define+KEYGEN_ALTERA');$taskLibraries=@('-L','vendor')
        if(!(Test-Path vendor)){& "$QuestaBin/vlib.exe" vendor}
        & "$QuestaBin/vlog.exe" -work vendor 'C:/intelFPGA_lite/24.1std/quartus/eda/sim_lib/altera_mf.v'
        if($LASTEXITCODE -ne 0){throw 'Actual Altera simulation model compile failed'}
    }
    & "$QuestaBin/vlog.exe" -vlog01compat @taskDefines "$taskRoot/IP/keygen_ram32_generic.v" "$taskRoot/IP/keygen_ram32_altera.v" "$taskRoot/IP/keygen_ram32.v"
    if($LASTEXITCODE -ne 0){throw 'RAM wrapper compile failed'}
    & "$QuestaBin/vlog.exe" -vlog01compat @taskDefines "$taskRoot/IP/third_party/picorv32/picorv32.v" "$taskRoot/rtl/rsa_softcore/keygen_softcore_control.v"
    if($LASTEXITCODE -ne 0){throw 'Verilog source compile failed'}
    & "$QuestaBin/vlog.exe" -sv @taskDefines "$taskRoot/testbench/softcore/tb_softcore_boot.sv"
    if($LASTEXITCODE -ne 0){throw 'Testbench compile failed'}
    $taskOutput=& "$QuestaBin/vsim.exe" -c -voptargs=+acc @taskLibraries work.tb_softcore_boot -do 'onerror {quit -code 1}; onbreak {quit -code 1}; run -all; quit -code 0' 2>&1
    $taskResult=$LASTEXITCODE
    $taskOutput | Tee-Object -FilePath simulation.log
    if($taskResult -ne 0 -or !($taskOutput -match 'PASS softcore:')){throw 'Simulation failed or missing PASS marker'}
} finally {Pop-Location}
