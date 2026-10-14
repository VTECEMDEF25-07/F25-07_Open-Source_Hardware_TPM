# Filename: simulate_top.py
# Authors: Project contributors; see Git history.
# Date: 2026-10-13
# General Description: Isolated board/reset-boundary regression; run under Linux/WSL.
# AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

"""Isolated board/reset-boundary regression; run under Linux/WSL."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

p=argparse.ArgumentParser();p.add_argument('--build',type=Path,required=True);a=p.parse_args()
here=Path(__file__).resolve().parent;build=a.build.resolve();build.mkdir(parents=True,exist_ok=False)
obj=build/'obj';sources=[];hashes={}
for original in (here/'keygen_de25_top.v',here/'tests/tb_keygen_top_reset.sv'):
    data=original.read_bytes();copy=build/original.name;copy.write_bytes(data);sources.append(copy)
    hashes[original.name]=hashlib.sha256(data).hexdigest()
command=['verilator','--cc','--exe','--main','--timing','--top-module','tb_keygen_top_reset','--Mdir',str(obj),'-Wno-fatal','+1364-2001ext+v','+1800-2017ext+sv']+[str(s) for s in sources]
with (build/'elaborate.log').open('w') as log:subprocess.run(command,cwd=build,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=60)
combined=obj/'combined.cpp';combined.write_text(''.join('#include "'+s.name+'"\n' for s in sorted(obj.glob('*.cpp'))))
vr=Path('/usr/share/verilator/include');binary=obj/'Vtb_keygen_top_reset'
command=['g++','-O0','-std=c++20','-pthread','-I'+str(obj),'-I'+str(vr),'-I'+str(vr/'vltstd'),str(combined)]
command += [str(vr/s) for s in ('verilated.cpp','verilated_timing.cpp','verilated_threads.cpp')]+['-o',str(binary)]
with (build/'compile.log').open('w') as log:subprocess.run(command,cwd=build,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=120)
with (build/'result.log').open('w') as log:subprocess.run([str(binary)],cwd=build,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=30)
result=(build/'result.log').read_text()
if 'PASS TOP_RESET' not in result or '%Error' in result:raise RuntimeError(result)
(build/'manifest.json').write_text(json.dumps({'source_sha256':hashes,'status':'PASS'},indent=2)+'\n')
print(result)
