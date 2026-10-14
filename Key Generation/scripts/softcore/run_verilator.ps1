# Filename: run_verilator.ps1
# Authors: Project contributors; see Git history.
# Date: 2026-10-13
# General Description: Provides run verilator support for the key-generation implementation and verification.
# AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

param([Parameter(Mandatory=$true)][string]$Toolchain,[ValidateSet('Firmware','Memory')][string]$Test='Firmware',[string]$Python='C:/Python314/python.exe',[string]$Distro='Ubuntu-24.04',[switch]$Exhaustion,[switch]$BlockingStatus)
$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path "$PSScriptRoot/../..").Path
$taskBuild=Join-Path $taskRoot 'build/softcore'
$taskExtra=@();if($Test -eq 'Memory'){$taskExtra=@('--memory-selftest')}
& $Python "$PSScriptRoot/build_rsa.py" --toolchain $Toolchain --output $taskBuild @taskExtra
if($LASTEXITCODE -ne 0){throw 'Firmware compilation failed'}
$taskLinuxRoot=(& wsl -d $Distro --exec wslpath -u $taskRoot).Trim()
if($LASTEXITCODE -ne 0){throw 'WSL path conversion failed'}
$taskHash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($taskRoot))).Substring(0,12).ToLowerInvariant()
$taskAlias='/tmp/keygen-softcore-'+$taskHash
# The alias changes only path spelling. All sources/artifacts stay in the class root.
& wsl -d $Distro --exec python3 -c 'import os,sys; p=sys.argv[1]; target=sys.argv[2]; assert not os.path.lexists(p) or os.readlink(p)==target; os.symlink(target,p) if not os.path.lexists(p) else None' $taskAlias $taskLinuxRoot
if($LASTEXITCODE -ne 0){throw 'Alias verification failed'}
$taskTop=if($Test -eq 'Memory'){'tb_softcore_memory'}else{'tb_rsa_firmware'}
$taskObject="$taskAlias/build/softcore/obj_$taskTop"
$taskSources=@('IP/keygen_ram32_generic.v','IP/keygen_ram32.v','IP/third_party/picorv32/picorv32.v','rtl/rsa_softcore/keygen_softcore_control.v','rtl/rsa_softcore/keygen_rsa_softcore.v',"testbench/softcore/$taskTop.sv") | ForEach-Object {"$taskAlias/$_"}
$taskSimulationArgs=if($Exhaustion){'+EXHAUSTION'}else{''}
$taskDefines=if($BlockingStatus){'+define+KEYGEN_BLOCKING_STATUS_TEST'}else{''}
$taskCommand="cd $taskAlias/build/softcore && verilator --binary --timing -j 2 -Wno-fatal -MAKEFLAGS CURDIR=$taskObject --top-module $taskTop $taskDefines --Mdir $taskObject $($taskSources -join ' ') > $taskTop-build.log 2>&1 && $taskObject/V$taskTop $taskSimulationArgs > $taskTop-run.log 2>&1"
& wsl -d $Distro --exec bash -lc $taskCommand
$taskExit=$LASTEXITCODE
Get-Content "$taskBuild/$taskTop-build.log" -Tail 5
$taskLog=Get-Content "$taskBuild/$taskTop-run.log" -ErrorAction SilentlyContinue
$taskLog
$taskMarker=if($Test -eq 'Memory'){'PASS CPU memory:'}else{'PASS RSA firmware control:'}
if($taskExit -ne 0 -or !($taskLog -match $taskMarker)){throw 'Verilator failed or missing PASS marker'}

if($Exhaustion -and $Test -eq 'Firmware' -and !($taskLog -match 'PASS full retry limits:')){throw 'Full retry boundary coverage did not complete'}
