"""Compile production RTL in Verilog-2001 mode and run bounded assertion tests.

Requires Questa (override --questa), or Icarus via --iverilog/--vvp.
Outputs go only to the explicitly supplied --build directory.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--build', type=Path, required=True)
    p.add_argument('--questa', type=Path)
    p.add_argument('--iverilog')
    p.add_argument('--vvp', default='vvp')
    p.add_argument('--seed', type=int, default=1)
    a = p.parse_args()
    here = Path(__file__).resolve().parent
    root = here.parents[2]
    rtl = root / 'Source Code' / 'Demo Memory'
    sources = [rtl / 'demo_byte_ram.v', rtl / 'demo_volatile_store.v']
    bench = here / 'tb_demo_memory.sv'
    inputs = sources + [bench, Path(__file__).resolve()]
    hashes = {str(x.relative_to(root)): hashlib.sha256(x.read_bytes()).hexdigest() for x in inputs}
    a.build.mkdir(parents=True, exist_ok=True)
    build = a.build.resolve()
    commands = []

    def run(name, cmd):
        commands.append(list(map(str, cmd)))
        r = subprocess.run(list(map(str, cmd)), cwd=build, capture_output=True, text=True, timeout=120)
        output = r.stdout + r.stderr
        (build / (name + '.log')).write_text(output, encoding='utf-8')
        if r.returncode or re.search(r'\*\* (?:Error|Fatal):|FAIL |FATAL:', output):
            raise SystemExit(output)
        return output

    if a.iverilog:
        run('rtl_compile', [a.iverilog, '-g2001', '-tnull', *sources])
        run('compile', [a.iverilog, '-g2012', '-s', 'tb_demo_memory', '-o', build/'memory.vvp', *sources, bench])
        result = run('simulation', [a.vvp, build/'memory.vvp', f'+SEED={a.seed}'])
    else:
        q = a.questa or Path('C:/intelFPGA_lite/24.1std/questa_fse/win64')
        suffix = '.exe' if (q/'vsim.exe').exists() else ''
        run('vlib', [q/('vlib'+suffix), 'work'])
        run('rtl_compile', [q/('vlog'+suffix), '-vlog01compat', *sources])
        run('compile', [q/('vlog'+suffix), '-sv', bench])
        result = run('simulation', [q/('vsim'+suffix), '-c', '-voptargs=+acc', 'work.tb_demo_memory',
                                   f'+SEED={a.seed}', '-do',
                                   'onbreak {quit -code 1}; onerror {quit -code 1}; run -all; quit -code 0'])
    marker = re.search(r'PASS demo_memory cases=\d+ checks=\d+ byte_transactions=\d+', result)
    if not marker:
        raise SystemExit('Missing completion marker; inspect simulation.log')
    if hashes != {str(x.relative_to(root)): hashlib.sha256(x.read_bytes()).hexdigest() for x in inputs}:
        raise SystemExit('Inputs changed during simulation')
    (build/'manifest.json').write_text(json.dumps({
        'status': 'PASS', 'seed': a.seed, 'result': marker.group(),
        'source_sha256': hashes, 'commands': commands,
        'simulation_log_sha256': hashlib.sha256((build/'simulation.log').read_bytes()).hexdigest()
    }, indent=2)+'\n', encoding='utf-8')
    print(marker.group())


if __name__ == '__main__':
    main()
