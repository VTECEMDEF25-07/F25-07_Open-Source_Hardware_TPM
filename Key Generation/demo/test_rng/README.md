<!--
Filename: README.md
Authors: Project contributors; see Git history.
Date: 2026-10-13
General Description: Documents Predictable hardware test-word source.
AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.
-->

# Predictable hardware test-word source

This Verilog-2001 module reproduces the reference fixture stream inside the FPGA. It produces public test data for AES/RSA demos. It is **not an approved DRBG**, an entropy source, a hierarchy-seed service, or a production random generator.

The fixed definition is SHA-256 of `ASCII("KEYGEN-TEST-v1") || 0x00 || seed[32] || counter[8, big-endian]`. The ASCII text is 14 bytes; including the zero byte the domain is 15 bytes. The whole message is **55 bytes / 440 bits**, so one SHA-256 block contains the message, `0x80`, then the 64-bit big-endian length 440. SHA-256 operations/constants follow [FIPS 180-4](https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.180-4.pdf).

## Interface

- `start_valid_i && start_ready_o` captures the 256-bit seed once and starts counter zero. The source stays busy until reset; subsequent starts cannot replace its context.
- `word_valid_o && word_ready_i` transfers one 32-bit word. Digest words appear most-significant first, matching Python's big-endian fixture words. Valid data and the counter remain stable when stalled.
- Only acceptance of the eighth word advances the 64-bit counter. Each next digest reinitializes the SHA state; it does not continue hashing the previous digest.
- After the last word for counter `2^64-1`, `failed_o` latches and the source emits no further words. Working state clears on the following clock. Reset is required to start another stream.
- Active-low reset immediately clears seed, digest, counter, compression state and all sixteen schedule registers, and invalidates output. Follow the enclosing system's synchronized reset-release contract.

This is ordinary portable logic with 32-bit additions, Boolean functions and rotations; there is no vendor-specific resource implementation to substitute. It uses a sixteen-word circular schedule, one SHA compression round per clock, and separate block-initialization/finalization cycles. A block becomes eight available output words after 66 processing clocks. Acceptance stalls extend the output period and cannot alter the stream.

## Review and verification

Read `keygen_test_source.v` in this order: domain/padding, schedule expansion, round update, then output/counter control. The fixture generator uses Python's independent `hashlib.sha256` and the existing twenty frozen seeds; it does not copy the RTL compression code.

```powershell
& 'Key Generation/demo/test_rng/simulate_test_source.ps1' -BuildDirectory '<absolute class AI/tmp scratch directory>'
```

The runner compiles source in Verilog-2001 mode and the permitted testbench in SystemVerilog. It requires an explicit `PASS test source:` marker. Tests compare four complete digests for every frozen seed and two extra full-width seed patterns, replay under different stalls, change inputs after capture, reset during compression and stalled output, and exercise a 32-bit counter carry and 64-bit overflow. Only the otherwise impractical counter positions are injected hierarchically; hash rounds, seed handling and transfer logic execute normally.

Hardware fit/timing and complete keygen integration are separate gates. This source contains no stored RSA keys or precomputed prime factors.

October 13 validation: the complete suite passed at simulation time 167,140 ns. Verilog-2001 source and SystemVerilog test compilation each reported zero errors/warnings; the only simulation warning was the expected `+acc` optimization warning for reset-state inspection. No vendor resource models are needed because this module contains no vendor-specific primitives.
