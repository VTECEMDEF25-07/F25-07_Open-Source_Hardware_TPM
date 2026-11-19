"""Reproduce adapter-only tests. These do not establish generated-slot integration.

Run prepare, compile, boundary, reset, adapter sequentially after obtaining the
shared native simulator. This runner refuses an existing native vsim process.
"""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import sys
import time


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['prepare', 'compile', 'adapter', 'boundary', 'reset'])
    parser.add_argument('--backend', type=int, choices=[0, 1], default=0)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[3]
    bench = root / 'Testing/Simulation/Asymmetric Module'
    build = root / 'build/rsa-adapter'
    build.mkdir(parents=True, exist_ok=True)
    tool_dir = Path('C:/intelFPGA_lite/24.1std/questa_fse/win64')
    model_dir = Path('C:/intelFPGA_lite/24.1std/quartus/eda/sim_lib')
    keygen = root / 'Source Code/Key Generation'
    sources = list((keygen / 'IP').glob('*.v')) + [keygen / 'rtl/arithmetic/keygen_pair_check.v']
    sources += list((root / 'Source Code/Asymmetric Module').glob('*.v'))
    sources += [root / 'Source Code/Execution Engine/execution_engine_rsa.v']
    source_hashes = {str(p.relative_to(root)): sha(p) for p in sources + [bench / 'tb_rsa_adapter.sv']}
    record = {'action': args.action, 'backend': args.backend, 'source_hashes': source_hashes,
              'runner_sha256': sha(Path(__file__)), 'adapter_only': True, 'full_width': 2048,
              'head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root).decode().strip(),
              'commands': []}

    def run(name, parameters, label, deadline=180):
        command = [str(tool_dir / (name + '.exe'))] + parameters
        path = build / (label + '.log')
        start = time.monotonic()
        with path.open('wb') as output:
            process = subprocess.Popen(command, cwd=build, stdout=output, stderr=subprocess.STDOUT,
                creationflags=subprocess.CREATE_NEW_PROCESS_GROUP | subprocess.CREATE_NO_WINDOW)
            try:
                process.wait(timeout=deadline)
            except subprocess.TimeoutExpired:
                # Kill only this launcher's process tree, never another user's sim.
                subprocess.run([str(Path(os.environ['SystemRoot']) / 'System32/taskkill.exe'),
                                '/PID', str(process.pid), '/T', '/F'], capture_output=True, timeout=10)
                process.wait(timeout=10)
                raise
            finally:
                record['commands'].append({'argv': command, 'deadline_seconds': deadline,
                    'elapsed_seconds': round(time.monotonic()-start, 3), 'returncode': process.returncode,
                    'transcript': path.name, 'sha256': sha(path)})
        text = path.read_text(errors='replace')
        if process.returncode or any(marker in text for marker in ['** Error:', '** Fatal:', '(Error):', 'Failed to open readmem']):
            raise RuntimeError(f'{label} failed: {path}')
        return text

    try:
        if args.action == 'prepare':
            reference = root / 'Testing/Simulation/Key Generation/reference'
            sys.path.insert(0, str(reference))
            from key_checker import check_key
            corpus = reference / 'expected_keys.json'
            key = {k: int(v, 16) for k, v in json.loads(corpus.read_text())['results'][0]['key'].items()}
            check_key(key)
            n, e = key['n'], key['e']
            d = pow(e, -1, math.lcm(key['p']-1, key['q']-1))
            assert d == key['d'] and n.bit_length() == 2048
            values = []
            for component, count in [('n', 64), ('e', 1), ('p', 32), ('q', 32)]:
                values += [(key[component] >> (32*i)) & 0xffffffff for i in reversed(range(count))]
            (build / 'slot.hex').write_text(''.join(f'{v:08x}\n' for v in values))
            public_rep = int.from_bytes(b''.join(hashlib.sha512(b'RSA2048-public-adapter'+bytes([i])).digest() for i in range(4)), 'big') % n
            private_rep = n-2
            vectors = [public_rep, pow(public_rep, e, n), private_rep, pow(private_rep, d, n)]
            (build / 'rsa_vectors.hex').write_text(''.join(f'{v:0512x}\n' for v in vectors))
            record['corpus_sha256'] = sha(corpus)
            record['checker_sha256'] = sha(reference / 'key_checker.py')
            record['fixtures'] = {name: sha(build / name) for name in ['slot.hex', 'rsa_vectors.hex']}
            record['expected_results'] = {'public': f'{vectors[1]:0512x}', 'private': f'{vectors[3]:0512x}'}
            print('RSA_ADAPTER_FIXTURES_PREPARED full_width=2048 slot_words=129 independent_python_pow=2')
        elif args.action == 'compile':
            run('vlib', ['work'], 'work-library')
            run('vlib', ['vendor'], 'vendor-library')
            run('vlog', ['-work', 'vendor'] + [str(model_dir / name) for name in ['220model.v', 'altera_mf.v']], 'vendor-compile')
            run('vlog', ['-vlog01compat'] + [str(p) for p in sources], 'rtl-compile')
            run('vlog', ['-sv', str(bench / 'tb_rsa_adapter.sv')], 'bench-compile')
            (build / 'compiled-inputs.json').write_text(json.dumps(source_hashes, indent=2)+'\n')
            print('RSA_ADAPTER_COMPILE_PASS Verilog2001')
        else:
            # License ownership also requires coordination; process absence is
            # only a guard against accidentally overlapping an existing run.
            processes = subprocess.check_output(['tasklist.exe', '/FO', 'CSV', '/NH']).decode(errors='replace').lower()
            if '"vsim.exe"' in processes or '"vsimk.exe"' in processes:
                raise RuntimeError('Native simulator in use; coordinate and retry after release')
            if json.loads((build / 'compiled-inputs.json').read_text()) != source_hashes:
                raise RuntimeError('Sources differ from compiled manifest; compile again')
            prepared = json.loads((build / 'prepare.json').read_text())
            record['fixtures'] = prepared['fixtures']
            for name, expected in record['fixtures'].items():
                if sha(build / name) != expected:
                    raise RuntimeError('Fixture changed after independent preparation: '+name)
            case = {'adapter': 0, 'boundary': 1, 'reset': 2}[args.action]
            script = build / 'run.do'
            script.write_text('onerror {quit -force -code 1}\nonbreak {quit -force -code 0}\nrun -all\nquit -force -code 1\n')
            output = run('vsim', ['-c', '-L', 'vendor', '-voptargs=+acc', f'-gTEST_CASE={case}',
                f'-gIP_TYPE={args.backend}', 'work.tb_rsa_adapter', '-do', 'do run.do'],
                f'{args.action}-{args.backend}', 7200 if case==0 else 1800)
            marker = f'RSA_ADAPTER_PASS case={case} backend={args.backend}'
            if marker not in output:
                raise RuntimeError('Missing explicit completion marker')
            record['pass_markers'] = [line.strip('# ') for line in output.splitlines() if 'RSA_ADAPTER_PASS' in line]
            print(record['pass_markers'][0])
    finally:
        suffix = '' if args.action in ['prepare', 'compile'] else '-'+str(args.backend)
        (build / (args.action+suffix+'.json')).write_text(json.dumps(record, indent=2)+'\n')


if __name__ == '__main__':
    main()
