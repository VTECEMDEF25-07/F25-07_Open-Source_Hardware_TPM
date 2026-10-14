# Filename: run_rsa_sim.ps1
# Authors: Project contributors; see Git history.
# Date: 2026-10-13
# General Description: Provides run rsa sim support for the key-generation implementation and verification.
# AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

param([ValidateSet("Generic","Altera")][string]$Backend="Generic",[Parameter(Mandatory=$true)][string]$Toolchain,[string]$QuestaBin='C:/intelFPGA_lite/24.1std/questa_fse/win64',[string]$Python='C:/Python314/python.exe',[switch]$BlockingStatus,[int]$StallCycles=3000,[switch]$Exhaustion)
$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path "$PSScriptRoot/../..").Path
$taskBuild=Join-Path $taskRoot 'build/softcore'
& $Python "$PSScriptRoot/build_rsa.py" --toolchain $Toolchain --output $taskBuild
if($LASTEXITCODE -ne 0 -or !(Test-Path "$taskBuild/rsa_control.hex")){throw 'RSA firmware build failed'}
& $Python "$PSScriptRoot/build_rsa.py" --toolchain $Toolchain --output $taskBuild --memory-selftest
if($LASTEXITCODE -ne 0){throw 'Memory fixture compile failed'}
Push-Location $taskBuild
try {
    if(!(Test-Path work)){& "$QuestaBin/vlib.exe" work; if($LASTEXITCODE -ne 0){throw 'vlib failed'}}
    $taskDefines=@();if($BlockingStatus){$taskDefines+=@('+define+KEYGEN_BLOCKING_STATUS_TEST')}
    $taskLibraries=@()
    if($Backend -eq 'Altera') {
        $taskDefines+=@('+define+KEYGEN_ALTERA');$taskLibraries=@('-L','vendor')
        if(!(Test-Path vendor)){& "$QuestaBin/vlib.exe" vendor}
        & "$QuestaBin/vlog.exe" -work vendor 'C:/intelFPGA_lite/24.1std/quartus/eda/sim_lib/altera_mf.v'
        if($LASTEXITCODE -ne 0){throw 'Actual Altera simulation model compile failed'}
    }
    & "$QuestaBin/vlog.exe" -vlog01compat @taskDefines "$taskRoot/IP/keygen_ram32_generic.v" "$taskRoot/IP/keygen_ram32_altera.v" "$taskRoot/IP/keygen_ram32.v"
    if($LASTEXITCODE -ne 0){throw 'RAM wrapper compile failed'}
    & "$QuestaBin/vlog.exe" -vlog01compat @taskDefines "$taskRoot/IP/third_party/picorv32/picorv32.v" "$taskRoot/rtl/rsa_softcore/keygen_softcore_control.v" "$taskRoot/rtl/rsa_softcore/keygen_rsa_softcore.v"
    if($LASTEXITCODE -ne 0){throw 'Verilog compile failed'}
    & "$QuestaBin/vlog.exe" -sv @taskDefines "$taskRoot/testbench/softcore/tb_rsa_firmware.sv" "$taskRoot/testbench/softcore/tb_softcore_memory.sv"
    if($LASTEXITCODE -ne 0){throw 'Testbench compile failed'}
    $taskRunTag=$Backend;if($BlockingStatus){$taskRunTag+='Blocking'}
    $taskSimulationArgs=@("+STALL_CYCLES=$StallCycles");if($Exhaustion){$taskSimulationArgs+='+EXHAUSTION'}
    $taskTimer=[Diagnostics.Stopwatch]::StartNew()
    $taskOutput=& "$QuestaBin/vsim.exe" -c @taskLibraries work.tb_rsa_firmware @taskSimulationArgs -do 'onerror {quit -code 1}; onbreak {quit -code 1}; run -all; quit -code 0' 2>&1
    $taskResult=$LASTEXITCODE;$taskTimer.Stop();$taskOutput | Tee-Object -FilePath "rsa_firmware_$taskRunTag.log"
    @{Backend=$Backend;BlockingStatus=[bool]$BlockingStatus;StallCycles=$StallCycles;WallSeconds=$taskTimer.Elapsed.TotalSeconds;Passed=($taskResult -eq 0 -and [bool]($taskOutput -match 'PASS RSA firmware control:'))} | ConvertTo-Json | Set-Content "benchmark_$taskRunTag.json"
    if($taskResult -ne 0 -or !($taskOutput -match 'PASS RSA firmware control:')){throw 'RSA firmware simulation failed or missing PASS marker'}
    $taskOutput=& "$QuestaBin/vsim.exe" -c @taskLibraries work.tb_softcore_memory -do 'onerror {quit -code 1}; onbreak {quit -code 1}; run -all; quit -code 0' 2>&1
    $taskResult=$LASTEXITCODE;$taskOutput | Tee-Object -FilePath "cpu_memory_$Backend.log"
    if($taskResult -ne 0 -or !($taskOutput -match 'PASS CPU memory:')){throw 'CPU memory simulation failed or missing PASS marker'}
} finally {Pop-Location}
