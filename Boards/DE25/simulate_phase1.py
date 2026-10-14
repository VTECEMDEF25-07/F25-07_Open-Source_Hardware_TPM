"""Replay Phase 1's checked-in SPI vectors against the DE25 top (WSL/Linux).

Clock/configuration/fan models are test-only. This is NOT PLL or fan validation.
The original TPM RTL and assertions are copied unchanged into a fresh snapshot.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess


def run(command, directory, name, timeout):
    result = subprocess.run(command, cwd=directory, capture_output=True,
                            text=True, timeout=timeout)
    (directory / name).write_text(result.stdout + result.stderr)
    result.check_returncode()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build', type=Path, required=True)
    parser.add_argument('--spi-hz', type=int, choices=(100000, 500000, 1000000, 15000000), default=1000000)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[2]
    build = args.build.resolve()
    build.mkdir(parents=True, exist_ok=False)
    paths = [repo / 'de25_soc_top.v', repo / 'TPM_TOP.v',
             repo / 'Management Module/management_module.v',
             repo / 'Execution Engine/execution_engine.v']
    paths += sorted((repo / 'IO Interface').glob('*.v'))
    hashes = {}
    sources = []
    for path in paths:
        data = path.read_bytes()
        target = build / path.name
        target.write_bytes(data)
        sources.append(str(target))
        hashes[str(path.relative_to(repo))] = hashlib.sha256(data).hexdigest()
    header = repo / 'IO Interface/tpm_types.vh'
    # Legacy source spells its include uppercase; Linux paths are case-sensitive.
    (build / 'TPM_TYPES.vh').write_bytes(header.read_bytes())
    hashes[str(header.relative_to(repo))] = hashlib.sha256(header.read_bytes()).hexdigest()
    original = repo / 'IO Interface/Testbenches/tb_test.v'
    bench = original.read_text()
    hashes[str(original.relative_to(repo))] = hashlib.sha256(original.read_bytes()).hexdigest()
    if bench.count('`define SPI_CLK_PERIOD #33') != 1:
        raise RuntimeError('legacy SPI timing definition changed')
    bench = bench.replace('`define SPI_CLK_PERIOD #33',
                          '`define SPI_CLK_PERIOD #'+str(500000000 // args.spi_hz))
    # Preserve every vector/assertion; only turn the interactive stop into an exit
    # and allow the new board-reset/PLL startup model to settle before vectors.
    anchor = '\t\t// test_debugRW'
    if anchor not in bench or bench.count('$stop;') != 10:
        raise RuntimeError('legacy bench layout changed')
    bench = bench.replace(anchor, '\t\trepeat (30) @(posedge clock);\n' + anchor, 1)
    prefix, suffix = bench.rsplit('$stop;', 1)
    prefix = prefix.replace('$stop;', '$fatal(1, "PHASE1 EXECUTION TIMEOUT");')
    bench = prefix + 'if (errors) $fatal(1, "PHASE1 ASSERTIONS FAILED");\n\t\t$display("PASS PHASE1 LEGACY VECTORS");\n\t\t$finish;' + suffix
    (build / 'tb_test.sv').write_text(bench)
    models = Path(__file__).with_name('tests') / 'phase1_board_models.sv'
    (build / models.name).write_bytes(models.read_bytes())
    hashes[str(models.relative_to(repo))] = hashlib.sha256(models.read_bytes()).hexdigest()
    obj = build / 'obj'
    run(['verilator', '--cc', '--exe', '--main', '--timing', '--top-module', 'tb_test',
         '--Mdir', str(obj), '-Wno-fatal', '+1364-2001ext+v', '+1800-2017ext+sv',
         '-I'+str(build)] + sources + [str(build / 'tb_test.sv'), str(build / models.name)],
        build, 'elaborate.log', 120)
    combined = obj / 'combined.cpp'
    combined.write_text(''.join('#include "'+p.name+'"\n' for p in sorted(obj.glob('*.cpp'))))
    include = Path('/usr/share/verilator/include')
    binary = obj / 'Vtb_test'
    run(['g++', '-O0', '-std=c++20', '-pthread', '-I'+str(obj), '-I'+str(include),
         '-I'+str(include / 'vltstd'), str(combined)] +
        [str(include / p) for p in ('verilated.cpp', 'verilated_timing.cpp', 'verilated_threads.cpp')] +
        ['-o', str(binary)], build, 'compile.log', 180)
    run([str(binary)], build, 'result.log', 120)
    result = (build / 'result.log').read_text()
    if 'PASS PHASE1 LEGACY VECTORS' not in result or 'There were errors' in result:
        raise RuntimeError('missing pass marker or legacy assertion failure')
    (build / 'manifest.json').write_text(json.dumps({'status': 'PASS', 'source_sha256': hashes,
        'spi_hz': args.spi_hz,
        'limitations': 'Behavioral board models; hardware/vendor clock not validated.'}, indent=2)+'\n')
    print(result)


if __name__ == '__main__':
    main()
