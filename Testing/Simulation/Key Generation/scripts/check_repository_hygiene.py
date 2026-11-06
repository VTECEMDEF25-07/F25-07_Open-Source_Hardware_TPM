# Filename: check_repository_hygiene.py
# Authors: Project contributors; see Git history.
# Date: 2026-10-13
# General Description: Check ignore rules without creating any dummy files or changing the index.
# AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

"""Check ignore rules without creating any dummy files or changing the index."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[4]
IGNORED = [
    'Testing/Simulation/Key Generation/build/test/result.log', 'Project/DE1/db/chip.qdb',
    'Project/DE1/output_files/keygen.sof',
    'Testing/Simulation/Key Generation/testbench/work/_info', 'Testing/Simulation/Key Generation/reference/__pycache__/a.pyc',
    'Project/DE1/dni/sandboxes/generated.sopcinfo',
    'Project/DE1/tmp-clearbox/generated.tdf',
]
TRACKABLE = [
    'Project/DE1/de1_soc_top.qpf', 'Project/DE1/de1_soc_top.qsf',
    'Project/DE1/de1_soc_top.sdc', 'Source Code/Key Generation/IP/keygen_ram32_altera.v',
    'Source Code/Key Generation/IP/keygen_ram32_generic.v', 'Testing/Simulation/Key Generation/testbench/tb_keygen_full.sv',
    'Testing/Simulation/Key Generation/reference/expected_keys.json',
    'Testing/Simulation/Key Generation/scripts/run_full_verilator.py', 'Source Code/Key Generation/docs/RTL_REVIEW_VALIDATION.md',
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
