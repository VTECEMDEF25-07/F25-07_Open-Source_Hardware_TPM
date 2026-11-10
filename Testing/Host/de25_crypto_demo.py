#!/usr/bin/env python3
"""DE25 demo v0.1 host verifier. No key read or host seed provisioning.

Run --self-test without a device. For a device/simulation, --transport pkg:factory
loads a callable factory returning an object with transact(packet, timeout_s=...)
-> complete TPM reply bytes. The integration/hardware owner supplies transport,
hardware locking/reset, and SPI FIFO framing. This program never programs FPGA.
"""
from __future__ import annotations
import argparse
import hashlib
import importlib
import json
import struct
from pathlib import Path

MODES = {0: "FRESH_UNQUALIFIED (experimental; entropy health/accounting incomplete)",
         1: "TEST_DETERMINISTIC (public fixture; not fresh entropy)", 2: "UNAVAILABLE"}
PUBLIC_TEST_KEY = hashlib.sha256(b"KEYGEN-TEST-v1\0" + bytes(32) + bytes(8)).digest()


def packet(code: int, payload: bytes = b"", tag: int = 0x8001) -> bytes:
    return struct.pack(">HII", tag, 10 + len(payload), code) + payload


def control(opcode: int, request_id: int, handle: int = 0, operands: bytes = b"") -> bytes:
    return packet(0x20000100, struct.pack(">BBHIII", 1, opcode, 0, request_id, handle, 0) + operands)


def aes_packet(handle: int, data: bytes, iv: bytes, decrypt: bool = False) -> bytes:
    if len(data) > 1024 or len(iv) != 16:
        raise ValueError("AES accepts <=1024 data bytes and exactly 16 IV bytes")
    auth = bytes.fromhex("400000090000000000")
    payload = struct.pack(">II", handle, len(auth)) + auth + struct.pack(">H", len(data)) + data
    payload += struct.pack(">BHH", int(decrypt), 0x0043, 16) + iv
    return packet(0x193, payload, 0x8002)


def hash_packet(data: bytes) -> bytes:
    if len(data) > 1024:
        raise ValueError("Hash accepts <=1024 data bytes")
    return packet(0x17D, struct.pack(">H", len(data)) + data + bytes.fromhex("000b40000007"))


def parse_reply(raw: bytes, expected_rc: int = 0) -> tuple[int, bytes]:
    if len(raw) < 10:
        raise AssertionError("Incomplete response header; discard frame and recover")
    tag, size, rc = struct.unpack(">HII", raw[:10])
    if size != len(raw) or not 10 <= size <= 4096 or tag not in (0x8001, 0x8002, 0x00C4):
        raise AssertionError("Malformed response framing")
    if rc != expected_rc:
        raise AssertionError(f"response RC {rc:#x}, expected {expected_rc:#x}")
    if rc and (size != 10 or tag != 0x8001):
        raise AssertionError("Error response exposed payload or wrong tag")
    return tag, raw[10:]


def parse_control(raw: bytes, opcode: int, expected_modexp_width: int = 2048) -> dict:
    if expected_modexp_width not in (256, 1024, 2048):
        raise ValueError("Expected MODEXP width must be 256, 1024, or 2048")
    tag, p = parse_reply(raw)
    if tag != 0x8001 or len(p) < 28:
        raise AssertionError("Invalid demo control response")
    version, op, mode, state, ident, handle, capacity, flags, operation, cleanup, width = struct.unpack(
        ">BBBBIIHHIII", p[:28])
    if version != 1 or op != opcode or mode not in MODES or capacity != 1024 or flags & ~0xF:
        raise AssertionError("Unsupported control descriptor")
    if flags & 4:
        raise AssertionError("v0.1 cannot claim qualified entropy")
    if bool(flags & 2) != (mode == 1):
        raise AssertionError("Provider/test provenance mismatch")
    if opcode in (0, 3):
        if width != expected_modexp_width:
            raise AssertionError(f"Expected {expected_modexp_width}-bit public MODEXP, got {width}")
    elif width != 0:
        raise AssertionError("Nonzero reserved field")
    if len(p) != 28 + (width // 8 if opcode == 3 else 0):
        raise AssertionError("Control payload length mismatch")
    return dict(mode=mode, state=state, id=ident, handle=handle, capacity=capacity, flags=flags,
                operation=operation, cleanup=cleanup, width=width, result=p[28:])


def parse_aes(raw: bytes, expected_length: int) -> tuple[bytes, bytes]:
    tag, p = parse_reply(raw)
    if tag != 0x8002 or len(p) != 29 + expected_length:
        raise AssertionError("AES response framing")
    if struct.unpack(">I", p[:4])[0] != expected_length + 20:
        raise AssertionError("AES parameter size")
    n = struct.unpack(">H", p[4:6])[0]
    if n != expected_length or p[6+n:8+n] != b"\0\x10" or p[24+n:] != b"\0\0\1\0\0":
        raise AssertionError("AES data/IV/password acknowledgment shape")
    return p[6:6+n], p[8+n:24+n]


def aes_oracle(key: bytes, data: bytes, iv: bytes) -> bytes:
    from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
    ctx = Cipher(algorithms.AES(key), modes.CFB(iv)).encryptor()
    return ctx.update(data) + ctx.finalize()


def final_iv(ciphertext: bytes, initial_iv: bytes) -> bytes:
    """Existing worker: partial final feedback is zero-filled, not continuable."""
    if not ciphertext:
        return initial_iv
    count = len(ciphertext) % 16 or 16
    return ciphertext[-count:] + bytes(16-count)


def run_demo(transport, message: bytes, repeat: int = 2, expected_modexp_width: int = 2048) -> list[dict]:
    if expected_modexp_width not in (256, 1024, 2048):
        raise ValueError("Unsupported expected public MODEXP width")
    evidence = []
    def exchange(command, rc=0):
        raw = bytes(transport.transact(command, timeout_s=185))
        parse_reply(raw, rc)
        evidence.append(dict(command=command.hex(), response=raw.hex(), expected_rc=rc))
        return raw
    exchange(packet(0x144, b"\0\0"))  # Startup(CLEAR); transport owns reset/recovery.
    caps = parse_control(exchange(control(0, 1)), 0, expected_modexp_width)
    print(MODES[caps["mode"]], flush=True)
    print(f"Public MODEXP capability: {caps['width']} bits (explicitly expected {expected_modexp_width})", flush=True)
    if caps["mode"] == 2 or caps["state"] != 0:
        raise AssertionError("Demo provider unavailable")
    ident = 2
    for iteration in range(repeat):
        generated = parse_control(exchange(control(1, ident)), 1, expected_modexp_width); ident += 1
        if generated["operation"] or generated["cleanup"] or not generated["flags"] & 1:
            raise AssertionError("Generation incomplete/uncommitted")
        if generated["mode"] != caps["mode"] or not generated["handle"]:
            raise AssertionError("Generation provenance/handle mismatch")
        handle = generated["handle"]; iv = bytes(range(16))
        ciphertext, iv_out = parse_aes(exchange(aes_packet(handle, message, iv)), len(message))
        if iv_out != final_iv(ciphertext, iv):
            raise AssertionError("Encrypt final IV mismatch")
        if caps["mode"] == 1 and ciphertext != aes_oracle(PUBLIC_TEST_KEY, message, iv):
            raise AssertionError("Independent deterministic-key ciphertext mismatch")
        recovered, decrypt_iv = parse_aes(exchange(aes_packet(handle, ciphertext, iv, True)), len(message))
        if recovered != message or decrypt_iv != iv_out:
            raise AssertionError("Plaintext/decrypt IV verification failed")
        for data in (recovered, ciphertext):
            _, hashed = parse_reply(exchange(hash_packet(data)))
            if len(hashed) != 42 or hashed[:2] != b"\0\x20" or hashed[2:34] != hashlib.sha256(data).digest():
                raise AssertionError("Independent host SHA256 mismatch")
            if hashed[34:] != bytes.fromhex("8024400000070000"):
                raise AssertionError("Hash null ticket mismatch")
        parse_control(exchange(control(2, ident, handle)), 2, expected_modexp_width); ident += 1
        exchange(aes_packet(handle, message, iv), 0x18B)
        print(f"round {iteration+1}: AES/IV/plaintext/SHA/flush-denial PASS", flush=True)
    # Public raw modular exponentiation at the explicitly matched capability width.
    width = caps["width"]; b = width//8
    modulus = (1 << width) - 159
    base = (1 << (width-7)) + 12345
    exponent = 65537
    operands = b"".join(x.to_bytes(b, "big") for x in (base, exponent, modulus))
    mx = parse_control(exchange(control(3, ident, operands=operands)), 3, expected_modexp_width)
    if mx["operation"] or mx["cleanup"] or int.from_bytes(mx["result"], "big") != pow(base, exponent, modulus):
        raise AssertionError(f"Independent {width}-bit public MODEXP mismatch")
    print(f"{width}-bit public MODEXP/Python pow PASS" +
          (" (full 2048-bit target)" if width == 2048 else
           " (explicit configured demo width; no 2048-bit hardware claim)"), flush=True)
    if caps["mode"] == 0:
        print("Fresh-key result is a functional roundtrip; no entropy-quality claim.", flush=True)
    return evidence


def self_test():
    key = bytes.fromhex("603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4")
    p = bytes.fromhex("6bc1bee22e409f96e93d7e117393172a"); iv = bytes(range(16))
    assert aes_oracle(key, p, iv).hex() == "dc7e84bfda79164b7ecd8486985d3860"
    assert PUBLIC_TEST_KEY.hex() == "3127189a1a42bcdcf45b4810b24d1c7ddd6c73cd5ea0053d34d5ae80db93bb22"
    assert len(control(1, 42)) == 26 and len(aes_packet(1, bytes(1024), iv)) == 1074
    assert len(hash_packet(bytes(1024))) == 1042
    assert final_iv(b"\x99", iv) == b"\x99" + bytes(15)
    for malformed in (b"", bytes(9), struct.pack(">HII", 0x8001, 11, 0)):
        try: parse_reply(malformed)
        except AssertionError: pass
        else: raise AssertionError("Malformed reply accepted")
    print("HOST_ORACLE_SELF_TEST_PASS (software fixtures/framing only; no FPGA evidence)")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--transport", help="module:factory -> object.transact(packet, timeout_s=...)")
    parser.add_argument("--message", default="DE25 internal-key crypto demo: encrypt, decrypt, independently verify.")
    parser.add_argument("--repeat", type=int, default=2)
    parser.add_argument("--evidence", type=Path)
    parser.add_argument("--expected-modexp-width", type=int, choices=(256, 1024, 2048), default=2048,
                        help="Require exact CAPS/MODEXP width (default: 2048); explicitly select 1024 for the bounded DE25 demo")
    args = parser.parse_args()
    if args.self_test:
        self_test(); return
    if not args.transport:
        parser.error("Specify --transport module:factory or --self-test")
    message = args.message.encode("utf-8")
    if len(message)>1024 or args.repeat<1:
        parser.error("Message must fit 1024 bytes; repeat must be >=1")
    module, factory = args.transport.rsplit(":",1)
    transport = getattr(importlib.import_module(module), factory)()
    try:
        evidence = run_demo(transport, message, args.repeat, args.expected_modexp_width)
        if args.evidence:
            args.evidence.write_text(json.dumps(dict(status="PASS", transactions=evidence),indent=2),encoding="utf-8")
    finally:
        if hasattr(transport,"close"): transport.close()

if __name__ == "__main__":
    main()
