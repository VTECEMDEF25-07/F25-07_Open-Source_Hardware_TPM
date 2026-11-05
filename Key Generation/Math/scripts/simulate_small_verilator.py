# Filename: simulate_small_verilator.py
# Authors: Project contributors; see Git history.
# Date: 2026-10-13
# General Description: Run actual math RTL with exhaustive small-input vectors, in Linux/WSL.
# AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

"""Run actual math RTL with exhaustive small-input vectors, in Linux/WSL."""
import argparse,subprocess,json,hashlib
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('build',type=Path);p.add_argument('--source-root',type=Path,required=True);a=p.parse_args()
root=a.source_root.resolve();here=Path(__file__).resolve().parents[1];build=a.build.resolve();obj=build/'obj';obj.mkdir(parents=True,exist_ok=True)
subprocess.run(['python3',str(here/'scripts/generate_small_vectors.py'),str(build/'small_vectors.txt')],check=True)
sources=list((root/'IP').glob('keygen_*.v'))+[root/'rtl/arithmetic/keygen_math.v',here/'tests/tb_keygen_math_small.sv']
inputs=sources+[Path(__file__).resolve(),here/'scripts/generate_small_vectors.py',build/'small_vectors.txt',build/'small_vectors.hex']
def hashes():return {str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}
manifest=hashes();(build/'inputs.json').write_text(json.dumps(manifest,indent=2))
with (build/'build.log').open('w') as log:
 subprocess.run(['verilator','--cc','--exe','--main','--timing','--top-module','tb_keygen_math_small','--Mdir',str(obj),'-DKEYGEN_MATH_SMALL','-Wno-fatal']+list(map(str,sources)),stdout=log,stderr=subprocess.STDOUT,check=True)
 vr=Path('/usr/share/verilator/include')
 subprocess.run(['g++','-O1','-std=c++20','-pthread','-I'+str(obj),'-I'+str(vr),'-I'+str(vr/'vltstd')]+list(map(str,obj.glob('*.cpp')))+[str(vr/s) for s in ['verilated.cpp','verilated_timing.cpp','verilated_threads.cpp']]+['-o',str(obj/'run')],stdout=log,stderr=subprocess.STDOUT,check=True)
with (build/'result.log').open('w') as log:subprocess.run([str(obj/'run')],cwd=build,stdout=log,stderr=subprocess.STDOUT,check=True)
assert hashes()==manifest,'Source changed during simulation'
text=(build/'result.log').read_text();assert 'PASS SMALL_MATH' in text
print(text[-1200:])
