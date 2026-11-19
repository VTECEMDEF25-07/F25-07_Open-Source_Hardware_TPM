"""Generic exact private retry after failed derivation, without system reset."""
import hashlib,json,os,signal,subprocess,time
from pathlib import Path

root=Path(__file__).resolve().parents[3]
build=root/'build/rsa-retry';build.mkdir(parents=True,exist_ok=True)
keygen=root/'Source Code/Key Generation'
sources=list((keygen/'IP').glob('*.v'))+[keygen/'rtl/arithmetic/keygen_pair_check.v']
sources+=list((root/'Source Code/Asymmetric Module').glob('*.v'))
sources+=[root/'Source Code/Execution Engine/execution_engine_rsa.v',Path(__file__).with_name('tb_rsa_retry.sv')]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
record={'inputs':{str(p.relative_to(root)):sha(p) for p in sources+[Path(__file__)]},'full_width':2048,'backend':'Generic','commands':[]}
prepared=json.loads((root/'build/rsa-adapter/prepare.json').read_text())
record['fixture_origin']=prepared
for name,expected in prepared['fixtures'].items():
    source=root/'build/rsa-adapter'/name
    assert sha(source)==expected,'Independent fixture changed'
    (build/name).write_bytes(source.read_bytes())
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
    run(['verilator','--cc','--exe','--main','--timing','--unroll-count','1','-Wno-fatal','--top-module','tb_rsa_retry','--Mdir','obj']+[str(p) for p in sources],'elaborate',300)
    run(['g++','-O1','-std=c++20','-pthread','-Iobj','-I/usr/share/verilator/include','-I/usr/share/verilator/include/vltstd']+
        [str(p.relative_to(build)) for p in (build/'obj').glob('*.cpp')]+
        ['/usr/share/verilator/include/'+p for p in ['verilated.cpp','verilated_timing.cpp','verilated_threads.cpp']]+['-o','obj/test_retry'],'compile',900)
    output=run(['./obj/test_retry'],'result',1800)
    record['pass_markers']=[line for line in output.splitlines() if 'RSA_NO_RESET_PRIVATE_RETRY_PASS' in line]
    assert record['pass_markers'],'Missing explicit completion marker'
    assert record['inputs']=={str(p.relative_to(root)):sha(p) for p in sources+[Path(__file__)]},'Inputs changed during run'
    print(record['pass_markers'][0],flush=True)
finally:(build/'evidence.json').write_text(json.dumps(record,indent=2)+'\n')
