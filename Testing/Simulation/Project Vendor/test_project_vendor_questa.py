"""Verify one project selection, both board RAM families, RNG behavior and rejection.

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
repo=here.parents[2]
source=repo/'Source Code'
build=a.build.resolve()
build.mkdir(parents=True,exist_ok=True)
lifecycle=build/'lifecycle'
subprocess.run([sys.executable,str(here.parent/'Key Generation/scripts/test_lifecycle_questa.py'),
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
benches=[here/'tb_vendor_rejection.sv',here.parent/'Key Generation/IP/tests/tb_keygen_resources.sv']
run('vlog',['-sv','+incdir+'+str(source)]+list(map(str,benches)),'compile-sv.log')
rng_benches=[here.parent/'RNG Module'/n for n in ['tb_entropy_capture.v','tb_tpm2_get_random.v']]
run('vlog',['-vlog01compat','+incdir+'+str(source)]+list(map(str,rng_benches)),'compile-rng.log')
do='onerror {quit -code 1}; onbreak {quit -code 1}; run -all; quit -code 0'
for family in ['Agilex 5','Cyclone V']:
    output=run('vsim',['-c','-L','vendor','-gDEVICE_FAMILY='+family,'work.tb_keygen_resources','-do',do],
               'resources-'+family.replace(' ','-')+'.log')
    assert 'PASS resources: products=2637 reads=2750 collisions=596 stalls=1300' in output,output[-3000:]
    print('PASS resource differential '+family,flush=True)
for ip_type in [0,1]:
    for bench in ['tb_entropy_capture','tb_tpm2_get_random']:
        # The original capture bench ends with $stop; accept only its explicit
        # pass text and absence of failures/timeouts, then terminate the batch.
        output=run('vsim',['-c','-L','vendor','-gIP_TYPE='+str(ip_type),'work.'+bench,'-do',
            'onerror {quit -code 1}; onbreak {quit -code 0}; run -all; quit -code 0'],
            bench+'-'+str(ip_type)+'.log')
        assert 'ALL TESTS PASSED' in output and 'FAIL' not in output and 'TIMEOUT' not in output,output[-3000:]
        print('PASS RNG behavior '+bench+' IP_TYPE='+str(ip_type),flush=True)
for scenario,ip_type,marker in [
    (s,i,'KEYGEN_INVALID_IP_TYPE' if s==0 else 'RNG_UNSUPPORTED_IP_TYPE')
    for s in [0,1] for i in [2,99,-1]
]+[(2,1,'PROJECT_UNSUPPORTED_DEVICE_FAMILY'),(3,1,'RNG_INVALID_STAGES')]:
    run('vsim',['-c','-L','vendor','-gSCENARIO='+str(scenario),'-gIP_TYPE='+str(ip_type),
                'work.tb_vendor_rejection','-do',do],
        'reject-'+str(scenario)+'-'+str(ip_type)+'.log',reject=marker)
    print('PASS rejected scenario='+str(scenario)+' IP_TYPE='+str(ip_type),flush=True)
for macro in ['RO_INTEL','RO_XILINX','RO_ICE40']:
    run('vlog',['-vlog01compat','+incdir+'+str(source),'+define+'+macro,
                str(source/'RNG Module/ring_osc.v')],'legacy-compile-'+macro+'.log')
    run('vsim',['-c','-L','vendor','-gSCENARIO=1','-gIP_TYPE=1',
                'work.tb_vendor_rejection','-do',do],'legacy-reject-'+macro+'.log',
        reject='RNG_LEGACY_VENDOR_DEFINE')
    print('PASS rejected legacy '+macro,flush=True)
run('vlog',['-vlog01compat','+incdir+'+str(source),str(source/'RNG Module/ring_osc.v')],
    'restore-ring-compile.log')
inputs=benches+rng_benches+[Path(__file__).resolve()]+list(source.rglob('*.v'))+list(source.rglob('*.vh'))
(build/'manifest.json').write_text(json.dumps({'commands':commands,'inputs':{
    str(f.relative_to(repo)):hashlib.sha256(f.read_bytes()).hexdigest() for f in inputs}},indent=2)+'\n')
print('PASS project-wide vendor selection',flush=True)
