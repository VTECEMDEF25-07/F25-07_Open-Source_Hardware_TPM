"""Reproducible bounded Verilator regressions; outputs confined to ignored build/.
Run with Linux/WSL Python. HDL sources compiled as Verilog-2001, benches as SV.
"""
import argparse, hashlib, json, subprocess, shutil, sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
BUILD=ROOT/'Integration/build'

def sha(b): return hashlib.sha256(b).digest()
def df(b): return (sha(b'\x01'+(440).to_bytes(4,'big')+b)+sha(b'\x02'+(440).to_bytes(4,'big')+b))[:55]
class Reference:
    def __init__(self,seed): self.v=int.from_bytes(df(seed),'big'); self.reset_c()
    def reset_c(self): self.c=int.from_bytes(df(b'\0'+self.v.to_bytes(55,'big')),'big'); self.counter=1
    def reseed(self,entropy): self.v=int.from_bytes(df(b'\1'+self.v.to_bytes(55,'big')+entropy),'big'); self.reset_c()
    def generate(self):
        value=self.v.to_bytes(55,'big'); result=sha(value)
        self.v=(self.v+int.from_bytes(sha(b'\3'+value),'big')+self.c+self.counter)%(1<<440)
        self.counter+=1
        return result

def vectors():
    BUILD.mkdir(parents=True,exist_ok=True)
    seeds=[bytes(range(48)),bytes([0xff])*48,bytes(48),sha(b'seed')+sha(b'nonce')[:16]]
    expected=[]
    for seed in seeds:
        ref=Reference(seed)
        expected.extend(ref.generate().hex() for _ in range(3))
        ref.reseed(seed[:32][::-1]); expected.extend(ref.generate().hex() for _ in range(2))
    (BUILD/'seeds.hex').write_text('\n'.join(s.hex() for s in seeds)+'\n')
    (BUILD/'drbg.hex').write_text('\n'.join(expected)+'\n')
    messages=[b'',b'abc',bytes(range(55)),bytes(range(56)),bytes(range(64)),bytes(range(111))]
    (BUILD/'messages.hex').write_text('\n'.join(m.ljust(111,b'\0').hex() for m in messages)+'\n')
    (BUILD/'digests.hex').write_text('\n'.join(sha(m).hex() for m in messages)+'\n')
    fixture=sha(b'KEYGEN-TEST-v1\0'+(1).to_bytes(32,'big')+bytes(8))
    (BUILD/'fixture.hex').write_text('\n'.join(fixture[i:i+4].hex() for i in range(0,32,4))+'\n')
    # Existing provider domain is 15 bytes (the declared 120-bit constant).
    row=json.loads((ROOT/'Key Generation/reference/expected_keys.json').read_text())['results'][19]
    words=[]
    for component,width in [('n',256),('e',4),('p',128),('q',128)]:
        value=int(row['key'][component],16).to_bytes(width,'big')
        words.extend(value[i:i+4].hex() for i in range(0,width,4))
    (BUILD/'rsa.hex').write_text('\n'.join(words)+'\n')
    conditioned=sha(bytes([0x55])*96)
    second=sha(bytes([0x33])*96)
    (BUILD/'entropy.hex').write_text((conditioned+conditioned[:16]).hex()+'\n'+(second+second[:16]).hex()+'\n')

def fresh_rsa_vectors():
    sys.path.insert(0,str(ROOT/'Key Generation/reference'))
    from keygen_reference import generate_key
    from key_checker import check_key
    provider=Reference(bytes(range(48)))
    pending=[];count=0
    def word():
        nonlocal count
        if not pending:
            block=provider.generate();pending.extend(int.from_bytes(block[i:i+4],'big') for i in range(0,32,4))
        count+=1
        return pending.pop(0)
    key=generate_key(word);check_key(key)
    words=[]
    for name,width in [('n',256),('e',4),('p',128),('q',128)]:
        value=key[name].to_bytes(width,'big');words.extend(value[i:i+4].hex() for i in range(0,width,4))
    (BUILD/'rsa_fresh.hex').write_text('\n'.join(words)+'\n')
    (BUILD/'rsa_fresh_reference.json').write_text(json.dumps({'words':count,'key':{k:hex(v) for k,v in key.items()},'test_seed':bytes(range(48)).hex()},indent=2))
    print(f'Independent fresh-DRBG RSA reference: {count} words',flush=True)

def run(top,extra=(),softcore=False,timeout=180):
    build=BUILD/(top+('_fresh' if '+define+FRESH' in extra else '')+('_rsa' if '+define+RSA_TEST' in extra else '')+('_watchdog' if '+define+WATCHDOG_TEST' in extra else '')+('_softcore' if softcore else ''))
    build.mkdir(parents=True,exist_ok=True)
    for f in BUILD.glob('*.hex'): shutil.copyfile(f,build/f.name)
    kg=ROOT/'Key Generation'
    if softcore:
        firmware=kg/'build/full/rsa_control.hex'
        if not firmware.exists(): raise RuntimeError('Build the reviewed RSA firmware first: Key Generation/scripts/softcore/build_rsa.py')
        shutil.copyfile(firmware,build/'rsa_control.hex')
    sources=list((ROOT/'RNG Module/rtl').glob('*.v'))+list((ROOT/'Integration/rtl').glob('*.v'))
    sources+=list((kg/'rtl').rglob('*.v'))+list((kg/'IP').glob('*.v'))
    sources += [ROOT/'RNG Module/entropy_source.v',ROOT/'RNG Module/ring_osc.v',ROOT/'RNG Module/RNG.v']
    sources += [kg/'IP/third_party/picorv32/picorv32.v',kg/'demo/test_rng/keygen_test_source.v']
    sources += [ROOT/'Integration/tests'/f'{top}.sv']
    input_hashes={str(f.relative_to(ROOT)):hashlib.sha256(f.read_bytes()).hexdigest() for f in sources}
    input_hashes[str(Path(__file__).relative_to(ROOT))]=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    fixtures={f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in build.glob('*.hex')}
    obj=build/'obj'
    command=['verilator','--cc','--exe','--main','--timing','--top-module',top,'--Mdir',str(obj),'-Wno-fatal','+1364-2001ext+v','+1800-2017ext+sv']
    if softcore: command+=['+define+KEYGEN_SOFTCORE']
    command += list(extra)+[str(s) for s in sources]
    def execute(cmd,name,limit):
        p=subprocess.run(cmd,cwd=build,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=limit)
        (build/name).write_bytes(p.stdout)
        if p.returncode: raise RuntimeError(f'{name}:\n'+p.stdout.decode(errors='replace')[-6000:])
        return p.stdout.decode(errors='replace')
    execute(command,'elaborate.log',120)
    inc=Path('/usr/share/verilator/include')
    binary=obj/f'V{top}'
    execute(['g++','-O2','-std=c++20','-pthread','-I'+str(obj),'-I'+str(inc),'-I'+str(inc/'vltstd')]+[str(f) for f in sorted(obj.glob('*.cpp'))]+[str(inc/f) for f in ['verilated.cpp','verilated_timing.cpp','verilated_threads.cpp']]+['-o',str(binary)],'compile.log',300)
    output=execute([str(binary)],'result.log',timeout)
    if 'PASS '+top not in output: raise RuntimeError(output)
    (build/'manifest.json').write_text(json.dumps({'sources':input_hashes,'fixture_hashes':fixtures,'defines':list(extra),'softcore':softcore,'simulator':subprocess.check_output(['verilator','--version'],text=True).strip(),'result':output},indent=2))
    print(output,flush=True)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--suite',default='tb_rng_crypto');p.add_argument('--softcore',action='store_true');p.add_argument('--fresh',action='store_true');p.add_argument('--rsa',action='store_true');p.add_argument('--watchdog',action='store_true');a=p.parse_args()
    vectors()
    if a.fresh and a.rsa: fresh_rsa_vectors()
    run(a.suite,extra=(['+define+FRESH'] if a.fresh else [])+(['+define+RSA_TEST'] if a.rsa else [])+(['+define+WATCHDOG_TEST'] if a.watchdog else []),softcore=a.softcore,timeout=1800 if a.rsa else 180)
