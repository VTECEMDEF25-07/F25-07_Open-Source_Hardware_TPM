"""Validate protected exponent handoff with independent full-width values.

Run in WSL with python3. Generic numerical test; native vendor runs separately.
"""
import hashlib,json,math,os,signal,subprocess,time
from pathlib import Path

root=Path(__file__).resolve().parents[3]
build=root/'build/rsa-protected-d'
build.mkdir(parents=True,exist_ok=True)
keygen=root/'Source Code/Key Generation'
sources=list((keygen/'IP').glob('*.v'))+[keygen/'rtl/arithmetic/keygen_pair_check.v',Path(__file__).with_name('tb_protected_d.sv')]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
record={'inputs':{str(p.relative_to(root)):sha(p) for p in sources+[Path(__file__)]},'full_width':2048,'backend':'Generic','commands':[]}
corpus=root/'Testing/Simulation/Key Generation/reference/expected_keys.json'
key={k:int(v,16) for k,v in json.loads(corpus.read_text())['results'][0]['key'].items()}
d=pow(65537,-1,math.lcm(key['p']-1,key['q']-1))
assert d==key['d']
(build/'protected_d.hex').write_text(f"{key['n']:0512x}\n{d:0512x}\n")
(build/'slot.hex').write_bytes((root/'build/rsa-adapter/slot.hex').read_bytes())
record['fixtures']={p.name:sha(p) for p in build.glob('*.hex')}
def run(argv,label,deadline):
    path=build/(label+'.log');start=time.monotonic()
    with path.open('wb') as output:
        proc=subprocess.Popen(argv,cwd=build,stdout=output,stderr=subprocess.STDOUT,start_new_session=True)
        try:proc.wait(timeout=deadline)
        except BaseException:os.killpg(proc.pid,signal.SIGKILL);proc.wait();raise
        finally:record['commands'].append({'argv':argv,'deadline_seconds':deadline,'elapsed_seconds':round(time.monotonic()-start,3),'returncode':proc.returncode,'sha256':sha(path)})
    if proc.returncode:raise RuntimeError(str(path))
    return path.read_text()
try:
    record['version']=subprocess.check_output(['verilator','--version']).decode().strip()
    run(['verilator','--cc','--exe','--main','--timing','--unroll-count','1','-Wno-fatal','--top-module','tb_protected_d','--Mdir','obj']+[str(p) for p in sources],'elaborate',300)
    run(['g++','-O1','-std=c++20','-pthread','-Iobj','-I/usr/share/verilator/include','-I/usr/share/verilator/include/vltstd']+
        [str(p.relative_to(build)) for p in (build/'obj').glob('*.cpp')]+
        ['/usr/share/verilator/include/'+p for p in ['verilated.cpp','verilated_timing.cpp','verilated_threads.cpp']]+['-o','obj/test_d'],'compile',900)
    output=run(['./obj/test_d'],'result',1800)
    record['pass_markers']=[line for line in output.splitlines() if 'RSA_PROTECTED_D_PASS' in line]
    assert record['pass_markers'],'Missing explicit completion marker'
    assert record['inputs']=={str(p.relative_to(root)):sha(p) for p in sources+[Path(__file__)]},'Inputs changed during run'
    print(record['pass_markers'][0],flush=True)
finally:(build/'evidence.json').write_text(json.dumps(record,indent=2)+'\n')
