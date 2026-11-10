"""Offline control/failure tests only; no hardware or private-key arithmetic."""
import json
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch
from validate_keygen_module import measure, MESSAGES

CORPUS = Path(__file__).parents[1] / 'Simulation/Key Generation/reference/expected_keys.json'
PUBLIC_N = [int(row['key']['n'], 16) for row in json.loads(CORPUS.read_text())['results'][:3]]


class Public:
    def __init__(self, client, n):
        self.client, self.modulus, self.exponent = client, n, client.exponent

    def encrypt_on_laptop(self, message):
        ciphertext = len(self.client.messages).to_bytes(256, 'big')
        self.client.messages[ciphertext] = message
        return ciphertext[:-1] if self.client.bad_width else ciphertext


class Fake:
    provider = 0
    exponent = 65537
    bits = 2048
    hz = 50_000_000
    duplicate = False
    mismatch = False
    zero_handle = False
    bad_factor = False
    bad_width = False
    timeout = False

    def __init__(self):
        self.generated, self.decrypted = 0, 0
        self.messages = {}

    def startup(self):
        pass

    def capabilities(self):
        return SimpleNamespace(core_hz=self.hz, rsa_bits=self.bits)

    def generate_rsa_public(self):
        self.generated += 1
        n = PUBLIC_N[0 if self.duplicate else self.generated - 1]
        if self.bad_factor:
            n = 3 * ((1 << 2046) + 1)
        return 0 if self.zero_handle else 0x80000000 + self.generated, Public(self, n)

    def decrypt_rsa(self, handle, ciphertext):
        self.decrypted += 1
        if self.timeout:
            raise TimeoutError('controlled incomplete FPGA response')
        return b'wrong actual board bytes' if self.mismatch else self.messages[ciphertext]


class Tests(unittest.TestCase):
    def run_case(self, fake, samples=3):
        record = dict(status='RUNNING', evidence_kind='SIMULATION', method='mock driver-control test only')
        ticks = iter(range(0, 100_000_000, 1_000_000))
        with patch('validate_keygen_module.time.monotonic_ns', side_effect=lambda: next(ticks)):
            return measure(fake, samples, record)

    def test_three_distinct_keys_and_exact_denominator(self):
        f = Fake()
        r = self.run_case(f)
        self.assertEqual((f.generated, f.decrypted), (3, 24))
        self.assertEqual((r['generated_keys'], r['distinct_moduli'], r['private_roundtrips_passed'], r['private_roundtrips_total']), (3, 3, 24, 24))
        self.assertEqual(r['generation_host_seconds'], dict(median=.001, minimum=.001, maximum=.001))
        self.assertEqual(r['evidence_kind'], 'SIMULATION')
        self.assertFalse(r['core_cycle_measurement'])
        self.assertFalse(r['private_context_exported'])
        self.assertEqual([c['message_bytes'] for c in r['keys'][0]['roundtrips']], [len(m) for m in MESSAGES])
        for case,message in zip(r['keys'][0]['roundtrips'],MESSAGES):
            self.assertEqual(bytes.fromhex(case['message_hex']),message)
            self.assertEqual(bytes.fromhex(case['returned_plaintext_hex']),message)
            self.assertEqual(len(bytes.fromhex(case['ciphertext_hex'])),256)
            self.assertIsNone(case['worker_cycles64'])

    def test_duplicate_modulus(self):
        f = Fake(); f.duplicate = True
        with self.assertRaisesRegex(RuntimeError, 'uniqueness'):
            self.run_case(f)

    def test_actual_plaintext_mismatch(self):
        f = Fake(); f.mismatch = True
        with self.assertRaisesRegex(RuntimeError, 'Actual FPGA private result mismatch'):
            self.run_case(f)

    def test_test_provider_denied(self):
        f = Fake(); f.provider = 1
        with self.assertRaisesRegex(RuntimeError, 'no fallback'):
            self.run_case(f)
        self.assertEqual(f.generated, 0)

    def test_wrong_profile(self):
        f = Fake(); f.bits = 1024
        with self.assertRaises(RuntimeError): self.run_case(f)

    def test_zero_handle(self):
        f = Fake(); f.zero_handle = True
        with self.assertRaises(RuntimeError): self.run_case(f)

    def test_small_prime_factor(self):
        f = Fake(); f.bad_factor = True
        with self.assertRaisesRegex(RuntimeError, 'small-prime'):
            self.run_case(f)

    def test_wrong_exponent(self):
        f = Fake(); f.exponent = 3
        with self.assertRaises(RuntimeError): self.run_case(f)

    def test_short_ciphertext(self):
        f = Fake(); f.bad_width = True
        with self.assertRaisesRegex(RuntimeError, 'ciphertext width'):
            self.run_case(f)
        self.assertEqual(f.decrypted, 0)

    def test_timeout_is_failure(self):
        f = Fake(); f.timeout = True
        with self.assertRaises(TimeoutError): self.run_case(f)


if __name__ == '__main__':
    unittest.main()
