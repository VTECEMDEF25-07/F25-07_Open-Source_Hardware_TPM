"""Run the isolated 50 MHz / mode-0 DE25 serializer regression with Questa.

Example: python Boards/DE25/simulate_spi.py --build PATH --questa-bin PATH
Uses no FPGA, USB adapter, vendor IP model or command-execution mock.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build', type=Path, required=True)
    parser.add_argument('--questa-bin', type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    build = args.build.resolve()
    build.mkdir(parents=True, exist_ok=False)
    tools = args.questa_bin.resolve()
    executable_suffix = '.exe' if (tools / 'vsim.exe').exists() else ''
    rtl = root / 'IO Interface/de25_spi_slave.v'
    bench = root / 'Boards/DE25/tests/tb_de25_spi.sv'
    inputs = [rtl, bench, Path(__file__).resolve()]
    digest = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
    hashes = {str(path.relative_to(root)): digest(path) for path in inputs}
    commands = []

    def run(tool, arguments, log):
        command = [str(tools / (tool + executable_suffix))] + list(map(str, arguments))
        commands.append(command)
        result = subprocess.run(command, cwd=build, capture_output=True, timeout=120)
        output = result.stdout + result.stderr
        (build / log).write_bytes(output)
        result.check_returncode()
        return output

    version = run('vsim', ['-version'], 'version.log').decode().strip()
    run('vlib', ['work'], 'library.log')
    run('vlog', ['-vlog01compat', rtl], 'rtl.log')
    run('vlog', ['-sv', bench], 'bench.log')
    output = run('vsim', ['-c', 'work.tb_de25_spi', '-do',
        'onerror {quit -code 1}; onbreak {quit -code 1}; run -all; quit -code 0'], 'result.log')
    if b'PASS DE25 SPI:' not in output or b'\x00' in output:
        raise RuntimeError('Missing PASS marker or damaged transcript')
    if hashes != {str(path.relative_to(root)): digest(path) for path in inputs}:
        raise RuntimeError('Inputs changed during simulation')
    (build / 'manifest.json').write_text(json.dumps({
        'status': 'PASS', 'tool': version, 'source_sha256': hashes,
        'commands': commands, 'log_sha256': digest(build / 'result.log')
    }, indent=2) + '\n')
    print(output.decode())


if __name__ == '__main__':
    main()
