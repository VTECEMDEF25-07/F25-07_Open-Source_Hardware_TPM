import copy
import unittest
from summarize_hardware import audit


def fixture():
    return {"action": "corpus", "result": "PASS", "test_mode": True,
            "control": "softcore", "backend": "altera", "build_fingerprint": "a" * 64,
            "inputs_sha256": {"C:\\reference\\seeds.json": "seed-hash"},
            "results": [{"seed_id": seed, "profile": 2, "result": "PASS",
                         "core_cycles": 1_000_000_000, "core_seconds": 20,
                         "host_operation_seconds": 21,
                         "fan_samples": [{"fan_fail_safe": False, "i2c_ready": True,
                                          "alarm": 0, "fan_rpm": 4000, "fpga_c": 32,
                                          "board_c": 30, "temperature_valid": False}]}
                        for seed in range(1, 21)]}


class CorpusAuditTests(unittest.TestCase):
    def test_healthy_report_and_missed_pulse(self):
        result = audit(fixture(), "seed-hash")
        self.assertTrue(result["corpus_gate_pass"])
        self.assertEqual(result["median_core_seconds"], 20)
        self.assertEqual(result["max_reported_temperature_c"], 32)

    def test_incomplete_duplicate_or_wrong_profile(self):
        for change in (lambda r: r["results"].pop(),
                       lambda r: r["results"][0].update(seed_id=2),
                       lambda r: r["results"][0].update(profile=0)):
            report = fixture()
            change(report)
            self.assertFalse(audit(report, "seed-hash")["corpus_gate_pass"])

    def test_failed_run_and_provenance(self):
        report = fixture()
        report["result"] = "RUNNING"
        self.assertFalse(audit(report, "seed-hash")["corpus_gate_pass"])
        self.assertFalse(audit(fixture(), "different-seeds")["corpus_gate_pass"])

    def test_invalid_or_inconsistent_runtime(self):
        for change in ({"core_seconds": float("nan")}, {"core_cycles": -1},
                       {"core_seconds": 21}, {"host_operation_seconds": 180.001},
                       {"host_operation_seconds": float("inf")}):
            report = fixture()
            report["results"][0].update(change)
            self.assertFalse(audit(report, "seed-hash")["corpus_gate_pass"])

    def test_slow_median(self):
        report = fixture()
        for row in report["results"]:
            row.update(core_seconds=31, core_cycles=1_550_000_000, host_operation_seconds=32)
        self.assertFalse(audit(report, "seed-hash")["corpus_gate_pass"])

    def test_each_cooling_fault_blocks_gate(self):
        for change in ({"fan_fail_safe": True}, {"i2c_ready": False},
                       {"alarm": 1}, {"fan_rpm": 0}):
            report = fixture()
            report["results"][0]["fan_samples"][0].update(change)
            result = audit(report, "seed-hash")
            self.assertFalse(result["corpus_gate_pass"])
            self.assertEqual(result["unhealthy_cooling_samples"], 1)

    def test_missing_cooling_does_not_pass(self):
        report = fixture()
        report["results"][0]["fan_samples"] = []
        self.assertFalse(audit(report, "seed-hash")["corpus_gate_pass"])

    def test_input_not_modified(self):
        report = fixture()
        before = copy.deepcopy(report)
        audit(report, "seed-hash")
        self.assertEqual(report, before)


if __name__ == "__main__":
    unittest.main()
