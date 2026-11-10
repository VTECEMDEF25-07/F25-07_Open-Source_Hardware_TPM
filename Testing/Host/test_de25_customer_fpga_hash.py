"""Offline packet/oracle/error checks. These do not open or simulate a board pass."""
import hashlib
import struct
import unittest
from de25_customer_fpga_hash import FPGAHashError, NULL_TICKET, hash_request, parse_hash_response, verify_fpga_sha256


def reply(digest, *, rc=0, tag=0x8001, ticket=NULL_TICKET):
    body = b'\x00\x20' + digest + ticket if not rc else b''
    return struct.pack('>HII', tag, 10 + len(body), rc) + body


class Transport:
    def __init__(self, response):
        self.response, self.calls = response, []
    def transact(self, request, timeout_s):
        self.calls.append((request, timeout_s))
        return self.response


class Recorder:
    def __init__(self): self.events = []
    def emit(self, event, text, **fields): self.events.append((event, text, fields))


class Tests(unittest.TestCase):
    def test_known_abc_request_and_digest(self):
        expected = bytes.fromhex('8001000000150000017d0003616263000b40000007')
        self.assertEqual(hash_request(b'abc'), expected)
        digest = bytes.fromhex('ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad')
        transport, recorder = Transport(reply(digest)), Recorder()
        result = verify_fpga_sha256(transport, b'abc', recorder)
        self.assertTrue(result['match']); self.assertEqual(result['fpga_digest_hex'], digest.hex())
        self.assertEqual(transport.calls, [(expected, 185)])
        self.assertIn('FPGA   SHA-256: '+digest.hex(), [row[1] for row in recorder.events])

    def test_empty_utf8_and_maximum_byte_lengths(self):
        for message in (b'', 'Hello, Lenovo — FPGA hash!'.encode(), bytes(range(256))*4):
            with self.subTest(length=len(message)):
                digest = hashlib.sha256(message).digest()
                result = verify_fpga_sha256(Transport(reply(digest)), message, Recorder())
                self.assertEqual(result['message_hex'], message.hex())
                self.assertEqual(len(hash_request(message)), 18+len(message))

    def test_invalid_inputs_do_not_open_transport(self):
        for message in (bytes(1025), 'not bytes', None):
            transport = Transport(b'')
            with self.assertRaises(ValueError): verify_fpga_sha256(transport, message, Recorder())
            self.assertEqual(transport.calls, [])

    def test_digest_mismatch_is_failure(self):
        recorder = Recorder()
        with self.assertRaises(FPGAHashError):
            verify_fpga_sha256(Transport(reply(bytes(32))), b'abc', recorder)
        self.assertEqual(recorder.events[-1][1], 'SHA-256 comparison: FAIL')
        self.assertFalse(recorder.events[-1][2]['match'])

    def test_framing_ticket_and_hardware_errors_rejected(self):
        digest = hashlib.sha256(b'abc').digest()
        malformed = [b'', bytes(9), reply(digest, rc=0x101), reply(digest, tag=0x8002),
                     reply(digest[:-1]), reply(digest, ticket=bytes(8)), reply(digest)+b'\0']
        for response in malformed:
            with self.subTest(response=response.hex()), self.assertRaises(FPGAHashError):
                parse_hash_response(response)


if __name__ == '__main__': unittest.main()
