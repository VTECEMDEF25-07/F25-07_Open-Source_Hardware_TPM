param([string] $BuildDirectory='', [switch] $Altera, [switch] $Full, [switch] $Small)
$ErrorActionPreference='Stop'
$taskSource=(Resolve-Path "$PSScriptRoot/..").Path.Replace('\','/')
$taskIp=(Resolve-Path "$PSScriptRoot/../../IP").Path.Replace('\','/')
if(!$BuildDirectory){throw 'Specify scratch BuildDirectory outside checkout.'}
New-Item -ItemType Directory -Force $BuildDirectory|Out-Null
$taskBuild=(Resolve-Path $BuildDirectory).Path
$taskExtra=@();if($Full){$taskExtra+='--full'};if($Small){$taskExtra+=@('--max-limbs','32')}
& 'C:/Python314/python.exe' "$taskSource/scripts/generate_vectors.py" "$taskBuild/vectors.txt" @taskExtra
if($LASTEXITCODE -ne 0){throw 'Vector generation failed'}
$taskCommands=@('onerror {quit -code 1 -force}','onbreak {quit -code 1 -force}','if {![file isdirectory work]} {vlib work}')
$taskDefine=''
if($Altera){
 $taskDefine='+define+KEYGEN_ALTERA'
 $taskCommands+=@('if {![file isdirectory vendor]} {vlib vendor}', 'vlog -work vendor C:/intelFPGA_lite/24.1std/quartus/eda/sim_lib/220model.v C:/intelFPGA_lite/24.1std/quartus/eda/sim_lib/altera_mf.v')
}
foreach($taskFile in Get-ChildItem "$taskIp/*.v"){$taskCommands+="vlog -vlog01compat $taskDefine {$($taskFile.FullName.Replace('\','/'))}"}
$taskCommands+=@("vlog -vlog01compat $taskDefine {$taskSource/../rtl/arithmetic/keygen_math.v}","vlog -sv $(if($Small){'+define+KEYGEN_MATH_SMALL'}) {$taskSource/tests/tb_keygen_math.sv}","vsim $(if($Altera){'-L vendor'}) work.tb_keygen_math",'run -all','quit -code 0 -force')
$taskCommands|Set-Content -Encoding ascii "$taskBuild/simulate.do"
Push-Location $taskBuild
try{
 & 'C:/intelFPGA_lite/24.1std/questa_fse/win64/vsim.exe' -c -do simulate.do -l math.log
 if($LASTEXITCODE -ne 0){throw 'Math simulation failed'}
 if(!(Select-String -Path math.log -Pattern 'PASS math:')){throw 'No explicit math PASS'}
}finally{Pop-Location}
