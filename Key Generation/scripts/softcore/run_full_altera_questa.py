"""Full-key Questa regression against genuine installed Altera models. All build products remain under this repository.

Vendor files are compiled unchanged; generic implementations remain unselected.
All source RTL is compiled as Verilog 2001, with SystemVerilog only for tests.
"""
import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import time
from datetime import datetime, timezone
from vendor_evidence import file_hash, input_hashes, save_json, validate_reuse

p=argparse.ArgumentParser()
p.add_argument('--source-root',type=Path,help='Integrated Key Generation source root')
p.add_argument('--altera-models',type=Path,default=Path('C:/intelFPGA_lite/24.1std/quartus/eda/sim_lib'))
p.add_argument('--questa-bin',type=Path,default=Path('C:/intelFPGA_lite/24.1std/questa_fse/win64'))
p.add_argument('--softcore',action='store_true')
p.add_argument('--directed',action='store_true',help='Known prime candidates and witness2; functional test, not search-performance evidence')
p.add_argument('--seeds',nargs='+',type=int,default=[1])
p.add_argument('--reuse-build',action='store_true')
p.add_argument('--build-only',action='store_true')
p.add_argument('--label',default='verified',help='Unique evidence directory suffix')
a=p.parse_args()
if not re.fullmatch(r'[A-Za-z0-9_-]+',a.label):p.error('label must contain only letters, digits, underscores or hyphens')
root=(a.source_root or Path(__file__).resolve().parents[2]).resolve()
build=root/'build'/(('full_altera_softcore' if a.softcore else 'full_altera_rtl')+('_directed' if a.directed else '')+'-'+a.label)
obj=build/'obj'
build.mkdir(parents=True,exist_ok=True)
sources=[
    'IP/keygen_mult32.v','IP/keygen_mult32_generic.v','IP/keygen_mult32_altera.v',
    'IP/keygen_ram32.v','IP/keygen_ram32_generic.v','IP/keygen_ram32_altera.v',
    'rtl/aes/keygen_aes_core.v','rtl/arithmetic/keygen_math.v','rtl/arithmetic/keygen_pair_check.v',
    'rtl/rsa_rtl/keygen_rsa_services.v','rtl/rsa_rtl/keygen_rsa_controller.v',
    'rtl/rsa_rtl/keygen_rsa_engine.v','rtl/common/keygen_core.v',
    'demo/test_rng/keygen_test_source.v','testbench/tb_keygen_full.sv',
]
if a.softcore:
    sources += ['IP/third_party/picorv32/picorv32.v','rtl/rsa_softcore/keygen_softcore_control.v',
                'rtl/rsa_softcore/keygen_rsa_softcore.v']

models=[(a.altera_models/name).resolve() for name in ('220model.v','altera_mf.v')]
simulator=subprocess.run([str(a.questa_bin/'vsim.exe'),'-version'],capture_output=True,text=True,check=True).stdout.strip()
manifest_path=build/'build-manifest.json'
manifest={'inputs':input_hashes(root,sources,models,a.softcore),'simulator':simulator,
          'configuration':{'softcore':a.softcore,'backend':'KEYGEN_ALTERA','top':'tb_keygen_full',
                           'rtl_language':'Verilog2001','test_language':'SystemVerilog'},'commands':[]}
if a.reuse_build:
    manifest=validate_reuse(manifest_path,manifest)
    if a.softcore and file_hash(build/'rsa_control.hex')!=file_hash(root/'build/full/rsa_control.hex'):
        raise RuntimeError('Stale built firmware rejected')
else:
    if manifest_path.exists():raise RuntimeError('Preserve previous evidence: choose a new --label or --reuse-build')
    if a.softcore:shutil.copyfile(root/'build/full/rsa_control.hex',build/'rsa_control.hex')

def run_tool(tool, args, log_name):
    manifest['commands'].append([str(a.questa_bin/(tool+'.exe'))]+args)
    with (build/log_name).open('w') as log:
        subprocess.run([str(a.questa_bin/(tool+'.exe'))]+args, cwd=build,
                       stdout=log, stderr=subprocess.STDOUT, check=True)
if not a.reuse_build:
    for library in ('work','vendor'):
        if not (build/library).exists():run_tool('vlib',[library],library+'_create.log')
    run_tool('vlog',['-work','vendor']+[str(a.altera_models/s) for s in ('220model.v','altera_mf.v')],'vendor_compile.log')
    defines=['+define+KEYGEN_ALTERA']
    if a.softcore:defines+=['+define+KEYGEN_SOFTCORE']
    run_tool('vlog',['-vlog01compat']+defines+[str(root/s) for s in sources if s.endswith('.v')],'rtl_compile.log')
    run_tool('vlog',['-sv']+defines+[str(root/s) for s in sources if s.endswith('.sv')],'test_compile.log')
    if input_hashes(root,sources,models,a.softcore)!=manifest['inputs']:raise RuntimeError('Sources changed during compilation')
    save_json(manifest_path,manifest)
    print('PASS full-top Altera source compile',build,flush=True)
if a.build_only:raise SystemExit(0)
corpus=json.loads((root/'reference/expected_keys.json').read_text())
reports=[]
for seed in a.seeds:
    fixture=next(x for x in corpus['results'] if x['seed_id']==seed)
    words=[]
    for name,count in [('n',64),('e',1),('p',32),('q',32)]:
        value=int(fixture['key'][name],16)
        words += [(value>>(32*i))&0xffffffff for i in reversed(range(count))]
    path=build/f'expected-{seed}.hex'
    path.write_text(''.join(f'{w:08x}\n' for w in words))
    command=[str(a.questa_bin/'vsim.exe'),'-c','-L','vendor','work.tb_keygen_full',f'+SEED={seed}',f'+EXPECTED={path}',f'+WORDS={fixture["words_consumed"]}']
    if a.directed:
        stimulus=[]
        for prime in ('p','q'):
            for value in [int(fixture['key'][prime],16)]+[2]*5:
                stimulus += [(value>>(32*i))&0xffffffff for i in reversed(range(32))]
        stimulus_path=build/f'stimulus-{seed}.hex'
        stimulus_path.write_text(''.join(f'{w:08x}\n' for w in stimulus))
        command=[str(a.questa_bin/'vsim.exe'),'-c','-L','vendor','work.tb_keygen_full',f'+SEED={seed}',f'+EXPECTED={path}','+WORDS=384',
                 '+DIRECTED',f'+STIMULUS={stimulus_path}']
    command+=['-do','onerror {quit -code 1}; onbreak {quit -code 1}; run -all; quit -code 0']
    run_path=build/f'seed-{seed}-manifest.json'
    if run_path.exists():raise RuntimeError('Preserve previous run evidence: choose a new --label')
    evidence={'status':'RUNNING','started_utc':datetime.now(timezone.utc).isoformat(),
              'build_manifest_sha256':file_hash(manifest_path),'command':command,
              'expected_fixture_sha256':file_hash(path),'directed':a.directed,
              'firmware_sha256':file_hash(build/'rsa_control.hex') if a.softcore else None}
    if a.directed:evidence['stimulus_sha256']=file_hash(stimulus_path)
    save_json(run_path,evidence)
    started=time.monotonic()
    try:
        with (build/f'seed-{seed}.log').open('w') as log:
            subprocess.run(command,cwd=build,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=7200)
    except (subprocess.CalledProcessError,subprocess.TimeoutExpired) as failure:
        evidence['status']='FAILED_OR_INCOMPLETE';evidence['error']=str(failure);save_json(run_path,evidence);raise
    text=(build/f'seed-{seed}.log').read_text()
    match=re.search(r'PASS FULL_RSA seed=(\d+) softcore=(\d+) words=(\d+) cycles=(\d+)',text)
    if not match:
        evidence['status']='FAILED_MISSING_PASS';save_json(run_path,evidence)
        raise RuntimeError('No complete-key PASS evidence')
    report=dict(zip(['seed','softcore','words','cycles'],map(int,match.groups())))
    report['resource_backend']='Altera: installed 220model.v and altera_mf.v'
    report['simulator']='Questa'
    report['simulator_seconds']=time.monotonic()-started
    report['hardware_seconds_50mhz']=report['cycles']/50_000_000
    report['directed_candidates_not_search_benchmark']=a.directed
    evidence['status']='PASS';evidence['result']=report;evidence['log_sha256']=file_hash(build/f'seed-{seed}.log');save_json(run_path,evidence)
    reports.append(report)
    (build/'results.json').write_text(json.dumps(reports,indent=2)+'\n')
    print(json.dumps(report),flush=True)
