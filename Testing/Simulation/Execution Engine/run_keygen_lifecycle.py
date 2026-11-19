"""Reproduce protected-slot tests with sequential native Questa license use.

Run compile first, then boundary/rsa/real/health/engine/host. All outputs are
under build/keygen-lifecycle. Public fixture logs are test-only, never keys
generated from physical production entropy. Requires the installed vendor models.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import queue
import re
import signal
import subprocess
import sys
import threading
import time


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["compile", "boundary", "rsa", "real", "health", "engine", "host", "regression", "resources"])
    parser.add_argument("--label", default="keygen-lifecycle", help="Output directory name under build/")
    parser.add_argument("--backend", type=int, choices=[0, 1], default=0)
    parser.add_argument("--family", choices=["Agilex 5", "Cyclone V"], default="Agilex 5")
    parser.add_argument("--questa-bin", type=Path, default=Path("C:/intelFPGA_lite/24.1std/questa_fse/win64"))
    parser.add_argument("--altera-models", type=Path, default=Path("C:/intelFPGA_lite/24.1std/quartus/eda/sim_lib"))
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[3]
    if not re.fullmatch(r"[A-Za-z0-9_-]+", args.label):
        parser.error("label must contain only letters, digits, underscores or hyphens")
    build = root / "build" / args.label
    build.mkdir(parents=True, exist_ok=True)
    bench = root / "Testing/Simulation/Execution Engine"
    qsf = root / "Project/DE1/de1_soc_top.qsf"
    sources = [(qsf.parent / p).resolve() for p in re.findall(r'-name VERILOG_FILE "([^"]+)"', qsf.read_text())]
    benches = [bench / name for name in ("tb_keygen_slot.sv", "tb_keygen_engine.sv", "tb_getrandom_engine.sv")]
    models = [args.altera_models / name for name in ("220model.v", "altera_mf.v")]
    inputs = {str(p.relative_to(root)): sha(p) for p in [qsf] + sources + benches}
    if args.action == "regression":
        for directory in [root / "Source Code", root / "Testing/Simulation/Execution Engine", root / "Testing/Simulation/Symmetric Module", root / "Testing/Simulation/IO Interface"]:
            for path in directory.rglob("*"):
                if path.suffix in [".v", ".sv", ".vh", ".do"]:
                    inputs[str(path.relative_to(root))] = sha(path)
    if args.action == "resources":
        path = root / "Testing/Simulation/Key Generation/IP/tests/tb_keygen_resources.sv"
        inputs[str(path.relative_to(root))] = sha(path)
    vendor_inputs = {p.name: sha(p) for p in models}
    record = {"action": args.action, "backend": args.backend, "inputs": inputs,
              "vendor_inputs": vendor_inputs, "runner_sha256": sha(Path(__file__)), "commands": []}
    label = args.action if args.action == "compile" else f"{args.action}-{args.backend}"
    if args.action == "resources":
        label = "resources-" + args.family.replace(" ", "")
        record["compares_backends"] = [0, 1]
        record["device_family"] = args.family

    def run(tool, parameters, name, deadline=120):
        command = [str(args.questa_bin / (tool + ".exe"))] + parameters
        start = time.monotonic()
        log = build / (name + ".log")
        options = {"creationflags": subprocess.CREATE_NEW_PROCESS_GROUP} if os.name == "nt" else {"start_new_session": True}
        process = subprocess.Popen(command, cwd=build, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, bufsize=0, **options)
        messages = queue.Queue()
        chunks, pending = [], b""

        def read_output():
            try:
                while True:
                    chunk = process.stdout.read(65536)
                    if not chunk:
                        break
                    messages.put(chunk)
            finally:
                messages.put(None)

        reader = threading.Thread(target=read_output, daemon=True)
        reader.start()
        try:
            while True:
                remaining = deadline - (time.monotonic() - start)
                if remaining <= 0:
                    raise subprocess.TimeoutExpired(command, deadline)
                try:
                    chunk = messages.get(timeout=min(1, remaining))
                except queue.Empty:
                    continue
                if chunk is None:
                    break
                chunks.append(chunk)
                pending += chunk
                while b"\n" in pending:
                    line, pending = pending.split(b"\n", 1)
                    if b"KEYGEN_PROGRESS" in line:
                        print(line.decode("utf-8", errors="replace").strip(), flush=True)
            process.wait(timeout=max(0.001, deadline - (time.monotonic() - start)))
        except BaseException:
            # Terminate this invocation's entire process tree; a timed-out native
            # vsim launcher must not leave vsimk holding the shared license.
            if os.name == "nt":
                subprocess.run([str(Path(os.environ["SystemRoot"]) / "System32/taskkill.exe"),
                                "/PID", str(process.pid), "/T", "/F"], capture_output=True, timeout=10)
            else:
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
            process.wait(timeout=10)
            raise
        finally:
            reader.join(timeout=10)
            while not messages.empty():
                chunk = messages.get_nowait()
                if chunk is not None:
                    chunks.append(chunk)
            process.stdout.close()
            log.write_bytes(b"".join(chunks))
            record["commands"].append({"argv": command, "deadline_seconds": deadline,
                                       "elapsed_seconds": round(time.monotonic() - start, 3),
                                       "returncode": process.returncode, "transcript": log.name,
                                       "transcript_sha256": sha(log)})
        output = log.read_text(errors="replace")
        if process.returncode or "** Fatal:" in output or "** Error:" in output or "(Error):" in output or "Failed to open readmem" in output:
            raise RuntimeError(f"{name} failed; see {log}")
        return output

    try:
        if args.action == "compile":
            run("vlib", ["work"], "work-library")
            run("vlog", ["-vlog01compat", "+incdir+" + str(root / "Source Code/IO Interface")] + [str(p) for p in sources], "rtl-compile")
            run("vlib", ["vendor"], "vendor-library")
            run("vlog", ["-work", "vendor"] + [str(p) for p in models], "vendor-compile")
            run("vlog", ["-sv"] + [str(p) for p in benches], "bench-compile")
            (build / "compiled-inputs.json").write_text(json.dumps({"inputs": inputs, "vendor_inputs": vendor_inputs}, indent=2) + "\n")
        elif args.action == "regression":
            script = bench / "run_keygen_host_regression.do"
            output = run("vsim", ["-c", "-do", "do {" + script.as_posix() + "}"], label, 600)
            required = ["KEYGEN_HOST_REGRESSION_PASS", "TPM_LEGACY_SPI_PASS entry=240 errors=0",
                        "KEYGEN_ENGINE_RESERVATION_HOST_ELIGIBILITY_PASS", "GETRANDOM_ENGINE_OWNER_TIMEOUT_RESET_PASS",
                        "GETRANDOM_REAL_RCT_PROPAGATION_PASS", "GETRANDOM_REAL_APT_PROPAGATION_PASS",
                        "GETRANDOM_RESET_HEALTHY_RECOVERY_PASS"]
            if any(marker not in output for marker in required):
                raise RuntimeError("Missing combined-command completion marker")
            record["pass_markers"] = [line.lstrip("# ") for line in output.splitlines() if "PASS" in line]
            print("KEYGEN_HOST_REGRESSION_PASS", flush=True)
        elif args.action == "resources":
            run("vlib", ["resources"], label + "-library")
            resource_dir = root / "Source Code/Key Generation/IP"
            paths = [resource_dir / ("keygen_" + name + ".v") for name in
                     ["mult32", "mult32_generic", "mult32_altera", "ram32", "ram32_generic", "ram32_altera"]]
            run("vlog", ["-work", "resources", "-vlog01compat"] + [str(p) for p in paths], label + "-compile")
            path = root / "Testing/Simulation/Key Generation/IP/tests/tb_keygen_resources.sv"
            run("vlog", ["-work", "resources", "-sv", str(path)], label + "-bench-compile")
            script = build / (label + ".do")
            script.write_text("onerror {quit -force -code 1}\nonbreak {quit -force -code 0}\nrun -all\nquit -force -code 1\n")
            output = run("vsim", ["-c", "-L", "vendor", "-onfinish", "stop", "-gDEVICE_FAMILY=" + args.family,
                                  "resources.tb_keygen_resources", "-do", "do " + script.name], label, 180)
            if "PASS resources:" not in output:
                raise RuntimeError("Missing resource result")
            record["pass_markers"] = [line.lstrip("# ") for line in output.splitlines() if "PASS resources:" in line]
            print("\n".join(record["pass_markers"]), flush=True)
        else:
            compiled = json.loads((build / "compiled-inputs.json").read_text())
            if compiled != {"inputs": inputs, "vendor_inputs": vendor_inputs}:
                raise RuntimeError("Source/model inputs changed: rerun compile before testing")
            cases = {"boundary": 0, "rsa": 1, "real": 2, "health": 3}
            top = {"engine": "tb_keygen_engine", "host": "tb_getrandom_engine"}.get(args.action, "tb_keygen_slot")
            parameters = ["-c", "-L", "vendor", "-onfinish", "stop"]
            if args.action in cases:
                parameters += [f"-gTEST_CASE={cases[args.action]}", f"-gIP_TYPE={args.backend}"]
            parameters += ["work." + top]
            if args.action == "rsa":
                reference = root / "Testing/Simulation/Key Generation/reference"
                sys.path.insert(0, str(reference))
                from key_checker import check_key
                corpus = reference / "expected_keys.json"
                fixture = json.loads(corpus.read_text())["results"][0]
                key = {k: int(v, 16) for k, v in fixture["key"].items()}
                check_key(key)  # Independent arithmetic, primality and RSA round trips.
                expected, stimulus = [], []
                for name, count in [("n", 64), ("e", 1), ("p", 32), ("q", 32)]:
                    expected += [(key[name] >> (32 * i)) & 0xffffffff for i in reversed(range(count))]
                for prime in ["p", "q"]:
                    for value in [key[prime]] + [2] * 5:
                        stimulus += [(value >> (32 * i)) & 0xffffffff for i in reversed(range(32))]
                record["public_corpus_sha256"] = sha(corpus)
                record["independent_key_checker_sha256"] = sha(reference / "key_checker.py")
                record["directed_correctness_not_prime_search_performance"] = True
                record["fixtures"] = {}
                for name, words in [("expected", expected), ("stimulus", stimulus)]:
                    path = build / (name + ".hex")
                    path.write_text("".join(f"{w:08x}\n" for w in words))
                    record["fixtures"][path.name] = {"words": len(words), "sha256": sha(path)}
                    parameters.append("+" + name.upper() + "=" + path.name)
            # Explicit SV PASS markers below establish completed checks. A
            # simulator exit code alone cannot distinguish $finish from $fatal.
            # Avoid Tcl reads of optimized-away flags in an optimized RSA run.
            script = build / (label + ".do")
            script.write_text("onerror {quit -force -code 1}\nonbreak {quit -force -code 0}\nrun -all\nquit -force -code 1\n")
            parameters += ["-do", "do " + script.name]
            output = run("vsim", parameters, label, 7200 if args.action == "rsa" else 180)
            marker = {"engine": "KEYGEN_ENGINE_RESERVATION_HOST_ELIGIBILITY_PASS",
                      "host": "GETRANDOM_ENGINE_OWNER_TIMEOUT_RESET_PASS"}.get(args.action, "KEYGEN_SLOT_PASS")
            if marker not in output:
                raise RuntimeError("Missing explicit completion marker")
            record["pass_markers"] = [line.lstrip("# ") for line in output.splitlines() if marker in line]
            if args.action in ["real", "health"]:
                # Group entropy by each reset's three-block instantiation, then
                # independently calculate Hash_df and the first Hashgen output.
                entropy = re.findall(r"PUBLIC_ENTROPY ([0-9a-f]+)", output)
                actual = re.findall(r"PUBLIC_DRBG ([0-9a-f]+)", output)
                if not actual or len(entropy) != 3 * len(actual):
                    raise RuntimeError("Missing complete public seed/output records")
                expected_blocks = []
                for i in range(len(actual)):
                    seed = bytes.fromhex("".join(entropy[3 * i:3 * i + 3]))
                    v = b"".join(hashlib.sha256(bytes([counter]) + (440).to_bytes(4, "big") + seed).digest() for counter in [1, 2])[:55]
                    expected_blocks.append(hashlib.sha256(v).hexdigest())
                slot = "".join(re.findall(r"PUBLIC_SLOT \d+ ([0-9a-f]+)", output))
                if actual != expected_blocks or len(slot) != (64 if args.action == "real" else 32) or slot != expected_blocks[-1][:len(slot)]:
                    raise RuntimeError("Independent Hash_DRBG/slot mismatch")
                record["independent_hash_drbg_slot"] = "PASS"
                record["public_blocks_checked"] = len(actual)
            print("\n".join(record["pass_markers"]), flush=True)
        record["result"] = "PASS"
    except BaseException:
        record["result"] = "FAIL"
        raise
    finally:
        (build / (label + ".json")).write_text(json.dumps(record, indent=2) + "\n")


if __name__ == "__main__":
    main()
