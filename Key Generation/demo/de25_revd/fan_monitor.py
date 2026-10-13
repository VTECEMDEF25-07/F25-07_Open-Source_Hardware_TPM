"""Read-only cooling diagnostics for explicitly fingerprinted test images."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import time
from host_test import SpiAdapter, telemetry
from fan_diagnostics import read_diagnostics


def identify_fan(adapter, manifest):
    if manifest.get("fan_diagnostics_version") != 1:
        raise RuntimeError("manifest lacks supported fan diagnostics")
    expected_identity = 0x46414E31 if manifest.get("diagnostic_mode") is True else 0x4B473031
    if adapter.register(0) != expected_identity:
        raise RuntimeError("loaded diagnostic/keygen image identity differs from manifest")
    fingerprint = "".join(f"{adapter.register(index):08x}" for index in range(24, 32))
    expected = manifest.get("build_fingerprint", "")
    if len(expected) != 64 or expected == "0" * 64 or expected != fingerprint:
        raise RuntimeError("loaded build fingerprint differs from manifest")
    return fingerprint


def diagnostic_telemetry(adapter):
    sample = telemetry(adapter)
    sample.update(read_diagnostics(adapter))
    return sample


def healthy(sample):
    return (sample["i2c_ready"] and not sample["fan_fail_safe"] and
            not sample["fan_fault_reasons"] and sample["alarm"] == 0 and sample["fan_rpm"] > 0)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--report", required=True, type=Path)
    parser.add_argument("--samples", type=int, default=30)
    args = parser.parse_args()
    if not 10 <= args.samples <= 600:
        parser.error("samples must be between 10 and 600")
    manifest_bytes = args.manifest.read_bytes()
    manifest = json.loads(manifest_bytes.decode("utf-8-sig"))
    sources = [Path(__file__).resolve(), Path(__file__).with_name("host_test.py"),
               Path(__file__).with_name("fan_diagnostics.py")]
    hashes = {str(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in sources}
    report = {"result": "RUNNING", "started_utc": datetime.now(timezone.utc).isoformat(),
              "manifest_sha256": hashlib.sha256(manifest_bytes).hexdigest(), "inputs_sha256": hashes,
              "samples": [], "scope": "Cooling diagnostic only; no key-generation acceptance."}
    args.report.parent.mkdir(parents=True, exist_ok=True)
    if args.report.exists():
        raise RuntimeError("use a fresh report path to preserve previous evidence")
    try:
        with SpiAdapter() as adapter:
            report["build_fingerprint"] = identify_fan(adapter, manifest)
            for index in range(args.samples):
                sample = diagnostic_telemetry(adapter)
                sample["observed_utc"] = datetime.now(timezone.utc).isoformat()
                report["samples"].append(sample)
                args.report.write_text(json.dumps(report, indent=2) + "\n")
                print(json.dumps(sample), flush=True)
                if index + 1 < args.samples:
                    time.sleep(1)
            if not all(healthy(sample) for sample in report["samples"][-10:]):
                raise RuntimeError("last ten cooling samples are not all healthy")
        if hashes != {str(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in sources}:
            raise RuntimeError("monitor input files changed during observation")
        report["result"] = "PASS"
    except Exception as error:
        report.update(result="FAIL", error=str(error), cleanup_errors=getattr(error, "cleanup_errors", []))
    args.report.write_text(json.dumps(report, indent=2) + "\n")
    print(report["result"] + ": " + str(args.report))
    raise SystemExit(0 if report["result"] == "PASS" else 1)


if __name__ == "__main__":
    main()
