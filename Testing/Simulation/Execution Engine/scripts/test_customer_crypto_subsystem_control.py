"""Real hub/status, explicitly mocked leaf services. No cryptography claim."""
from pathlib import Path
import re,json,hashlib,subprocess,time,argparse
p=argparse.ArgumentParser();p.add_argument('--build-dir',type=Path,required=True);a=p.parse_args()
repo=Path(__file__).resolve().parents[4];src=repo/'Source Code';build=a.build_dir.resolve();build.mkdir(parents=True,exist_ok=True)
modules={
 'customer_demo_packet':src/'Execution Engine/customer_demo_packet.v',
 'demo_keygen_operation':src/'Key Generation/integration/demo_keygen_operation.v',
 'demo_volatile_store':src/'Demo Memory/demo_volatile_store.v',
 'customer_aes_worker':src/'Execution Engine/customer_aes_worker.v',
 'demo_rsa_private_worker':src/'Asymmetric Module/demo_rsa_private_worker.v'}
models='// CONTROL MODELS ONLY: these modules perform no cryptography.\n'
for name,path in modules.items():
 text=re.sub(r'//[^\n]*','',path.read_text())
 m=re.search(r'(module\s+'+name+r'\s*(?:#\s*\([\s\S]*?\)\s*)?\(([\s\S]*?)\);)',text)
 assert m,name
 header=m[1];outputs=[];direction=None
 for part in m[2].split(','):
  part=part.strip();d=re.match(r'(input|output|inout)\s+(.*)',part,re.S)
  if d:direction=d[1];part=d[2];part=re.sub(r'^(wire|reg)\s+','',part);part=re.sub(r'^\[[^\]]+\]\s*','',part)
  if direction=='output':outputs.append(part.strip())
 models+=re.sub(r'output\s+wire','output reg',header)+'\n'
 models+='initial begin\n'+''.join(f'    {n}=0;\n' for n in outputs)+'end\n'
 models+='always @(negedge reset_n_i) begin\n'+''.join(f'    {n}<=0;\n' for n in outputs)+'end\nendmodule\n'
(build/'control_models.sv').write_text(models)
sources=[src/'Execution Engine/customer_crypto_subsystem.v',src/'Display/demo_lcd_status.v',build/'control_models.sv',repo/'Testing/Simulation/Execution Engine/tb_customer_crypto_subsystem_control.sv']
manifest={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in sources}
(build/'inputs.json').write_text(json.dumps(manifest,indent=2))
obj=build/'obj';obj.mkdir(exist_ok=True)
with (build/'build.log').open('w') as f:
 subprocess.run(['verilator','--cc','--exe','--main','--timing','--top-module','tb_customer_crypto_subsystem_control','--Mdir',str(obj),'-Wno-fatal','-Werror-PINMISSING']+list(map(str,sources)),stdout=f,stderr=subprocess.STDOUT,check=True)
 subprocess.run(['g++','-O1','-std=c++20','-pthread','-I'+str(obj),'-I/usr/share/verilator/include','-I/usr/share/verilator/include/vltstd']+list(map(str,obj.glob('*.cpp')))+['/usr/share/verilator/include/verilated.cpp','/usr/share/verilator/include/verilated_timing.cpp','/usr/share/verilator/include/verilated_threads.cpp','-o',str(obj/'run')],stdout=f,stderr=subprocess.STDOUT,check=True)
start=time.monotonic()
with (build/'simulation.log').open('w') as f:result=subprocess.run([str(obj/'run')],stdout=f,stderr=subprocess.STDOUT,cwd=build)
assert manifest=={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in sources},'source changed'
text=(build/'simulation.log').read_text();print(text)
summary={'returncode':result.returncode,'scope':'MOCK_SERVICES_REAL_HUB_AND_STATUS','cryptography_claim':False,'seconds':time.monotonic()-start}
(build/'summary.json').write_text(json.dumps(summary,indent=2));print(summary)
assert result.returncode==0 and 'CONTROL_HUB_PASS' in text
