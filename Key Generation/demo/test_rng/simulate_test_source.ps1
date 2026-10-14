# Filename: simulate_test_source.ps1
# Authors: Project contributors; see Git history.
# Date: 2026-10-13
# General Description: Provides simulate test source support for the key-generation implementation and verification.
# AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

param(
    [Parameter(Mandatory=$true)][string] $BuildDirectory,
    [string] $QuestaBin = 'C:/intelFPGA_lite/24.1std/questa_fse/win64',
    [string] $Python = 'C:/Python314/python.exe'
)
$ErrorActionPreference = 'Stop'
$taskSource = (Resolve-Path $PSScriptRoot).Path.Replace('\','/')
New-Item -ItemType Directory -Force -Path $BuildDirectory | Out-Null
$taskBuild = (Resolve-Path $BuildDirectory).Path
& $Python "$taskSource/tests/generate_vectors.py" $taskBuild
if ($LASTEXITCODE -ne 0) { throw 'Fixture generation failed.' }
$taskCommands = @(
    'onerror {quit -code 1 -force}', 'onbreak {quit -code 1 -force}',
    'if {![file isdirectory work]} {vlib work}',
    "vlog -vlog01compat {$taskSource/keygen_test_source.v}",
    "vlog -sv {$taskSource/tests/tb_keygen_test_source.sv}",
    'vsim -voptargs=+acc work.tb_keygen_test_source', 'run -all', 'quit -code 0 -force'
)
$taskCommands | Set-Content -Encoding ascii "$taskBuild/simulate.do"
Push-Location $taskBuild
try {
    & "$QuestaBin/vsim.exe" -c -do simulate.do -l test_source.log
    if ($LASTEXITCODE -ne 0) { throw 'Test source simulation failed.' }
    if (!(Select-String -Path test_source.log -Pattern 'PASS test source:')) { throw 'No explicit PASS marker.' }
} finally { Pop-Location }
