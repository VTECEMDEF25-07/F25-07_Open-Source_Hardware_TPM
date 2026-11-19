"""Run full-width word-engine carry, reduction and fixed-latency vectors in WSL."""
import hashlib
import json
from pathlib import Path
import random
import subprocess

root = Path(__file__).resolve().parents[3]
build = root / 'build/rsa-word-vectors'
build.mkdir(parents=True, exist_ok=True)
ip = root / 'Source Code/Key Generation/IP'
sources = sorted(ip.glob('*.v')) + [
    root / 'Source Code/Asymmetric Module/rsa_montgomery_words.v',
    Path(__file__).with_name('tb_rsa_words.sv'),
]
rng = random.Random(48062048)
radix = 1 << 2048
near_half = (radix >> 1) + 1
near_full = radix - 1
random_n = (radix >> 1) | rng.getrandbits(2047) | 1
cases = [
    (near_half, 0, 65537),
    (near_full, 1, 0),
    (near_half, near_half - 1, radix - 1),
    (near_full, rng.randrange(near_full), int('aa' * 256, 16)),
    (random_n, rng.randrange(random_n), rng.getrandbits(2048)),
]
fixture = build / 'word_vectors.hex'
fixture.write_text(''.join(f'{word:0512x}\n' for n, base, exp in cases
                           for word in (n, base, exp, pow(base, exp, n))))


def hashes():
    return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sources + [Path(__file__), fixture]}


inputs = hashes()


def run(command, log, timeout):
    with (build / log).open('w') as output:
        subprocess.run(command, cwd=build, stdout=output, stderr=subprocess.STDOUT,
                       timeout=timeout, check=True)


run(['verilator', '--cc', '--exe', '--main', '--timing', '-Wno-fatal', '--Mdir', 'obj',
     '--top-module', 'tb_rsa_words', *sources], 'elaborate.log', 300)
include = Path('/usr/share/verilator/include')
run(['g++', '-O2', '-std=c++20', '-pthread', '-Iobj', '-I'+str(include),
     '-I'+str(include/'vltstd'), *sorted((build/'obj').glob('*.cpp')),
     *[include/p for p in ('verilated.cpp','verilated_timing.cpp','verilated_threads.cpp')],
     '-o', 'obj/test_words'], 'compile.log', 900)
run(['./obj/test_words'], 'result.log', 3600)
markers = [line for line in (build/'result.log').read_text().splitlines() if 'PASS' in line]
if len(markers)!=len(cases)+1 or 'RSA_WORDS_PASS ' not in markers[-1] or hashes()!=inputs:
    raise RuntimeError('Missing complete fixed-latency evidence or input bytes changed')
(build/'evidence.json').write_text(json.dumps({
    'head': subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),
    'version': subprocess.check_output(['verilator','--version'],text=True).strip(),
    'inputs':inputs, 'markers':markers,
},indent=2)+'\n')
print(markers[-1],flush=True)
