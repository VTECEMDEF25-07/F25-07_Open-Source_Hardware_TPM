# Filename: test_prepare_build.py
# Authors: Project contributors; see Git history.
# Date: 2026-10-13
# General Description: Checks prepare build behavior and reports failures.
# AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

"""Offline evidence-integrity tests; no compiler or board access."""
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / "prepare_build.py"
spec = importlib.util.spec_from_file_location("prepare_build", SCRIPT)
build = importlib.util.module_from_spec(spec)
spec.loader.exec_module(build)
compile_spec = importlib.util.spec_from_file_location("compile_build", SCRIPT.with_name("compile_build.py"))
compile_build = importlib.util.module_from_spec(compile_spec)
compile_spec.loader.exec_module(compile_build)
TMP = next((p / "AI/tmp" for p in SCRIPT.parents if (p / "AI/tmp").is_dir()),
           SCRIPT.parents[2] / "build/test_prepare_tmp")
TMP.mkdir(parents=True, exist_ok=True)


class EvidenceTests(unittest.TestCase):
    def test_compiler_output_uses_pipe_and_retains_exit_code(self):
        with tempfile.TemporaryDirectory(dir=TMP) as folder:
            directory = Path(folder)
            result = subprocess.CompletedProcess([], 7, b"compiler failure details\n")
            with patch.object(compile_build.subprocess, "run", return_value=result) as run:
                self.assertEqual(compile_build.capture_compile("unused", directory), 7)
            self.assertEqual(run.call_args.kwargs["stdout"], subprocess.PIPE)
            self.assertEqual(run.call_args.kwargs["stderr"], subprocess.STDOUT)
            self.assertEqual((directory / "compile.log").read_bytes(), result.stdout)
    def test_detects_changed_input(self):
        with tempfile.TemporaryDirectory(dir=TMP) as folder:
            source = Path(folder) / "source.v"
            source.write_bytes(b"original")
            build.verify_inputs({source: b"original"})
            source.write_bytes(b"changed")
            with self.assertRaisesRegex(RuntimeError, "source changed"):
                build.verify_inputs({source: b"original"})

    def test_snapshot_hashes_and_existing_directory_rejection(self):
        with tempfile.TemporaryDirectory(dir=TMP) as folder:
            root = Path(folder)
            core = root / "core"
            (core / "rtl/common").mkdir(parents=True)
            (core / "rtl/common/keygen_core.v").write_text("module keygen_core; endmodule\n")
            argv = [str(SCRIPT), "--core-root", str(core), "--build-root", str(root / "out"),
                    "--variant", "rtl_generic"]
            version = subprocess.CompletedProcess([], 0, "Quartus test version\n", "")
            with patch("sys.argv", argv), patch.object(build.subprocess, "run", return_value=version) as tool:
                build.main()
                self.assertEqual(tool.call_count, 1)
            project = root / "out/rtl_generic"
            manifest_path = project / "build_manifest.json"
            original_manifest = manifest_path.read_bytes()
            manifest = json.loads(original_manifest)
            self.assertEqual(manifest["quartus_version"], "Quartus test version")
            self.assertFalse((project / "rsa_control.hex").exists())
            self.assertNotIn("firmware_sha256", manifest)
            compile_build.verify(project, manifest)
            settings = project / "keygen_de25.sdc"
            original_settings = settings.read_bytes()
            settings.write_bytes(original_settings+b"# changed\n")
            with self.assertRaisesRegex(RuntimeError, "configuration changed"):
                compile_build.verify(project, manifest)
            settings.write_bytes(original_settings)
            expected_fingerprint = build.digest(json.dumps(manifest["fingerprint_inputs"], sort_keys=True, separators=(",", ":")).encode())
            self.assertEqual(manifest["build_fingerprint"], expected_fingerprint)
            self.assertIn("256'h"+expected_fingerprint, (project / "keygen_de25.qsf").read_text())
            for name, expected in manifest["config_sha256"].items():
                self.assertEqual(build.digest((project / name).read_bytes()), expected)
            for name, expected in manifest["snapshot_sha256"].items():
                self.assertEqual(build.digest(Path(name).read_bytes()), expected)
            self.assertEqual(list(manifest["source_sha256"].values()),
                             list(manifest["snapshot_sha256"].values()))
            with patch("sys.argv", argv), patch.object(build.subprocess, "run") as tool:
                with self.assertRaises(FileExistsError):
                    build.main()
                tool.assert_not_called()
            self.assertEqual(manifest_path.read_bytes(), original_manifest)
            second_argv = [str(root / "out2") if x == str(root / "out") else x for x in argv]
            with patch("sys.argv", second_argv), patch.object(build.subprocess, "run", return_value=version):
                build.main()
            second = json.loads((root / "out2/rtl_generic/build_manifest.json").read_text())
            self.assertEqual(second["build_fingerprint"], expected_fingerprint)
            manifest_path.unlink()
            with patch("sys.argv", argv), patch.object(build.subprocess, "run") as tool:
                with self.assertRaises(FileExistsError):
                    build.main()
                tool.assert_not_called()


if __name__ == "__main__":
    unittest.main()
