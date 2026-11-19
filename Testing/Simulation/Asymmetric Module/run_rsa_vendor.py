"""Sequential native Questa tests using genuine Altera resource models.

Obtain the shared simulator before running. No hardware access. Run compile,
boundary, protected-d, adapter. Full generated-key acceptance is a separate test.
"""
import argparse,hashlib,json,os,re,subprocess,time
from pathlib import Path


def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action',choices=['compile','boundary','protected-d','adapter','generated','resets','errors','word-resets'])
    args=parser.parse_args()
    root=Path(__file__).resolve().parents[3]
    bench=Path(__file__).parent
    build=root/'build/rsa-native-vendor';build.mkdir(parents=True,exist_ok=True)
    tools=Path('C:/intelFPGA_lite/24.1std/questa_fse/win64')
    modeldir=Path('C:/intelFPGA_lite/24.1std/quartus/eda/sim_lib')
    board=root/'Project/DE1/de1_soc_top.qsf'
    sources=[(board.parent/p).resolve() for p in re.findall(r'-name VERILOG_FILE "([^"]+)"',board.read_text())]
    benches=[bench/'tb_rsa_adapter.sv',bench/'tb_protected_d.sv',bench/'tb_rsa_generated.sv']
    inputs={str(p.relative_to(root)):sha(p) for p in sources+benches}
    models=[modeldir/'220model.v',modeldir/'altera_mf.v']
    record={'action':args.action,'backend':'Altera','full_width':2048,'inputs':inputs,
        'model_hashes':{p.name:sha(p) for p in models},'runner_sha256':sha(Path(__file__)),
        'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root).decode().strip(),'commands':[]}
    def run(name,parameters,label,deadline):
        path=build/(label+'.log');command=[str(tools/(name+'.exe'))]+parameters;start=time.monotonic()
        with path.open('wb') as out:
            proc=subprocess.Popen(command,cwd=build,stdout=out,stderr=subprocess.STDOUT,
                creationflags=subprocess.CREATE_NEW_PROCESS_GROUP|subprocess.CREATE_NO_WINDOW)
            try:proc.wait(timeout=deadline)
            except BaseException:
                subprocess.run([str(Path(os.environ['SystemRoot'])/'System32/taskkill.exe'),'/PID',str(proc.pid),'/T','/F'],capture_output=True,timeout=10)
                proc.wait();raise
            finally:record['commands'].append({'argv':command,'deadline_seconds':deadline,'elapsed_seconds':round(time.monotonic()-start,3),
                'returncode':proc.returncode,'transcript':path.name,'sha256':sha(path)})
        output=path.read_text(errors='replace')
        if proc.returncode or any(m in output for m in ['** Error:','** Fatal:','(Error):','Failed to open readmem']):raise RuntimeError(str(path))
        return output
    try:
        if args.action=='compile':
            run('vlib',['work'],'work-library',60);run('vlib',['vendor'],'vendor-library',60)
            run('vlog',['-work','vendor']+[str(p) for p in models],'vendor-compile',180)
            run('vlog',['-vlog01compat','+incdir+'+str(root/'Source Code/IO Interface')]+[str(p) for p in sources],'rtl-compile',180)
            run('vlog',['-sv']+[str(p) for p in benches],'bench-compile',180)
            (build/'compiled-inputs.json').write_text(json.dumps(inputs,indent=2)+'\n')
            print('RSA_VENDOR_COMPILE_PASS Verilog2001',flush=True)
        else:
            tasks=subprocess.check_output(['tasklist.exe','/FO','CSV','/NH']).decode(errors='replace').lower()
            if '"vsim.exe"' in tasks or '"vsimk.exe"' in tasks:raise RuntimeError('Native simulator busy; coordinate first')
            if json.loads((build/'compiled-inputs.json').read_text())!=inputs:raise RuntimeError('Compile manifest is stale')
            for name in ['slot.hex','rsa_vectors.hex','canonical_d.hex']:(build/name).write_bytes((root/'build/rsa-adapter'/name).read_bytes())
            parameters=['-c','-L','vendor','-gIP_TYPE=1']
            if args.action=='generated':
                # Same 384 candidate/witness words as the independent Generic run.
                corpus=root/'Testing/Simulation/Key Generation/reference/expected_keys.json'
                key=json.loads(corpus.read_text())['results'][0]['key']
                words=[(value>>(32*i))&0xffffffff for component in ('p','q')
                       for value in [int(key[component],16)]+[2]*5 for i in reversed(range(32))]
                (build/'stimulus.hex').write_text(''.join(f'{word:08x}\n' for word in words))
                record['corpus_sha256']=sha(corpus)
                top='tb_rsa_generated'
                marker='RSA_GENERATED_PASS backend=1'
            elif args.action=='protected-d':
                (build/'protected_d.hex').write_bytes((root/'build/rsa-protected-d/protected_d.hex').read_bytes())
                top='tb_protected_d'
                marker='RSA_PROTECTED_D_PASS backend=1'
            else:
                case={'adapter':0,'boundary':1,'resets':2,'errors':3,'word-resets':4}[args.action]
                top='tb_rsa_adapter'
                parameters.append(f'-gTEST_CASE={case}')
                marker=f'RSA_ADAPTER_PASS case={case} backend=1'
            script=build/'run.do'
            script.write_text('onerror {quit -force -code 1}\nonbreak {quit -force -code 0}\nrun -all\nquit -force -code 1\n')
            output=run('vsim',parameters+['work.'+top,'-do','do run.do'],args.action,
                       28800 if args.action=='generated' else 10800)
            if marker not in output:raise RuntimeError('Missing explicit PASS marker')
            record['pass_markers']=[line.strip('# ') for line in output.splitlines() if marker in line]
            record['fixtures']={p.name:sha(p) for p in build.glob('*.hex')}
            if inputs!={str(p.relative_to(root)):sha(p) for p in sources+benches}:raise RuntimeError('Inputs changed during run')
            print(record['pass_markers'][0],flush=True)
    finally:(build/(args.action+'.json')).write_text(json.dumps(record,indent=2)+'\n')


if __name__=='__main__':main()
