# Phase One TPM2_GetRandom

Imported from PR #53 commit `5ea744a` into Lenovo baseline `e78e438`.
The original validation notes below describe the upstream RNG tests.
In this branch, AES keeps engine states 12/13 and GetRandom uses states 14/15.
Both runner entry points execute the combined Lenovo AES/Hash/GetRandom/legacy
regression, including a mixed SPI instance with AES and RNG enabled.
Production board defaults retain `ENABLE_GETRANDOM=0`. AES key generation
still uses the public deterministic source; the RNG-to-keygen adapter is a
subsequent connection.

## Behavior and ownership

- The Phase One engine captures ownership in IDLE, dispatches GetRandom in
  states 14/15, and publishes through its existing post-processing state 9.
  Existing states 0–11 and Hash behavior are retained. Disabled GetRandom
  returns `TPM_RC_COMMAND_CODE` (`0x143`) without starting the RNG.
- `execution_engine_getrandom` adapts synchronous CRB reads to the existing
  `tpm2_get_random` byte-stream handler, buffers its response, and supplies
  payload bytes to the CRB, which writes the standard TPM header. Supported
  framing is `TPM_ST_NO_SESSIONS`, 12-byte command, command code `0x17b`.
  Session-tagged commands retain the handler's unsupported-tag rejection.
  Requests clamp to 32 bytes; success is 12+n bytes, errors are ten bytes.
- `phase_one_rng` owns the real source, raw-sample health detector,
  Hash_DRBG, sticky failure, and output suppression. It exposes fault status
  to the engine. Its DRBG hashes use the real `hash_subsystem` RNG requester,
  sharing SHA with TPM2_Hash. There is no substitute SHA or random generator
  in the integrated SPI bench.
- Source sanity tests observe valid, synchronized raw samples before
  conditioning: 32 identical consecutive samples fail the repetition test;
  each non-overlapping 512-bit window must contain 128–384 ones inclusive.
  The first complete passing window is required before seed blocks enter the
  DRBG. These are engineering thresholds, not measured SP800-90B thresholds.
- A source fault suppresses RNG output immediately and remains latched until
  global reset. The command adapter also bounds unavailable RNG output to
  1,000,000 system clocks (20 ms at 50 MHz); expiry latches a failure.
  In-flight SHA messages drain after source failure so Hash remains usable.
  A stalled shared SHA implementation may itself require global reset.
  Faults detected before response publication revoke success and erase the
  buffered random payload. An already published response is a committed
  transaction; it is not rewritten partway through host reads.
- Pre-startup GetRandom returns `0x100` without marking engine initialization
  complete or consuming the CRB's management setup pulse. Startup following
  that error is covered through the actual SPI path.

## Reproduction

From the repository root on Windows with Questa on PATH:

```powershell
vsim -c -do 'do {Testing/Simulation/Execution Engine/run_tpm2_getrandom.do}'
python 'Testing/Simulation/RNG Module/run_getrandom.py' --output '<scratch-directory>'
```

The first script checks explicit `passed` flags, not just simulator exit code.
It includes existing Hash command/SPI, optional AES SPI and keygen/AES
integration tests, and the original SPI bench through entry 240 with zero errors.
The second script independently checks the SHA test model against 142 hashlib
vectors, shared-SHA requester isolation/backpressure, and existing RNG commands.

New deterministic coverage:

- SPI requests 0, 1, 31, 32, 33 and 65535; exact TPM header and TPM2B lengths;
  missing/truncated parameters, extra bytes, unsupported/bad tags, disabled
  admission, pre-startup failure, and successful commands after errors.
- Mixed Hash/GetRandom commands through the actual engine, DRBG, shared SHA,
  CRB, FIFO and SPI. Observed before recovery: 18 GetRandom dispatches/replies,
  24 RNG SHA grants. Hash's `abc` digest remains correct after a source fault
  and after global reset/reseed.
- A stuck sampled source during a pending real DRBG request triggers the
  actual repetition detector. Its RNG-owned sticky fault reaches GetRandom
  as `0x101`, responseSize=10, with no random payload. Returning to a healthy
  sample pattern does not clear failure.
- A 7/8-one source triggers the actual window detector without reaching the
  repetition threshold; after Startup, GetRandom returns the same ten-byte
  failure. Global reset plus healthy deterministic samples restores successful
  GetRandom and Hash responses.
- A focused engine bench checks exact payload byte order with a known block,
  rejection of a second ready/changed metadata while busy, mismatched frame
  size, oversized frames, timeout, reset during a pending request, fresh
  response after reset, and fault revocation during reply collection.

Expected new pass markers:

```text
GETRANDOM_ENGINE_OWNER_TIMEOUT_RESET_PASS
GETRANDOM_REAL_RCT_PROPAGATION_PASS
GETRANDOM_MIXED_ENGINE_SHA_PASS starts=18 replies=18 rng_hashes=24
GETRANDOM_REAL_APT_PROPAGATION_PASS
GETRANDOM_RESET_HEALTHY_RECOVERY_PASS
TPM2_GETRANDOM_SPI_PASS                 (enabled and disabled configurations)
TPM_LEGACY_SPI_PASS entry=240 errors=0
```

## Hardware limits

Physical entropy remains unverified on this integrated FPGA image and needs
later measurement. Deterministic healthy/stuck/biased sample stimuli validate
fault logic and propagation; they do not establish physical entropy adequacy,
min-entropy, independence, oscillator placement/timing, or standards compliance.
An alternating predictable sequence intentionally passes these sanity tests.
No FPGA image was built, fitted, programmed or physically measured for this
change. Prior-image diagnostic captures do not establish entropy adequacy for
this image. Review remains required; this PR must not be auto-merged.
