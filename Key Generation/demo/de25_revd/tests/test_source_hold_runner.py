# Filename: test_source_hold_runner.py
# Authors: Project contributors; see Git history.
# Date: 2026-10-13
# General Description: Checks source hold runner behavior and reports failures.
# AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

"""Fail-closed runner evidence tests: no simulator or hardware required."""
import importlib.util
from pathlib import Path
import unittest

path=Path(__file__).resolve().parents[1]/"simulate_source_hold.py"
spec=importlib.util.spec_from_file_location("source_hold_runner",path)
runner=importlib.util.module_from_spec(spec);spec.loader.exec_module(runner)

class EvidenceTests(unittest.TestCase):
    def test_clean_pass(self):
        runner.validate_result(0,"PASS SOURCE_HOLD",{"rtl":"same"},{"rtl":"same"})
    def test_missing_marker_zero_exit(self):
        with self.assertRaisesRegex(RuntimeError,"marker"):
            runner.validate_result(0,"simulation stopped early",{}, {})
    def test_failed_process_with_marker(self):
        with self.assertRaisesRegex(RuntimeError,"status"):
            runner.validate_result(1,"PASS SOURCE_HOLD",{}, {})
    def test_changed_source_even_with_pass(self):
        with self.assertRaisesRegex(RuntimeError,"source changed"):
            runner.validate_result(0,"PASS SOURCE_HOLD",{"rtl":"before"},{"rtl":"after"})
    def test_error_text_with_zero_exit(self):
        with self.assertRaisesRegex(RuntimeError,"marker"):
            runner.validate_result(0,"PASS SOURCE_HOLD\n%Error injected",{}, {})

if __name__=="__main__": unittest.main()
