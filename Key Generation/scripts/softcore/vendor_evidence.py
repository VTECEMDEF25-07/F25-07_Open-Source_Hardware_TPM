# Filename: vendor_evidence.py
# Authors: Project contributors; see Git history.
# Date: 2026-10-13
# General Description: Evidence helpers for genuine-vendor simulations; never copy vendor sources.
# AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

"""Evidence helpers for genuine-vendor simulations; never copy vendor sources."""
import hashlib
import json
import sys
from pathlib import Path


def file_hash(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def save_json(path, value):
    Path(path).write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')


def input_hashes(root, sources, models, softcore):
    files = {str(root / name): file_hash(root / name) for name in sources}
    files[str(root / 'reference/expected_keys.json')] = file_hash(root / 'reference/expected_keys.json')
    if softcore:
        for name in ('firmware/rsa_control.c', 'firmware/rsa_start.S',
                     'firmware/rsa_control.ld', 'firmware/rsa_control_manifest.json',
                     'build/full/rsa_control.hex'):
            files[str(root / name)] = file_hash(root / name)
    runners=[Path(__file__).resolve(),Path(sys.argv[0]).resolve()]
    return {'project_files': files,
            'runner_files':{str(path):file_hash(path) for path in runners if path.is_file()},
            'unmodified_vendor_models': {str(path): file_hash(path) for path in models}}


def validate_reuse(path, expected):
    if not path.exists():
        raise RuntimeError('No build provenance: compile a fresh labeled build before reuse')
    previous = json.loads(path.read_text())
    for field in ('inputs', 'simulator', 'configuration'):
        if previous.get(field) != expected[field]:
            raise RuntimeError('Stale build rejected: ' + field + ' changed')
    return previous
