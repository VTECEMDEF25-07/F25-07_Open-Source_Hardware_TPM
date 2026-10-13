import sys
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from fan_monitor import diagnostic_telemetry, healthy, identify_fan


class ReadOnlyAdapter:
    def __init__(self):
        self.values = {0: 0x46414E31, 13: 0x0020001E, 14: 4000, 15: 0x300,
                       32: 0, 33: 0x80278000, 34: 0x55421020}
        self.values.update({index: 0xAAAAAAAA for index in range(24, 32)})

    def register(self, index):
        return self.values[index]


class FanMonitorTests(unittest.TestCase):
    def setUp(self):
        self.adapter = ReadOnlyAdapter()
        self.manifest = {"fan_diagnostics_version": 1, "diagnostic_mode": True,
                         "build_fingerprint": "a" * 64}

    def test_bound_identity(self):
        self.assertEqual(identify_fan(self.adapter, self.manifest), "a" * 64)
        self.adapter.values[0] = 0x4B473031
        with self.assertRaises(RuntimeError):
            identify_fan(self.adapter, self.manifest)
        self.manifest["diagnostic_mode"] = False
        self.assertEqual(identify_fan(self.adapter, self.manifest), "a" * 64)

    def test_wrong_fingerprint_or_missing_capability(self):
        self.adapter.values[24] ^= 1
        with self.assertRaises(RuntimeError):
            identify_fan(self.adapter, self.manifest)
        self.manifest.pop("fan_diagnostics_version")
        with self.assertRaises(RuntimeError):
            identify_fan(self.adapter, self.manifest)

    def test_byte_fields(self):
        sample = diagnostic_telemetry(self.adapter)
        self.assertEqual((sample["manufacturer"], sample["device"], sample["local_low"],
                          sample["remote1_low"]), (0x55, 0x42, 0x10, 0x20))
        self.assertEqual((sample["remote2_high"], sample["remote2_low"], sample["raw_sensor_status"]),
                         (0x27, 0x80, 0x80))
        self.assertTrue(healthy(sample))

    def test_wait_is_not_a_fault_but_each_reason_is(self):
        self.adapter.values[32] = 256
        sample = diagnostic_telemetry(self.adapter)
        self.assertTrue(sample["conversion_wait"])
        self.assertTrue(healthy(sample))
        for bit in range(8):
            self.adapter.values[32] = 1 << bit
            sample = diagnostic_telemetry(self.adapter)
            self.assertEqual(len(sample["fan_fault_reasons"]), 1)
            self.assertFalse(healthy(sample))

    def test_full_speed_fallback_cannot_pass_as_normal(self):
        self.adapter.values[14] = 7000
        self.adapter.values[15] |= 1024
        self.assertFalse(healthy(diagnostic_telemetry(self.adapter)))


if __name__ == "__main__":
    unittest.main()
