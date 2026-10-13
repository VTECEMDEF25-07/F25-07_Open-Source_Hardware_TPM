param(
    [Parameter(Mandatory=$true)][string] $BuildDirectory,
    [string] $IpDirectory = '',
    [string] $Corpus = '',
    [ValidateSet('generic','altera','both')][string] $Backend = 'both',
    [string] $QuestaBin = 'C:/intelFPGA_lite/24.1std/questa_fse/win64',
    [string] $VendorModelDirectory = 'C:/intelFPGA_lite/24.1std/quartus/eda/sim_lib',
    [string] $Python = 'C:/Python314/python.exe'
)
$ErrorActionPreference = 'Stop'
$taskSource = (Resolve-Path "$PSScriptRoot/..").Path.Replace('\','/')
if (!$IpDirectory) { $IpDirectory = "$taskSource/IP" }
$taskIp = (Resolve-Path $IpDirectory).Path.Replace('\','/')
$taskBackends = if ($Backend -eq 'both') { @('generic','altera') } else { @($Backend) }
if (!$Corpus) { $Corpus = "$taskSource/reference/expected_keys.json" }
foreach ($taskBackend in $taskBackends) {
    $taskBuild = Join-Path $BuildDirectory $taskBackend
    New-Item -ItemType Directory -Force -Path $taskBuild | Out-Null
    $taskBuild = (Resolve-Path $taskBuild).Path
    & $Python "$taskSource/reference/pair_vectors.py" "$taskBuild/pair_vectors.mem" --corpus $Corpus
    if ($LASTEXITCODE -ne 0 -or !(Test-Path "$taskBuild/pair_vectors.mem")) { throw 'Vector generation failed.' }
    $taskDefine = if ($taskBackend -eq 'altera') {'+define+KEYGEN_ALTERA'} else {''}
    $taskCommands = @('onerror {quit -code 1 -force}', 'onbreak {quit -code 1 -force}', 'vlib work')
    if ($taskBackend -eq 'altera') {
        if (!(Test-Path "$VendorModelDirectory/220model.v")) { throw 'Actual Altera lpm_mult model missing.' }
        $taskCommands += @('vlib vendor', "vlog -work vendor {$VendorModelDirectory/220model.v} {$VendorModelDirectory/altera_mf.v}")
    }
    $taskCommands += @(
        "vlog -vlog01compat $taskDefine {$taskIp/keygen_mult32.v} {$taskIp/keygen_mult32_$taskBackend.v} {$taskIp/keygen_ram32.v} {$taskIp/keygen_ram32_$taskBackend.v} {$taskSource/rtl/arithmetic/keygen_pair_check.v}",
        "vlog -sv {$taskSource/testbench/tb_keygen_pair_check.sv}",
        'vsim -L vendor work.tb_keygen_pair_check', 'run -all', 'quit -code 0 -force'
    )
    if ($taskBackend -eq 'generic') { $taskCommands = $taskCommands -replace ' -L vendor', '' }
    $taskCommands | Set-Content -Encoding ascii "$taskBuild/simulate.do"
    Push-Location $taskBuild
    try {
        & "$QuestaBin/vsim.exe" -c -do simulate.do -l pair_check.log
        if ($LASTEXITCODE -ne 0) { throw "Pair-check simulation failed: $taskBackend" }
        if (!(Select-String -Path pair_check.log -Pattern 'PASS pair check:')) { throw 'No explicit PASS marker.' }
    } finally { Pop-Location }
}
