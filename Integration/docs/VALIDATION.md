# Integration validation

Validation date: 2026-10-23. This is simulation and source-review evidence,
not FPGA or physical entropy qualification.

## Baseline and isolation

Fresh clone of Aaron's `aaron/keygen-consolidated-review` at
`c90610165605cac55243522847c5e5f50f60ef08`; merged Jungyeon's `rng` at
`092bac8a4e481e214e26578b8e4d1b4af9176411` into the separate
`aaron/rng-keygen-integration` branch. No edits were made to the original
working checkout or the existing pull-request branch.

## Completed checks

| Check | Evidence |
| --- | --- |
| Verilog-2001 lint/elaboration | Both standalone RNG and physical integrated top pass. |
| SHA-256 | Six independent hashlib vectors, including the 55/56-byte padding boundary and 111-byte maximum; response stalls and clear. |
| Hash_DRBG | Twenty independent Python reference outputs across four seeds, instantiate/generate/reseed, held output, erase and reuse. |
| Entropy admission | Two independently checked conditioned seeds; startup delay, default-disabled gate, RCT/APT alarms, continuous monitoring while stalled/hashing, fault at seed acceptance, partial/hash clearing. |
| Shared service, deterministic test provider | AES-128/256 exact output; GetRandom byte counts and framing; arbitration, stalls, startup/tag rejection, fault timing, ownership and cleanup. |
| Shared service, actual Hash_DRBG | Same integration checks with dedicated and soft-core keygen configurations. Simulation injects a known qualified seed; it does not validate physical entropy. |
| Supervisor | Missing-seed failure/retry, stalled response timeout, recovery admission lock, retained ownership/client metadata, exact-deadline status/last-byte completion. |
| RSA-2048, dedicated backend | All 129 n/e/p/q words match existing seed-20 reference fixture, including result backpressure, ownership and source erasure. Passed in 579,639,070 simulated clocks. |
| RSA-2048, fresh DRBG and soft-core backend | All 129 n/e/p/q words match independently generated and checked Python reference, consuming 41,728 reference words from seed bytes 0 through 47. Result backpressure, ownership and source erasure pass in 1,040,757,369 simulated clocks. |

The unchanged soft-core firmware was built with the pinned xPack RISC-V
15.2.0 toolchain and matched its checked manifest: 1,648 bytes, image SHA-256
`a9b67a3d34031e12b4fc4afba521fbf13549d39523749980195c55fa9c86fb9f`.

## Independent review

Three read-only subagents reviewed the cryptographic construction, interfaces,
and fault/reset/ownership lifecycle. Findings were corrected and regression
checked: SHA response holding; reset release; receiver scrub acknowledgment;
sticky entropy alarms; per-client timeout accounting; retained recovery
metadata; duplicate terminal prevention; and completion exactly at a deadline.
Final focused reviews reported no remaining serious issue. This review does
not substitute for simulation or hardware qualification.

## Reproduction and evidence

Commands and prerequisites are in `../README.md`. Each runner stores its
source and fixture SHA-256 hashes, simulator version, defines, and PASS output
in `../build/<suite>/manifest.json`. Compiler and simulation logs stay beside
the manifest. Build products are ignored; compact passing manifests are kept
under `evidence/` for review, with machine-specific path prefixes removed from
the displayed PASS output. Hashes describe the tested file bytes; checkout
line-ending conversion can change them without changing HDL behavior.

## Remaining acceptance gates

- Physical FPGA synthesis/timing and ring-oscillator preservation, board
  sampling and defensible entropy/nonce/health-test thresholds. Physical
  admission remains disabled by default.
- Primary derivation remains explicitly rejected until the hierarchy and
  canonical derivation contract are supplied.
- System receiver/transport wiring must honor scrub, operation reset,
  ownership persistence and recovery acknowledgment. No full TPM or power-loss
  reconciliation claim is made.
- The selected simulations do not establish exhaustive seed coverage, all
  backend combinations, formal verification or certification.
