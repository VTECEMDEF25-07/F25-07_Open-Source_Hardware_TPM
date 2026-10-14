# Filename: simulate_real.py
# Authors: Project contributors; see Git history.
# Date: 2026-10-13
# General Description: Real-core SPI regression under Linux/WSL; no behavioral keygen replacement.
# AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

"""Real-core SPI regression under Linux/WSL; no behavioral keygen replacement."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
p=argparse.ArgumentParser()
p.add_argument('--core-root',type=Path,required=True)
p.add_argument('--build',type=Path,required=True)
p.add_argument('--softcore',action='store_true')
a=p.parse_args();here=Path(__file__).resolve().parent;core=a.core_root.resolve();build=a.build.resolve()
obj=build/'obj';snapshot=build/'sources';snapshot.mkdir(parents=True,exist_ok=True)
originals=sorted((core/'rtl').rglob('*.v'))+sorted(s for s in (core/'IP').rglob('*.v') if 'tests' not in s.parts)
originals += [here/'keygen_demo_spi.v',here/'keygen_demo_system.v',here.parent/'test_rng/keygen_test_source.v',here/'tests/tb_keygen_demo_real.sv']
sources=[];hashes={}
for index,source in enumerate(originals):
    target=snapshot/(str(index).zfill(3)+'_'+source.name);shutil.copyfile(source,target)
    hashes[str(source)]=hashlib.sha256(target.read_bytes()).hexdigest();sources.append(target)
firmware=core/'build/full/rsa_control.hex'
if not firmware.exists():raise FileNotFoundError('Build real firmware first; no placeholder allowed')
shutil.copyfile(firmware,build/'rsa_control.hex')
# Independent standard-library oracle, without importing the project's generator.
digest=hashlib.sha256(b'KEYGEN-TEST-v1\0'+(1).to_bytes(32,'big')+bytes(8)).digest()
expected=build/'aes_expected.hex';expected.write_text(''.join(digest[i:i+4].hex()+'\n' for i in range(0,32,4)))
manifest={'controller':'softcore' if a.softcore else 'rtl','source_sha256':hashes,'firmware_sha256':hashlib.sha256(firmware.read_bytes()).hexdigest(),'oracle':'Python hashlib, seed1 counter0','status':'running'}
(build/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
command=['verilator','--cc','--exe','--main','--timing','--top-module','tb_keygen_demo_real','--Mdir',str(obj),'-Wno-fatal','+1364-2001ext+v','+1800-2017ext+sv']
if a.softcore:command+=['+define+TEST_SOFTCORE']
command += [str(s) for s in sources]
with (build/'elaborate.log').open('w') as log:subprocess.run(command,cwd=build,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=180)
combined=obj/'combined.cpp';combined.write_text(''.join('#include "'+s.name+'"\n' for s in sorted(obj.glob('*.cpp')) if s!=combined))
vr=Path('/usr/share/verilator/include');binary=obj/'Vtb_keygen_demo_real'
command=['g++','-O0','-std=c++20','-pthread','-I'+str(obj),'-I'+str(vr),'-I'+str(vr/'vltstd'),str(combined)]
command += [str(vr/s) for s in ('verilated.cpp','verilated_timing.cpp','verilated_threads.cpp')]+['-o',str(binary)]
with (build/'compile.log').open('w') as log:subprocess.run(command,cwd=build,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=600)
with (build/'result.log').open('w') as log:subprocess.run([str(binary),'+EXPECTED='+str(expected)],cwd=build,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=300)
result=(build/'result.log').read_text()
if 'PASS REAL_SPI_CORE' not in result or '%Error' in result:raise RuntimeError(result)
manifest['status']='PASS';(build/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');print(result)
