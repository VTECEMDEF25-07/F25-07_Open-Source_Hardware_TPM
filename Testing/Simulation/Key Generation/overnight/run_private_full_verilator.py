"""WSL Verilator full private keygen run; reuse prepared independent fixtures.
No simulator license, no GNU make (class paths contain spaces), no hardware.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--build', type=Path, required=True)
    p.add_argument('--prepared', type=Path, required=True)
    p.add_argument('--reuse', action='store_true')
    p.add_argument('--top', choices=['tb_keygen_full', 'tb_pair_private', 'tb_private_lease', 'tb_private_store'], default='tb_keygen_full')
    a = p.parse_args()
    build, prepared = a.build.resolve(), a.prepared.resolve()
    if os.name == 'nt':
        def wsl(path):
            s = str(Path(path).resolve()).replace('\\', '/')
            return '/mnt/' + s[0].lower() + s[2:]
        command = ['wsl.exe', '-d', 'Ubuntu-24.04', '--', 'python3', wsl(__file__),
                   '--build', wsl(build), '--prepared', wsl(prepared), '--top', a.top]
        if a.reuse:
            command += ['--reuse']
        subprocess.run(command, check=True)
        return
    repo = Path(__file__).resolve().parents[4]
    source = repo / 'Source Code/Key Generation'
    verification = repo / 'Testing/Simulation/Key Generation'
    files = sorted((source / 'rtl').rglob('*.v')) + sorted((source / 'IP').glob('*.v'))
    test = prepared / (a.top + '.sv') if a.top in ('tb_keygen_full','tb_pair_private') else Path(__file__).with_name(a.top+'.sv')
    files += [verification / 'testbench/fixtures/keygen_test_source.v', test]
    if a.top=='tb_private_store':
        files += [repo/'Source Code/Demo Memory/demo_volatile_store.v']
    build.mkdir(parents=True, exist_ok=True)
    obj = build / 'obj'
    binary = obj / ('V'+a.top)
    def digest(path):
        return hashlib.sha256(path.read_bytes()).hexdigest()
    hashes = {str(f): digest(f) for f in files}
    manifest = build / 'manifest.json'
    def run(label, arguments, timeout=1800):
        result = subprocess.run(list(map(str, arguments)), cwd=build, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True, timeout=timeout)
        (build / (label + '.log')).write_text(result.stdout)
        print(label + ': ' + result.stdout[-1800:], flush=True)
        if result.returncode:
            raise SystemExit(label + ' failed')
        return result.stdout
    if not a.reuse:
        run('elaborate', ['verilator', '--cc', '--exe', '--main', '--timing', '--top-module', a.top,
                         '--Mdir', obj, '-Wno-fatal', '+1364-2001ext+v', '+1800-2017ext+sv', *files])
        vr = Path('/usr/share/verilator/include')
        run('compile', ['g++', '-O2', '-std=c++20', '-pthread', '-I' + str(obj), '-I' + str(vr), '-I' + str(vr / 'vltstd'),
                        *sorted(obj.glob('*.cpp')), *[vr / x for x in ('verilated.cpp', 'verilated_timing.cpp', 'verilated_threads.cpp')], '-o', binary])
        assert hashes == {str(f): digest(f) for f in files}, 'sources changed during build'
        manifest.write_text(json.dumps(dict(status='BUILT', source_sha256=hashes, binary_sha256=digest(binary)), indent=2))
    else:
        old = json.loads(manifest.read_text())
        assert old['source_sha256'] == hashes and old['binary_sha256'] == digest(binary), 'stale simulation binary'
    if a.top=='tb_pair_private':
        (build/'pair_vectors.mem').write_bytes((prepared/'pair_vectors.mem').read_bytes())
    arguments=['+DIRECTED', '+STALLS', '+WORDS=384', '+EXPECTED=' + str(prepared / 'expected.hex'), '+STIMULUS=' + str(prepared / 'stimulus.hex')] if a.top=='tb_keygen_full' else []
    out = run('simulation', [binary,*arguments], timeout=3600)
    marker={'tb_keygen_full':'PASS FULL_RSA','tb_pair_private':'PASS pair check:','tb_private_lease':'PASS PRIVATE_LEASE','tb_private_store':'PASS PRIVATE_STORE'}[a.top]
    assert marker in out, 'no complete private keygen pass'
    assert hashes == {str(f): digest(f) for f in files}, 'sources changed during simulation'
    manifest.write_text(json.dumps(dict(status='PASS', source_sha256=hashes, binary_sha256=digest(binary),
        directed_public_fixture=True, fresh_rng_claim=False, private_mode=1, simulator='Verilator'), indent=2))


if __name__ == '__main__':
    main()
