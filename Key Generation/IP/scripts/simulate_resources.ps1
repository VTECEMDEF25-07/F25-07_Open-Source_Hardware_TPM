# Filename: simulate_resources.ps1
# Authors: Project contributors; see Git history.
# Date: 2026-10-13
# General Description: Provides simulate resources support for the key-generation implementation and verification.
# AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

param(
    [string] $BuildDirectory = '',
    [string] $QuestaBin = 'C:/intelFPGA_lite/24.1std/questa_fse/win64',
    [string] $VendorModelDirectory = 'C:/intelFPGA_lite/24.1std/quartus/eda/sim_lib'
)
$ErrorActionPreference = 'Stop'
$taskSource = (Resolve-Path "$PSScriptRoot/..").Path.Replace('\', '/')
if (!$BuildDirectory) { throw 'Pass an absolute scratch BuildDirectory outside the source checkout.' }
New-Item -ItemType Directory -Force -Path $BuildDirectory | Out-Null
$taskBuild = (Resolve-Path $BuildDirectory).Path
foreach ($taskName in @('220model.v', 'altera_mf.v')) {
    if (!(Test-Path "$VendorModelDirectory/$taskName")) { throw "Missing real vendor model: $taskName" }
}
$taskCommands = @(
    'onerror {quit -code 1 -force}',
    'onbreak {quit -code 1 -force}',
    'if {![file isdirectory work]} {vlib work}',
    'if {![file isdirectory vendor]} {vlib vendor}',
    "vlog -work vendor {$VendorModelDirectory/220model.v} {$VendorModelDirectory/altera_mf.v}"
)
foreach ($taskFile in Get-ChildItem "$taskSource/*.v") {
    $taskCommands += "vlog -work work -vlog01compat {$($taskFile.FullName.Replace('\','/'))}"
}
$taskCommands += @(
    "vlog -sv {$taskSource/tests/tb_keygen_resources.sv}",
    'vsim -L vendor work.tb_keygen_resources',
    'run -all',
    'quit -code 0 -force'
)
$taskCommands | Set-Content -Encoding ascii "$taskBuild/simulate.do"
Push-Location $taskBuild
try {
    & "$QuestaBin/vsim.exe" -c -do simulate.do -l resources.log
    if ($LASTEXITCODE -ne 0) { throw "Simulation failed: $LASTEXITCODE" }
    if (!(Select-String -Path resources.log -Pattern 'PASS resources:')) { throw 'No explicit PASS; simulation is not accepted.' }
} finally { Pop-Location }
