"""Run independent full-width Generic simulations with local Verilator in WSL.

Windows: wsl.exe --exec python3 <this path> generated|adapter|boundary|reset
All build/evidence output stays in this checkout. No vendor-model acceptance.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import time


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['generated', 'adapter', 'boundary', 'reset', 'errors', 'word-resets'])
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[3]
    bench = Path(__file__).parent
    build = root / ('build/rsa-fast-'+args.action)
    build.mkdir(parents=True, exist_ok=True)
    fixture_record = json.loads((root / 'build/rsa-adapter/prepare.json').read_text())
    for name, expected in fixture_record['fixtures'].items():
        source = root / 'build/rsa-adapter' / name
        if sha(source) != expected:
            raise RuntimeError('Independent fixture changed: '+name)
        (build / name).write_bytes(source.read_bytes())
    case = {'adapter': 0, 'boundary': 1, 'reset': 2, 'errors': 3, 'word-resets': 4}.get(args.action)
    if args.action == 'generated':
        top='tb_rsa_generated'
        qsf = root / 'Project/DE1/de1_soc_top.qsf'
        sources = [(qsf.parent / p).resolve() for p in re.findall(r'-name VERILOG_FILE "([^"]+)"', qsf.read_text())]
        # Original keygen receives real candidate and witness draws through the
        # shared RNG word service; there is no prime-test bypass or slot preload.
        corpus = root / 'Testing/Simulation/Key Generation/reference/expected_keys.json'
        key = {k:int(v,16) for k,v in json.loads(corpus.read_text())['results'][0]['key'].items()}
        values=[]
        for component in ['p','q']:
            for value in [key[component]]+[2]*5:
                values += [(value>>(32*i))&0xffffffff for i in reversed(range(32))]
        (build/'stimulus.hex').write_text(''.join(f'{v:08x}\n' for v in values))
    else:
        top='tb_rsa_adapter'
        keygen=root/'Source Code/Key Generation'
        sources=list((keygen/'IP').glob('*.v'))+[keygen/'rtl/arithmetic/keygen_pair_check.v']
        sources+=list((root/'Source Code/Asymmetric Module').glob('*.v'))
        sources+=[root/'Source Code/Execution Engine/execution_engine_rsa.v']
    sources+=[bench/(top+'.sv')]
    inputs={str(p.relative_to(root)):sha(p) for p in sources+[Path(__file__)]}
    record={'action':args.action,'simulator':'Verilator Generic','full_width':2048,
            'generated_slot':args.action=='generated','directed_correctness_not_fresh_search':True,
            'inputs':inputs,'fixture_origin':fixture_record,'commands':[],
            'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root).decode().strip()}
    def run(argv,label,deadline):
        start=time.monotonic();path=build/(label+'.log')
        with path.open('wb') as output:
            process=subprocess.Popen(argv,cwd=build,stdout=output,stderr=subprocess.STDOUT,start_new_session=True)
            try:
                process.wait(timeout=deadline)
            except BaseException:
                os.killpg(process.pid,signal.SIGKILL);process.wait();raise
            finally:
                record['commands'].append({'argv':argv,'deadline_seconds':deadline,
                    'elapsed_seconds':round(time.monotonic()-start,3),'returncode':process.returncode,
                    'transcript':path.name,'sha256':sha(path)})
        if process.returncode:
            raise RuntimeError(f'{label} failed: {path}')
        return path.read_text(errors='replace')
    try:
        record['version']=subprocess.check_output(['verilator','--version']).decode().strip()
        argv=['verilator','--cc','--exe','--main','--timing','--unroll-count','256','-Wno-fatal',
            '--top-module',top,'--Mdir','obj','-I'+str(root/'Source Code/IO Interface')]
        if case is not None:argv+=['-GTEST_CASE='+str(case)]
        run(argv+[str(p) for p in sources],'elaborate',300)
        run(['g++','-O1','-std=c++20','-pthread','-Iobj','-I/usr/share/verilator/include','-I/usr/share/verilator/include/vltstd']+
            [str(p.relative_to(build)) for p in (build/'obj').glob('*.cpp')]+
            ['/usr/share/verilator/include/'+name for name in ['verilated.cpp','verilated_timing.cpp','verilated_threads.cpp']]+
            ['-o','obj/test_rsa'],'compile',900)
        output=run(['./obj/test_rsa'],'result',3600)
        marker='RSA_GENERATED_PASS' if args.action=='generated' else f'RSA_ADAPTER_PASS case={case} backend=0'
        if marker not in output:raise RuntimeError('Missing explicit completion marker')
        record['pass_markers']=[line for line in output.splitlines() if marker in line]
        record['inputs_after']={str(p.relative_to(root)):sha(p) for p in sources+[Path(__file__)]}
        if inputs!=record['inputs_after']:raise RuntimeError('Input bytes changed during run')
        record['fixtures']={p.name:sha(p) for p in build.glob('*.hex')}
        print(record['pass_markers'][0],flush=True)
    finally:
        (build/'evidence.json').write_text(json.dumps(record,indent=2)+'\n')


if __name__=='__main__':main()
