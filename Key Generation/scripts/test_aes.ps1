param([string]$QuestaBin='C:/intelFPGA_lite/24.1std/questa_fse/win64', [string]$BuildDirectory='')
$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if(!$BuildDirectory){$BuildDirectory=Join-Path $taskRoot 'build/aes'}
$taskBuild=[IO.Path]::GetFullPath($BuildDirectory)
New-Item -ItemType Directory -Force -Path $taskBuild | Out-Null
$taskSavedTemp=$env:TEMP; $taskSavedTmp=$env:TMP
Push-Location -LiteralPath $taskBuild
try {
    $env:TEMP=$taskBuild; $env:TMP=$taskBuild
    & "$QuestaBin/vlib.exe" work
    if($LASTEXITCODE -ne 0){throw 'vlib failed'}
    & "$QuestaBin/vlog.exe" -vlog01compat -work work (Join-Path $taskRoot 'rtl/aes/keygen_aes_core.v') -l source.log
    if($LASTEXITCODE -ne 0){throw 'Verilog source compilation failed'}
    & "$QuestaBin/vlog.exe" -sv -work work (Join-Path $taskRoot 'testbench/tb_keygen_aes_core.sv') -l tests.log
    if($LASTEXITCODE -ne 0){throw 'SV test compilation failed'}
    & "$QuestaBin/vsim.exe" -c -voptargs=+acc -wlf NUL work.tb_keygen_aes_core -l result.log -do 'onerror {quit -code 1}; onbreak {quit -code 1}; run -all; quit -code 0'
    if($LASTEXITCODE -ne 0){throw 'AES simulation failed'}
    $taskReport=Get-Content -LiteralPath result.log -Raw
    if($taskReport -notmatch 'PASS AES_CORE' -or $taskReport -match '\*\* (Error|Fatal):'){throw 'Missing PASS or simulator error'}
    Write-Output "PASS AES evidence: $taskBuild/result.log"
}finally{Pop-Location;$env:TEMP=$taskSavedTemp;$env:TMP=$taskSavedTmp}
