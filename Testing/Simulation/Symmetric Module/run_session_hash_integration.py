"""Verify KDFa/session bytes against Python HMAC and OpenSSL AES-256-CFB.

Run with --build pointing outside the source tree. Requires Python, OpenSSL,
and Questa. HMAC is a simulation service because PR #39 omits its RTL body.
"""
import argparse
import hashlib
import hmac
from pathlib import Path
import shutil
import subprocess
import sys


def packed(data, size):
    return f"{size*8}'h" + data.ljust(size, b"\0").hex()


def kdfa(secret, label, newer, older, bits):
    material = bytearray()
    counter = 1
    while len(material)*8 < bits:
        message = counter.to_bytes(4, "big") + label + b"\0" + newer + older + bits.to_bytes(4, "big")
        material.extend(hmac.new(secret, message, hashlib.sha256).digest())
        counter += 1
    return bytes(material[:bits//8])


def vector(length, xor=False, decrypt=False, secret_length=48, newer_length=17, older_length=32):
    secret = bytes((i*7+3) % 256 for i in range(secret_length))
    newer = bytes((i+0x20) % 256 for i in range(newer_length))
    older = bytes((i+0x70) % 256 for i in range(older_length))
    plain = bytes((i*13+9) % 256 for i in range(length))
    iv = bytes(range(16))
    key = bytes(32)
    derived_iv = iv
    if not length:
        cipher, final_iv, calls = plain, iv, 0
    elif xor:
        mask = kdfa(secret, b"XOR", newer, older, length*8)
        cipher = bytes(a ^ b for a, b in zip(plain, mask))
        final_iv, calls = iv, (length+31)//32
    else:
        derived = kdfa(secret, b"CFB", newer, older, 384)
        key, derived_iv = derived[:32], derived[32:]
        cipher = subprocess.run(
            [shutil.which("openssl") or "openssl", "enc", "-aes-256-cfb", "-K", key.hex(),
             "-iv", derived_iv.hex(), "-nopad"], input=plain, check=True, capture_output=True
        ).stdout
        final_iv = cipher[(length-1)//16*16:].ljust(16, b"\0")
        calls = 2
    return "\n".join([
        "@(negedge clock_i);",
        "session_valid_i=1; key_valid_i=1; mode_i=1; expected_rc=0;",
        f"session_use_xor_i={int(xor)}; session_decrypt_i={int(decrypt)}; session_encrypt_i={int(not decrypt)};",
        f"session_value_i={packed(secret,128)}; session_value_bytes_i={len(secret)};",
        f"nonce_newer_i={packed(newer,64)}; nonce_newer_bytes_i={len(newer)};",
        f"nonce_older_i={packed(older,64)}; nonce_older_bytes_i={len(older)};",
        f"data_in_i={packed(cipher if decrypt else plain,1024)}; data_bytes_i={length}; iv_i={packed(iv,16)};",
        f"expected_data={packed(plain if decrypt else cipher,1024)}; expected_iv={packed(final_iv,16)};",
        f"expected_key={packed(key,32)}; expected_first_iv={packed(derived_iv,16)};",
        f"expected_hmac={calls}; expected_cfb={0 if xor else (length+15)//16};",
        "hold_start=1; mutate_inputs=1; execute();",
    ])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", type=Path, required=True)
    parser.add_argument("--hash-sources", type=Path,
                        help="Directory containing shared SHA RTL for hardware HMAC verification")
    parser.add_argument("--questa-bin", type=Path,
                        default=Path("C:/intelFPGA_lite/24.1std/questa_fse/win64"))
    args = parser.parse_args()
    bench = Path(__file__).resolve().parent
    repo = bench.parents[2]
    source = repo/"Source Code/Symmetric Module"
    build = args.build.resolve()
    build.mkdir(parents=True, exist_ok=True)
    cases = []
    for length in (0, 1, 15, 16, 17, 31, 32, 33, 65, 1024):
        for xor in (False, True):
            for decrypt in (False, True):
                cases.append(vector(length, xor, decrypt))
    for lengths in ((0, 0, 0), (1, 1, 0), (32, 32, 32), (64, 32, 17), (80, 17, 32), (128, 64, 64)):
        cases.append(vector(33, secret_length=lengths[0], newer_length=lengths[1], older_length=lengths[2]))
    # Reject bounds and invalid job context before starting the shared service.
    for invalid, rc in (("session_value_bytes_i=129", "095"), ("nonce_newer_bytes_i=65", "095"),
                        ("nonce_older_bytes_i=65", "095"), ("data_bytes_i=1025", "095"),
                        ("session_valid_i=0", "08b"), ("key_valid_i=0", "09c"),
                        ("session_decrypt_i=1", "082"), ("mode_i=0", "089")):
        setup = vector(16).rsplit("hold_start=", 1)[0]
        cases.append(setup + f"\n{invalid}; expected_rc=12'h{rc}; expected_data=0; expected_iv=0; "
                     "expected_hmac=0; expected_cfb=0; hold_start=0; mutate_inputs=0; execute();")
    (build/"session_vectors.svh").write_text("\n".join(cases))
    setup = vector(33).rsplit("hold_start=", 1)[0]
    faults = setup + """
expected_rc=12'h101; expected_data=0; expected_iv=0; expected_cfb=2;
hold_start=0; mutate_inputs=0;
fork
    execute();
    begin
        wait(cfb_calls==2);
        wait(dut.cfb_done);
        force dut.cfb_rc=12'h101;
        @(posedge clock_i); @(negedge clock_i);
        release dut.cfb_rc;
    end
join
"""
    faults += setup + """
hold_start=0; mutate_inputs=0;
force hmac_busy_i=1'b1;
fork
    execute();
    begin
        repeat(15) @(negedge clock_i);
        if (hmac_start_o || hmac_calls != 0) $fatal(1,"Started an occupied HMAC service");
        release hmac_busy_i;
    end
join
"""
    (build/"session_faults.svh").write_text(faults)
    (build/"session_recovery.svh").write_text(vector(33, xor=True))
    sources = ["aes_sbox.v", "aes_inv_sbox.v", "aes_key_mem.v", "aes_encipher_block.v",
               "aes_decipher_block.v", "aes_core.v", "aes.v", "kdfa_control.v", "cfb_block.v", "session_parameter_controller.v", "encrypt_decrypt2_controller.v", "symmetric_top.v"]
    commands = ["onerror {quit -force -code 1}", "onbreak {resume}", "vlib work"]
    commands += [f"vlog -work work {{{(source/name).as_posix()}}}" for name in sources]
    service = bench/"hmac_stream_test_service.sv"
    if args.hash_sources:
        hash_root = source.parent/"Hash Module"
        commands += [f"vlog -work work {{{path.as_posix()}}}"
                     for path in sorted(args.hash_sources.resolve().glob("*.v"))]
        commands.append(f"vlog -work work {{{(hash_root/'hmac_sha256.v').as_posix()}}}")
        service = repo/"Testing/Simulation/Hash Module/hmac_rtl_service.sv"
    commands += [f"vlog -sv {{+incdir+{build.as_posix()}}} {{{service.as_posix()}}} "
                 f"{{{(bench/'tb_session_hash_integration.sv').as_posix()}}}",
                 f"vsim -voptargs=+acc -onfinish stop work.tb_session_hash_integration "
                 f"{{+PYTHON={Path(sys.executable).as_posix()}}} "
                 "+HMAC_SERVICE=hmac_reference_service.py",
                 "run -all", "quit -force -code 0"]
    shutil.copy2(bench/"professor_demo/hmac_reference_service.py", build/"hmac_reference_service.py")
    script = build/"run.do"
    script.write_text("\n".join(commands))
    result = subprocess.run([str(args.questa_bin/"vsim.exe"), "-c", "-do", f"do {{{script.as_posix()}}}"],
                            cwd=build, capture_output=True, text=True)
    (build/"run.log").write_text(result.stdout+result.stderr)
    for line in (result.stdout+result.stderr).splitlines():
        if any(word in line for word in ("PASS", "Error", "Fatal", "Warning")):
            print(line)
    if result.returncode or "SESSION_HASH_INTEGRATION_PASS" not in result.stdout:
        raise SystemExit(f"Integration failed. Read {build/'run.log'}")


if __name__ == "__main__":
    main()
