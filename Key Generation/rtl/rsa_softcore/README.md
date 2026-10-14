<!--
Filename: README.md
Authors: Project contributors; see Git history.
Date: 2026-10-13
General Description: Documents Softcore feasibility slice.
AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.
-->

# Softcore feasibility slice

The later real RSA sequencing controller is documented in [RSA_CONTROL.md](RSA_CONTROL.md). This page retains the independently reproducible initial boot milestone.

This revision proves that a portable Verilog RV32I CPU boots and controls a descriptor handshake. It is **not RSA firmware** and does not generate a key. The accelerator is represented by a testbench handshake peer, explicitly implementing only test opcode 0. No production success is returned by a fake RSA engine.

## Read in this order

1. This page: memory map, transaction and limits.
2. `../../firmware/softcore_boot.S` (from the Key Generation root, `firmware/softcore_boot.S`): 24 public self-test instructions.
3. `keygen_softcore_control.v`: scrub/release, native memory bus and descriptor bridge.
4. `../../testbench/softcore/tb_softcore_boot.sv` (root `testbench/softcore/`): independent stimulus and checks.
5. Root `IP/third_party/picorv32/README.md`: pin, license and local cleanup patch.

## Fixed feasibility contract

Single clock, active-low reset held for at least one rising edge. Board integration must synchronize reset release. Readiness stays low while 4096 RAM words are cleared, one word per clock. The CPU remains reset throughout. This slice exposes no key request or whole-result ownership interface yet.

| CPU address | Meaning |
| --- | --- |
| 0x00000000..0x00007fff | 32 KiB read-only firmware ROM; generated image, initialized explicitly |
| 0x10000000..0x10003fff | 16 KiB data RAM, byte write enables, scrubbed on reset |
| 0x40000000 | COMMAND, full-word write: opcode in bits 7:0; accepted only idle with no unacknowledged completion |
| 0x40000004 | STATUS read: bit 0 busy, bit 1 done, bits 15:8 response code |
| 0x40000008/+0x0c/+0x10/+0x14 | ARG0..ARG3, full-word writes while idle only |
| 0x40000018 | ACK, full-word write clears completed response when not busy |
| 0x4000001c | Public self-test REPORT, read/write; not a key result register |

The command descriptor holds stable until command_valid AND command_ready. After command acceptance, response_ready permits one response. Completion remains visible until ACK. Opcode 0 is reserved for self-test; mathematical opcodes 1+ will be frozen with the accelerator. ARG0..3 are opaque public descriptors here, not operands. There is no CPU load path into accelerator scratch or a generation stream.

Example: firmware writes args 32, 64, 96, 32, submits opcode 0, polls done, rejects a nonzero response code, acknowledges success, writes 0x600d0001 to REPORT and loops. An error produces 0xffffffff. The SV peer delays command acceptance and response independently.

Unknown addresses, ROM writes, unsupported MMIO reads/writes, instruction fetch from MMIO and partial MMIO writes assert a sticky bus fault output until reset. Parent integration must treat trap_o as failure and perform subsystem reset/cleanup; this feasibility module is not the final job controller.

ROM initialization is a boot-image contract. FPGA synthesis uses the explicit image. Generic ASIC delivery requires ROM-content mapping by the target flow; this prototype does not claim an ASIC physical implementation.

## Reproduce

From the repository root in PowerShell:

```powershell
& './Key Generation/scripts/softcore/run_sim.ps1'
& './Key Generation/scripts/softcore/run_synthesis.ps1'
```

The scripts build under `Key Generation/build/softcore/`. Source compiles in Verilog-2001 mode, then the separate SV testbench. Simulation requires its explicit PASS marker, not just a zero process exit. The firmware builder emits a full ROM image and SHA-256 manifest; the expected manifest is checked in, generated binaries are not. The assembler supports only the small documented RV32I instruction subset used by this self-test; a general C compiler/toolchain is still required for RSA control firmware.

## What this proves / does not prove

Questa 2024.3: source compilation 0 errors/0 warnings; PASS at 421980 ns for boot, stalled command stability, success/error response, full RAM scrub, CPU data-register reset, repeat boot, and reset with a command pending. Simulation's single warning is +acc disabling some optimizations.

Synthesis report is recorded separately below. This isolated slice is not place-and-route or timing closure, not the generic-versus-Altera resource equivalence suite, not a complete 32 KiB firmware workload, and not board validation. Current ROM contains 24 instructions; synthesis may compress unused constant ROM contents. Both RSA implementations must still use common arithmetic and lifecycle contracts before a key-generation claim.

## Synthesis feasibility result

Quartus Pro 26.1, device A5ED013BB32AE4SCS: synthesis succeeded, 3383 logic cells and 64 RAM segments reported. These are synthesis resource units, not post-fit ALMs. The 16 KiB RAM inferred altsyncram 4096x32 with byte enables after combining scrub and normal writes into one physical write port. No Fitter, timing closure or board test was run.

Warnings requiring later integration review: missing board Reset Release IP in this intentionally board-independent top; inherited PicoRV32 full_case/parallel_case synthesis attributes and shift-width truncations; inferred RAM read-during-write bypass logic. The synthesized DRC snapshot reports no high-severity rule failure and one medium-severity rule category. That initial result predates the shared RAM conversion. Current macro-backed CPU RAM and actual generic/Altera simulation evidence are documented in RSA_CONTROL.md.
