"""Linux/WSL full-key regression. All build products remain under this repository.

Verilator emits C++; compile directly with g++ because GNU make rejects spaces
in its current directory. No source copies or external workspace are needed.
"""
import argparse
import hashlib
import json
import os
import selectors
import signal
from pathlib import Path
import re
import shutil
import subprocess
import time


def run_simulation(command, cwd, log_path, timeout):
    """Keep stdout in memory; never hold a SeaDrive log open during simulation."""
    chunks = []
    pending = b''
    deadline = time.monotonic() + timeout
    last_progress = 0.0
    process = subprocess.Popen(command, cwd=cwd, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, bufsize=0,
                               start_new_session=True)
    selector = selectors.DefaultSelector()
    selector.register(process.stdout, selectors.EVENT_READ)
    try:
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise subprocess.TimeoutExpired(command, timeout)
            if not selector.select(min(5.0, remaining)):
                continue
            chunk = os.read(process.stdout.fileno(), 65536)
            if not chunk:
                break
            chunks.append(chunk)
            pending += chunk
            while b'\n' in pending:
                line, pending = pending.split(b'\n', 1)
                now = time.monotonic()
                if line.startswith(b'PASS ') or (line.startswith(b'PROGRESS ') and now-last_progress >= 10):
                    print(line.decode('utf-8', errors='replace'), flush=True)
                    last_progress = now
        returncode = process.wait(timeout=max(0.001, deadline-time.monotonic()))
        if returncode:
            raise subprocess.CalledProcessError(returncode, command)
    except BaseException:
        # A timeout or interruption must not leave descendants running.
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        tail, _ = process.communicate(timeout=5)
        if tail:
            chunks.append(tail)
        raise
    finally:
        selector.close()
        process.stdout.close()
        temporary = log_path.with_name(log_path.name + '.partial')
        temporary.write_bytes(b''.join(chunks))
        temporary.replace(log_path)

p=argparse.ArgumentParser()
p.add_argument('--softcore',action='store_true')
p.add_argument('--directed',action='store_true',help='Known prime candidates and witness2; functional test, not search-performance evidence')
p.add_argument('--stalls',action='store_true',help='Insert source gaps, result backpressure and ownership delay')
p.add_argument('--seeds',nargs='+',type=int,default=[1])
p.add_argument('--reuse-build',action='store_true')
p.add_argument('--build-only',action='store_true')
p.add_argument('--label',default='',help='Optional evidence directory suffix; letters, digits, underscore and hyphen only')
a=p.parse_args()
if a.label and not re.fullmatch(r'[A-Za-z0-9_-]+',a.label):p.error('Invalid evidence label')
root=Path(__file__).resolve().parents[1]
build=root/'build'/(('full_softcore' if a.softcore else 'full_rtl')+('_directed' if a.directed else '')+('_stalls' if a.stalls else '')+('_'+a.label if a.label else ''))
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
    shutil.copyfile(root/'build/full/rsa_control.hex',build/'rsa_control.hex')
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
manifest_path=build/'source_manifest.json'
inputs={s:digest(root/s) for s in sources}
if a.softcore:inputs['build/full/rsa_control.hex']=digest(root/'build/full/rsa_control.hex')
inputs['reference/expected_keys.json']=digest(root/'reference/expected_keys.json')
inputs['scripts/run_full_verilator.py']=digest(Path(__file__))
manifest={'inputs_sha256':inputs,'controller':'softcore' if a.softcore else 'dedicated',
          'resources':'generic','simulator':subprocess.check_output(['verilator','--version'],text=True).strip()}
binary=obj/'Vtb_keygen_full'
if a.reuse_build:
    if not manifest_path.exists():raise RuntimeError('Reuse requires a recorded source manifest; rebuild with a fresh label')
    previous=json.loads(manifest_path.read_text())
    if any(previous.get(k)!=v for k,v in manifest.items()):raise RuntimeError('Source/tool/firmware changed; refusing stale binary')
    if previous.get('binary_sha256')!=digest(binary):raise RuntimeError('Binary hash differs from recorded build')
    manifest=previous
if not a.reuse_build:
    if obj.exists():
        if obj.resolve().parent!=build.resolve():raise RuntimeError('Object directory escaped its build directory')
        shutil.rmtree(obj)
    command=['verilator','--cc','--exe','--main','--timing','--top-module','tb_keygen_full',
             '--Mdir',str(obj),'-Wno-fatal','+1364-2001ext+v','+1800-2017ext+sv']
    if a.softcore:command+=['+define+KEYGEN_SOFTCORE']
    command += [str(root/s) for s in sources]
    with (build/'elaborate.log').open('w') as log:
        subprocess.run(command,cwd=build,stdout=log,stderr=subprocess.STDOUT,check=True)
    vr=Path('/usr/share/verilator/include')
    command=['g++','-O2','-std=c++20','-pthread','-I'+str(obj),'-I'+str(vr),'-I'+str(vr/'vltstd')]
    command += [str(s) for s in sorted(obj.glob('*.cpp'))]
    command += [str(vr/s) for s in ['verilated.cpp','verilated_timing.cpp','verilated_threads.cpp']]
    command += ['-o',str(binary)]
    with (build/'compile.log').open('w') as log:
        subprocess.run(command,cwd=build,stdout=log,stderr=subprocess.STDOUT,check=True)
    # Catch concurrent edits while compilation was in progress.
    if any(digest(root/s)!=h for s,h in inputs.items()):raise RuntimeError('Source changed during build; rebuild from a stable snapshot')
    manifest['binary_sha256']=digest(binary)
    manifest_path.write_text(json.dumps(manifest,indent=2)+'\n')
    print('PASS full-top build',binary,flush=True)
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
    command=[str(binary),f'+SEED={seed}',f'+EXPECTED={path}',f'+WORDS={fixture["words_consumed"]}']
    if a.directed:
        stimulus=[]
        for prime in ('p','q'):
            for value in [int(fixture['key'][prime],16)]+[2]*5:
                stimulus += [(value>>(32*i))&0xffffffff for i in reversed(range(32))]
        stimulus_path=build/f'stimulus-{seed}.hex'
        stimulus_path.write_text(''.join(f'{w:08x}\n' for w in stimulus))
        command=[str(binary),f'+SEED={seed}',f'+EXPECTED={path}','+WORDS=384',
                 '+DIRECTED',f'+STIMULUS={stimulus_path}']
    started=time.monotonic()
    if a.stalls:command+=['+STALLS']
    run_simulation(command, build, build/f'seed-{seed}.log', timeout=7200)
    text=(build/f'seed-{seed}.log').read_text()
    match=re.search(r'PASS FULL_RSA seed=(\d+) softcore=(\d+) words=(\d+) cycles=(\d+)',text)
    if not match:raise RuntimeError('No complete-key PASS evidence')
    report=dict(zip(['seed','softcore','words','cycles'],map(int,match.groups())))
    report['simulator_seconds']=time.monotonic()-started
    report['hardware_seconds_50mhz']=report['cycles']/50_000_000
    report['directed_candidates_not_search_benchmark']=a.directed
    report['external_stalls']=a.stalls
    report['source_manifest_sha256']=digest(manifest_path)
    reports.append(report)
    (build/'results.json').write_text(json.dumps(reports,indent=2)+'\n')
    print(json.dumps(report),flush=True)
