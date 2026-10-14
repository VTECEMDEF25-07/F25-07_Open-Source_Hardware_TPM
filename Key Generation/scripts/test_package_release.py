"""Offline release gate tests; synthetic evidence is never hardware acceptance."""
import json
from pathlib import Path
import tempfile
import shutil
import unittest
from unittest.mock import patch
import subprocess

import package_release as release


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        base = Path(__file__).resolve().parents[1]/'build/package_tests'
        base.mkdir(parents=True, exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(dir=base)
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)/'core'
        self.root.mkdir()
        self.output = Path(self.temp.name)/'release'
        self.config = {'variants': {}, 'completion_matrix': str(self.root/'matrix.md')}
        def write(relative, content):
            path = self.root/relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content)
            return path
        for relative in release.PROVENANCE.values():
            write(relative, relative)
        for relative in ('docs/spec.md', 'IP/third_party/picorv32/COPYING',
                         'IP/third_party/picorv32/README.md', 'demo/de25_revd/README.md',
                         'demo/de25_revd/FAN_MONITOR.md', 'scripts/softcore/build_rsa.py',
                         'demo/de25_revd/prepare_build.py', 'demo/de25_revd/compile_build.py',
                         'demo/de25_revd/vendor/pin_reference.qsf',
                         'scripts/package_release.py', 'scripts/summarize_hardware.py', 'matrix.md'):
            write(relative, 'synthetic fixture; not acceptance')
        write('firmware/rsa_control_manifest.json', json.dumps({'source_sha256': {}, 'image_sha256': release.sha(b'ROM')}))
        self.provenance = {name: release.sha((self.root/path).read_bytes()) for name, path in release.PROVENANCE.items()}
        for variant in sorted(release.VARIANTS):
            build = self.root/variant
            hardware = build/'hardware'
            hardware.mkdir(parents=True)
            source = write(variant+'/sources/core.v', 'module core; endmodule')
            config_hashes = {}
            for name, value in {'rsa_control.hex': 'ROM', 'keygen_de25.sdc': 'CLOCK',
                                'keygen_de25.qsf': 'SETTINGS', 'keygen_de25.qpf': 'PROJECT'}.items():
                config_hashes[name] = release.sha(write(variant+'/'+name, value).read_bytes())
            inputs = {'sources': {source.name: release.sha(source.read_bytes())}, 'sdc': 'CLOCK',
                      'variant': variant, 'firmware': release.sha(b'ROM'),
                      'settings_before_fingerprint': [f'set_global_assignment -name VERILOG_FILE "{source}"',
                                                     'set_global_assignment -name SDC_FILE keygen_de25.sdc']}
            fingerprint = release.sha(json.dumps(inputs, sort_keys=True, separators=(',', ':')).encode())
            manifest = {'variant': variant, 'status': 'compiled', 'test_mode': True, 'timing_accepted': True,
                        'diagnostic_mode': False, 'build_fingerprint': fingerprint, 'fingerprint_inputs': inputs,
                        'snapshot_sha256': {str(source): release.sha(source.read_bytes())},
                        'firmware_sha256': release.sha(b'ROM'), 'timing_review': {'audit': 'acceptance_audit.json'}}
            write(variant+'/build_manifest.json', json.dumps(manifest))
            sof = write(variant+'/output_files/keygen_de25.sof', 'synthetic sof')
            report_hashes = {name: release.sha(write(variant+'/output_files/'+name, 'reviewed synthetic report').read_bytes())
                             for name in ('keygen_de25.sta.rpt', 'keygen_de25.fit.rpt')}
            timing = {'variant': variant, 'status': 'timing_resource_review_passed',
                      'build_fingerprint': fingerprint, 'source_snapshot_hashes_verified': True,
                      'all_tns_zero': True, 'unconstrained_ports': 0, 'reset_synchronizer_violations': 0,
                      'minimum_slack_ns': {name: .1 for name in ('setup', 'hold', 'recovery', 'removal')},
                      'post_tool_config_sha256': config_hashes, 'report_sha256': report_hashes,
                      'sof_sha256': release.sha(sof.read_bytes())}
            write(variant+'/acceptance_audit.json', json.dumps(timing))
            reports = {}
            for role in release.ROLES:
                control, backend = variant.split('_')
                report = {'action': 'transport' if role in release.TRANSPORT else role,
                          'result': 'PASS', 'test_mode': True, 'control': control,
                          'backend': backend, 'build_fingerprint': fingerprint,
                          'inputs_sha256': self.provenance, 'results': []}
                if role in release.TRANSPORT:
                    report.update(frequency_hz=release.TRANSPORT[role], transport='PASS', partial_frame_abort='PASS')
                if role == 'corpus': report['results'] = [self.job(2, seed) for seed in range(1, 21)]
                if role == 'aes': report['results'] = [self.job(0), self.job(1)]
                if role == 'reset-replay':
                    report['results'] = [{'reset_boundary': boundary, 'result': 'PASS', 'fan': self.fan()} for boundary in
                                         ('generation_stall', 'rsa_active', 'result_stall', 'ownership_stall', 'held_success')]
                    report['results'] += [dict(self.job(profile), reset_replay=True) for profile in range(3)]
                if role == 'stall-replay':
                    transitions = [dict(scheduled_seconds=t, observed_seconds=t+.001, hold_generation=h)
                                   for t, h in zip((.02,.12,.20,.30), (True,False,True,False))]
                    report['results'] = [dict(self.job(2), replay=name, source_transitions=transitions) for name in
                                         ('baseline', 'generation_stalls')]
                if role == 'fault-replay':
                    report['results'] = [dict(fault_boundary=name, profile=profile, result='PASS', expected_status=2,
                                             observed_status=2, no_stale_result=True, fan_samples=[self.fan()],
                                             host_operation_seconds=1) for name, profile in
                                         (('generation_stall',2), ('rsa_active',2), ('result_stall',0), ('ownership_stall',1))]
                    report['results'] += [dict(self.job(i), fault_replay=True) for i in range(3)]
                if role == 'soak':
                    report['results'] = [dict(self.job(i % 3, (i//3)%20+1), soak_elapsed_seconds=(i+1)*10.1) for i in range(180)]
                    report.update(soak_seconds=1818.1, soak_jobs=180)
                reports[role] = role+'.json'
                write(variant+'/hardware/'+role+'.json', json.dumps(report))
            self.config['variants'][variant] = {'build_dir': str(build), 'hardware_dir': str(hardware), 'reports': reports}

    @staticmethod
    def fan():
        return dict(fan_fail_safe=False, i2c_ready=True, alarm=0, fan_rpm=4000, fpga_c=40, board_c=30, fan_fault_reasons=[])

    def job(self, profile, seed=1):
        return dict(profile=profile, seed_id=seed, result='PASS', core_cycles=500_000_000,
                    core_seconds=10, host_operation_seconds=10.1, fan_samples=[self.fan()])

    def mutate_report(self, role, change):
        path = self.root/'rtl_generic/hardware'/f'{role}.json'
        obj = json.loads(path.read_text()); change(obj); path.write_text(json.dumps(obj))

    def rejected(self):
        with self.assertRaises((ValueError, KeyError, FileNotFoundError)):
            release.package(self.config, self.root, self.output)
        self.assertFalse(self.output.exists())

    def test_package_hashes_every_payload_and_manifest(self):
        result = release.package(self.config, self.root, self.output)
        self.assertEqual(result['status'], 'PACKAGED_MACHINE_GATES_PASSED')
        for line in (self.output/'SHA256SUMS').read_text().splitlines():
            expected, name = line.split('  ', 1)
            self.assertEqual(release.sha((self.output/name).read_bytes()), expected)
        with self.assertRaises(ValueError): release.package(self.config, self.root, self.output)

    def test_missing_variant(self):
        self.config['variants'].pop('softcore_altera'); self.rejected()

    def test_wrong_bitstream(self):
        (self.root/'rtl_generic/output_files/keygen_de25.sof').write_text('different'); self.rejected()

    def test_unreviewed_timing(self):
        path = self.root/'rtl_generic/build_manifest.json'
        obj = json.loads(path.read_text()); obj['timing_accepted'] = False; path.write_text(json.dumps(obj)); self.rejected()

    def test_wrong_fingerprint(self):
        self.mutate_report('aes', lambda r: r.update(build_fingerprint='0'*64)); self.rejected()

    def test_snapshot_tamper(self):
        (self.root/'rtl_generic/sources/core.v').write_text('changed source'); self.rejected()

    def test_missing_timing_evidence(self):
        path = self.root/'rtl_generic/acceptance_audit.json'
        obj = json.loads(path.read_text()); obj['report_sha256'] = {}; path.write_text(json.dumps(obj)); self.rejected()

    def test_negative_timing(self):
        path = self.root/'rtl_generic/acceptance_audit.json'
        obj = json.loads(path.read_text()); obj['minimum_slack_ns']['hold'] = -.01; path.write_text(json.dumps(obj)); self.rejected()

    def test_incomplete_corpus(self):
        self.mutate_report('corpus', lambda r: r['results'].pop()); self.rejected()

    def test_failed_corpus(self):
        self.mutate_report('corpus', lambda r: r.update(result='FAIL')); self.rejected()

    def test_short_soak(self):
        self.mutate_report('soak', lambda r: r.update(soak_seconds=1799)); self.rejected()

    def test_soak_cooling_fault(self):
        self.mutate_report('soak', lambda r: r['results'][0]['fan_samples'][0].update(fan_fault_reasons=['stale'])); self.rejected()

    def test_missing_reset_boundary(self):
        self.mutate_report('reset-replay', lambda r: r['results'].pop(0)); self.rejected()

    def test_incomplete_stall_schedule(self):
        self.mutate_report('stall-replay', lambda r: r['results'][1].update(source_transitions=[])); self.rejected()

    def test_fault_status_and_stale_results(self):
        self.mutate_report('fault-replay', lambda r: r['results'][0].update(observed_status=0, no_stale_result=False)); self.rejected()

    def test_wrong_stall_polarity(self):
        self.mutate_report('stall-replay', lambda r: r['results'][1]['source_transitions'][0].update(hold_generation=False)); self.rejected()

    def test_soak_seed_rotation(self):
        self.mutate_report('soak', lambda r: r['results'][6].update(seed_id=1)); self.rejected()

    def test_missing_transport_rate(self):
        self.config['variants']['rtl_generic']['reports'].pop('transport_100000'); self.rejected()

    def test_wrong_transport_rate(self):
        self.mutate_report('transport_500000', lambda r: r.update(frequency_hz=100000)); self.rejected()

    def test_missing_configuration_hashes(self):
        path = self.root/'rtl_generic/acceptance_audit.json'
        obj = json.loads(path.read_text()); obj['post_tool_config_sha256'] = {}; path.write_text(json.dumps(obj)); self.rejected()

    def test_compressed_soak_chronology(self):
        self.mutate_report('soak', lambda r: r['results'][0].update(soak_elapsed_seconds=.001)); self.rejected()

    def test_stall_after_completed_job(self):
        self.mutate_report('stall-replay', lambda r: r['results'][1]['source_transitions'][-1].update(observed_seconds=179)); self.rejected()

    def test_fingerprint_variant_binding(self):
        path = self.root/'rtl_generic/build_manifest.json'
        obj = json.loads(path.read_text()); obj['fingerprint_inputs']['variant'] = 'softcore_generic'
        obj['build_fingerprint'] = release.sha(json.dumps(obj['fingerprint_inputs'], sort_keys=True, separators=(',', ':')).encode())
        path.write_text(json.dumps(obj)); self.rejected()

    def test_rebuild_after_package_move(self):
        release.package(self.config, self.root, self.output)
        moved = self.output.with_name('moved_package'); shutil.copytree(self.output, moved)
        fresh = self.output.with_name('fresh_build')
        with patch.object(release.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, 'Quartus test', '')):
            manifest = release.prepare_rebuild(moved, 'rtl_generic', fresh, self.root/'quartus.exe')
        self.assertEqual(manifest['status'], 'prepared'); self.assertFalse(manifest['timing_accepted'])
        self.assertNotEqual(manifest['build_fingerprint'], manifest['rebuild_of'])
        self.assertIn('"sources/core.v"', (fresh/'keygen_de25.qsf').read_text())
        self.assertNotIn(str(self.root/'rtl_generic'), (fresh/'keygen_de25.qsf').read_text())
        self.assertEqual((fresh/'rsa_control.hex').read_bytes(), b'ROM')

    def test_provenance_changed(self):
        (self.root/'reference/key_checker.py').write_text('changed'); self.rejected()

    def test_proprietary_models_and_path_escape_rejected(self):
        for name in ('220model.v', 'altera_mf.v'):
            path = self.root/name; path.write_text('not redistributable')
            with self.assertRaises(ValueError): release.Payload().add(path, name)
        with self.assertRaises(ValueError): release.Payload().add(self.root/'matrix.md', '../escape')


if __name__ == '__main__':
    unittest.main()
