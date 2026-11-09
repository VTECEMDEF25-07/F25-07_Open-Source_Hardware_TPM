# DE25 internal TPM clock sweep — November 8, 2026

**Highest tested passing core clock: 160.000 MHz (3.20× the original 50 MHz).**
This is a nominal PLL clock, verified from fitted clock constraints and the exact
programmed SOF hash, without an independent oscilloscope frequency measurement.
The result covers the existing TPM command path; RNG and keygen are inactive and
may be optimized away in this image. It is not their clock limit or an end-to-end
throughput multiplier. No production margin recommendation is implied.

## Routed results

All variants start from reviewed SPI integration `80597de2b42828cd49141e13b225c718020e3f08`.
Only PLL C0/C1 dividers and the corresponding generated-clock constraints change.
Core and reset-clock frequencies retain their 1:2 relationship. SPI remains
constrained at 30 MHz; the original fan controller stays on the raw 50 MHz input.
No algorithm, voltage, fan setting or CDC exception was changed for this sweep.

Fresh full Quartus Pro 26.1 builds completed for all four variants. The table
contains worst slack across all four operating corners in ns. The unchanged
hardened audit also checks mailbox routes, synchronizer stages, pulse widths,
missing timing collections, unconstrained paths and legacy-detector absence.

| Core MHz | Full audit | Setup | Hold | Recovery | Removal |
|---|---|---:|---:|---:|---:|
| 100.000 | PASS | +0.358 | +0.001 | +0.809 | +0.005 |
| 160.000 | PASS | +0.054 | +0.023 | +0.052 | +0.069 |
| 177.778 | FAIL | -0.046 | +0.002 | -0.132 | +0.060 |
| 200.000 | FAIL | +0.020 | +0.009 | -0.265 | +0.011 |

The first 50 MHz fit reported 141.3 MHz same-clock Fmax. That was an estimate
for that placement; fresh fits can improve it. At 160 MHz, same-clock Fmax is
211.95 MHz, but reset release is tighter: `tpm_release_reg[1]` launches from the
falling edge of the twice-core clock into TPM core registers. Only a quarter
core period is available. Its worst setup/recovery margins are +0.054/+0.052 ns.
Report this reset constraint when assessing the limit; Fmax alone omits related
cross-clock paths. Faster failing configurations were not programmed.

All ten routed pins match the verified DE25 RevD USB-adapter map. Source changes,
period checks, hashes, corner counts and detailed margins are recorded in
[timing-results.json](tmp/de25-core-clock-20261108/timing-results.json).

## Physical original C tester

DE25 A5ED013BB32AE4SCS, JTAG ID `4364C0DD`; FTDI serial `FTA6H280`.
Every successful run completed all eight original suites and exited zero.
The existing Linux compatibility port preserves assertions and transaction
vectors; tester/source hashes matched the prior audit. No simulation result
is counted as a physical pass.

| Nominal core MHz | Configured SPI MHz | Passing runs / total |
|---|---:|---:|
| 50.000 | 1 | 1/1 |
| 50.000 | 15 | 1/1 |
| 50.000 | 30 | 0/1 |
| 160.000 | 1 | 3/3 |
| 160.000 | 15 | 3/3 |
| 160.000 | 30 | 0/3 |

The configured 30 MHz tests fail with a command-execution polling timeout in
the status-state-machine suite, including at the original 50 MHz core. A faster
core therefore does not fix that physical SPI failure. Requested 24 MHz selects
30 MHz with the existing library; no true 24 MHz acceptance is claimed.

Ideal-clock original-assertion simulations passed at 100 and 160 MHz core,
each with 1/30 MHz SPI. These do not replace routed or physical checks.

## Final state and evidence

The board was restored to the exact reviewed **50 MHz** image, then all eight
original suites passed at 1 and 15 MHz SPI. FTDI interface 0 was reattached.
The shared hardware lock was used throughout programming/tests. Programmer
memory/swap ceilings remained 1536 MiB; no container resource change was made.
The independent vendor fan logic was retained throughout. This image has no
temperature/RPM monitor; no new thermal-acceptance claim is made.

The SPI branch is pushed through documentation commit `511f9e0`; PR #37 targets
main and remains open/mergeable, with no CI checks reported. Its description and
DE25 validation document explicitly record the physical high-speed failure.
Main was not merged or modified. Faster clock variants remain local experiments.

| Core MHz | SOF SHA256 |
|---|---|
| 50.000 | `56e28b3ded10ea1d856d4ff6c3a1dac5652e1e00954749a08f3efdd87a2ba573` |
| 100.000 | `e346b90cac022d60f48efdbdc4d80cdb3891752176bcd64520d06325ba16c471` |
| 160.000 | `6dd2160c040f1c31ca2e7be9a89084db10091621adb1bb591df061b46d2eb8bb` |
| 177.778 | `d6b54da3dcba04793bf28ab89717a686bf65fe08476e3ca43d2c4d6a654e2532` |
| 200.000 | `5e50079e8b161625921efd87511644e8dd6a19d68cb4147674c9857a69c8db1d` |

Evidence: [baseline](tmp/de25-core-clock-20261108/baseline-results.json),
[160 MHz](tmp/de25-core-clock-20261108/c20-results.json),
[restoration](tmp/de25-core-clock-20261108/restore-results.json),
[simulations](tmp/de25-core-clock-20261108/simulation-results.json).
Audit logs and detailed core-path reports remain in
`AI/tmp/de25-core-clock-20261108/`; server raw physical logs remain in
`/mnt/SSDs/fpga-dev/workspace/de25-core-20261108-01a1bd97/`.
Reproduction helpers: `prepare.py`, `simulate.py`, `core_paths.tcl`,
`collect_results.py` and `remote_test.py` in that class-local evidence folder.
