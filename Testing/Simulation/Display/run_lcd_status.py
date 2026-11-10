"""Offline status capture test using Verilator, no FPGA or Questa license."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--build', required=True, type=Path)
a = p.parse_args()
root = Path(__file__).resolve().parents[3]
sources = [root/'Source Code/Display/demo_lcd_status.v', Path(__file__).with_name('tb_demo_lcd_status.sv')]
out = a.build.resolve(); out.mkdir(parents=True, exist_ok=True)
hashes = {str(x.relative_to(root)): hashlib.sha256(x.read_bytes()).hexdigest() for x in sources}
# Keep make command paths free of spaces even when the class root has spaces.
for x in sources: (out/x.name).write_bytes(x.read_bytes())
commands = []
def run(name,cmd):
    commands.append(cmd)
    r = subprocess.run(cmd,cwd=out,capture_output=True,text=True,timeout=180)
    log = r.stdout+r.stderr; (out/(name+'.log')).write_text(log)
    if r.returncode or 'FAIL ' in log:
        raise SystemExit(log)
    return log
run('verilate',['verilator','--cc','--exe','--main','--timing','--top-module','tb_demo_lcd_status',
                '-Wno-fatal','--Mdir','obj',*[x.name for x in sources]])
version = subprocess.check_output(['verilator','-V'],text=True)
inc = Path(re.search(r'VERILATOR_ROOT\s*=\s*(\S+)',version).group(1))/'include'
# GNU Make refuses a directory with spaces. Compile the generated model directly
# so all build products remain under the authorized AI/tmp class directory.
run('compile',['g++','-std=c++20','-O0','-pthread','-DVL_TIME_CONTEXT',
               '-I'+str(inc),'-I'+str(inc/'vltstd'),'-Iobj',
               *[str(x.relative_to(out)) for x in sorted((out/'obj').glob('*.cpp'))],
               str(inc/'verilated.cpp'),str(inc/'verilated_timing.cpp'),str(inc/'verilated_threads.cpp'),
               '-o','status_test'])
log=run('run',[str(out/'status_test')])
match = re.search(r'PASS LCD_STATUS checks=\d+ transitions=\d+ clock=50MHz', log)
if not match:
    raise SystemExit('missing status completion marker')
assert hashes == {str(x.relative_to(root)): hashlib.sha256(x.read_bytes()).hexdigest() for x in sources}
(out/'manifest.json').write_text(json.dumps({'status':'PASS','result':match.group(),
    'source_sha256':hashes,'commands':commands},indent=2)+'\n')
print(match.group())
