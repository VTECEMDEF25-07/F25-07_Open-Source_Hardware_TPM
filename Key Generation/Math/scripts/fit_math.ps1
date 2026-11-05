# Filename: fit_math.ps1
# Authors: Project contributors; see Git history.
# Date: 2026-10-13
# General Description: Provides fit math support for the key-generation implementation and verification.
# AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

param(
    [string] $BuildDirectory = '',
    [string] $QuartusBin = 'C:/altera_pro/26.1/quartus/bin64',
    [switch] $Generic,
    [int] $MaxLimbs = 32
)
$ErrorActionPreference = 'Stop'
$taskSource = (Resolve-Path "$PSScriptRoot/../../IP").Path.Replace('\','/')
$taskMath = (Resolve-Path "$PSScriptRoot/../../rtl/arithmetic/keygen_math.v").Path.Replace('\','/')
if (!$BuildDirectory) { throw 'Pass an absolute scratch BuildDirectory outside the source checkout.' }
New-Item -ItemType Directory -Force -Path $BuildDirectory | Out-Null
$taskBuild = (Resolve-Path $BuildDirectory).Path
$taskSettings = @(
    "set_parameter -name MAX_LIMBS $MaxLimbs",
    'set_global_assignment -name FAMILY "Agilex 5"',
    'set_global_assignment -name DEVICE A5ED013BB32AE4SCS',
    'set_global_assignment -name TOP_LEVEL_ENTITY keygen_math',
    'set_global_assignment -name NUM_PARALLEL_PROCESSORS 4',
    'set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files',
    'set_global_assignment -name SDC_FILE math.sdc',
    'set_global_assignment -name VERILOG_INPUT_VERSION VERILOG_2001',
    'set_instance_assignment -name VIRTUAL_PIN ON -to *'
)
if (!$Generic) { $taskSettings += 'set_global_assignment -name VERILOG_MACRO "KEYGEN_ALTERA=1"' }
foreach ($taskFile in Get-ChildItem "$taskSource/*.v") {
    $taskSettings += "set_global_assignment -name VERILOG_FILE `"$($taskFile.FullName.Replace('\','/'))`""
}
$taskSettings += "set_global_assignment -name VERILOG_FILE `"$taskMath`""
$taskSettings | Set-Content -Encoding ascii "$taskBuild/math.qsf"
'PROJECT_REVISION = "math"' | Set-Content -Encoding ascii "$taskBuild/math.qpf"
@('create_clock -name core_clock -period 20.000 [get_ports clock_i]', 'derive_clock_uncertainty') | Set-Content -Encoding ascii "$taskBuild/math.sdc"
Push-Location $taskBuild
try {
    & "$QuartusBin/quartus_sh.exe" --flow compile math *> compile.log
    if ($LASTEXITCODE -ne 0) { Get-Content compile.log -Tail 60; throw 'Quartus compile failed.' }
    Get-Content output_files/math.fit.summary
    if (!(Select-String -Path output_files/math.fit.summary -Pattern 'Fitter Status : Successful')) { throw 'No successful fitter report.' }
} finally { Pop-Location }
