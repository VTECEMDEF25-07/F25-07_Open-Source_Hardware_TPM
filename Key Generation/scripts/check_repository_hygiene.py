"""Check ignore rules without creating any dummy files or changing the index."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
IGNORED = [
    'Key Generation/build/test/result.log', 'Key Generation/demo/de25/db/chip.qdb',
    'Key Generation/demo/de25/output_files/keygen.sof',
    'Key Generation/firmware/generated/image.bin', 'Key Generation/firmware/start.o',
    'Key Generation/testbench/work/_info', 'Key Generation/reference/__pycache__/a.pyc',
]
TRACKABLE = [
    'Key Generation/demo/de25/keygen.qpf', 'Key Generation/demo/de25/keygen.qsf',
    'Key Generation/demo/de25/keygen.sdc', 'Key Generation/IP/altera/ram.v',
    'Key Generation/IP/generic/ram.v', 'Key Generation/simulation/check.sv',
    'Key Generation/firmware/start.S', 'Key Generation/reference/fixtures.json',
    'Key Generation/scripts/run.tcl', 'Key Generation/docs/evidence.md',
]
for expected, paths in [(True, IGNORED), (False, TRACKABLE)]:
    for path in paths:
        result = subprocess.run(['git', 'check-ignore', '--no-index', '-q', path], cwd=ROOT)
        if result.returncode not in (0, 1):
            raise SystemExit(f'git check-ignore failed: {path}')
        if (result.returncode == 0) != expected:
            raise SystemExit(f'Incorrect ignore rule: {path}; ignored={expected} expected')
print(f'PASS repository hygiene: {len(IGNORED)} generated paths ignored; '
      f'{len(TRACKABLE)} reproducible inputs trackable')
