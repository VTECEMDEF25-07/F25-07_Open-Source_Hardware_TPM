#!/usr/bin/env python3
"""RSA2048 worker reference/control tests. Test fixtures are never customer keys."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import subprocess
import time


def run(command, cwd, log, timeout=1800):
    start=time.monotonic()
    with log.open('w',encoding='utf-8') as output:
        result=subprocess.run(command,cwd=cwd,stdout=output,stderr=subprocess.STDOUT,timeout=timeout)
    data=log.read_text(errors='replace')
    elapsed=time.monotonic()-start
    print(f'{log.name}: exit={result.returncode} seconds={elapsed:.3f}',flush=True)
    if result.returncode or '%Error' in data or 'FAIL:' in data:
        raise RuntimeError(data[-7000:])
    return data,elapsed


def fixtures(root,build,selected=None):
    corpus=root/'Testing/Simulation/Key Generation/reference/expected_keys.json'
    keys=json.loads(corpus.read_text())['results'][:2]
    rows=[]
    for ki,entry in enumerate(keys):
        key={name:int(value,16) for name,value in entry['key'].items()}
        n,e,d,p,q=(key[name] for name in ('n','e','d','p','q'))
        assert n.bit_length()==2048 and p*q==n and e==65537
        assert d==pow(e,-1,math.lcm(p-1,q-1))
        messages=([b'Lenovo: actual FPGA RSA private decrypt',
                   'Leading zero \x00 and UTF-8: λ'.encode(),bytes(range(240))]
                  if ki==0 else [b'Second independent RSA key/context'])
        values=[]
        for payload in messages:
            assert len(payload)<=240
            block=b'\0DE25'+len(payload).to_bytes(2,'big')+payload+bytes(249-len(payload))
            assert len(block)==256
            values.append(int.from_bytes(block,'big'))
        if ki==0:values += [0,n-1]
        for value in values:
            assert 0<=value<n
            cipher=pow(value,e,n)
            expected=pow(cipher,d,n)
            assert expected==value
            rows.append((n,d,cipher,expected))
    if selected is not None:
        if len(selected)<2 or len(set(selected))!=len(selected) or any(i<0 or i>=len(rows) for i in selected):
            raise ValueError('Select at least two distinct in-range vector indexes')
        rows=[rows[i] for i in selected]
    if len({row[0] for row in rows})!=2:
        raise ValueError('Private-worker regression must cover both fixture keys')
    (build/'private_vectors.txt').write_text(str(len(rows))+'\n'+''.join(
        ' '.join(f'{x:0512x}' for x in row)+'\n' for row in rows),encoding='ascii')
    (build/'oracle.json').write_text(json.dumps({'test_only':True,'rsa_bits':2048,
        'keys':2,'cases':len(rows),'selected_source_indexes':selected,
        'oracle':'Python public/private pow and n=p*q/canonical inverse',
        'source_corpus_sha256':hashlib.sha256(corpus.read_bytes()).hexdigest()},indent=2)+'\n')
    return corpus,len(rows)


def compile_cpp(obj,build,binary,log):
    version=subprocess.check_output(['verilator','-V'],text=True)
    root=next(line.split('=',1)[1].strip() for line in version.splitlines()
              if line.strip().startswith('VERILATOR_ROOT') and line.split('=',1)[1].strip())
    inc=Path(root)/'include'
    run(['g++','-O1','-std=c++20','-pthread','-I'+str(obj),'-I'+str(inc),'-I'+str(inc/'vltstd'),
         *(str(p) for p in sorted(obj.glob('*.cpp'))),
         *(str(inc/name) for name in ('verilated.cpp','verilated_timing.cpp','verilated_threads.cpp')),
         '-o',str(binary)],build,log)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--build-dir',type=Path,required=True)
    parser.add_argument('--math-source-root',type=Path)
    parser.add_argument('--compact',action='store_true')
    parser.add_argument('--suite',choices=('control','real','all'),default='all')
    parser.add_argument('--vector-indices',help='Focused comma-separated original vector indexes; default all six')
    args=parser.parse_args()
    root=Path(__file__).resolve().parents[4]
    kg=(args.math_source_root or root/'Source Code/Key Generation').resolve()
    build=args.build_dir.resolve();build.mkdir(parents=True,exist_ok=True)
    bench=root/'Testing/Simulation/Asymmetric Module/tb_demo_rsa_private_worker.sv'
    worker=root/'Source Code/Asymmetric Module/demo_rsa_private_worker.v'
    sources=[worker,kg/'rtl/arithmetic/keygen_math.v',*sorted((kg/'IP').glob('*.v')),bench]
    selected=[int(x) for x in args.vector_indices.split(',')] if args.vector_indices else None
    corpus,count=fixtures(root,build,selected)
    inputs=sources+[Path(__file__).resolve(),corpus]
    before={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}
    variants=[]
    if args.suite in ('control','all'):
        variants += [('control',1,9000000000,0),('timeout',1,20000,1)]
    if args.suite in ('real','all'):
        variants += [('real_math64',0,9000000000,0)]
    results=[]
    for name,mock,deadline,mode in variants:
        obj=build/('obj_'+name)
        command=['verilator','--cc','--exe','--main','--timing','-Wno-fatal',
                 '--top-module','tb_demo_rsa_private_worker','--Mdir',obj.name,
                 '-GMOCK='+str(mock),'-GDEADLINE='+str(deadline)]
        if args.compact:command+=['-DTEST_COMPACT_MATH']
        run(command+[str(p) for p in sources],build,build/(name+'_elaborate.log'))
        binary=obj/'Vtb_demo_rsa_private_worker'
        compile_cpp(obj,build,binary,build/(name+'_compile.log'))
        output,elapsed=run([str(binary),'+mode='+str(mode)],build,build/(name+'_result.log'))
        marker=(f'ALL RSA PRIVATE WORKER TESTS PASSED mock={mock}' if mode==0 else
                'RSA_PRIVATE_TIMEOUT_CONTROL_PASS mock=1')
        if marker not in output:raise RuntimeError(output[-7000:])
        print(output[-3500:],flush=True)
        results.append({'variant':name,'crypto_claim':not bool(mock),'seconds':elapsed,
                        'summary':next(line for line in output.splitlines() if marker in line)})
    assert before=={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs},'Source changed during run'
    (build/'results.json').write_text(json.dumps({'status':'PASS','physical':False,
        'width':2048,'key_count':2,'independent_vectors':count,'compact':args.compact,
        'source_sha256':before,'results':results},indent=2)+'\n')
    print('PASS RSA private worker regression; simulation only, no on-board keygen claim',flush=True)


if __name__=='__main__':main()
