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
TMP = next(p / "AI/tmp" for p in SCRIPT.parents if (p / "AI/tmp").is_dir())


class EvidenceTests(unittest.TestCase):
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
            (core / "build/full").mkdir(parents=True)
            (core / "build/full/rsa_control.hex").write_text("00000000\n")
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
            manifest_path.unlink()
            with patch("sys.argv", argv), patch.object(build.subprocess, "run") as tool:
                with self.assertRaises(FileExistsError):
                    build.main()
                tool.assert_not_called()


if __name__ == "__main__":
    unittest.main()
