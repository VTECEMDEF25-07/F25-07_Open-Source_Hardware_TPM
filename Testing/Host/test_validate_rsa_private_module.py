"""Synthetic artifact-schema unit tests only; never hardware validation results."""
import copy
import hashlib
import json
from pathlib import Path
import unittest
from validate_rsa_private_module import audit,SUITES


def fixture():
    source='a'*40;sof='b'*64
    phase=dict(status='PASS',source_commit=source,sof_sha256=sof,core_hz=50000000,spi_hz=100000,
        assertions_unchanged=True,suite_count=8,failure_count=0,completion_marker=True,assertion_count=8,
        log_path='UNIT-TEST-FIXTURE-NOT-HARDWARE',started_utc='2026-11-10T05:00:00+00:00',ended_utc='2026-11-10T05:01:00+00:00',
        suites=[dict(name=name,completed=True,assertion_calls=1,failures=0) for name in sorted(SUITES)])
    corpus=Path(__file__).resolve().parents[2]/'Testing/Simulation/Key Generation/reference/expected_keys.json'
    public_rows=json.loads(corpus.read_text())['results'][:2]
    record=dict(status='PASS',evidence_kind='HARDWARE',source_revision=source,sof_sha256=sof,
        core_hz=50000000,spi_hz=100000,provider='FRESH_UNQUALIFIED',entropy_qualified=False,
        private_context_exported=False,width_or_profile='RSA2048/e65537',
        started_utc='2026-11-10T05:05:00+00:00',ended_utc='2026-11-10T05:10:00+00:00',
        messages_per_key=2,samples_requested=2,generated_keys=2,distinct_moduli=2,
        private_roundtrips_passed=4,private_roundtrips_total=4,keys=[])
    for ki,public in enumerate(public_rows):
        n=int(public['key']['n'],16);e=int(public['key']['e'],16)
        key=dict(public_modulus_hex=f'{n:0512x}',public_exponent=e,handle=f'0x{0x80000001+ki:08x}',
                 public_checks_pass=True,generation_request_id=100*ki+1,roundtrips=[])
        for case,message in enumerate((b'',b'zero\0UTF8'+ 'λ'.encode()),1):
            block=b'\0DE25'+len(message).to_bytes(2,'big')+message+bytes(249-len(message))
            cipher=pow(int.from_bytes(block,'big'),e,n).to_bytes(256,'big')
            sha=hashlib.sha256(message).hexdigest()
            key['roundtrips'].append(dict(case=case,message_bytes=len(message),message_hex=message.hex(),
                ciphertext_hex=cipher.hex(),returned_plaintext_hex=message.hex(),
                expected_sha256=sha,returned_sha256=sha,actual_plaintext_match=True,
                request_id=100*ki+case+1,handle=key['handle'],worker_cycles64=None,private_decrypt_host_elapsed_s=0.5))
        record['keys'].append(key)
    return record,phase


class ArtifactAuditTests(unittest.TestCase):
    def setUp(self):self.record,self.phase=fixture()
    def reject(self):
        with self.assertRaises(ValueError):audit(self.record,self.phase)
    def test_valid_schema_not_hardware_measurement(self):
        value=audit(self.record,self.phase)
        self.assertEqual(value['denominator'],4)
        self.assertEqual(value['key_count'],2)
        self.assertIsNone(value['worker_cycles'])
    def test_reject_simulation_relabel(self):
        self.record['evidence_kind']='SIMULATION';self.reject()
    def test_reject_pending_run(self):
        self.record['status']='RUNNING';self.reject()
    def test_reject_other_sof(self):
        self.phase['sof_sha256']='c'*64;self.reject()
    def test_reject_phase1_failure(self):
        self.phase['suites'][0]['failures']=1;self.reject()
    def test_reject_conflicting_phase1_alias(self):
        self.phase['suites'][0]['status']='FAIL';self.reject()
    def test_reject_cipher_mutation(self):
        row=self.record['keys'][0]['roundtrips'][0]
        row['ciphertext_hex']='00'+row['ciphertext_hex'][2:];self.reject()
    def test_reject_actual_return_mutation_even_with_updated_hash(self):
        row=self.record['keys'][0]['roundtrips'][0]
        row['returned_plaintext_hex']='41';row['returned_sha256']=hashlib.sha256(b'A').hexdigest();self.reject()
    def test_reject_reused_id(self):
        self.record['keys'][1]['roundtrips'][0]['request_id']=1;self.reject()
    def test_reject_reduced_width(self):
        self.record['keys'][0]['public_modulus_hex']='00'+self.record['keys'][0]['public_modulus_hex'][2:];self.reject()
    def test_reject_private_material(self):
        self.record['keys'][0]['d']='01';self.reject()
    def test_reject_wrong_handle(self):
        self.record['keys'][0]['roundtrips'][0]['handle']='0x80000002';self.reject()
    def test_reject_private_id_reuses_generation_id(self):
        self.record['keys'][0]['roundtrips'][0]['request_id']=1;self.reject()
    def test_reject_partial_or_unattributed_cycle_sample(self):
        row=self.record['keys'][0]['roundtrips'][0]
        row.update(worker_cycles64=155000000,worker_status=0,worker_job_id=row['request_id']);self.reject()
    def test_reject_denominator_mismatch(self):
        self.record['private_roundtrips_total']=24;self.reject()


if __name__=='__main__':unittest.main()
