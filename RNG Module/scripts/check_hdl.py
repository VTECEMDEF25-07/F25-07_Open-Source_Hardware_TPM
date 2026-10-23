"""Elaborate both physical entry points in Verilog-2001 mode (simulation model).
This checks wiring/language only, not FPGA placement or entropy quality.
"""
import hashlib,json,subprocess
from pathlib import Path
r=Path(__file__).resolve().parents[2];kg=r/'Key Generation'
files=list((r/'RNG Module/rtl').glob('*.v'))+list((r/'Integration/rtl').glob('*.v'))
files+=list((kg/'rtl').rglob('*.v'))+list((kg/'IP').glob('*.v'))
files+=[kg/'IP/third_party/picorv32/picorv32.v',kg/'demo/test_rng/keygen_test_source.v']
files+=[r/'RNG Module'/f for f in ['RNG.v','entropy_source.v','ring_osc.v']]
build=r/'Integration/build/lint';build.mkdir(parents=True,exist_ok=True)
for top in ['RNG','rng_keygen_physical']:
 p=subprocess.run(['verilator','--lint-only','--timing','--top-module',top,'--language','1364-2001','-Wno-fatal']+[str(f) for f in files],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=120)
 (build/(top+'.log')).write_bytes(p.stdout)
 if p.returncode:raise RuntimeError(p.stdout.decode(errors='replace'))
 print('PASS Verilog-2001 elaboration: '+top)
(build/'manifest.json').write_text(json.dumps({str(f.relative_to(r)):hashlib.sha256(f.read_bytes()).hexdigest() for f in files},indent=2))
