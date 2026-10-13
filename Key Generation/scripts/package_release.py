#!/usr/bin/env python3
"""Package explicitly selected, reviewed demo evidence; never flash or publish."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import math
from pathlib import Path, PurePosixPath

from summarize_hardware import audit

VARIANTS = {f'{control}_{backend}' for control in ('rtl', 'softcore')
            for backend in ('generic', 'altera')}
ROLES = {'aes', 'corpus', 'reset-replay', 'stall-replay', 'fault-replay', 'soak'}
PROVENANCE = {'host_test.py': 'demo/de25_revd/host_test.py',
              'fan_diagnostics.py': 'demo/de25_revd/fan_diagnostics.py',
              **{name: 'reference/'+name for name in
                 ('key_checker.py', 'keygen_reference.py', 'seeds.json', 'expected_keys.json')}}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def read_json(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def basename(path):
    return str(path).replace('\\', '/').split('/')[-1]


def finite(value):
    return type(value) in (int, float) and math.isfinite(value)


def healthy(sample):
    return (sample.get('fan_fail_safe') is False and sample.get('i2c_ready') is True
            and sample.get('alarm') == 0 and finite(sample.get('fan_rpm'))
            and sample['fan_rpm'] > 0 and not sample.get('fan_fault_reasons')
            and all(finite(sample.get(name)) for name in ('fpga_c', 'board_c')))


def report_gate(report, role, variant, fingerprint, provenance):
    require(report.get('result') == 'PASS' and report.get('action') == role,
            f'{variant}: missing/failed {role}')
    require(report.get('test_mode') is True and report.get('build_fingerprint') == fingerprint
            and f"{report.get('control')}_{report.get('backend')}" == variant,
            f'{variant}: {role} identity mismatch')
    actual = {}
    for name, value in report.get('inputs_sha256', {}).items():
        base = name.replace('\\', '/').split('/')[-1]
        require(base not in actual, 'ambiguous host provenance')
        actual[base] = value
    require(actual == provenance, f'{variant}: {role} tester/reference provenance differs')
    rows = report.get('results', [])
    require(rows and all(row.get('result') == 'PASS' for row in rows), 'empty/failed hardware results')
    for row in rows:
        if 'profile' in row and 'fault_boundary' not in row:
            cycles, seconds, elapsed = (row.get(key) for key in
                                        ('core_cycles', 'core_seconds', 'host_operation_seconds'))
            require(type(cycles) is int and cycles > 0 and finite(seconds) and seconds > 0
                    and finite(elapsed) and seconds <= elapsed+1e-6 <= 180.000001
                    and math.isclose(seconds, cycles/50_000_000, rel_tol=0, abs_tol=1e-9),
                    'invalid operation timing/deadline')
            require(row.get('fan_samples') and all(healthy(s) for s in row['fan_samples']),
                    'missing/unhealthy operation cooling')
        elif 'reset_boundary' in row:
            require(healthy(row.get('fan', {})), 'missing/unhealthy reset cooling')
        else:
            require(finite(row.get('host_operation_seconds')) and 0 < row['host_operation_seconds'] <= 180
                    and row.get('fan_samples') and all(healthy(s) for s in row['fan_samples']),
                    'missing/unhealthy failure timing/cooling')
    if role == 'corpus':
        result = audit(report, provenance['seeds.json'])
        require(result['corpus_gate_pass'], '; '.join(result['errors']))
    elif role == 'aes':
        require(sorted(row.get('profile') for row in rows) == [0, 1], 'AES128/256 required')
    elif role == 'reset-replay':
        expected = {'generation_stall', 'rsa_active', 'result_stall', 'ownership_stall', 'held_success'}
        boundaries = [r['reset_boundary'] for r in rows if 'reset_boundary' in r]
        replay = [r for r in rows if r.get('reset_replay') is True]
        require(len(rows) == 8 and len(boundaries) == 5 and set(boundaries) == expected
                and sorted(r.get('profile') for r in replay) == [0, 1, 2], 'incomplete reset replay')
    elif role == 'fault-replay':
        failures = [r for r in rows if 'fault_boundary' in r]
        replay = [r for r in rows if r.get('fault_replay') is True]
        profiles = {'generation_stall': 2, 'rsa_active': 2, 'result_stall': 0, 'ownership_stall': 1}
        require(len(rows) == 7 and len(failures) == 4
                and {r['fault_boundary'] for r in failures} ==
                    {'generation_stall', 'rsa_active', 'result_stall', 'ownership_stall'}
                and all(r.get('expected_status') == 2 and r.get('observed_status') == 2
                        and r.get('no_stale_result') is True
                        and r.get('profile') == profiles.get(r['fault_boundary']) for r in failures)
                and sorted(r.get('profile') for r in replay) == [0, 1, 2], 'incomplete generation-failure replay')
    elif role == 'stall-replay':
        require(len(rows) == 2 and {r.get('replay') for r in rows} == {'baseline', 'generation_stalls'}
                and all(r.get('profile') == 2 for r in rows)
                and len({r.get('seed_id') for r in rows}) == 1, 'incomplete deterministic stall replay')
        stalled = next(r for r in rows if r['replay'] == 'generation_stalls')
        transitions = stalled.get('source_transitions', [])
        require(len(transitions) == 4, 'stall schedule did not complete')
        for transition, scheduled, hold in zip(transitions, (.02, .12, .20, .30), (True, False, True, False)):
            require(transition.get('scheduled_seconds') == scheduled and transition.get('hold_generation') is hold
                    and finite(transition.get('observed_seconds')) and scheduled <= transition['observed_seconds'] <= 180,
                    'stall schedule evidence differs')
        require(all(a['observed_seconds'] <= b['observed_seconds'] for a, b in zip(transitions, transitions[1:])),
                'stall transitions out of order')
    elif role == 'soak':
        elapsed = [r.get('soak_elapsed_seconds') for r in rows]
        require(finite(report.get('soak_seconds')) and report['soak_seconds'] >= 1800
                and report.get('soak_jobs') == len(rows) and len(rows) >= 3
                and all(finite(t) and t > 0 for t in elapsed)
                and all(a < b for a, b in zip(elapsed, elapsed[1:]))
                and elapsed[-1] >= 1800 and elapsed[-1] <= report['soak_seconds']
                and all(r.get('profile') == i % 3 and r.get('seed_id') == (i//3)%20+1
                        for i, r in enumerate(rows)),
                'soak must complete at least 30 minutes of alternating AES128/AES256/RSA jobs')


class Payload:
    def __init__(self):
        self.files = {}
        self.inputs = {}

    def add(self, source, destination, expected=None):
        source = Path(source).resolve()
        target = PurePosixPath(destination)
        require(not target.is_absolute() and '..' not in target.parts and ':' not in destination,
                'unsafe package destination')
        require(not any(part.lower() in ('qdb', 'db', 'incremental_db') for part in source.parts)
                and not source.name.lower().endswith(('220model.v', 'altera_mf.v')),
                'proprietary model/build database excluded')
        require(str(target) not in self.files, 'duplicate package destination')
        data = source.read_bytes()
        require(len(data) <= 64*1024*1024, 'file exceeds compact package limit')
        require(expected is None or sha(data) == expected, f'hash mismatch: {source}')
        self.inputs[source] = sha(data)
        self.files[str(target)] = data
        return data

    def unchanged(self):
        for path, expected in self.inputs.items():
            require(sha(path.read_bytes()) == expected, f'input changed during packaging: {path}')


def package(config, root, output):
    root, output = Path(root).resolve(), Path(output).resolve()
    require(not output.exists(), 'output already exists; preserve prior release')
    entries = config.get('variants', {})
    require(set(entries) == VARIANTS, 'exactly four controller/backend variants required')
    payload = Payload()
    provenance = {name: sha(payload.add(root/path, 'tools/'+path)) for name, path in PROVENANCE.items()}
    for directory in ('docs', 'firmware'):
        for path in sorted((root/directory).iterdir()):
            if path.is_file():
                payload.add(path, directory+'/'+path.name)
    for relative in ('IP/third_party/picorv32/COPYING', 'IP/third_party/picorv32/README.md',
                     'demo/de25_revd/README.md', 'demo/de25_revd/FAN_MONITOR.md',
                     'scripts/softcore/build_rsa.py', 'scripts/package_release.py',
                     'scripts/summarize_hardware.py'):
        payload.add(root/relative, relative)
    firmware = read_json(root/'firmware/rsa_control_manifest.json')
    for name, expected in firmware['source_sha256'].items():
        require(sha((root/'firmware'/name).read_bytes()) == expected, 'firmware source provenance mismatch')
    matrix = Path(config['completion_matrix']).resolve()
    payload.add(matrix, 'review/COMPLETION_MATRIX.md')
    selected = {}
    for variant, entry in sorted(entries.items()):
        build, hardware = Path(entry['build_dir']).resolve(), Path(entry['hardware_dir']).resolve()
        prefix = 'variants/'+variant+'/'
        manifest = json.loads(payload.add(build/'build_manifest.json', prefix+'build_manifest.json'))
        fingerprint = manifest.get('build_fingerprint')
        require(manifest.get('variant') == variant and manifest.get('status') == 'compiled'
                and manifest.get('test_mode') is True and manifest.get('timing_accepted') is True
                and manifest.get('diagnostic_mode') is False, f'{variant}: unaccepted build')
        require(sha(json.dumps(manifest['fingerprint_inputs'], sort_keys=True,
                               separators=(',', ':')).encode()) == fingerprint, 'invalid build fingerprint')
        require(manifest['snapshot_sha256'] and
                {basename(p): value for p, value in manifest['snapshot_sha256'].items()}
                == manifest['fingerprint_inputs']['sources'], 'snapshot not bound to fingerprint')
        audit_path = build/manifest['timing_review']['audit']
        timing = json.loads(payload.add(audit_path, prefix+'acceptance_audit.json'))
        require(timing.get('status') == 'timing_resource_review_passed'
                and timing.get('variant') == variant and timing.get('build_fingerprint') == fingerprint
                and timing.get('source_snapshot_hashes_verified') is True
                and timing.get('all_tns_zero') is True and timing.get('unconstrained_ports') == 0
                and timing.get('reset_synchronizer_violations') == 0,
                f'{variant}: timing/source review missing or failed')
        slack = timing.get('minimum_slack_ns', {})
        require(set(slack) >= {'setup', 'hold', 'recovery', 'removal'}
                and all(finite(v) and v >= 0 for v in slack.values()), 'negative/missing routed timing')
        for original, expected in manifest['snapshot_sha256'].items():
            name = basename(original)
            payload.add(build/'sources'/name, prefix+'sources/'+name, expected)
        for name, expected in timing['post_tool_config_sha256'].items():
            require(Path(name).name == name, 'unexpected configuration path')
            payload.add(build/name, prefix+name, expected)
        require(manifest['firmware_sha256'] == firmware['image_sha256'], 'firmware image revision mismatch')
        require(sha((build/'rsa_control.hex').read_bytes()) == manifest['firmware_sha256']
                and sha((build/'keygen_de25.sdc').read_bytes())
                == sha(manifest['fingerprint_inputs']['sdc'].encode()), 'firmware/constraints fingerprint mismatch')
        require({'keygen_de25.sta.rpt', 'keygen_de25.fit.rpt'} <= set(timing['report_sha256']),
                'missing routed timing/resource reports')
        for name, expected in timing['report_sha256'].items():
            require(Path(name).name == name, 'unexpected timing report path')
            payload.add(build/'output_files'/name, prefix+'reports/'+name, expected)
        payload.add(build/'output_files/keygen_de25.sof', prefix+'keygen_de25.sof', timing['sof_sha256'])
        require(set(entry['reports']) == ROLES, f'{variant}: missing required hardware report role')
        for role, filename in entry['reports'].items():
            path = (hardware/filename).resolve()
            require(path.is_relative_to(hardware), 'hardware report outside explicit directory')
            report = json.loads(payload.add(path, prefix+'hardware/'+role+'.json'))
            report_gate(report, role, variant, fingerprint, provenance)
        selected[variant] = {'build_fingerprint': fingerprint, 'sof_sha256': timing['sof_sha256']}
    for evidence in config.get('evidence', []):
        path = Path(evidence['path'])
        require(path.suffix.lower() in ('.json', '.md', '.txt', '.log', '.rpt'), 'evidence must be text')
        payload.add(path, 'review/'+evidence['name'], evidence['sha256'])
    payload.unchanged()
    require(sum(map(len, payload.files.values())) <= 256*1024*1024, 'package exceeds 256 MiB')
    release = {'format': 'KEYGEN-RELEASE-v1', 'created_utc': datetime.now(timezone.utc).isoformat(),
               'status': 'PACKAGED_MACHINE_GATES_PASSED', 'test_only': True, 'variants': selected,
               'human_completion_review': 'review/COMPLETION_MATRIX.md',
               'scope': 'Selected evidence packaged; does not certify simulation coverage, timing interpretation, licensing or whole-spec completion.',
               'files_sha256': {name: sha(data) for name, data in sorted(payload.files.items())}}
    payload.files['release_manifest.json'] = (json.dumps(release, indent=2)+'\n').encode()
    sums = ''.join(f'{sha(data)}  {name}\n' for name, data in sorted(payload.files.items()))
    payload.files['SHA256SUMS'] = sums.encode()
    output.mkdir(parents=True)
    for name, data in payload.files.items():
        path = output/name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        require(sha(path.read_bytes()) == sha(data), f'output write mismatch: {path}')
    return release


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--selection', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = package(read_json(args.selection), Path(__file__).resolve().parents[1], args.output)
    print(json.dumps({'status': result['status'], 'output': str(args.output.resolve())}))


if __name__ == '__main__':
    main()
