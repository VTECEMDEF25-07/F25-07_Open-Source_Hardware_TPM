#!/usr/bin/env python3
"""Independent public pow oracle + byte-memory lifecycle regression (Verilator)."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import random
import runpy
import subprocess
import time


def run(command, cwd, log):
    started = time.monotonic()
    with log.open('w', encoding='utf-8') as output:
        process = subprocess.run(command, cwd=cwd, stdout=output,
                                 stderr=subprocess.STDOUT, timeout=1800)
    text = log.read_text(errors='replace')
    elapsed = time.monotonic() - started
    print(f'{log.name}: exit={process.returncode} seconds={elapsed:.3f}', flush=True)
    if process.returncode or 'FAIL:' in text or '%Error' in text:
        raise RuntimeError(text[-6000:])
    return text, elapsed


def vectors(width):
    rng = random.Random(0xDE250000 + width)
    n = (1 << width) - 189
    values = [(0, 0, n), (1, 65537, n), (n-1, 3, n)]
    for exponent in (0, 1, 65537, (1 << (width-1)) | 0x12345):
        modulus = rng.getrandbits(width) | (1 << (width-1)) | 1
        values.append((rng.randrange(2, modulus-1), exponent, modulus))
    values.append((0x0123456789abcdef % n, 65537, n))
    return [(a, e, n, pow(a, e, n)) for a, e, n in values]


def compile_cpp(obj, build, executable, log):
    # GNU Make refuses physical paths containing spaces. Compile generated C++
    # with an argv list instead; all real outputs remain in the class workspace.
    version = subprocess.check_output(['verilator', '-V'], text=True)
    root = next(line.split('=', 1)[1].strip() for line in version.splitlines()
                if line.strip().startswith('VERILATOR_ROOT') and line.split('=', 1)[1].strip())
    include = Path(root)/'include'
    command = ['g++', '-O1', '-std=c++20', '-pthread', '-I'+str(obj),
               '-I'+str(include), '-I'+str(include/'vltstd'),
               *(str(p) for p in sorted(obj.glob('*.cpp'))),
               *(str(include/name) for name in ('verilated.cpp', 'verilated_timing.cpp',
                                                'verilated_threads.cpp')),
               '-o', str(executable)]
    run(command, build, log)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--width', type=int, choices=(32, 256, 2048), default=32)
    parser.add_argument('--build-dir', type=Path, required=True)
    parser.add_argument('--deadline-tests', action='store_true')
    parser.add_argument('--prior', action='store_true')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[4]
    rtl = root/'Source Code/Asymmetric Module'
    benches = root/'Testing/Simulation/Asymmetric Module'
    build = args.build_dir.resolve()
    build.mkdir(parents=True, exist_ok=True)
    sources = [rtl/'montgomery_mult.v', rtl/'rsa_modexp.v',
               rtl/'demo_modexp_adapter.v', benches/'tb_demo_modexp_adapter.sv']
    manifest = {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in sources + [Path(__file__).resolve()]}
    values = vectors(args.width)
    digits = args.width//4
    (build/'vectors.txt').write_text(''.join(' '.join(f'{v:0{digits}x}' for v in row)+'\n'
                                           for row in values), encoding='ascii')
    results = []
    variants = [('normal', 50000000, [0])]
    if args.deadline_tests:
        if args.width != 32:
            parser.error('--deadline-tests uses WIDTH=32')
        variants += [('deadline', 2000, [1, 2, 3, 4])]
    for name, limit, modes in variants:
        obj = build/('obj_'+name)
        command = ['verilator', '--cc', '--exe', '--main', '--timing', '-Wno-fatal',
                   '--top-module', 'tb_demo_modexp_adapter', '--Mdir', obj.name,
                   '-GWIDTH='+str(args.width), '-GJOB_LIMIT='+str(limit),
                   '-CFLAGS', '-O2', *(str(p) for p in sources)]
        run(command, build, build/(name+'_build.log'))
        compile_cpp(obj, build, obj/'Vtb_demo_modexp_adapter', build/(name+'_cpp.log'))
        for mode in modes:
            output, elapsed = run([str(obj/'Vtb_demo_modexp_adapter'), '+mode='+str(mode)],
                                  build, build/(name+f'_mode{mode}.log'))
            marker = f'ALL DEMO MODEXP ADAPTER TESTS PASSED width={args.width} mode={mode}'
            if marker not in output:
                raise RuntimeError(output[-6000:])
            print(output[-1800:], flush=True)
            results.append({'variant': name, 'mode': mode, 'seconds': elapsed,
                            'summary': next(line for line in output.splitlines() if marker in line)})
    if args.prior:
        for top in ('tb_montgomery_mult', 'tb_rsa_modexp', 'tb_rsa_controller'):
            obj = build/('obj_'+top)
            command = ['verilator', '--cc', '--exe', '--main', '--timing', '-Wno-fatal', '--top-module', top,
                       '--Mdir', obj.name, *(str(p) for p in (rtl/'montgomery_mult.v',
                       rtl/'rsa_modexp.v', rtl/'rsa_controller.v', benches/(top+'.v')))]
            run(command, build, build/(top+'_build.log'))
            compile_cpp(obj, build, obj/('V'+top), build/(top+'_cpp.log'))
            output, elapsed = run([str(obj/('V'+top))], build, build/(top+'.log'))
            if 'ALL TESTS PASSED' not in output:
                raise RuntimeError(output[-6000:])
            print(output[-600:], flush=True)
            results.append({'prior': top, 'seconds': elapsed, 'pass': True})
        if args.width == 2048:
            # Reuse unchanged prior oracle generators and benches. Only their
            # make-based launcher is replaced to support this workspace's spaces.
            for script, top, marker in (
                ('test_montgomery_mult_2048.py', 'tb_montgomery_mult_vectors',
                 'ALL 2048-BIT VECTORS PASSED (18 cases)'),
                ('test_rsa_modexp_2048.py', 'tb_rsa_modexp_vectors',
                 'ALL 2048-BIT RSA MODEXP TESTS PASSED')):
                namespace = runpy.run_path(str(benches/'scripts'/script))
                case = build/top
                case.mkdir(exist_ok=True)
                if top == 'tb_montgomery_mult_vectors':
                    namespace['write_vectors'](case/'vectors.txt', namespace['make_vectors']())
                else:
                    namespace['write_vector'](case/'vectors.txt', namespace['make_vector']())
                obj = case/'obj'
                command = ['verilator', '--cc', '--exe', '--main', '--timing',
                           '-Wno-fatal', '--top-module', top, '--Mdir', obj.name,
                           str(rtl/'montgomery_mult.v'), str(rtl/'rsa_modexp.v'),
                           str(benches/(top+'.v'))]
                run(command, case, case/'elaborate.log')
                compile_cpp(obj, case, obj/('V'+top), case/'compile.log')
                output, elapsed = run([str(obj/('V'+top))], case, case/'result.log')
                if marker not in output:
                    raise RuntimeError(output[-6000:])
                print(output[-1000:], flush=True)
                results.append({'prior': script, 'seconds': elapsed, 'pass': True})
    assert manifest == {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
                        for p in sources + [Path(__file__).resolve()]}
    (build/'results.json').write_text(json.dumps({'width': args.width, 'vectors':len(values),
        'source_sha256': manifest, 'results': results}, indent=2)+'\n', encoding='utf-8')
    print('PASS: independent-reference adapter regression complete', flush=True)


if __name__ == '__main__':
    main()
