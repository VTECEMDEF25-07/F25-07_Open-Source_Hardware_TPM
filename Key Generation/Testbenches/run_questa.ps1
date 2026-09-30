# AI-authored unit regression runner. All generated libraries/logs stay in class AI/tmp.
param(
    [string]$QuestaBin = 'C:/intelFPGA_lite/24.1std/questa_fse/win64'
)
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$classRoot = (Resolve-Path (Join-Path $repoRoot '../..')).Path
$runRoot = Join-Path $classRoot ('AI/tmp/keygen-plumbing/run-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $runRoot | Out-Null
$workLibrary = Join-Path $runRoot 'work'
$savedTemp = $env:TEMP
$savedTmp = $env:TMP
Push-Location -LiteralPath $runRoot
try {
    $env:TEMP = $runRoot
    $env:TMP = $runRoot
    $vlib = Join-Path $QuestaBin 'vlib.exe'
    $vlog = Join-Path $QuestaBin 'vlog.exe'
    $vsim = Join-Path $QuestaBin 'vsim.exe'
    foreach ($toolPath in @($vlib, $vlog, $vsim)) {
        if (-not (Test-Path -LiteralPath $toolPath)) { throw "Missing Questa tool: $toolPath" }
    }
    & $vlib 'work'
    if ($LASTEXITCODE -ne 0) { throw 'vlib failed' }
    $sources = @(
        (Join-Path $repoRoot 'Key Generation/keygen_dispatch_adapter.v'),
        (Join-Path $repoRoot 'Key Generation/aes_key_assembler.v'),
        (Join-Path $repoRoot 'Execution Engine/execution_engine.v'),
        (Join-Path $PSScriptRoot 'tb_execution_keygen_plumbing.sv'),
        (Join-Path $PSScriptRoot 'tb_unavailable_keygen_backend.sv'),
        (Join-Path $PSScriptRoot 'tb_aes_key_assembler.sv')
    )
    & $vlog -sv -work 'work' @sources
    if ($LASTEXITCODE -ne 0) { throw 'vlog failed' }
    foreach ($testName in @('tb_execution_keygen_plumbing', 'tb_unavailable_keygen_backend', 'tb_aes_key_assembler')) {
        $doFile = Join-Path $runRoot ($testName + '.do')
        $logFile = Join-Path $runRoot ($testName + '.log')
        # Do not retain waveforms containing key material, even synthetic unit vectors.
        $waveFile = 'NUL'
        # Real macro gives onbreak/onerror handlers effect; log check also catches $fatal exits.
        @('onbreak {quit -code 1}', 'onerror {quit -code 1}', 'run -all', 'quit -code 0') |
            Set-Content -LiteralPath $doFile
        $macroPath = $doFile.Replace('\', '/')
        & $vsim -c -onfinish exit -lib 'work' $testName -l $logFile -wlf $waveFile -do "do {$macroPath}"
        $simExit = $LASTEXITCODE
        $logText = Get-Content -LiteralPath $logFile -Raw
        if ($simExit -ne 0 -or $logText -match '\*\* Fatal:|Errors: [1-9]' -or $logText -notmatch '# PASS') {
            throw "$testName failed; inspect $logFile"
        }
    }
    Write-Output "PASS unit regression; logs: $runRoot"
} finally {
    Pop-Location
    $env:TEMP = $savedTemp
    $env:TMP = $savedTmp
}
