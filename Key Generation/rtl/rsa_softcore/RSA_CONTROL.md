# RSA firmware controller review

`keygen_rsa_softcore.v` now runs real compiled RV32I control firmware, `firmware/rsa_control.c`. It sequences the shared RSA service/arithmetic contracts; those external engines supply the cryptographic computation. The scripted-service test proves sequencing and recovery, not complete RSA generation.

## Read in order

1. This interface/ownership description.
2. `firmware/rsa_control.c`: prime search, five witness rounds, pair restart and status reporting.
3. `keygen_rsa_softcore.v`: job handshake, instruction-progress watchdog and cleanup before completion.
4. `keygen_softcore_control.v`: CPU memory/MMIO bridge and RAM scrub.
5. `testbench/softcore/tb_rsa_firmware.sv`: expected descriptor sequence and fault injection.

Paths above other than the local Verilog files are relative to `Key Generation/`.

## Ownership and job lifecycle

The controller accepts work_valid/work_ready once ready. It then boots the CPU from its reset vector with initialized public firmware and scrubbed RAM. No raw generation words or big integer operands are CPU-readable. The CPU issues one descriptor at a time, polls public status and acknowledges each response before issuing the next.

On firmware completion, CPU trap or progress-watchdog failure, the wrapper captures the public status, asserts local CPU/MMIO reset, clears all local RAM, then holds completion_valid/status until completion_ready. Successful math completion is not whole-core success: accelerator P/Q/N stay available for the outer protected receiver, which owns handoff and final accelerator-secret cleanup. External reset aborts without creating completion and blocks new work until RAM initialization finishes.

Status: 0 success; 2 generation failure; 3 exhausted candidate attempts; 4 arithmetic/service failure; 6 CPU/bus trap; 7 stalled instruction progress. The default watchdog watches instruction-fetch handshakes over 2^20 core clocks. The independent descriptor watchdog bounds internal command acceptance and every accepted non-DRAW response to 50000000 clocks (one second at 50 MHz), returning status7 with cleanup even while firmware keeps polling. After DRAW is accepted, external generation-source stalls have no time limit. The instruction watchdog still detects a CPU that stops fetching during that legal external wait. A logically incorrect loop that fetches instructions without issuing commands is not covered; outer orchestration supplies bounded demo/test waits and reset recovery.

## Service contract and procedure

Fixed little-endian scratch addresses: W0, W-1 at32, odd exponent M64, witness B96, Z128, P160, Q192, N224, ONE288, TWO320, temporary Z352; Montgomery workspace512. CPU access uses only addresses/lengths, never values.

| Opcode | Operation and arguments | Response predicates |
| --- | --- | --- |
| 0x30 | DRAW(dest,32,force_odd,0) | 0 accepted; nonzero generation failure |
| 0x31 | PREPARE_PRIME(W,W-1,M,q_mode) | 0 valid; 0x10 range redraw; 0x11 separation redraw; 0x12 composite/count retry |
| 0x11 | MOD_SETUP(W,512,32,0) | 0 success |
| 0x32 | WITNESS_CHECK(B,0,0,0) | 0 valid; 0x10 redraw witness |
| 0x13 | MODEXP(Z,B,M,32) | 0 success |
| 0x33 | MR_CHECK(first_result,0,0,0) | 0 round passes; 0x10 square again; 0x11 composite/count retry |
| 0x13 + 0x01 | MODEXP(TMP_Z,Z,TWO,1), COPY(Z,TMP_Z,0,32) | 0 success; avoids in-place assumptions |
| 0x01 | COPY(P or Q,W,0,32) | Preserve accepted prime |
| 0x34 | PAIR_CHECK(0,0,0,0) | 0 successful pair; 0x10 short d restarts both searches |

For each prime, five passing M-R witness rounds are required. Range, pair-separation and witness-range redraws do not advance the candidate rejection counter. Composite rejection from preparation or M-R increments it exactly once. Limits are 10240 rejected p candidates and 20480 rejected q candidates; reaching the limit returns status3. Both counters restart after a short-d pair restart. Final standards conformance depends on the independently checked service implementations and accepted FIPS mapping, not on the firmware alone.

## Reproduce and evidence

```powershell
& './Key Generation/scripts/softcore/run_rsa_sim.ps1' -Toolchain '<portable compiler bin directory>'
& './Key Generation/scripts/softcore/run_rsa_synthesis.ps1' -Toolchain '<portable compiler bin directory>'
```

Pinned compiler/reproducible ROM hash are documented in `firmware/TOOLCHAIN.md` and `firmware/rsa_control_manifest.json`. C compilation uses -Wall -Wextra -Werror. ROM text is 1648 bytes, data/BSS0; capacity32KiB ROM/16KiB RAM.

Questa2024.3 control regression PASS:118 descriptors at1089680ns; range/composite/witness rejection, five rounds, squaring, q separation, short-d pair restart, source/service failures, real illegal-instruction trap, watchdog fault, long service stall, reset abort, held completion, repeat job, and every CPU architectural register/RAM word cleared before completion. RTL compiled as Verilog2001; SV only in tests. Later retry-boundary and full-size integration results are recorded below.

QuartusPro26.1 actual RSA-controller synthesis on A5ED013BB32AE4SCS succeeded:3554 logic cells,64 RAM segments (explicit Altera RAM macro). These are synthesis units, not final ALMs, fit or timing closure. Warnings remain as documented in README: board Reset Release integration, inherited CPU attributes/shift widths, inferred RAM bypass/DRC. The CPU data RAM now uses the shared keygen_ram32 wrapper. Whole-word stores write directly; byte/halfword stores use a serialized read-modify-write, preserving other byte lanes. The wrapper adds the defined synchronous read acknowledgment cycle.

## CPU RAM backend validation

`run_rsa_sim.ps1 -Backend Generic` and `-Backend Altera` both pass the full 118-descriptor control regression at the same 1089680ns completion time. The Altera run loads actual `vendor.altsyncram` and `altsyncram_body` models from installed Quartus `altera_mf.v`; it is not a relabeled generic memory. Both builds also execute `memory_selftest.c` on PicoRV32: all byte lanes, both halfword stores, word stores, LBU/LHU/LW readback and final cleanup pass at171930ns.

Scrub validation observes all4096 sequential zero writes in both backends and checks every RAM word directly in the generic backend. Architectural register clearing is checked in both. CPU data RAM is a real shared-resource implementation, while immutable firmware ROM remains portable inferred readmemh content. The existing separate resource suite owns cycle-by-cycle RAM equivalence testing.

The same generic controller and memory-instruction tests also pass Verilator5.020 through `run_verilator.ps1 -Toolchain <bin> -Test Firmware` or `-Test Memory`. A verified temporary WSL symlink only shortens paths; actual sources/builds stay under the class root. The runner overrides GNU Make CURDIR with that alias because symlinks alone do not avoid its spaces restriction.

Source SHA-256 manifests normalize line endings to LF; generated machine-code hashes remain exact. The RSA firmware image hash remains a9b67a3d34031e12b4fc4afba521fbf13549d39523749980195c55fa9c86fb9f.

## Complete-key and retry-boundary evidence

Generic full-core integration passed directed RSA-2048 seed 1: 384 input words, 133572067 cycles, and exact reference n/e/p/q comparison after protected handoff and final cleanup. At 50 MHz that cycle count is 2.67144134 seconds. The directed stream supplies known acceptable prime candidates and five witnesses per prime; all arithmetic is real, but this does not measure candidate-search latency. Verilator simulation took 154.08 seconds. Canonical integration evidence is under `build/full_softcore_directed/`.

`run_verilator.ps1 -Toolchain <bin> -Exhaustion` additionally passed 61591 scripted descriptors using the unmodified production firmware limits. It verifies p exhaustion at 10240 and q exhaustion at 20480, status3 plus cleanup, exclusion of range/separation redraws from the counter, and inclusion of a Miller-Rabin composite. These tests validate control flow; the service peer remains scripted.

`run_full_altera_questa.py --source-root <integrated Key Generation directory> --softcore --directed --seeds 1` compiles unchanged installed `220model.v` and `altera_mf.v` with KEYGEN_ALTERA selected. Its default output directory is distinct from generic evidence. Genuine vendor full-top elaboration in Verilator5.020 failed on unsupported tristate semantics at lpm_mult's sum port, so this runner uses Questa. Do not substitute generic models or claim a passing run from compilation alone. Full vendor run results are recorded only after the final full-key PASS marker.

## Internal descriptor watchdog

The later wrapper fix adds `COMMAND_TIMEOUT_CYCLES=50000000` without changing the ROM image. Tests use 1000 cycles only for this timeout parameter, not the production prime retry limits. They hold DRAW acceptance indefinitely and require status7, accept PREPARE_PRIME but withhold its response while firmware actively polls and require status7, and accept DRAW then stall more than both test watchdog intervals without failure. An independent instruction-fetch stall during accepted DRAW still requires status7. Every terminal path retains CPU/register/RAM cleanup before completion. Earlier complete-key cycle counts above were measured before this watchdog addition; final complete-key and fit checks must use the updated wrapper.

## Vendor-run provenance

The actual-model Questa runner accepts `--label <unique-name>`. A fresh build records project RTL/testbench hashes, source firmware and ROM-image hashes, expected-key corpus hash, unchanged vendor-model hashes, simulator version, language/backend configuration, runner hashes, and exact compiler commands in `build-manifest.json`. Each run records generated stimulus/reference hashes, the exact simulation command, linked build-manifest hash, status and final log hash. It refuses to overwrite existing build/run manifests; select a new label for new evidence.

`--reuse-build` rejects changed source, model, runner, firmware, simulator or configuration fingerprints. Matching reuse plus all six stale-input rejection classes were checked. Historical baseline directories predate this provenance support and must not be relabeled as final acceptance runs.

Stable Verilator5.052 was also built locally from official tag v5.052 (source commit ea338be98e1e838d3518809ce8899f85a009963c). It still rejects the unchanged lpm_mult sum-port tristate semantics, including constant, named-wire and unused-port connection probes. The complete local build, license notices and compatibility logs remain in class-root AI/tmp/keygen-verilator. This failed compatibility experiment supplies no full-key acceptance evidence; use the actual-model Questa runner.

## CPU RAM output-latch cleanup

RAM initialization now performs 4096 zero writes, a synchronous read of the cleared final word, and one wait edge before readiness. This clears the wrapper/vendor RAM output latch as well as its array. The added two-cycle tail runs after external reset and every job's cleanup. No CPU interface or firmware change is required.

The memory-instruction test creates a nonzero RAM output, aborts the active job with reset, requires a zero latch before readiness, and then runs two complete jobs. Both normal completion and reset recovery must clear the stale latch. This fix is independent of the optional blocking-STATUS performance experiment.
