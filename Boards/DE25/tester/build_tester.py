"""Compile with an existing Windows-targeting GCC and official FTDI SDK; no USB."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

parser=argparse.ArgumentParser()
parser.add_argument('--compiler',type=Path,required=True)
parser.add_argument('--sdk',type=Path,required=True,help='Official Windows SDK release directory')
parser.add_argument('--driver',type=Path,required=True,help='Matching x64 ftd2xx.dll link input')
parser.add_argument('--output',type=Path,required=True)
parser.add_argument('--system-include',type=Path)
args=parser.parse_args()
source=Path(os.path.abspath(__file__)).with_name('testbench_safe.c')
build=Path(os.path.abspath(args.output))
build.mkdir(parents=True,exist_ok=False)
include=build/'include/FTDI';include.mkdir(parents=True)
for name,original in [('ftd2xx.h',args.sdk/'libftd2xx/ftd2xx.h'),
                      ('libMPSSE_spi.h',args.sdk/'include/libmpsse_spi.h')]:
    shutil.copyfile(original,include/name)
shutil.copyfile(args.sdk/'build/x64/DLL/libmpsse.dll',build/'libmpsse.dll')
command=[str(args.compiler),'-std=c11','-Wall','-Wextra','-D_WIN32_WINNT=0x0600','-I'+str(build/'include')]
if args.system_include:
    command.append('-I'+str(args.system_include))
command += [str(source),str(build/'libmpsse.dll'),str(args.driver),'-o',str(build/'tester.exe')]
inputs=[source,source.with_name('TpmTypes.h'),include/'ftd2xx.h',include/'libMPSSE_spi.h',build/'libmpsse.dll',args.driver]
digest=lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
hashes={str(path):digest(path) for path in inputs}
result=subprocess.run(command,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=120)
(build/'compile.log').write_bytes(result.stdout)
record={'command':command,'returncode':result.returncode,'inputs_sha256':hashes,'hardware_executed':False}
if result.returncode==0:
    assert hashes=={str(path):digest(path) for path in inputs},'Compile inputs changed'
    record['exe_sha256']=digest(build/'tester.exe')
(build/'build.json').write_text(json.dumps(record,indent=2)+'\n')
print(result.stdout.decode(errors='replace'))
raise SystemExit(result.returncode)
