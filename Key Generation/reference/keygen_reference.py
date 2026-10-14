# Filename: keygen_reference.py
# Authors: Project contributors; see Git history.
# Date: 2026-10-13
# General Description: Executable RSA-2048 procedure oracle. Predictable fixtures only, never production RNG.
# AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

"""Executable RSA-2048 procedure oracle. Predictable fixtures only, never production RNG."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
from typing import Callable

NLEN = 2048
PRIME_BITS = 1024
EXPONENT = 65537
ROUNDS = 5
LOWER_BOUND = math.isqrt(1 << 2047) + 1
SEPARATION = 1 << 924
DOMAIN = b"KEYGEN-TEST-v1\x00"
PROCEDURE = "RSA-2048-v1-trial251"
TRIAL_PRIMES = (3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47,
                53, 59, 61, 67, 71, 73, 79, 83, 89, 97, 101, 103, 107,
                109, 113, 127, 131, 137, 139, 149, 151, 157, 163, 167,
                173, 179, 181, 191, 193, 197, 199, 211, 223, 227, 229,
                233, 239, 241, 251)


class GenerationFailure(RuntimeError):
    """Failure invalidates all key fields; no partially generated key is returned."""


class Sha256Words:
    """SHA256(domain || 32-byte seed || 64-bit BE counter), eight BE words/block."""

    def __init__(self, seed: bytes):
        if len(seed) != 32:
            raise ValueError("fixture seed must be exactly 32 bytes")
        self.seed = seed
        self.counter = 0
        self.pending = []
        self.words = 0

    def word(self) -> int:
        if not self.pending:
            if self.counter >= 1 << 64:
                raise GenerationFailure("test stream exhausted")
            digest = hashlib.sha256(DOMAIN + self.seed + self.counter.to_bytes(8, "big")).digest()
            self.pending = [int.from_bytes(digest[i:i + 4], "big") for i in range(0, 32, 4)]
            self.counter += 1
        self.words += 1
        return self.pending.pop(0)


def read_integer(word: Callable[[], int], bits: int = PRIME_BITS) -> int:
    if bits <= 0 or bits % 32:
        raise ValueError("draw width must be a positive multiple of 32")
    value = 0
    for _ in range(bits // 32):
        item = word()
        if type(item) is not int or not 0 <= item < 1 << 32:
            raise GenerationFailure("invalid generation word")
        value = (value << 32) | item
    return value


def _event(trace, kind, **fields):
    if trace is not None:
        trace.append({"event": kind, **fields})


def probable_prime(candidate: int, word: Callable[[], int], trace=None) -> bool:
    """B.3.1 with five accepted random witnesses; each rejected draw consumes 32 words."""
    if candidate.bit_length() != PRIME_BITS or not candidate & 1:
        raise ValueError("generation primality test requires odd 1024-bit input")
    odd_part = candidate - 1
    powers = 0
    while not odd_part & 1:
        odd_part >>= 1
        powers += 1
    for round_index in range(ROUNDS):
        while True:
            base = read_integer(word)
            if 2 <= base <= candidate - 2:
                break
            _event(trace, "witness_rejected", round=round_index)
        _event(trace, "witness_accepted", round=round_index)
        residue = pow(base, odd_part, candidate)
        if residue == 1 or residue == candidate - 1:
            continue
        for _ in range(powers - 1):
            residue = residue * residue % candidate
            if residue == candidate - 1:
                break
            if residue == 1:
                return False
        else:
            return False
        if residue != candidate - 1:
            return False
    return True


def generate_prime(word: Callable[[], int], other: int | None = None, trace=None) -> int:
    """A.1.3 steps 4/5 with exact small-prime composite prefilter, versioned above."""
    phase = "p" if other is None else "q"
    limit = 5 * NLEN if other is None else 10 * NLEN
    failures = 0
    while True:
        candidate = read_integer(word) | 1
        _event(trace, "candidate", phase=phase, failures=failures)
        if candidate < LOWER_BOUND:
            _event(trace, "range_rejected", phase=phase)
            continue
        if other is not None and abs(candidate - other) <= SEPARATION:
            _event(trace, "separation_rejected", phase=phase)
            continue
        compatible = math.gcd(candidate - 1, EXPONENT) == 1
        divisor = next((p for p in TRIAL_PRIMES if candidate % p == 0), None) if compatible else None
        if divisor is not None:
            _event(trace, "trial_division_rejected", phase=phase, divisor=divisor)
        if compatible and divisor is None and probable_prime(candidate, word, trace):
            _event(trace, "prime_accepted", phase=phase, failures=failures)
            return candidate
        failures += 1
        _event(trace, "candidate_failed", phase=phase, failures=failures,
               reason="composite" if compatible else "exponent")
        if failures == limit:
            raise GenerationFailure(f"{phase} retry limit {limit}")


def private_exponent(p: int, q: int) -> int:
    return pow(EXPONENT, -1, math.lcm(p - 1, q - 1))


def generate_key(word: Callable[[], int], trace=None) -> dict[str, int]:
    while True:
        p = generate_prime(word, trace=trace)
        q = generate_prime(word, other=p, trace=trace)
        d = private_exponent(p, q)
        if d <= 1 << PRIME_BITS:
            _event(trace, "pair_restarted_low_d")
            continue
        n = p * q
        if n.bit_length() != NLEN:
            raise GenerationFailure("internal modulus length mismatch")
        return {"n": n, "e": EXPONENT, "p": p, "q": q, "d": d}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=int, default=1, choices=range(1, 21))
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    fixtures = json.loads(Path(__file__).with_name("seeds.json").read_text())
    source = Sha256Words(bytes.fromhex(fixtures["seeds"][args.seed - 1]["seed_hex"]))
    events = []
    key = generate_key(source.word, events)
    from key_checker import check_key
    check_key(key)
    result = {"test_only": True, "seed_id": args.seed, "words_consumed": source.words,
              "key": {name: hex(value) for name, value in key.items()}, "events": events}
    if args.output:
        args.output.write_text(json.dumps(result, indent=2) + "\n")
    print(f"PASS RSA-2048 seed={args.seed} words={source.words} checker_rounds=64")


if __name__ == "__main__":
    main()
