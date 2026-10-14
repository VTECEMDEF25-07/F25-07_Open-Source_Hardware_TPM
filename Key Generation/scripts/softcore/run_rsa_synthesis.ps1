# Filename: run_rsa_synthesis.ps1
# Authors: Project contributors; see Git history.
# Date: 2026-10-13
# General Description: Provides run rsa synthesis support for the key-generation implementation and verification.
# AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

param([ValidateSet("Generic","Altera")][string]$Backend="Generic",[Parameter(Mandatory=$true)][string]$Toolchain,[string]$QuartusBin = 'C:/altera_pro/26.1/quartus/bin64', [string]$Python = 'C:/Python314/python.exe')
$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path "$PSScriptRoot/../..").Path
$taskBuild=Join-Path $taskRoot 'build/rsa_softcore'
New-Item -ItemType Directory -Force $taskBuild | Out-Null
& $Python "$PSScriptRoot/build_rsa.py" --toolchain $Toolchain --output $taskBuild
if($LASTEXITCODE -ne 0 -or !(Test-Path "$taskBuild/rsa_control.hex")){throw 'Firmware build failed'}
$taskQsf=@(
'set_global_assignment -name FAMILY "Agilex 5"',
'set_global_assignment -name DEVICE A5ED013BB32AE4SCS',
'set_global_assignment -name TOP_LEVEL_ENTITY keygen_rsa_softcore',
'set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files'
)
if($Backend -eq 'Altera'){$taskQsf+='set_global_assignment -name VERILOG_MACRO KEYGEN_ALTERA'}
foreach($taskSource in @('IP/keygen_ram32_generic.v','IP/keygen_ram32_altera.v','IP/keygen_ram32.v','IP/third_party/picorv32/picorv32.v','rtl/rsa_softcore/keygen_softcore_control.v','rtl/rsa_softcore/keygen_rsa_softcore.v')) {
    $taskPath=(Join-Path $taskRoot $taskSource).Replace('\','/')
    $taskQsf+='set_global_assignment -name VERILOG_FILE "'+$taskPath+'"'
}
$taskQsf+='set_global_assignment -name SDC_FILE softcore.sdc'
$taskQsf | Set-Content "$taskBuild/softcore.qsf"
'PROJECT_REVISION = "softcore"' | Set-Content "$taskBuild/softcore.qpf"
'create_clock -name clock_i -period 20.000 [get_ports clock_i]' | Set-Content "$taskBuild/softcore.sdc"
Push-Location $taskBuild
try {
    & "$QuartusBin/quartus_syn.exe" --read_settings_files=on --write_settings_files=off softcore
    if($LASTEXITCODE -ne 0){throw 'Synthesis failed'}
} finally {Pop-Location}
