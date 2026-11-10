"""SHA-256 demo through the real TPM2_Hash command; no device access on import."""
import hashlib
import hmac
import struct
import time

TPM_CC_HASH = 0x0000017D
TPM_ALG_SHA256 = 0x000B
TPM_RH_NULL = 0x40000007
NULL_TICKET = bytes.fromhex('8024400000070000')


class FPGAHashError(RuntimeError):
    pass


def hash_request(message: bytes) -> bytes:
    if not isinstance(message, bytes) or len(message) > 1024:
        raise ValueError('FPGA SHA-256 accepts at most 1024 message bytes')
    body = struct.pack('>H', len(message)) + message
    body += struct.pack('>HI', TPM_ALG_SHA256, TPM_RH_NULL)
    return struct.pack('>HII', 0x8001, 10 + len(body), TPM_CC_HASH) + body


def parse_hash_response(response: bytes) -> bytes:
    if len(response) < 10:
        raise FPGAHashError('FPGA Hash returned an incomplete response header')
    tag, size, rc = struct.unpack('>HII', response[:10])
    if tag != 0x8001 or size != len(response):
        raise FPGAHashError('FPGA Hash response framing is invalid')
    if rc:
        raise FPGAHashError(f'FPGA Hash failed with TPM response code 0x{rc:08x}')
    body = response[10:]
    if len(body) != 42 or body[:2] != b'\x00\x20' or body[34:] != NULL_TICKET:
        raise FPGAHashError('FPGA SHA-256 digest length or null-ticket framing is invalid')
    return body[2:34]


def verify_fpga_sha256(transport, message: bytes, recorder) -> dict:
    """Hash actual FPGA-returned plaintext, then compare the two independent digests."""
    request = hash_request(message)
    laptop = hashlib.sha256(message).digest()
    recorder.emit('hash-submit',
        f'HASH: sending the {len(message)}-byte decrypted message to the FPGA SHA-256 engine.',
        algorithm='SHA256', message_bytes=len(message), source='FPGA-returned plaintext')
    recorder.emit('hash-laptop', 'LAPTOP SHA-256: ' + laptop.hex(), digest_hex=laptop.hex(), location='laptop')
    start = time.monotonic()
    response = bytes(transport.transact(request, timeout_s=185))
    elapsed = time.monotonic() - start
    fpga = parse_hash_response(response)
    recorder.emit('hash-fpga', 'FPGA   SHA-256: ' + fpga.hex(), digest_hex=fpga.hex(), location='FPGA')
    matched = hmac.compare_digest(fpga, laptop)
    recorder.emit('hash-compare', 'SHA-256 comparison: ' + ('PASS' if matched else 'FAIL'),
        match=matched, algorithm='SHA256', message_bytes=len(message))
    if not matched:
        raise FPGAHashError('Actual FPGA SHA-256 digest does not match the laptop hash')
    return dict(algorithm='SHA256', message_bytes=len(message),
        message_hex=message.hex(), laptop_digest_hex=laptop.hex(), fpga_digest_hex=fpga.hex(),
        match=True, host_roundtrip_s=elapsed, request_hex=request.hex(), hardware_response_hex=response.hex(),
        measurement_window='Host request/response, including SPI and FPGA computation')
