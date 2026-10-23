# Filename: check_repository_hygiene.py
# Authors: Project contributors; see Git history.
# Date: 2026-10-13
# General Description: Check ignore rules without creating any dummy files or changing the index.
# AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

"""Check ignore rules without creating any dummy files or changing the index."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
IGNORED = [
    'Key Generation/build/test/result.log', 'Boards/DE1/db/chip.qdb',
    'Boards/DE1/output_files/keygen.sof',
    'Key Generation/testbench/work/_info', 'Key Generation/reference/__pycache__/a.pyc',
    'Boards/DE1/dni/sandboxes/generated.sopcinfo',
    'Boards/DE1/tmp-clearbox/generated.tdf',
]
TRACKABLE = [
    'Boards/DE1/keygen.qpf', 'Boards/DE1/keygen.qsf',
    'Boards/DE1/keygen.sdc', 'Key Generation/IP/altera/ram.v',
    'Key Generation/IP/generic/ram.v', 'Key Generation/simulation/check.sv',
    'Key Generation/reference/fixtures.json',
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
