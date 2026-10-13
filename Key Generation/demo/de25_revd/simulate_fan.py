"""Linux/WSL Verilator fan safety regression; products must be under AI/tmp."""
import argparse
from pathlib import Path
import subprocess
p=argparse.ArgumentParser();p.add_argument('--build',type=Path,required=True);a=p.parse_args()
here=Path(__file__).resolve().parent;build=a.build.resolve();obj=build/'obj';build.mkdir(parents=True,exist_ok=True)
sources=[here/'keygen_fan_guard.v',here/'tests/tb_keygen_fan.sv']+sorted((here/'vendor').glob('*.v'))
sources=[s for s in sources if s.name!='altera_s10_user_rst_clkgate.v']
command=['verilator','--cc','--exe','--main','--timing','--top-module','tb_keygen_fan','--Mdir',str(obj),'-Wno-fatal','+1364-2001ext+v','+1800-2017ext+sv']+[str(s) for s in sources]
with (build/'elaborate.log').open('w') as log:subprocess.run(command,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=120)
vr=Path('/usr/share/verilator/include');binary=obj/'Vtb_keygen_fan'
combined=obj/'combined.cpp'
combined.write_text(''.join('#include "'+s.name+'"\n' for s in sorted(obj.glob('*.cpp')) if s!=combined))
command=['g++','-O0','-std=c++20','-pthread','-I'+str(obj),'-I'+str(vr),'-I'+str(vr/'vltstd')]+[str(combined)]+[str(vr/s) for s in ('verilated.cpp','verilated_timing.cpp','verilated_threads.cpp')]+['-o',str(binary)]
with (build/'compile.log').open('w') as log:subprocess.run(command,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=300)
with (build/'result.log').open('w') as log:subprocess.run([str(binary)],stdout=log,stderr=subprocess.STDOUT,check=True,timeout=120)
result=(build/'result.log').read_text()
if 'PASS FAN_GUARD' not in result:raise RuntimeError(result)
print(result)
