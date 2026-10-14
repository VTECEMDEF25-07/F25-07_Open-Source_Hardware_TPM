# Four-build comparison

**In progress: no final default is recommended yet.** Each row must pass the
same simulation, routed timing and physical acceptance gates. A passing corpus
alone does not complete a row. The [completion matrix](COMPLETION_MATRIX.md)
records the full requirement coverage.

## Measured results

All generation times below are measured hardware core cycles divided by 50 MHz.
The median uses all 20 fixed seeds; each host operation also has a 180-second
deadline. Directed simulation fixtures are excluded from this performance table.

| Configuration | 20-seed median | Slowest seed | Occupied ALMs | M20Ks | Final physical acceptance |
|---|---:|---:|---:|---:|---|
| Dedicated / generic | Pending | Pending | Pending | Pending | Pending |
| Dedicated / Altera | Pending | Pending | Pending | Pending | Pending |
| Soft-core / generic | Pending | Pending | Pending | Pending | Pending |
| Soft-core / Altera | 26.40469044 s | 101.45542472 s | 30,504 / 46,800 (65.18%) | 20 / 358 | Corpus and recovery pass; 30-minute soak running |

Soft-core / Altera meets the 30-second median target. All 20 keys passed
independent checks and every host operation met its deadline. Its corpus logged
754 healthy cooling samples, a maximum reported temperature of 32 C and fan
speeds of 3,600–3,660 RPM. SPI passed at 100 kHz, 500 kHz and 1 MHz. Both AES
profiles, reset recovery, source-failure cleanup/reuse and deterministic source
stall replay passed on the same loaded image.

## Resource and timing interpretation

Use **occupied ALMs** to discuss physical fabric headroom. Quartus also reports
logic needed, which is smaller and does not include all placement overhead.
The soft-core / Altera image needs 27,261 ALMs (58.25%) but occupies 30,504
(65.18%), leaving 34.82% physically unoccupied. Actual team integration can
change packing and timing; this percentage is not a guarantee that another
design of that size will route.

The same image uses 24,366 registers and 284,504 memory bits. Its fitter reports
4 needed DSP blocks and 6 physical DSP blocks out of 188; the flow summary uses
a different metric, 4 out of 376. These denominators must not be mixed.

Routed minimum slack is +1.729 ns setup, +0.068 ns hold, +14.445 ns recovery and
+0.096 ns removal. All total negative slack values are zero. Clock/reset
crossings, timing exceptions, remaining DRC warnings and the absence of
unconstrained paths were separately reviewed before programming.

## Selected evidence

Paths below start at the class workspace. Each build manifest identifies the
exact compiled source, configuration, tool version and padded firmware ROM.

| Configuration | Build | Physical evidence |
|---|---|---|
| Soft-core / Altera | `AI/tmp/kga4/softcore_altera/` | `AI/tmp/keygen-hardware-v4/softcore_altera/` |

Soft-core / Altera identities:

- Build fingerprint: `630fcd0833cbcd9f2d804bfd501d798e4fb92eaaf139e4639ed545bfd7e86d17`.
- SOF SHA-256: `60db202a52d3acd629c4f215f2d12062ba3259937286d627269216222d70bd0b`.
- Corpus report SHA-256: `66ae64a70ea5ddedc4b69ee9966749945fb8a3a5ec88546618ab10b3d50f9e7e`.

The earlier image under `keygen-hardware-final` failed cooling acceptance and
is retained only as historical evidence. It is not selected for release.

## Choosing a default

Both controllers remain available. Compare complete, accepted rows before
choosing the default: generation latency, physical resource use, timing margin
and the practical benefit of firmware control. A smaller controller does not
automatically generate keys faster because both implementations share the
arithmetic engine. The final recommendation is pending the remaining measured
results and acceptance gates.
