"""Run real HMAC/SHA RTL against RFC 4231 and Python, then session KDFa.

Upstream SHA sources are read from pinned local Git objects into an isolated
build directory.
"""
import argparse
import hashlib
import hmac
from pathlib import Path
import subprocess
import sys


def vector(key, message, separate_end=False, execute=True):
    def packed(data):
        return "16384'h" + data.ljust(2048, b"\0").hex()
    digest = hmac.new(key, message, hashlib.sha256).hexdigest()
    lines = [f"key_blob={packed(key)}; key_length={len(key)};",
             f"message_blob={packed(message)}; message_length={len(message)};",
             f"separate_end={int(separate_end)}; expected_digest=256'h{digest};"]
    if execute:
        lines.append("run_job();")
    return "\n".join(lines)


def rfc_vectors():
    # RFC 4231 sections 4.2 through 4.8. Case 5 specifies a 128-bit prefix.
    vectors = [
        (b"\x0b"*20, b"Hi There", "b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7"),
        (b"Jefe", b"what do ya want for nothing?", "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843"),
        (b"\xaa"*20, b"\xdd"*50, "773ea91e36800e46854db8ebd09181a72959098b3ef8c122d9635514ced565fe"),
        (bytes(range(1,26)), b"\xcd"*50, "82558a389a443c0ea4cc819899f2083a85f0faa3e578f8077a2e3ff46729665b"),
        (b"\x0c"*20, b"Test With Truncation", "a3b6167473100ee06e0c796c2955552b"),
        (b"\xaa"*131, b"Test Using Larger Than Block-Size Key - Hash Key First",
         "60e431591ee0b67f0d8a26aacbf5b77f8e0bc6213728c5140546040f0ee37f54"),
        (b"\xaa"*131, b"This is a test using a larger than block-size key and a larger than block-size data. "
         b"The key needs to be hashed before being used by the HMAC algorithm.",
         "9b09ffa71b942fcb27635fbcd5b0e944bfdc63644f0713938a7f51535c3a35e2"),
    ]
    for key, message, expected in vectors:
        if not hmac.new(key, message, hashlib.sha256).hexdigest().startswith(expected):
            raise RuntimeError("RFC 4231 reference mismatch")
        yield key, message


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", type=Path, required=True)
    parser.add_argument("--questa-bin", type=Path, default=Path("C:/intelFPGA_lite/24.1std/questa_fse/win64"))
    args = parser.parse_args()
    bench = Path(__file__).resolve().parent
    repo = bench.parents[2]
    build = args.build.resolve()
    upstream = build/"upstream"
    upstream.mkdir(parents=True, exist_ok=True)
    revisions = {
        "a0a5986ae17c662d78e0a2c202c4fe51bebaabf8":
            ["Hash Module/"+name for name in ("hash_arbiter.v", "hash_engine.v", "sha256_controller.v", "sha_256.v")],
        "8a9a83787773affd83740cafa6214e3c986d356f":
            ["Source Code/Hash Module/"+name for name in
             ("input_buffer.v", "padding.v", "message_schedule.v", "round_operations.v")],
    }
    for ref, files in revisions.items():
        for path in files:
            contents = subprocess.check_output(["git", "show", f"{ref}:{path}"], cwd=repo)
            (upstream/Path(path).name).write_bytes(contents)
    (upstream/"revisions.txt").write_text("\n".join(revisions))
    cases = [vector(key, message, bool(i%2)) for i, (key, message) in enumerate(rfc_vectors())]
    for key_length in (0, 1, 32, 63, 64, 65, 128, 131, 1024):
        for message_length in (0, 1, 55, 56, 63, 64, 65, 119, 120, 127, 128, 129, 1024):
            key = bytes((i*7+3)%256 for i in range(key_length))
            message = bytes((i*13+9)%256 for i in range(message_length))
            cases.append(vector(key, message, bool((key_length+message_length)%2)))
    (build/"hmac_vectors.svh").write_text("\n".join(cases))
    (build/"hmac_reset_vector.svh").write_text(vector(b"\xaa"*131, b"\xdd"*129, execute=False))
    (build/"hmac_recovery_vector.svh").write_text(vector(b"Jefe", b"what do ya want for nothing?", execute=False))
    sources = [*sorted(upstream.glob("*.v")), repo/"Source Code/Hash Module/hmac_sha256.v"]
    commands = ["onerror {quit -force -code 1}", "onbreak {resume}", "vlib work"]
    commands += [f"vlog -work work {{{path.as_posix()}}}" for path in sources]
    commands += [f"vlog -sv {{+incdir+{build.as_posix()}}} {{{(bench/'tb_hmac_sha256.sv').as_posix()}}}",
                 "vsim -voptargs=+acc -onfinish stop work.tb_hmac_sha256", "run -all", "quit -force -code 0"]
    script = build/"run.do"
    script.write_text("\n".join(commands))
    result = subprocess.run([str(args.questa_bin/"vsim.exe"), "-c", "-do", f"do {{{script.as_posix()}}}"],
                            cwd=build, text=True, capture_output=True)
    (build/"run.log").write_text(result.stdout+result.stderr)
    for line in (result.stdout+result.stderr).splitlines():
        if any(word in line for word in ("PASS", "Fatal", "** Error")):
            print(line)
    if result.returncode or "HMAC_SHA256_PASS" not in result.stdout:
        raise SystemExit(f"HMAC regression failed. Read {build/'run.log'}")
    subprocess.run([sys.executable, str(repo/"Testing/Simulation/Symmetric Module/run_session_hash_integration.py"),
                    "--build", str(build/"session"), "--questa-bin", str(args.questa_bin),
                    "--hash-sources", str(upstream)], check=True)


if __name__ == "__main__":
    main()
