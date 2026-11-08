"""Elaborate actual board sources and enforce synthesis-only rejection paths.

Author: Aaron Grossman; Codex assisted with coding and verification.
No programming, fitting or hardware access. Outputs stay in --build.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

p=argparse.ArgumentParser()
p.add_argument('--build',type=Path,required=True)
p.add_argument('--lite-bin',type=Path,default=Path('C:/intelFPGA_lite/24.1std/quartus/bin64'))
p.add_argument('--pro-bin',type=Path,default=Path('C:/altera_pro/26.1/quartus/bin64'))
p.add_argument('--case',help='Run one named case instead of the complete suite')
a=p.parse_args()
repo=Path(__file__).resolve().parents[3]
build=a.build.resolve()
build.mkdir(parents=True,exist_ok=True)
evidence=[]
def elaborate(label,qsf,tool,expected=None,synthesize=False):
    if a.case and a.case != label:
        return
    directory=build/label
    directory.mkdir(exist_ok=True)
    (directory/'vendor.qsf').write_text(qsf)
    (directory/'vendor.qpf').write_text('PROJECT_REVISION = "vendor"\n')
    command=[str(tool)]+([] if synthesize else ['--analysis_and_elaboration'])+['vendor']
    result=subprocess.run(command,cwd=directory,capture_output=True,timeout=300)
    output=(result.stdout+result.stderr).decode(errors='replace')
    (directory/'elaboration.log').write_text(output)
    if expected:
        assert result.returncode != 0 and expected in output,output[-4000:]
    else:
        assert result.returncode == 0,output[-4000:]
    evidence.append({'case':label,'command':command,'returncode':result.returncode,'expected_error':expected})
    print('PASS '+label,flush=True)

for board,tool in [('DE1',a.lite_bin/'quartus_map.exe'),('DE25',a.pro_bin/'quartus_syn.exe')]:
    board_dir=repo/'Project'/board
    original=(board_dir/(board.lower()+'_soc_top.qsf')).read_text()
    # Resolve file/search paths against the actual board project, not scratch.
    pattern=r'(set_global_assignment -name (?:\w+_FILE|SEARCH_PATH)\s+)(?:"([^"]+)"|(\S+))'
    qsf=re.sub(pattern,lambda m:m[1]+'"'+(board_dir/(m[2] or m[3])).resolve().as_posix()+'"',original)
    elaborate(board+'-altera',qsf,tool)
    elaborate(board+'-reject-xilinx',qsf+'\nset_parameter -name IP_TYPE 2\n',tool,
              'PROJECT_UNSUPPORTED_BOARD_BACKEND')

probe=build/'vendor_entropy_probe.v'
probe.write_text('''`include "ip_types.vh"
module vendor_entropy_probe #(parameter IP_TYPE = `IP_ALTERA) (input enable, output sample);
    ring_osc #(.IP_TYPE(IP_TYPE)) oscillator (.enable(enable), .out(sample));
endmodule
''')
base='''set_global_assignment -name FAMILY "Cyclone V"
set_global_assignment -name DEVICE 5CSEMA5F31C6
set_global_assignment -name TOP_LEVEL_ENTITY vendor_entropy_probe
set_global_assignment -name VERILOG_INPUT_VERSION VERILOG_2001
'''
for path in [probe,repo/'Source Code/RNG Module/ring_osc.v']:
    base+='set_global_assignment -name VERILOG_FILE "'+path.as_posix()+'"\n'
base+='set_global_assignment -name SEARCH_PATH "'+(repo/'Source Code').as_posix()+'"\n'
for ip_type in [1,0,2]:
    elaborate('physical-ring-'+str(ip_type),base+'set_parameter -name IP_TYPE '+str(ip_type)+'\n',
              a.lite_bin/'quartus_map.exe',None if ip_type==1 else 'RNG_UNSUPPORTED_IP_TYPE')

# Unlike the TPM's inactive placeholder, this RAM has live top-level ports.
# Mapping verifies that the new DE1 family really accepts the M10K macro.
ram_qsf=base.replace('TOP_LEVEL_ENTITY vendor_entropy_probe','TOP_LEVEL_ENTITY keygen_ram32')
for name in ['keygen_ram32.v','keygen_ram32_generic.v','keygen_ram32_altera.v']:
    ram_qsf+='set_global_assignment -name VERILOG_FILE "'+(repo/'Source Code/Key Generation/IP'/name).as_posix()+'"\n'
ram_qsf+='set_parameter -name IP_TYPE 1\nset_parameter -name DEVICE_FAMILY "Cyclone V"\nset_parameter -name ADDRESS_WIDTH 12\n'
elaborate('active-cyclone-ram',ram_qsf,a.lite_bin/'quartus_map.exe',synthesize=True)
inputs=list((repo/'Source Code').rglob('*.v'))+list((repo/'Source Code').rglob('*.vh'))
inputs+=list((repo/'Project').rglob('*.qsf'))+[Path(__file__).resolve()]
(build/'manifest.json').write_text(json.dumps({'cases':evidence,'inputs':{
    str(f.relative_to(repo)):hashlib.sha256(f.read_bytes()).hexdigest() for f in inputs}},indent=2)+'\n')
assert evidence,'No matching case: '+str(a.case)
print('PASS Quartus project vendor checks cases='+str(len(evidence)),flush=True)
