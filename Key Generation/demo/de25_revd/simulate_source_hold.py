# Filename: simulate_source_hold.py
# Authors: Project contributors; see Git history.
# Date: 2026-10-13
# General Description: Focused actual-SPI/SHA hold regression; controllable test core, not RSA proof.
# AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

"""Focused actual-SPI/SHA hold regression; controllable test core, not RSA proof.

Run under Linux/WSL with --build pointing to an ignored build or AI/tmp path.
Optional --system accepts a preserved baseline for negative regression testing.
"""
import argparse,hashlib,json,subprocess
from pathlib import Path

def validate_result(returncode, output, before, after):
    """Reject incomplete evidence even when a simulator incorrectly exits zero."""
    if before != after:
        raise RuntimeError("source changed during simulation")
    if returncode != 0:
        raise RuntimeError(f"simulation exited with status {returncode}")
    if "PASS SOURCE_HOLD" not in output or "%Error" in output:
        raise RuntimeError("simulation lacks a clean PASS SOURCE_HOLD marker")


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[2]);p.add_argument('--system',type=Path);p.add_argument('--build',type=Path,required=True);a=p.parse_args()
    if a.system is None:a.system=a.root/'demo/de25_revd/keygen_demo_system.v'
    here=Path(__file__).resolve().parent;b=a.build.resolve();b.mkdir(parents=True,exist_ok=True)
    model=(a.root/'demo/de25_revd/tests/keygen_core_model.sv').read_text()
    for anchor in ('reg [2:0] state_reg=0;', 'assign generation_ready_o=state_reg==1;', '1: if(generation_valid_i) begin'):
        if model.count(anchor)!=1:raise RuntimeError('Test model changed: inspect readiness hook before use')
    model=model.replace('reg [2:0] state_reg=0;', 'reg allow_ready=0;\n    reg [2:0] state_reg=0;')
    model=model.replace('assign generation_ready_o=state_reg==1;', 'assign generation_ready_o=state_reg==1 && allow_ready;')
    model=model.replace('1: if(generation_valid_i) begin', '1: if(generation_valid_i && generation_ready_o) begin')
    (b/'core_model.sv').write_text(model)
    src=[a.system,a.root/'demo/de25_revd/keygen_demo_spi.v',a.root/'demo/test_rng/keygen_test_source.v',here/'tests/tb_source_hold.sv',b/'core_model.sv']
    hashes={str(s):hashlib.sha256(s.read_bytes()).hexdigest() for s in src}
    digest=hashlib.sha256(b'KEYGEN-TEST-v1\0'+(1).to_bytes(32,'big')+bytes(8)).digest();expected=b/'expected.hex';expected.write_text(''.join(digest[i:i+4].hex()+'\n' for i in range(0,32,4)))
    obj=b/'obj';cmd=['verilator','--cc','--exe','--main','--timing','--top-module','tb_source_hold','--Mdir',str(obj),'-Wno-fatal','+1364-2001ext+v','+1800-2017ext+sv']+[str(s.resolve()) for s in src]
    r=subprocess.run(cmd,capture_output=True,text=True,timeout=180);(b/'build.log').write_text(r.stdout+r.stderr);r.check_returncode()
    combined=obj/'combined.cpp';combined.write_text(''.join('#include "'+f.name+'"\n' for f in sorted(obj.glob('*.cpp')) if f!=combined))
    vr=Path('/usr/share/verilator/include')
    cc=['g++','-O0','-std=c++20','-pthread','-I'+str(obj),'-I'+str(vr),'-I'+str(vr/'vltstd'),str(combined)]+[str(vr/n) for n in ('verilated.cpp','verilated_timing.cpp','verilated_threads.cpp')]+['-o',str(obj/'Vtb_source_hold')]
    r=subprocess.run(cc,capture_output=True,text=True,timeout=180);(b/'compile.log').write_text(r.stdout+r.stderr);r.check_returncode()
    r=subprocess.run([str(obj/'Vtb_source_hold'),'+EXPECTED='+str(expected)],capture_output=True,text=True,timeout=30);(b/'result.log').write_text(r.stdout+r.stderr)
    after={str(s):hashlib.sha256(s.read_bytes()).hexdigest() for s in src}
    error=None
    try: validate_result(r.returncode,r.stdout+r.stderr,hashes,after)
    except RuntimeError as failure: error=str(failure)
    (b/'evidence.json').write_text(json.dumps({'inputs':hashes,'returncode':r.returncode,'pass':error is None,'error':error,'scope':'Actual SPI and SHA source, controllable test model core; not RSA verification'},indent=2)+'\n')
    print(r.stdout+r.stderr)
    if error is not None: raise RuntimeError(error)


if __name__ == "__main__":
    main()
