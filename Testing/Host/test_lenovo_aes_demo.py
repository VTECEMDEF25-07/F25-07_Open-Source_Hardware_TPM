import contextlib
import io
import struct
import unittest

from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes

from lenovo_aes_demo import demo_key, decrypt_reply, decrypt_request, run_message


class PacketTransport:
    """Independent software peer for checking the host's TPM wire encoding."""
    def transact(self, packet, timeout_s):
        tag, size, code, handle, auth_size = struct.unpack(">HIIII", packet[:18])
        assert (tag, size, code, handle, auth_size) == (0x8002, len(packet), 0x193, 0x80000000, 9)
        assert packet[18:27] == bytes.fromhex("400000090000000000")
        length = int.from_bytes(packet[27:29], "big")
        ciphertext = packet[29:29 + length]
        assert packet[29 + length:34 + length] == bytes.fromhex("0100430010")
        iv = packet[34 + length:]
        decryptor = Cipher(algorithms.AES(demo_key()), modes.CFB(iv)).decryptor()
        plaintext = decryptor.update(ciphertext) + decryptor.finalize()
        used = len(ciphertext) % 16 or 16
        final_iv = ciphertext[-used:] + bytes(16 - used) if ciphertext else iv
        body = struct.pack(">IH", len(plaintext) + 20, len(plaintext))
        body += plaintext + b"\0\x10" + final_iv + b"\0\0\1\0\0"
        return struct.pack(">HII", 0x8002, len(body) + 10, 0) + body


class LenovoAesHostTests(unittest.TestCase):
    def test_known_seed_key(self):
        self.assertEqual(demo_key().hex(), "3127189a1a42bcdcf45b4810b24d1c7ddd6c73cd5ea0053d34d5ae80db93bb22")

    def test_message_boundaries_and_utf8(self):
        for message in ("", "x", "a" * 15, "b" * 16, "c" * 17, "d" * 1024, "Hello — Lenovo"):
            with self.subTest(bytes=len(message.encode("utf-8"))):
                with contextlib.redirect_stdout(io.StringIO()):
                    actual = run_message(PacketTransport(), message)
                self.assertEqual(actual, message.encode("utf-8"))

    def test_input_limits(self):
        with self.assertRaises(ValueError):
            decrypt_request(bytes(1025), bytes(16))
        with self.assertRaises(ValueError):
            decrypt_request(b"", bytes(15))
        with self.assertRaises(ValueError):
            run_message(None, "é" * 513)

    def test_reject_malformed_or_failed_replies(self):
        reply = PacketTransport().transact(decrypt_request(b"abc", bytes(16)), 10)
        for malformed in (b"", reply[:-1], b"\x80\x01" + reply[2:], reply[:-1] + b"\x01",
                          reply[:10] + bytes(4) + reply[14:],
                          bytes.fromhex("80010000000a0000018b")):
            with self.subTest(reply=malformed.hex()):
                with self.assertRaises(ValueError):
                    decrypt_reply(malformed, 3)

    def test_reject_wrong_plaintext(self):
        class CorruptTransport(PacketTransport):
            def transact(self, packet, timeout_s):
                reply = bytearray(super().transact(packet, timeout_s))
                reply[16] ^= 1
                return reply

        with contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaises(ValueError):
                run_message(CorruptTransport(), "hello")


if __name__ == "__main__":
    unittest.main()
