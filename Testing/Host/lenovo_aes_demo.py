"""Interactive deterministic AES-256 CFB demo through TPM2_EncryptDecrypt2."""
import argparse
import hashlib
import importlib
import os
import struct

DEMO_SEED = bytes(32)
DEMO_HANDLE = 0x80000000
MAX_MESSAGE_BYTES = 1024


def demo_key():
    """Mirror block zero of the FPGA's public deterministic test source."""
    return hashlib.sha256(b"KEYGEN-TEST-v1\0" + DEMO_SEED + bytes(8)).digest()


def decrypt_request(ciphertext, iv, handle=DEMO_HANDLE):
    if len(ciphertext) > MAX_MESSAGE_BYTES or len(iv) != 16:
        raise ValueError("Use at most 1024 ciphertext bytes and a 16-byte IV")
    authorization = struct.pack(">IHBH", 0x40000009, 0, 0, 0)
    parameters = struct.pack(">H", len(ciphertext)) + ciphertext
    parameters += struct.pack(">BHH", 1, 0x0043, 16) + iv
    body = struct.pack(">II", handle, len(authorization)) + authorization + parameters
    return struct.pack(">HII", 0x8002, 10 + len(body), 0x193) + body


def decrypt_reply(reply, expected_length):
    if len(reply) < 10:
        raise ValueError("Incomplete TPM reply")
    tag, size, code = struct.unpack(">HII", reply[:10])
    if size != len(reply):
        raise ValueError("TPM reply size mismatch")
    if code:
        raise ValueError(f"TPM2_EncryptDecrypt2 returned 0x{code:08x}")
    if tag != 0x8002 or size != expected_length + 39:
        raise ValueError("Unexpected AES reply framing")
    parameters, length = struct.unpack(">IH", reply[10:16])
    end = 16 + length
    if parameters != length + 20 or length != expected_length:
        raise ValueError("Unexpected AES plaintext size")
    if reply[end:end + 2] != b"\0\x10" or reply[end + 18:] != b"\0\0\1\0\0":
        raise ValueError("Invalid returned IV or password acknowledgment")
    return reply[16:end], reply[end + 2:end + 18]


def run_message(transport, message):
    from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes

    plaintext = message.encode("utf-8")
    if len(plaintext) > MAX_MESSAGE_BYTES:
        raise ValueError("Message exceeds 1024 UTF-8 bytes")
    iv = os.urandom(16)
    encryptor = Cipher(algorithms.AES(demo_key()), modes.CFB(iv)).encryptor()
    ciphertext = encryptor.update(plaintext) + encryptor.finalize()
    print("Laptop plaintext ", repr(message))
    print("Laptop ciphertext", ciphertext.hex())
    reply = bytes(transport.transact(decrypt_request(ciphertext, iv), timeout_s=10))
    recovered, final_iv = decrypt_reply(reply, len(ciphertext))
    last = len(ciphertext) % 16 or 16
    expected_iv = ciphertext[-last:] + bytes(16 - last) if ciphertext else iv
    if recovered != plaintext or final_iv != expected_iv:
        raise ValueError("FPGA plaintext or final IV differs from the expected result")
    print("FPGA plaintext   ", repr(recovered.decode("utf-8")))
    print("PASS - FPGA plaintext and final IV match\n")
    return recovered


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--message", help="Run once with this UTF-8 message")
    parser.add_argument("--transport", default="de25_d2xx_transport:factory")
    parser.add_argument("--hash-panel", action="store_true", help="Show FPGA Hash demo with Nucleo buttons")
    parser.add_argument("--port", help="Nucleo serial port for the Hash panel, such as COM5")
    args = parser.parse_args()
    print("DETERMINISTIC TEST KEY - public zero seed, AES-256 CFB128")
    print("The FPGA generates the key after reset; the laptop derives the same public test key.")
    module, factory = args.transport.rsplit(":", 1)
    transport = getattr(importlib.import_module(module), factory)()
    try:
        startup = bytes.fromhex("80010000000c000001440000")
        if bytes(transport.transact(startup, timeout_s=10)) != bytes.fromhex("80010000000a00000000"):
            raise ValueError("TPM Startup failed")
        if args.message is not None:
            run_message(transport, args.message)
        elif not args.hash_panel:
            while True:
                try:
                    message = input("Message to encrypt on laptop and decrypt on FPGA (Ctrl+C to exit): ")
                except (EOFError, KeyboardInterrupt):
                    break
                if len(message.encode("utf-8")) > MAX_MESSAGE_BYTES:
                    print("Use at most 1024 UTF-8 bytes.")
                    continue
                run_message(transport, message)
        if args.hash_panel:
            from lenovo_hash_panel import run_panel
            run_panel(transport, args.port)
    finally:
        transport.close()


if __name__ == "__main__":
    main()
