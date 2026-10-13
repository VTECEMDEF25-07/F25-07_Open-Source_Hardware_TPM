param(
    [Parameter(Mandatory=$true)][string] $BuildDirectory,
    [string] $QuestaBin='C:/intelFPGA_lite/24.1std/questa_fse/win64'
)
$ErrorActionPreference='Stop'
$taskSource=(Resolve-Path $PSScriptRoot).Path.Replace('\','/')
New-Item -ItemType Directory -Force -Path $BuildDirectory | Out-Null
$taskBuild=(Resolve-Path $BuildDirectory).Path
@(
 'onerror {quit -code 1 -force}','onbreak {quit -code 1 -force}',
 'if {![file isdirectory work]} {vlib work}',
 "vlog -vlog01compat {$taskSource/keygen_demo_spi.v} {$taskSource/keygen_demo_system.v} {$taskSource/../test_rng/keygen_test_source.v}",
 "vlog -sv {$taskSource/tests/keygen_core_model.sv} {$taskSource/tests/tb_keygen_demo.sv}",
 'vsim -voptargs=+acc work.tb_keygen_demo','run -all','quit -code 0 -force'
) | Set-Content -Encoding ascii "$taskBuild/simulate.do"
Push-Location $taskBuild
try {
 & "$QuestaBin/vsim.exe" -c -do simulate.do -l demo.log
 if($LASTEXITCODE -ne 0){throw 'Demo simulation failed.'}
 if(!(Select-String -Path demo.log -Pattern 'PASS demo SPI/receiver:')){throw 'No explicit PASS marker.'}
} finally {Pop-Location}
