"""Hardware-lead-only RSA keygen module measurement using the frozen V2 client.

Imports/opening hardware happen only in main, after same-image Phase I evidence
validation. Records PUBLIC n/e, counts and HOST elapsed times; no d/p/q or host
private operation. All original assertions and final-image acceptance stay with
the hardware lead. This script never programs the board.
"""
from __future__ import annotations
import argparse
from datetime import datetime, timezone
import hashlib
import importlib
import json
from pathlib import Path
import statistics
import sys
import time


MESSAGES = (b'', b'a', b'DE25 RSA generated onboard', 'Lenovo — FPGA private decrypt'.encode('utf-8'),
            b'Z' * 31, b'K' * 128, bytes(32 + i % 95 for i in range(239)), b'Q' * 240)


def measure(client, samples, record, save=lambda: None):
    """Accept a client for offline failure tests; caller owns hardware provenance."""
    seen = set()
    client.startup()
    caps = client.capabilities()
    if caps.core_hz != 50_000_000 or caps.rsa_bits != 2048 or client.provider != 0:
        raise RuntimeError('Requires actual RSA2048/50MHz/FRESH_UNQUALIFIED capability; no fallback')
    record.update(core_hz=caps.core_hz, width_or_profile='RSA2048/e65537', provider='FRESH_UNQUALIFIED',
                  entropy_qualified=False, private_context_exported=False,
                  measurement_window='host monotonic request/response, including SPI/polling/computation/cleanup',
                  core_cycle_measurement=False, samples_requested=samples, messages_per_key=len(MESSAGES), keys=[])
    save()
    for index in range(samples):
        generation_request_id = getattr(client, 'next_id', None)
        start = time.monotonic_ns()
        handle, public = client.generate_rsa_public()
        elapsed = (time.monotonic_ns() - start) / 1e9
        n, e = public.modulus, public.exponent
        if n.bit_length() != 2048 or not n & 1 or e != 65537 or n in seen or not handle:
            raise RuntimeError('Generated public key width/oddness/exponent/uniqueness/handle check failed')
        # A public modulus divisible by a small prime is an independently detected
        # keygen error. Passing this check is not a primality proof of its factors.
        for prime in (3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47):
            if n % prime == 0:
                raise RuntimeError('Generated modulus has an invalid small-prime factor')
        seen.add(n)
        key = dict(sample=index + 1, public_modulus_hex=f'{n:0512x}', public_exponent=e,
                   handle=f'0x{handle:08x}', generation_host_elapsed_s=elapsed,
                   generation_request_id=generation_request_id, generation_core_cycles=None,
                   public_checks_pass=True, roundtrips=[])
        record['keys'].append(key)
        save()
        for case, message in enumerate(MESSAGES):
            # Only PUBLIC encryption is performed on the laptop.
            ciphertext = public.encrypt_on_laptop(message)
            if len(ciphertext) != 256:
                raise RuntimeError('Public RSA ciphertext width changed')
            private_request_id = getattr(client, 'next_id', None)
            start = time.monotonic_ns()
            returned = client.decrypt_rsa(handle, ciphertext)
            decrypt_elapsed = (time.monotonic_ns() - start) / 1e9
            if returned != message:
                raise RuntimeError(f'Actual FPGA private result mismatch key={index + 1} case={case + 1}')
            key['roundtrips'].append(dict(case=case + 1, message_bytes=len(message),
                request_id=private_request_id,handle=f'0x{handle:08x}',
                message_hex=message.hex(),ciphertext_hex=ciphertext.hex(),
                returned_plaintext_hex=returned.hex(),worker_cycles64=None,
                expected_sha256=hashlib.sha256(message).hexdigest(),
                returned_sha256=hashlib.sha256(returned).hexdigest(), actual_plaintext_match=True,
                private_decrypt_host_elapsed_s=decrypt_elapsed))
            save()
        print(f'PASS keygen sample={index + 1}/{samples} RSA2048 public_checks=PASS '
              f'private_roundtrips={len(MESSAGES)}/{len(MESSAGES)} host_generation_s={elapsed:.6f}', flush=True)
    times = [key['generation_host_elapsed_s'] for key in record['keys']]
    total = sum(len(key['roundtrips']) for key in record['keys'])
    record.update(status='PASS', generated_keys=samples, distinct_moduli=len(seen),
        private_roundtrips_passed=total, private_roundtrips_total=samples * len(MESSAGES),
        generation_host_seconds=dict(median=statistics.median(times), minimum=min(times), maximum=max(times)),
        limit='Public checks and FPGA private roundtrips; not factor-primality proof, entropy qualification or core-only timing')
    save()
    return record


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--client-root', type=Path, help='Testing/Host folder containing accepted V2 client; default this folder')
    p.add_argument('--phase1-evidence', type=Path, required=True)
    p.add_argument('--image-sha256', required=True)
    p.add_argument('--samples', type=int, default=3)
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args()
    if not 1 <= a.samples <= 10:
        p.error('--samples must be1..10 (default3)')
    root = (a.client_root or Path(__file__).resolve().parent).resolve()
    sys.path.insert(0, str(root))
    from de25_customer_evidence import load_phase1
    phase1 = load_phase1(a.phase1_evidence, a.image_sha256)
    record = dict(status='RUNNING', schema_version=1,module='KEYGEN', evidence_kind='HARDWARE',
        source_revision=phase1['source_commit'], sof_sha256=a.image_sha256,
        spi_hz=phase1['spi_hz'], phase1_evidence=str(a.phase1_evidence.resolve()),
        exact_log_path=str(a.output.resolve()),host_script_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        started_utc=datetime.now(timezone.utc).isoformat(), requested_samples=a.samples)
    a.output.parent.mkdir(parents=True, exist_ok=True)
    def save():
        a.output.write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
    save()
    transport = None
    try:
        # The accepted transport owns the shared hardware mutex and exact serial.
        # No substitute transport or private-key oracle is selected here.
        transport_module = importlib.import_module('de25_customer_transport')
        from de25_customer_protocol import CustomerClient
        import os
        os.environ['DE25_SPI_HZ'] = str(phase1['spi_hz'])
        transport = transport_module.factory()
        record['host_client_sha256'] = {
            name: hashlib.sha256((root / name).read_bytes()).hexdigest()
            for name in ('de25_customer_protocol.py', 'de25_customer_crypto.py', 'de25_customer_transport.py')}
        measure(CustomerClient(transport, provider=0), a.samples, record, save)
    except BaseException as error:
        record.update(status='FAIL', error_type=type(error).__name__, error=str(error))
        save()
        raise
    finally:
        if transport is not None:
            transport.close()
        record['ended_utc'] = datetime.now(timezone.utc).isoformat()
        save()


if __name__ == '__main__':
    main()
