# Full-plan completion matrix

**Review snapshot: October 13, 2026. Overall status: INCOMPLETE.**

This matrix covers the approved four-build delivery, not merely a working demo.
PASS below applies only to the stated evidence and scope. PENDING is not approval.
The coordinating lead must update final build identities and physical results
before supplying this document to the release packager. Aaron retains MR review
and merge authority.

Paths beginning `build/` are relative to `Key Generation/`. `CLASS/AI/tmp/` means
the class workspace's evidence directory. Every final selection must retain its
manifest, exact input hashes, command/tool versions and completed result. A source
revision alone does not replace those hashes.

## Four-build acceptance

| Build | Complete-key simulation | Final routed board image | Final physical acceptance |
|---|---|---|---|
| Dedicated / generic | **PASS:** reset-audited directed+stalls and normal SHA seed1; see simulation table below. | **PENDING:** select and review final fan/source-offer-corrected image. | **PENDING:** all required actions and healthy soak on that exact image. |
| Dedicated / Altera | **PASS:** genuine installed models, directed+stalls, 136,232,057 cycles. | **PENDING:** select and review final fan/source-offer-corrected image. | **PENDING:** all required actions and healthy soak on that exact image. |
| Soft-core / generic | **PASS:** reset-audited directed+stalls and normal SHA seed1. | **PENDING:** select and review final fan/source-offer-corrected image. | **PENDING:** all required actions and healthy soak on that exact image. |
| Soft-core / Altera | **PENDING:** final actual-model run `build/full_altera_softcore_directed-reset-audited-pipe/`; running is not PASS. | **PENDING:** select and review final fan/source-offer-corrected image. | **PENDING:** repeat acceptance after correcting the initial image's cooling failure. |

The portable core simulation snapshot includes the registered-reset and cleanup
fixes. Later board-only fan and source-offer changes need their own board-wrapper
regression and final image evidence; they do not turn earlier physical results
into results for the new image.

| Simulation evidence | Result / limitation |
|---|---|
| `build/full_rtl_directed_stalls_reset-audited/` | PASS: 384 input words, 129 exact result words, 136,232,057 cycles. |
| `build/full_softcore_directed_stalls_reset-audited/` | PASS: same words/results, 136,243,488 cycles. |
| `build/full_rtl_reset-audited/` | PASS: normal SHA seed1, 54,336 words, 1,396,666,983 cycles. |
| `build/full_softcore_reset-audited/` | PASS: normal SHA seed1, 54,336 words, 1,397,148,558 cycles. |
| `build/full_altera_rtl_directed-reset_audited_capture_v1/` | PASS: real `220model.v`/`altera_mf.v`, exact generic cycle count, clean final transcript, unchanged inputs. |
| `build/lifecycle_rtl/`, `CLASS/AI/tmp/keygen-softcore-reset-audited/lifecycle-generic-results.json` | PASS: 28 final integration checks per generic controller. |
| `CLASS/AI/tmp/keygen-lifecycle-vendor-reset-audited/`, `keygen-lifecycle-vendor-softcore-reset-audited/` | PASS: 28 checks per actual-Altera controller. |

Directed prime candidates exercise full arithmetic/primality/pair validation but
skip candidate search. Their approximately 2.725-second result is **not** evidence
for the twenty-seed search median. Normal seed1 alone is also not that median.

## Requirement-by-requirement review

| Requirement | Status and evidence | Remaining closure |
|---|---|---|
| SYS-01 AES128/AES256 | **PASS, simulation:** standalone51-operation suite, exact4/8word assembly, repeated values/gaps/stalls; integrated lifecycle both controllers/backends. See `AES.md` and `ACCEPTANCE.md`. | Both profiles on each final physical image. |
| SYS-02/03 RSA2048 / fixed65537 / selected procedure | **PASS, mapped implementation and component tests:** `RSA_ALGORITHM.md` freezes bounds, trial251, five accepted witnesses, counters, separation and canonical d. Independent checker covers primality, relationships and round trips. | Final soft-core actual-model complete-key result and all four physical corpora. No FIPS certification claim. |
| SYS-04 both RSA architectures | **PASS, implemented:** dedicated FSM and PicoRV32 firmware use shared services/arithmetic and the same stream procedure. Generic normal/direct runs agree on keys and word consumption. | Complete final four-way latency/resource comparison; select a recommended default from measured evidence. |
| SYS-05/06 admission, ownership, terminal status | **PASS, simulation/review:** captured ID/profile, one request, held results/status, independent whole-result ownership, no success before cleanup. `INTERFACE.md`, `CORE.md`, lifecycle28; independent review `CLASS/AI/tmp/keygen-acceptance-audit/FINAL_PUBLIC_AES_REVIEW.md`. | Final physical reset/fault/reuse reports; external receiver/context coordination remains an integration responsibility. |
| SYS-07 n/e/p/q and private d validation | **PASS, simulation:**129word exact comparison; independent pair n/LCM/canonical-d fixtures and low-d retry branch. `PAIR_CHECK.md`, `RSA_ALGORITHM.md`. | Exact independent checks on all final hardware corpus results. CRT preparation remains deferred. |
| SYS-08 reset / local clearing | **PASS, component/integration tests:**8AESslots,4096math words,512pair words,4096CPU RAM words, hidden read latches and relevant registers; reset/held-output/repeat cases. `RESET_AUDIT.md`, `PAIR_CHECK.md`, `RSA_CONTROL.md`. | Final physical observable-boundary recovery. Physical SPI cannot by itself prove every hidden storage bit is zero. |
| SYS-09/10 source words, failure and replay | **PASS, source/component tests:** SHA20seeds×4blocks, full-width seeds, stalls/replay/counter failure; controller failure paths. Predictable source is demo-only. | Final same-seed hardware pause/replay and explicit generation-failure error2/discard/reuse for each image. External production fresh/repeatable service remains outside delivery. |
| SYS-11 generic/actual Altera resources | **PASS, resource/component equivalence:**2637products,2750reads,596collisions,1300stalls; full-width math/pair suites plus10,771small-domain cases. `IP/README.md`, `Math/README.md`. | Final soft-core full actual-model result and four routed configurations. Never count generic substitution as vendor evidence. |
| SYS-12/13 naming / Verilog source | **PASS, tested build configuration:** project RTL compiled Verilog2001 separately from SV tests; imported identifiers documented. `BUILD_AND_TEST.md`, CPU provenance. | Final reviewed source/constraint inventory must match selected manifests; no new SV source exception assumed. |
| SYS-14 progressive reviews | **IN PROGRESS:** focused draft MRs and review queue `CLASS/AI/PR_REVIEW_QUEUE.md`. | Final MRs explain dependencies, reading order, behavior, real tests and limitations. Aaron reviews/merges; no automatic merge. |

The pair checker's private 2 KiB allocation is documented: total arithmetic scratch
18 KiB, plus soft-core 32 KiB ROM and 16 KiB data RAM. Shared math's reserved DIV/GCD/LCM/
inverse opcodes are not implemented as public commands; the required fixed-e pair
operations are implemented privately in the pair checker.

## Arithmetic, controllers and cleanup evidence

| Gate | Evidence / disposition |
|---|---|
| Independent arithmetic | `Math/README.md`:48full-width cases and full1024-bit exponent tests on generic and genuine models. `CLASS/AI/tmp/keygen-math-small-{generic,altera}-preload/`:10,771independent small-domain cases, carry/borrow boundaries and pseudoprime arithmetic examples. **PASS.** |
| Pair validation / canonical d | `CLASS/AI/tmp/keygen-pair-registered-reset-{generic,altera}/`:8fixtures, twelve busy-reset phases, held-result reset, storage/latch cleanup. **PASS.** Vendor `final-console.json` and verified hashes are authoritative; damaged native transcript is retained and disclosed. |
| Dedicated retry/watchdog flow | `CLASS/AI/tmp/keygen-controller-final/result.log`, controller tests: real10240/20480limits, bounded command/internal-response waits, legal source waits and first fault. **PASS.** Scripted service tests prove control flow, not substitute arithmetic. |
| Soft-core firmware/control | `rtl/rsa_softcore/RSA_CONTROL.md`:119descriptor real-CPU tests, production retry exhaustion, traps/watchdogs, blocking status and RAM-latch cleanup on generic/Altera. **PASS within documented configurations.** |
| Portable reset generation | `RESET_AUDIT.md`:registered controls replace four contributed asynchronous state decodes; synchronizer/release behavior and imported Pico synchronous reset reviewed. **PASS.** Imported board-management scope is reviewed separately. |
| Demo source offer persistence | `CLASS/AI/tmp/keygen-source-hold-review/installed/`:actualSPI/SHA with controllable core model preserves pending offers, consumes exactly once, pauses/resumes without word loss, clears on reset. Old baseline fails same assertion. **PASS for focused test.** Real-core SPI tests also pass for both controllers with mid-RSA holds and transfer/ownership assertions: `CLASS/AI/tmp/keygen-real-spi-hold-final-{soft,rtl}/`. |

## Physical gates required for every selected image

Each of the four physical columns above stays PENDING until **all** rows below
are linked to the same selected source snapshot, SOF hash and loaded 256-bit
fingerprint. A filename containing “final” does not establish finality.

| Gate | Required evidence / current disposition |
|---|---|
| FPGA fit and clock | Full routed50MHz; reviewed setup/hold/recovery/removal/pulse-width, CDC/reset/constraints, all warnings; exact ALM/register/M20K/DSP use and <=70%principal-resource target. Four final selections **PENDING**. |
| Programmed identity | JTAG programming outcome/SOF hash plus all8fingerprint words and controller/backend/test-mode checks. Final selections **PENDING**. |
| Transport | Separate100kHz,500kHz,1MHz scratch/framing/partial-abort reports. Final selections **PENDING**. |
| AES and RSA corpus | AES128/256 and all20fixed seeds, independently validated key components. Record each core cycle count and host elapsed time, median/max; median<=30s, every host job<=180s. Final selections **PENDING**. |
| Replay and fault recovery | Same-seed source pauses, five observable reset boundaries, four source-failure boundaries with error2/no-stale/discard, then AES128/AES256/RSA reuse. Final selections **PENDING**. |
| Cooling and soak | Healthy temperature/fan/freshness samples; gray reset leaves cooling operational. At least30minutes mixed AES128/AES256/RSA per image, errors and samples retained. Final selections **PENDING**. |

The initial soft-core/Altera image at
`CLASS/AI/tmp/keygen-board-acceptance-v2/softcore_altera/` passed routed timing and
fit at 25,842 ALMs (55%), 20 RAM blocks and 4 DSP summary units. Its physical 20-seed corpus
passed mathematical checks (median 26.40469044 s, maximum 101.45542472 s), but cooling
remained in fallback. The independent corpus audit rejected its 757 unhealthy
samples. `CLASS/AI/tmp/keygen-hardware-final/softcore_altera/` is therefore
**intermediate/rejected for final cooling acceptance**, not a closed hardware
gate. Corrected fan/source-offer images must repeat physical acceptance.

## Provenance, licenses, packaging and delivery

| Gate | Status / evidence |
|---|---|
| Firmware reproducibility | Pinned xPackGCC15.2.0-1, RV32I/ILP32flags, source and exactROM hashes in `firmware/TOOLCHAIN.md`, `rsa_control_manifest.json`; current control text1648bytes. **PASS for recorded build.** Final ROMs must match selected manifests. |
| Upstream CPU / tool licenses | PicoRV32 ISC license and pin `ef203c2b0a3fb793280f5114941416c425c5b461` preserved with documented runtime cleanup patch. Toolchain licenses retained with external dependency; no toolchain redistribution assumed. **Human final license/provenance review required**, including board vendor sources. |
| Vendor model provenance | Unchanged installed Quartus24.1models under Questa2024.3; QuartusPro26.1fits establish actual Agilex5mapping. AUTO-family warning and Verilator incompatibility documented. Proprietary models excluded from release payload. |
| Evidence gate tooling | `scripts/package_release.py` at17b7f36 independently reviewed;26testsPASS, including missing rates/configs, failed cooling, bad hashes, timing chronology and relocated package preparation. **PASS for tooling, not a completed release.** |
| Selected release artifact | **PENDING:** four approvedimages with ninehardware report roles each, final simulation summaries, this reviewed matrix, licenses and SHA256index. `RELEASE.md` defines package/rebuild commands and limitations. |
| Rebuildability | Packager retains audited originals and prepares a separate relative-path snapshot with new fingerprint/tool version. Unit relocation testPASS; any actual rebuilt image needs new timing/physical acceptance. No inherited approval. |
| Final comparison and user review | **PENDING:** concise four-way correctness/latency/resource table, recommended default, residual limitations and progressive MR reading order. No whole-plan completion until all required cells close. |

`PACKAGED_MACHINE_GATES_PASSED` does not certify human timing interpretation,
license rights, full simulation coverage or whole-spec completion. This matrix
must be updated with the selected evidence and an explicit final review outcome;
the packaging script does not infer approval from its existence.

Production entropy/DRBG assurance, hierarchy seeds/context services, TPM command
parsing/authorization/wrapping/persistence, side-channel/physical-security
assurance, ASIC physical implementation and Xilinx-specific resources remain
explicit external or deferred work. Test keys and SPI export are demonstration
facilities, not a production secret-key interface.

## Review record

- Independent arithmetic/resource/public-core reviewer: component and dedicated
  actual-model evidence above; final public/AES review found no new blocker.
- Independent gap review at4049bec identified source-offer legality and missing
  physical source-fault evidence; focused offer regression passes, final physical
  reports remain required.
- Independent packaging review: the original 19 tests passed but missed concrete
  false-pass cases; 17b7f36 corrections independently rerun: 26/26 PASS.
- Actual Windows build review found an SDC CRLF-versus-logical-LF false rejection;
  5db4336 preserves exact raw hashes and normalizes only the logical comparison.
  Independent CRLF acceptance and snapshot-tamper tests both pass.
- Final coordinating reviewer / selected build identities / completion date:
  **PENDING**. Do not replace this with an automatic package success string.
