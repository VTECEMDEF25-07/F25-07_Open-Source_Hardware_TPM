# Implementation and evidence ledger

Target: RTL/generic, RTL/Altera, softcore/generic, softcore/Altera. Xilinx deferred.
Every entry remains pending until reproducible evidence is recorded.

| Requirement | Acceptance | Status |
|---|---|---|
| SYS-01 | AES128/256 exact4/8word results, gaps/stalls/repeated words | Standalone 51-operation simulation PASS; integrated generic lifecycle PASS both controllers. Board pending. |
| SYS-02/03 | RSA2048 algorithm mapping and independent full-key checks | Algorithm sheet reviewed against reference; 20-key software corpus independently checked. Full directed generic RSA PASS both controllers; dedicated generic normal seed1 PASS with exact54,336 input words. |
| SYS-04 | Four combinations simulate, fit and run | Two generic directed full-key configurations PASS. Vendor full-key simulation and board builds in progress. |
| SYS-05/06 | Captured request, ownership, scrub before status | AES and full directed RSA simulations PASS; reset-audited integrated lifecycle PASS28 checks each generic controller, including admission-gap faults. Final all-backend coverage pending. |
| SYS-07 | Prime retention and n/e/p/q transfer | Exact129-word comparison PASS both generic directed RSA controllers. |
| SYS-08 | Reset every phase, scrub and recovery | Pair12 busy phases, math scrub, CPU and integrated reset tests PASS; exhaustive integration phases and hardware pending. |
| SYS-09/10 | Isolated32bit stream, failure and replay | SHA20seeds×4blocks/stalls/replay PASS; source failure/captured operation tests PASS. Full search replay with stalls pending. |
| SYS-11 | Actual Altera models versus synthesizable generic | Resources2637 products/2750 reads/596 collisions/1300 stalls PASS; pair8 vectors and math48 full-width cases PASS both backends. Final full-core vendor gate pending. |
| SYS-12/13 | Verilog2001 source, separate SV tests, naming review | Project sources compiled in Verilog mode; third-party source exceptions documented. Final audit pending. |
| SYS-14 | Focused documented MRs, Aaron merges | In progress |
| Fit | Routed50MHz; reviewed unconstrained paths;70% resource target | Arithmetic-only routed PASS:12,266ALMs,8M20Ks,+12.503ns setup,+0.095ns hold. Original full design85%/92% estimates prompted pair optimization; optimized pair alone passes route at5,748ALMs/1M20K. Final whole-board fits running. |
| Speed | Each build median<=30s over fixed20seeds | Pending |
| Board | SPI3rates, reset/fault/replay,30min soak per build | Pending |

Measure accepted request through post-scrub terminal success with unstalled
source/receiver. Report SPI end-to-end time separately. Record every sample,
median and maximum, not inferred statistical tail guarantees.180s timeout fails
the host test, never weakens the algorithm.

Record source commit, configuration, tool versions, fixture/bitstream hashes,
command, explicit PASS/FAIL and report location. Generated reports stay outside
tracked source; commit concise reviewed summaries and reproducible scripts.

Review contracts/algorithm first, resources and AES next, arithmetic in small
chunks, then dedicated RSA and softcore independently. Review integrated board
evidence last. Each MR explains behavior/dependencies, an example, reading order,
tests actually run and limitations. Never merge automatically. Legacy AES is a
reference, not a dependency on the closed plumbing/store stack.

## Evidence locations and limits

Tests and commands are documented in `AES.md`, `RSA_ALGORITHM.md`,
`RSA_ENGINE.md`, `CORE.md`, `PAIR_CHECK.md`, `../IP/README.md`,
`../Math/README.md`, `../rtl/rsa_softcore/RSA_CONTROL.md` and
`../demo/de25_revd/README.md`. Generated simulator reports are under ignored
`../build/`; routed build reports and immutable source manifests are under the
class workspace's `AI/tmp/keygen-board-build/` and `AI/tmp/keygen-math-fit-altera32/`.

Directed RSA supplies known prime candidates and exercises all primality/pair
checks, but omits random search. Its ~2.67-second cycle count cannot establish
the 20-seed median requirement. The earlier SPI transport demonstration is not
key-generation hardware evidence. No final configuration is accepted yet.

Baseline normal SHA-stream seed1 completed on the dedicated generic build:
1,393,995,652 cycles, equivalent to 27.87991304 seconds at 50 MHz. Exact n/e/p/q
and source consumption matched the corpus. This used the original pair-storage
implementation before area optimization; it is one simulation sample, not a
final-source timing or hardware claim. Log: `build/full_rtl/seed-1.log`.

The corresponding soft-core normal seed1 baseline also passes with 54,336 words:
1,394,506,356 cycles (27.89012712 seconds at 50 MHz), exact same key. It has the
same original-pair limitation; log `build/full_softcore/seed-1.log`.

Optimized generic directed RSA with legal external stalls passes both controllers:
136,232,057 dedicated / 136,244,142 soft-core cycles, each 384 generation words.
Evidence is under `build/full_{rtl,softcore}_directed_stalls_optimized-v1/` with
source/firmware/binary manifests. These runs precede the later admission-gap and
CPU RAM output-latch fixes; affected final regressions must run again.

The CPU RAM output-latch fix passes generic and genuine Altera memory/control
tests, including nonzero stale data, reset, cleanup and repeated jobs. The real
SPI protocol test passes both generic controller configurations with actual core
logic and an independent AES oracle; this remains simulation, not board evidence.

Repository hygiene: `scripts/check_repository_hygiene.py` passed nine ignored
generated-path checks and ten trackable source/fixture/constraint checks.

## Registered-reset acceptance snapshot

The four contributed asynchronous FSM-decode reset drivers are registered; see
`RESET_AUDIT.md`. Final generic lifecycle tests pass 28 checks on both controllers.
The reset-audited directed RSA tests with legal external stalls also pass:
136,232,057 dedicated / 136,243,488 soft-core cycles, exactly 384 generation words
and 129 independently checked result words each. Manifests are retained under
`build/full_{rtl,softcore}_directed_stalls_reset-audited/`. Directed candidates do
not measure random-search performance.

The registered pair multiplier reset passes the complete generic and genuine
Altera suites with unchanged cycle counts, eight independent fixtures, twelve
busy reset phases and complete storage/latch clearing. Vendor evidence is under
class-workspace `AI/tmp/keygen-pair-registered-reset-altera/`; its direct captured
final console and verified input hashes are authoritative because the separate
native transcript developed SeaDrive NUL holes. The damaged transcript remains
preserved and is not represented as complete evidence.

Both genuine-Altera lifecycle configurations pass all 28 checks; evidence is
under `AI/tmp/keygen-lifecycle-vendor-reset-audited/` and
`AI/tmp/keygen-lifecycle-vendor-softcore-reset-audited/`. Complete vendor RSA runs,
all four routed builds and physical acceptance remain separate gates.
No final configuration has been accepted yet.

Arithmetic small-domain coverage additionally passes 10,771 independent cases
on both generic and genuine Altera resources, with identical preloaded vectors;
see `../Math/README.md` for exact commands and evidence locations.

## Initial physical validation, October 13

Reset-audited generic normal-stream seed 1 passes both controllers with the same
54,336 accepted words and independently checked key. Dedicated RTL takes
1,396,666,983 cycles; soft-core takes 1,397,148,558 cycles. The fingerprinted
reports are in `build/full_{rtl,softcore}_reset-audited/`. These are individual
simulation samples, not the required 20-seed hardware median.

The first soft-core/Altera board image routed at 25,842 ALMs (55%), 20 RAM blocks
and four DSP summary units. Worst board-clock setup slack is +1.491 ns; all
reported setup, hold, recovery, removal and pulse-width checks pass. Source
snapshots, post-tool configuration changes, timing exceptions and the remaining
nonzero DRC classes were reviewed. Evidence is retained in class-workspace
`AI/tmp/keygen-board-acceptance-v2/softcore_altera/` and the independent
`AI/tmp/keygen-reset-constraint-audit/FINAL_SOFTCORE_STA_REVIEW.md`.

That image was programmed and its exact 256-bit fingerprint verified. SPI
transport passes at 100 kHz, 500 kHz and 1 MHz. Both AES profiles pass, and the
first RSA seed passes independent validation at 1,397,148,551 board cycles
(27.94297102 seconds). Physical reports are in
`AI/tmp/keygen-hardware-final/softcore_altera/`. Despite that directory's name,
these are intermediate results: cooling remains in full-speed fallback and its
sensor sampling is being corrected. All 20 corpus keys now pass independent
checking: median 26.40469044 seconds, maximum 101.45542472 seconds, with every
host operation below 180 seconds. The separate corpus auditor correctly rejects
overall acceptance because all 757 cooling samples report fallback/invalid
health. Report SHA256: `1b76d8f935c792d6e8c1d1dd573d1e63048ba2ff6fc843f287bb48c85e783bef`.
Replay, reset, soak and other configurations remain pending. A corrected board image
must repeat acceptance. No thermal-health or final-completion claim is made.
