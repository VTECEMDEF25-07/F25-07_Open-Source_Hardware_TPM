"""Independent hashlib vectors + actual Verilog SHA/DRBG and demo adapter checks.
Aaron Grossman; Codex-assisted. Python standard library and Questa.
"""
import argparse
import hashlib
import os
from pathlib import Path
import shutil
import subprocess


def vectors():
    entropy = [bytes((i * 29 + j * 7 + 3) & 255 for j in range(32)) for i in range(7)]
    def df(message):
        return int.from_bytes(b''.join(hashlib.sha256(bytes([c]) + (440).to_bytes(4, 'big') + message).digest()
                                      for c in (1, 2))[:55], 'big')
    mask = (1 << 440) - 1
    v = df(b''.join(entropy[:3]))
    c = df(b'\0' + v.to_bytes(55, 'big'))
    counter = 1
    next_entropy = 3
    fresh = []
    for _ in range(4):
        if counter > 2:
            v = df(b'\1' + v.to_bytes(55, 'big') + b''.join(entropy[next_entropy:next_entropy + 2]))
            next_entropy += 2
            c = df(b'\0' + v.to_bytes(55, 'big'))
            counter = 1
        fresh.append(hashlib.sha256(v.to_bytes(55, 'big')).digest())
        h = int.from_bytes(hashlib.sha256(b'\3' + v.to_bytes(55, 'big')).digest(), 'big')
        v = (v + c + h + counter) & mask
        counter += 1
    test = [hashlib.sha256(b'KEYGEN-TEST-v1\0' + bytes(32) + i.to_bytes(8, 'big')).digest() for i in range(4)]
    return entropy, fresh, test


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--store', type=Path, help='Optional real protected-store RTL for operation integration bench')
    args = parser.parse_args()
    here = Path(__file__).resolve().parent
    repo = here.parents[3]
    build = args.output.resolve()
    build.mkdir(parents=True, exist_ok=True)
    questa = Path(os.environ.get('QUESTA_BIN', r'C:\intelFPGA_lite\24.1std\questa_fse\win64'))
    def run(label, executable, *arguments):
        exe = shutil.which(executable) or str(questa / (executable + '.exe'))
        result = subprocess.run([exe, *map(str, arguments)], cwd=build, text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        (build / (label + '.log')).write_text(result.stdout)
        print(result.stdout, flush=True)
        if result.returncode:
            raise SystemExit(result.returncode)
        return result.stdout
    entropy, fresh, test = vectors()
    rows = ['initial begin']
    rows += [f"entropy_fixture[{i}]=256'h{x.hex()};" for i, x in enumerate(entropy)]
    rows += [f"expected[{i}]=MODE==0 ? 256'h{f.hex()} : 256'h{t.hex()};" for i, (f, t) in enumerate(zip(fresh, test))]
    (build / 'demo_vectors.vh').write_text('\n'.join(rows + ['end\n']))
    if not (build / 'work').exists():
        run('library', 'vlib', 'work')
    source = repo / 'Source Code'
    rtl = list((source / 'Hash Module').glob('*.v'))
    rtl += [source / 'RNG Module' / (n + '.v') for n in ('ring_osc', 'entropy_source', 'random_number_generation')]
    rtl += list((source / 'Key Generation/rtl').rglob('*.v')) + list((source / 'Key Generation/IP').glob('*.v'))
    rtl += list((source / 'Key Generation/integration').glob('*.v'))
    if args.store:
        rtl.append(args.store.resolve())
    run('rtl', 'vlog', '-vlog01compat', '+define+SIMULATION', *rtl)
    benches = [here / 'tb_demo_generation.sv']
    if args.store:
        benches.append(here / 'tb_demo_operation.sv')
    run('bench', 'vlog', '-sv', f'+incdir+{build}', *benches)
    suites = [('tb_demo_generation', 'test', ['-gMODE=1']), ('tb_demo_generation', 'fresh', ['-gMODE=0'])]
    if args.store:
        suites += [('tb_demo_operation', 'operation-test', ['-gMODE=1']),
                   ('tb_demo_operation', 'operation-fresh', ['-gMODE=0'])]
    for top, label, generics in suites:
        out = run(label, 'vsim', '-c', '-onfinish', 'exit', top, *generics, '-do',
                  'onerror {quit -code 1}; onbreak {quit -code 1}; run -all; quit -code 0')
        marker = 'DEMO_OPERATION_PASS' if label.startswith('operation') else 'DEMO_GENERATION_PASS'
        if marker not in out or '** Error' in out or '** Fatal' in out:
            raise SystemExit(f'{label}: no accepted PASS')
    print('DEMO_RNG_SUITE_PASS')


if __name__ == '__main__':
    main()
