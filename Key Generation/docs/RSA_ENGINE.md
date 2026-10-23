<!--
Filename: RSA_ENGINE.md
Authors: Project contributors; see Git history.
Date: 2026-10-13
General Description: Documents RSA generation engine.
AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.
-->

# RSA generation engine

The dedicated controller issues descriptors to one
private arithmetic engine. For example, a candidate is drawn into scratch,
filtered, tested with five accepted witnesses, and copied to the retained prime
slot. A rejected witness consumes more source words but does not reject the
candidate. A low private exponent discards both primes and restarts generation.

Read `RSA_ALGORITHM.md` first, then `rtl/rsa_rtl/keygen_rsa_controller.v`,
`keygen_rsa_services.v` and `keygen_rsa_engine.v`. Arithmetic implementations
are documented in `../Math/README.md` and `PAIR_CHECK.md`. The independent
reference lives in `../reference/`; it does not call the hardware implementation.

## Private memory layout

All addresses below identify 32-bit words. Integers use little-endian limbs.

| Start | Length | Contents |
|---:|---:|---|
| 0 | 32 | Current candidate W |
| 32 | 32 | W minus one |
| 64 | 32 | Odd part of W minus one |
| 96 | 32 | Witness |
| 128 | 32 | Modular exponentiation result |
| 160 | 32 | Retained p |
| 192 | 32 | Retained q |
| 224 | 64 | Validated n |
| 288 | 32 | Constant one |
| 320 | 32 | Constant two |
| 352 | 32 | Temporary square result |
| 512 | bounded by arithmetic command | Montgomery workspace |

The accelerator owns all 4096 words. It clears the full allocation, its operand
caches and its synchronous RAM output before declaring reset cleanup complete.
The CPU cannot read these operands. Its MMIO returns status predicates only.
The area-optimized pair checker has an additional 512-word private RAM, also
scrubbed with its read latch. Total private arithmetic storage is therefore
18 KiB (16 KiB shared scratch plus 2 KiB pair scratch). CPU ROM/data allocations
remain separate. This small memory increase replaces thousands of registers
and wide arithmetic paths; it does not remove any key-pair validation.

## Service descriptors

The engine serializes a command and its held response. Commands 0x30–0x34 use
the services below; other commands go to the arithmetic block. Services borrow
the accelerator's private memory port while arithmetic is idle. Result reads
are possible only with neither command owner active.

| Opcode | Arguments | Behavior |
|---|---|---|
| 30 | destination, 32, force-odd, 0 | Draw exactly 32 MSW-first words; reverse limb order; optionally set only bit zero. |
| 31 | 0, 32, 64, q-mode | Apply range, optional p/q separation, exponent compatibility and trial-prime checks; prepare W−1 and its odd part. |
| 32 | 96, 0, 0, 0 | Accept witness only in [2,W−2]. |
| 33 | first-check, 0, 0, 0 | Check the exponentiation/square result and bound the remaining squarings. |
| 34 | 0, 0, 0, 0 | Validate the p/q pair, compute and check d, clear d, then retain n. |

Malformed descriptors return an error before memory mutation. Service status
0x10 is context-specific (redraw, square again or restart pair); controllers
interpret it only in the phase that requested it. See source for the complete
status mapping. Unexpected responses become arithmetic errors.

The dedicated controller counts only candidate failures specified by the
algorithm. It permits 10,240 failures for p and 20,480 for q. Accepted DRAW
commands may wait indefinitely for external data. Internal command admission
and non-DRAW execution have a 50-million-cycle watchdog; expiry reports code 7.
Outer cleanup runs before terminal failure becomes visible to the caller.

## Reproducible verification

- `scripts/test_rsa_services.ps1`: separate Verilog source/SV test compilation
  and bounded services tests in Questa.
- On Linux/WSL, `python3 scripts/run_integration_verilator.py --suite services`:
  **49 checks passed**, including malformed descriptors, draw order, filtering,
  witness rejection, exact q separation, held responses, eight-square limits,
  failure coincident with the last input word and cached-state reset.
- `scripts/run_full_verilator.py --directed --seeds 1`: complete dedicated
  generic RSA passed, including all five rounds per prime, pair arithmetic,
  exact 129-word n/e/p/q output, ownership and cleanup.

Directed candidates remove prime search from this test. The measured
historical 133,559,973 dedicated cycles are functional evidence,
**not** the twenty-seed search benchmark. Normal SHA-stream searches, actual
Altera full-key simulation and final board acceptance have separate evidence.

Review checklist: rejection counters and ordering match the algorithm;
descriptors cannot escape scratch bounds; witness rejection does not consume a
round; pair failure clears secrets; no status from one command is reused by the
next. No build or test result here authorizes merging automatically.
