"""Run: python -m unittest discover -s "Key Generation/reference" -v"""
import hashlib
import json
import unittest
from pathlib import Path
from unittest.mock import patch

import keygen_reference as ref
from key_checker import check_key, independently_probable_prime


def words_for(*values):
    for value in values:
        for shift in range(992, -1, -32):
            yield (value >> shift) & 0xFFFFFFFF


def repeating(value):
    while True:
        yield from words_for(value)


class ReferenceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        source = ref.Sha256Words((1).to_bytes(32, "big"))
        cls.key = ref.generate_key(source.word)
        cls.consumed = source.words

    def test_full_2048_generation_and_independent_check(self):
        check_key(self.key)

    def test_sha_stream_definition_and_boundary(self):
        seed = bytes(32)
        source = ref.Sha256Words(seed)
        expected = b"".join(hashlib.sha256(b"KEYGEN-TEST-v1\x00" + seed + i.to_bytes(8, "big")).digest()
                            for i in range(2))
        actual = b"".join(source.word().to_bytes(4, "big") for _ in range(16))
        self.assertEqual(actual, expected)
        self.assertEqual(source.words, 16)

    def test_fixture_manifest(self):
        manifest = json.loads(Path(ref.__file__).with_name("seeds.json").read_text())
        self.assertTrue(manifest["test_only"])
        self.assertEqual([x["seed_hex"] for x in manifest["seeds"]],
                         [i.to_bytes(32, "big").hex() for i in range(1, 21)])

    def test_input_order_and_validation(self):
        self.assertEqual(ref.read_integer(iter([0x01234567, 0x89ABCDEF]).__next__, 64),
                         0x0123456789ABCDEF)
        with self.assertRaises(ref.GenerationFailure):
            ref.read_integer(lambda: -1)

    def test_range_rejection_does_not_count_failure(self):
        p = self.key["p"]
        stream = words_for(0, ref.LOWER_BOUND - 2, p, 2, 2, 2, 2, 2)
        trace = []
        self.assertEqual(ref.generate_prime(stream.__next__, trace=trace), p)
        self.assertEqual(sum(x["event"] == "range_rejected" for x in trace), 2)
        self.assertEqual(trace[-1]["failures"], 0)

    def test_q_separation_rejection_does_not_count_failure(self):
        p, q = self.key["p"], self.key["q"]
        stream = words_for(p, p + 2, q, 2, 2, 2, 2, 2)
        trace = []
        self.assertEqual(ref.generate_prime(stream.__next__, p, trace), q)
        self.assertEqual(sum(x["event"] == "separation_rejected" for x in trace), 2)
        self.assertEqual(trace[-1]["failures"], 0)

    def test_witness_rejection_boundaries(self):
        p = self.key["p"]
        stream = words_for(0, 1, p - 1, p, (1 << 1024) - 1, 2, p - 2, 2, 2, 2)
        trace = []
        self.assertTrue(ref.probable_prime(p, stream.__next__, trace))
        self.assertEqual(sum(x["event"] == "witness_rejected" for x in trace), 5)
        self.assertEqual(sum(x["event"] == "witness_accepted" for x in trace), 5)

    def test_exact_p_and_q_retry_limits(self):
        # Odd candidate == 1 modulo e, so no witness consumption is possible.
        multiple = (ref.LOWER_BOUND + ref.EXPONENT - 1) // ref.EXPONENT
        multiple += multiple & 1
        bad = multiple * ref.EXPONENT + 1
        for other, limit in ((None, 10240), ((1 << 1024) - 1, 20480)):
            stream = repeating(bad)
            trace = []
            with self.assertRaisesRegex(ref.GenerationFailure, str(limit)):
                ref.generate_prime(stream.__next__, other, trace)
            self.assertEqual(trace[-1]["failures"], limit)
            self.assertEqual(sum(x["event"] == "candidate" for x in trace), limit)
            self.assertFalse(any(x["event"].startswith("witness") for x in trace))

    def test_composite_is_rejected(self):
        square = ((1 << 512) - 1) ** 2
        self.assertFalse(ref.probable_prime(square, repeating(2).__next__))
        for value in (0, 1, 4, 561, 1105, 3215031751):
            self.assertFalse(independently_probable_prime(value))

    def test_trial_division_counts_failure_without_consuming_witness(self):
        composite = ((ref.LOWER_BOUND + 2) // 3) * 3
        if composite % 2 == 0:
            composite += 3
        p = self.key["p"]
        stream = words_for(composite, p, 2, 2, 2, 2, 2)
        trace = []
        self.assertEqual(ref.generate_prime(stream.__next__, trace=trace), p)
        self.assertEqual(trace[-1]["failures"], 1)
        self.assertEqual(sum(x["event"] == "trial_division_rejected" for x in trace), 1)
        self.assertEqual(sum(x["event"] == "witness_accepted" for x in trace), 5)

    def test_low_d_regenerates_both_primes(self):
        # Inject only the rare arithmetic result; production constants and code stay unchanged.
        p, q = self.key["p"], self.key["q"]
        trace = []
        with patch.object(ref, "generate_prime", side_effect=[p, q, p, q]) as prime:
            with patch.object(ref, "private_exponent", side_effect=[1, self.key["d"]]):
                self.assertEqual(ref.generate_key(lambda: 0, trace), self.key)
        self.assertEqual(prime.call_count, 4)
        self.assertEqual(trace, [{"event": "pair_restarted_low_d"}])

    def test_checker_rejects_mutated_components(self):
        for name in ("n", "e", "p", "q", "d"):
            broken = dict(self.key)
            broken[name] += 2
            with self.assertRaises(ValueError, msg=name):
                check_key(broken)

    def test_repeatable_source_produces_same_key(self):
        source = ref.Sha256Words((1).to_bytes(32, "big"))
        self.assertEqual(ref.generate_key(source.word), self.key)
        self.assertEqual(source.words, self.consumed)


if __name__ == "__main__":
    unittest.main(verbosity=2)
