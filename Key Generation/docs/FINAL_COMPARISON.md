# Four-build comparison

**In progress: no final default is recommended yet.** Aaron waived the
30-minute soaks and requested delivery within 20 minutes on October 13.
Correctness, recovery and final generic-board validation were not waived.
The [completion matrix](COMPLETION_MATRIX.md) records the full coverage and
remaining work.

## Measured results

All generation times below are measured hardware core cycles divided by 50 MHz.
The median uses all 20 fixed seeds; each host operation also has a 180-second
deadline. Directed simulation fixtures are excluded from this performance table.

| Configuration | 20-seed median | Slowest seed | Occupied ALMs | M20Ks | Final physical acceptance |
|---|---:|---:|---:|---:|---|
| Dedicated / generic | Pending | Pending | Pending | Pending | Pending |
| Dedicated / Altera | Running | Running | 26,661 / 46,800 (56.97%) | 12 / 358 | Hardware correctness/recovery running; soak waived |
| Soft-core / generic | Pending | Pending | Pending | Pending | Pending |
| Soft-core / Altera | 26.40469044 s | 101.45542472 s | 30,504 / 46,800 (65.18%) | 20 / 358 | All non-soak gates pass; soak waived |

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

Dedicated / Altera needs 23,116 ALMs and occupies 26,661, leaving 43.03%
unoccupied. It uses 12 M20Ks and 6 physical DSP blocks out of 188. Its minimum
slack is +2.442 ns setup, +0.002 ns hold, +14.320 ns recovery and +0.012 ns
removal, with zero total negative slack. The small positive fan hold/removal
margins are retained explicitly; the 50 MHz board clock's hold margin is
+0.073 ns. Final source/configuration and report hashes were independently
verified before programming.

## Selected evidence

Paths below start at the class workspace. Each build manifest identifies the
exact compiled source, configuration, tool version and padded firmware ROM.

| Configuration | Build | Physical evidence |
|---|---|---|
| Soft-core / Altera | `AI/tmp/kga4/softcore_altera/` | `AI/tmp/keygen-hardware-v4/softcore_altera/` |
| Dedicated / Altera | `AI/tmp/kga4/rtl_altera/` | `AI/tmp/keygen-hardware-v4/rtl_altera/` |

Soft-core / Altera identities:

- Build fingerprint: `630fcd0833cbcd9f2d804bfd501d798e4fb92eaaf139e4639ed545bfd7e86d17`.
- SOF SHA-256: `60db202a52d3acd629c4f215f2d12062ba3259937286d627269216222d70bd0b`.
- Corpus report SHA-256: `66ae64a70ea5ddedc4b69ee9966749945fb8a3a5ec88546618ab10b3d50f9e7e`.

Dedicated / Altera identities:

- Build fingerprint: `8e8762d85f844755c3bdca8e5174e97bc3bbf602f0abee0c9e47bbb89111b310`.
- SOF SHA-256: `ac56d6e160784bdd0fbf88d58c161a49142162db144b7db3e14f2172b1db5375`.

The earlier image under `keygen-hardware-final` failed cooling acceptance and
is retained only as historical evidence. It is not selected for release.

## Choosing a default

Both controllers remain available. Compare complete, accepted rows before
choosing the default: generation latency, physical resource use, timing margin
and the practical benefit of firmware control. A smaller controller does not
automatically generate keys faster because both implementations share the
arithmetic engine. The final recommendation is pending the remaining measured
results and acceptance gates.
