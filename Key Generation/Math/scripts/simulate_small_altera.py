# Filename: simulate_small_altera.py
# Authors: Project contributors; see Git history.
# Date: 2026-10-13
# General Description: Genuine Altera small-domain math regression; coordinate the single Questa license.
# AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

"""Genuine Altera small-domain math regression; coordinate the single Questa license."""
import argparse,subprocess,json,hashlib,sys,time
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('build',type=Path);p.add_argument('--source-root',type=Path,required=True);p.add_argument('--compile-only',action='store_true');p.add_argument('--questa-bin',type=Path,default=Path('C:/intelFPGA_lite/24.1std/questa_fse/win64'));p.add_argument('--altera-models',type=Path,default=Path('C:/intelFPGA_lite/24.1std/quartus/eda/sim_lib'));a=p.parse_args()
root=a.source_root.resolve();here=Path(__file__).resolve().parents[1];build=a.build.resolve();build.mkdir(parents=True,exist_ok=True)
subprocess.run([sys.executable,str(here/'scripts/generate_small_vectors.py'),str(build/'small_vectors.txt')],check=True)
sources=list((root/'IP').glob('keygen_*.v'))+[root/'rtl/arithmetic/keygen_math.v',here/'tests/tb_keygen_math_small.sv']
models=[a.altera_models/name for name in ['220model.v','altera_mf.v']]
inputs=sources+models+[Path(__file__).resolve(),here/'scripts/generate_small_vectors.py',build/'small_vectors.txt',build/'small_vectors.hex']
def hashes():return {str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}
manifest=hashes();(build/'inputs.json').write_text(json.dumps(manifest,indent=2))
def run(tool,args,name):
 with (build/name).open('w') as log:subprocess.run([str(a.questa_bin/(tool+'.exe'))]+args,cwd=build,stdout=log,stderr=subprocess.STDOUT,check=True)
for lib in ['work','vendor']:
 if not (build/lib).exists():run('vlib',[lib],lib+'.log')
run('vlog',['-work','vendor']+list(map(str,models)),'vendor_compile.log')
run('vlog',['-vlog01compat','+define+KEYGEN_ALTERA']+[str(p) for p in sources if p.suffix=='.v'],'rtl_compile.log')
run('vlog',['-sv','+define+KEYGEN_ALTERA','+define+KEYGEN_MATH_SMALL',str(sources[-1])],'test_compile.log')
assert hashes()==manifest
print('PASS actual-Altera small-domain source compile',flush=True)
if a.compile_only:raise SystemExit
start=time.monotonic()
run('vsim',['-c','-L','vendor','work.tb_keygen_math_small','-do','onerror {quit -code 1}; onbreak {quit -code 1}; run -all; quit -code 0'],'result.log')
assert hashes()==manifest,'Source changed during simulation'
text=(build/'result.log').read_text();assert 'PASS SMALL_MATH cases=10771 carry_borrow_shift=3 full_scrub=4096' in text
(build/'results.json').write_text(json.dumps({'status':'PASS','seconds':time.monotonic()-start,'log_sha256':hashlib.sha256((build/'result.log').read_bytes()).hexdigest()},indent=2))
print(text[-1500:])
