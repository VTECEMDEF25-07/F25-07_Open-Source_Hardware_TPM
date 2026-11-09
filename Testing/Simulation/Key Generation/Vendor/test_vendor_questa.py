"""Verify keygen selection, both board RAM families and rejection.

Author: Aaron Grossman; Codex assisted with coding and verification.
Run with --build pointing to a fresh scratch directory outside tracked source.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

p=argparse.ArgumentParser()
p.add_argument('--build',type=Path,required=True)
p.add_argument('--questa-bin',type=Path,default=Path('C:/intelFPGA_lite/24.1std/questa_fse/win64'))
a=p.parse_args()
here=Path(__file__).resolve().parent
repo=here.parents[3]
source=repo/'Source Code'
build=a.build.resolve()
build.mkdir(parents=True,exist_ok=True)
lifecycle=build/'lifecycle'
subprocess.run([sys.executable,str(here.parent/'scripts/test_lifecycle_questa.py'),
                '--build',str(lifecycle),'--questa-bin',str(a.questa_bin)],check=True)
commands=[]
def run(tool,args,log,reject=None):
    command=[str(a.questa_bin/(tool+'.exe'))]+args
    commands.append(command)
    result=subprocess.run(command,cwd=lifecycle,capture_output=True,timeout=300)
    output=(result.stdout+result.stderr).decode(errors='replace')
    (build/log).write_text(output)
    if reject:
        assert result.returncode != 0 and reject in output and 'UNEXPECTED_ACCEPTANCE' not in output, output[-3000:]
    else:
        assert result.returncode == 0,output[-3000:]
    return output
benches=[here/'tb_vendor_rejection.sv',here.parent/'IP/tests/tb_keygen_resources.sv']
run('vlog',['-sv','+incdir+'+str(source)]+list(map(str,benches)),'compile-sv.log')
do='onerror {quit -code 1}; onbreak {quit -code 1}; run -all; quit -code 0'
for family in ['Agilex 5','Cyclone V']:
    output=run('vsim',['-c','-L','vendor','-gDEVICE_FAMILY='+family,'work.tb_keygen_resources','-do',do],
               'resources-'+family.replace(' ','-')+'.log')
    assert 'PASS resources: products=2637 reads=2750 collisions=596 stalls=1300' in output,output[-3000:]
    print('PASS resource differential '+family,flush=True)
for scenario,ip_type,marker in [(0,i,'KEYGEN_INVALID_IP_TYPE') for i in [2,99,-1]]+[(2,1,'PROJECT_UNSUPPORTED_DEVICE_FAMILY')]:
    run('vsim',['-c','-L','vendor','-gSCENARIO='+str(scenario),'-gIP_TYPE='+str(ip_type),
                'work.tb_vendor_rejection','-do',do],
        'reject-'+str(scenario)+'-'+str(ip_type)+'.log',reject=marker)
    print('PASS rejected scenario='+str(scenario)+' IP_TYPE='+str(ip_type),flush=True)
inputs=benches+[Path(__file__).resolve()]+list((source/'Key Generation').rglob('*.v'))+[source/'TPM_TOP.v']
(build/'manifest.json').write_text(json.dumps({'commands':commands,'inputs':{
    str(f.relative_to(repo)):hashlib.sha256(f.read_bytes()).hexdigest() for f in inputs}},indent=2)+'\n')
print('PASS keygen vendor selection',flush=True)
