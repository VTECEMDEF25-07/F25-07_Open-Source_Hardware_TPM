# Filename: test_lifecycle_questa.py
# Authors: Aaron Grossman; Project contributors; see Git history.
# Date: 2026-11-08
# General Description: Run the real lifecycle suite with both IP_TYPE values and reject invalid selection.
# AI Disclosure: Codex assisted with coding and verification.
"""Use one compilation for Generic/Altera instances; source remains Verilog-2001."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

p=argparse.ArgumentParser()
p.add_argument('--build',type=Path,required=True)
p.add_argument('--questa-bin',type=Path,default=Path('C:/intelFPGA_lite/24.1std/questa_fse/win64'))
p.add_argument('--altera-models',type=Path,default=Path('C:/intelFPGA_lite/24.1std/quartus/eda/sim_lib'))
a=p.parse_args()
root=Path(__file__).resolve().parents[1]
source=(root/'../../../Source Code/Key Generation').resolve()
build=a.build.resolve()
build.mkdir(parents=True,exist_ok=True)
shared=source.parent
files=sorted((source/'IP').glob('*.v'))+sorted((source/'rtl').rglob('*.v'))
files+=[shared/'TPM_TOP.v']
for directory in ['IO Interface','Execution Engine','Management Module','RNG Module']:
    files+=sorted((shared/directory).glob('*.v'))
bench=root/'testbench/tb_keygen_lifecycle.sv'
tpm_bench=root/'testbench/tb_tpm_ip_type.sv'
models=[a.altera_models/n for n in ['220model.v','altera_mf.v']]
inputs=files+[bench,tpm_bench,shared/'IO Interface/tpm_types.vh',Path(__file__).resolve()]+models
def hashes():return {str(f):hashlib.sha256(f.read_bytes()).hexdigest() for f in inputs}
before=hashes()
commands=[]
def run(tool,args,log,expected_failure=False):
    command=[str(a.questa_bin/(tool+'.exe'))]+args
    commands.append(command)
    result=subprocess.run(command,cwd=build,capture_output=True,timeout=300)
    (build/log).write_bytes(result.stdout+result.stderr)
    text=(result.stdout+result.stderr).decode(errors='replace')
    if expected_failure:
        if result.returncode==0 or 'KEYGEN_INVALID_IP_TYPE' not in text:
            raise RuntimeError('Invalid IP_TYPE was not rejected at elaboration: '+text[-2000:])
    elif result.returncode:
        raise RuntimeError(log+': '+text[-2000:])
    return text
for library in ['work','vendor']:
    if not (build/library).exists():run('vlib',[library],library+'.log')
run('vlog',['-work','vendor']+list(map(str,models)),'vendor_compile.log')
include='+incdir+'+str(shared)
run('vlog',['-vlog01compat',include,'+incdir+'+str(shared/'IO Interface')]+list(map(str,files)),'source_compile.log')
run('vlog',['-sv',include,str(bench),str(tpm_bench)],'test_compile.log')
for ip_type in [0,1]:
    text=run('vsim',['-c','-L','vendor','-gIP_TYPE='+str(ip_type),'work.tb_keygen_lifecycle','-do',
                     'onerror {quit -code 1}; onbreak {quit -code 1}; run -all; quit -code 0'],
             'lifecycle-'+str(ip_type)+'.log')
    if 'PASS CORE_LIFECYCLE checks=28' not in text or ('PASS IP_TYPE propagation='+str(ip_type)) not in text:
        raise RuntimeError('Missing lifecycle/propagation acceptance: '+text[-2000:])
    print('PASS lifecycle checks=28 IP_TYPE='+str(ip_type),flush=True)
text=run('vsim',['-c','-L','vendor','work.tb_tpm_ip_type','-do',
                 'onerror {quit -code 1}; onbreak {quit -code 1}; run -all; quit -code 0'],
         'tpm-placeholder.log')
if 'PASS TPM_IP_TYPE backends=2 families=2 rng_rings=4 inactive_cycles=6000' not in text:
    raise RuntimeError('Missing TPM placeholder acceptance: '+text[-2000:])
print('PASS TPM_IP_TYPE backends=2 families=2 rng_rings=4 inactive_cycles=6000',flush=True)
for ip_type in [2,-1]:
    run('vsim',['-c','-L','vendor','-gIP_TYPE='+str(ip_type),'work.tb_keygen_lifecycle','-do','quit -code 0'],
        'invalid-'+str(ip_type)+'.log',expected_failure=True)
    print('PASS rejected invalid IP_TYPE='+str(ip_type),flush=True)
assert hashes()==before,'Input changed during simulation'
(build/'manifest.json').write_text(json.dumps({'inputs':before,'commands':commands,'passed_ip_types':[0,1],'rejected_ip_types':[2,-1]},indent=2)+'\n')
