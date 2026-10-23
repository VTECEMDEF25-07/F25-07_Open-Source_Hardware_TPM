#!/usr/bin/env python3
# Filename: summarize_hardware.py
# Authors: Project contributors; see Git history.
# Date: 2026-10-13
# General Description: Provides summarize hardware support for the key-generation implementation and verification.
# AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

"""Independently audit corpus reports; this is not whole-system acceptance."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import statistics


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def audit(report, seed_hash):
    errors = []
    def require(condition, message):
        if not condition:
            errors.append(message)
    require(report.get("action") == "corpus", "not a corpus report")
    require(report.get("result") == "PASS", "host run did not pass")
    require(report.get("test_mode") is True, "test-build identity missing")
    control, backend = report.get("control"), report.get("backend")
    require(control == "rtl", "unknown controller")
    require(backend in ("generic", "altera"), "unknown backend")
    require(bool(re.fullmatch(r"[0-9a-f]{64}", report.get("build_fingerprint", ""))),
            "missing build fingerprint")
    seed_hashes = [value for name, value in report.get("inputs_sha256", {}).items()
                   if name.replace("\\", "/").split("/")[-1] == "seeds.json"]
    require(seed_hashes == [seed_hash], "seed provenance differs or is ambiguous")
    rows = report.get("results", [])
    require(len(rows) == 20, "exactly twenty completed results required")
    require(sorted(str(row.get("seed_id")) for row in rows) ==
            sorted(str(index) for index in range(1, 21)), "seed set must be 1..20 exactly once")
    times, runtimes, temperatures, speeds = [], [], [], []
    thermal_faults = 0
    for index, row in enumerate(rows):
        prefix = f"result {index + 1}: "
        require(row.get("result") == "PASS" and row.get("profile") == 2,
                prefix + "not a passed RSA operation")
        cycles, seconds, elapsed = (row.get(name) for name in
                                   ("core_cycles", "core_seconds", "host_operation_seconds"))
        valid = (type(cycles) is int and cycles > 0 and
                 type(seconds) in (int, float) and math.isfinite(seconds) and seconds > 0 and
                 type(elapsed) in (int, float) and math.isfinite(elapsed) and elapsed > 0)
        require(valid, prefix + "missing or invalid timing")
        if valid:
            require(math.isclose(seconds, cycles / 50_000_000, rel_tol=0, abs_tol=1e-9),
                    prefix + "cycle/second mismatch")
            require(elapsed <= 180, prefix + "host deadline exceeded")
            require(seconds <= 180, prefix + "core deadline exceeded")
            require(elapsed + 1e-6 >= seconds, prefix + "host duration shorter than core duration")
            times.append(seconds)
            runtimes.append({"seed": row.get("seed_id"), "core_cycles": cycles,
                             "core_seconds": seconds, "host_seconds": elapsed})
        samples = row.get("fan_samples", [])
        require(bool(samples), prefix + "no cooling samples")
        for sample in samples:
            healthy = (sample.get("fan_fail_safe") is False and
                       sample.get("i2c_ready") is True and sample.get("alarm") == 0 and
                       not sample.get("fan_fault_reasons", []) and
                       type(sample.get("fan_rpm")) in (int, float) and
                       math.isfinite(sample["fan_rpm"]) and sample["fan_rpm"] > 0)
            if not healthy:
                thermal_faults += 1
            for name in ("fpga_c", "board_c"):
                value = sample.get(name)
                valid_temperature = type(value) in (int, float) and math.isfinite(value)
                require(valid_temperature, prefix + "invalid temperature sample")
                if valid_temperature:
                    temperatures.append(value)
            if type(sample.get("fan_rpm")) in (int, float) and math.isfinite(sample["fan_rpm"]):
                speeds.append(sample["fan_rpm"])
    median = statistics.median(times) if times else None
    require(median is not None and median <= 30, "median exceeds target or is unavailable")
    require(thermal_faults == 0, f"{thermal_faults} unhealthy cooling samples")
    return {"variant": f"{control}_{backend}", "build_fingerprint": report.get("build_fingerprint"),
            "corpus_gate_pass": not errors, "errors": errors,
            "completed_results": len(rows), "median_core_seconds": median,
            "max_core_seconds": max(times) if times else None,
            "max_reported_temperature_c": max(temperatures) if temperatures else None,
            "fan_rpm_range": [min(speeds), max(speeds)] if speeds else None,
            "unhealthy_cooling_samples": thermal_faults, "runtimes": runtimes,
            "scope": "Host-reported corpus results/timing and sampled cooling only; not release acceptance or independent bitstream/source binding."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("reports", nargs="+", type=Path)
    args = parser.parse_args()
    seed_hash = digest(Path(__file__).resolve().parents[1] / "reference" / "seeds.json")
    results = []
    for path in args.reports:
        result = audit(json.loads(path.read_text(encoding="utf-8-sig")), seed_hash)
        result.update(report=str(path.resolve()), report_sha256=digest(path))
        results.append(result)
    variants = [result["variant"] for result in results]
    unique = len(set(variants)) == len(variants)
    print(json.dumps({"corpus_reports": results, "unique_variants": unique}, indent=2))
    raise SystemExit(0 if unique and all(result["corpus_gate_pass"] for result in results) else 1)


if __name__ == "__main__":
    main()
