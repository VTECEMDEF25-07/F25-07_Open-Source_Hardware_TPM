"""Replay Phase 1's checked-in SPI vectors against either board top (Questa).

Clock/configuration/fan models are test-only. This is NOT PLL or fan validation.
Current TPM RTL and original assertions are copied into a fresh snapshot.
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
    parser.add_argument('--questa-bin', type=Path, required=True)
    parser.add_argument('--board', choices=('DE1','DE25'), default='DE25')
    parser.add_argument('--repo', type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument('--models', type=Path, default=None)
    parser.add_argument('--build', type=Path, required=True)
    parser.add_argument('--spi-hz', type=int, choices=(100000,500000,1000000,10000000,15000000,24000000,30000000), default=1000000)
    args = parser.parse_args()
    repo = args.repo.resolve()
    build = args.build.resolve()
    build.mkdir(parents=True, exist_ok=False)
    paths = [repo / ('Project/DE25/de25_soc_top.v' if args.board == 'DE25' else 'Project/DE1/de1_soc_top.v'), repo / 'Source Code/TPM_TOP.v',
             repo / 'Source Code/Management Module/management_module.v',
             repo / 'Source Code/Execution Engine/execution_engine.v']
    paths += sorted((repo / 'Source Code/IO Interface').glob('*.v'))
    hashes = {}
    sources = []
    for path in paths:
        data = path.read_bytes()
        target = build / path.name
        target.write_bytes(data)
        sources.append(str(target))
        hashes[str(path.relative_to(repo))] = hashlib.sha256(data).hexdigest()
    header = repo / 'Source Code/IO Interface/tpm_types.vh'
    # Legacy source spells its include uppercase; Linux paths are case-sensitive.
    (build / 'TPM_TYPES.vh').write_bytes(header.read_bytes())
    hashes[str(header.relative_to(repo))] = hashlib.sha256(header.read_bytes()).hexdigest()
    original = repo / 'Simulation/IO Interface/tb_test.v'
    bench = original.read_text().replace('`timescale 1ns/1ns','`timescale 1ns/1ps')
    hashes[str(original.relative_to(repo))] = hashlib.sha256(original.read_bytes()).hexdigest()
    if bench.count('`define SPI_CLK_PERIOD #33') != 1:
        raise RuntimeError('legacy SPI timing definition changed')
    bench = bench.replace('`define SPI_CLK_PERIOD #33',
                          '`define SPI_CLK_PERIOD #'+format(500000000 / args.spi_hz, '.6f'))
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
    models = (args.models or repo / 'Simulation' / args.board / 'tests/spi_board_model.sv').resolve()
    (build / models.name).write_bytes(models.read_bytes())
    hashes['test_only/phase1_board_models.sv'] = hashlib.sha256(models.read_bytes()).hexdigest()
    tools = args.questa_bin.resolve()
    suffix = '.exe' if (tools / 'vsim.exe').exists() else ''
    run([str(tools / ('vlib'+suffix)), 'work'], build, 'library.log', 60)
    run([str(tools / ('vlog'+suffix)), '-vlog01compat', '+incdir+'+str(build)] + sources,
        build, 'compile.log', 120)
    run([str(tools / ('vlog'+suffix)), '-sv', str(build/'tb_test.sv'), str(build/models.name)],
        build, 'bench.log', 120)
    run([str(tools / ('vsim'+suffix)), '-c', 'work.tb_test', '-do',
         'onerror {quit -code 1}; onbreak {quit -code 1}; run -all; quit -code 0'],
        build, 'result.log', 180)
    result = (build / 'result.log').read_text()
    if 'PASS PHASE1 LEGACY VECTORS' not in result or 'There were errors' in result:
        raise RuntimeError('missing pass marker or legacy assertion failure')
    for path in paths + [header, original]:
        if hashlib.sha256(path.read_bytes()).hexdigest() != hashes[str(path.relative_to(repo))]:
            raise RuntimeError('Source changed during simulation: '+str(path))
    if hashlib.sha256(models.read_bytes()).hexdigest() != hashes['test_only/phase1_board_models.sv']:
        raise RuntimeError('Test model changed during simulation')
    (build / 'manifest.json').write_text(json.dumps({'status': 'PASS', 'source_sha256': hashes,
        'board': args.board, 'spi_hz': args.spi_hz,
        'limitations': 'Behavioral board models; hardware/vendor clock not validated.'}, indent=2)+'\n')
    print(result)


if __name__ == '__main__':
    main()
