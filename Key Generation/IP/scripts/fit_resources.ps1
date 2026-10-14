param(
    [string] $BuildDirectory = '',
    [string] $QuartusBin = 'C:/altera_pro/26.1/quartus/bin64',
    [switch] $Generic
)
$ErrorActionPreference = 'Stop'
$taskSource = (Resolve-Path "$PSScriptRoot/..").Path.Replace('\','/')
if (!$BuildDirectory) { throw 'Pass an absolute scratch BuildDirectory outside the source checkout.' }
New-Item -ItemType Directory -Force -Path $BuildDirectory | Out-Null
$taskBuild = (Resolve-Path $BuildDirectory).Path
$taskSettings = @(
    'set_global_assignment -name FAMILY "Agilex 5"',
    'set_global_assignment -name DEVICE A5ED013BB32AE4SCS',
    'set_global_assignment -name TOP_LEVEL_ENTITY keygen_resources_smoke',
    'set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files',
    'set_global_assignment -name SDC_FILE resources.sdc',
    'set_global_assignment -name VERILOG_INPUT_VERSION VERILOG_2001',
    'set_instance_assignment -name VIRTUAL_PIN ON -to *'
)
if (!$Generic) { $taskSettings += 'set_global_assignment -name VERILOG_MACRO "KEYGEN_ALTERA=1"' }
foreach ($taskFile in Get-ChildItem "$taskSource/*.v") {
    $taskSettings += "set_global_assignment -name VERILOG_FILE `"$($taskFile.FullName.Replace('\','/'))`""
}
$taskSettings += "set_global_assignment -name VERILOG_FILE `"$taskSource/tests/keygen_resources_smoke.v`""
$taskSettings | Set-Content -Encoding ascii "$taskBuild/resources.qsf"
'PROJECT_REVISION = "resources"' | Set-Content -Encoding ascii "$taskBuild/resources.qpf"
@('create_clock -name core_clock -period 20.000 [get_ports clock_i]', 'derive_clock_uncertainty') | Set-Content -Encoding ascii "$taskBuild/resources.sdc"
Push-Location $taskBuild
try {
    & "$QuartusBin/quartus_sh.exe" --flow compile resources *> compile.log
    if ($LASTEXITCODE -ne 0) { Get-Content compile.log -Tail 60; throw 'Quartus compile failed.' }
    Get-Content output_files/resources.fit.summary
    if (!(Select-String -Path output_files/resources.fit.summary -Pattern 'Fitter Status : Successful')) { throw 'No successful fitter report.' }
} finally { Pop-Location }
