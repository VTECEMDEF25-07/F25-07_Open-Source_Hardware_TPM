# DE25 OCRAM LCD firmware

This freestanding AArch64 payload drives the dedicated HPS UART1/SPIM0/GPIO
LCD island. It uses OCRAM only: no DDR, Linux, SD-card or persistent-media setup.
The guarded entry requires core0, EL3, little endian and MMU/caches disabled.

## Validated build

The customer display uses plain operation messages and omits provider qualification,
operation IDs, detail codes and sequence counters. Raw snapshot fields and frame
acknowledgements remain available in host logs; `diagnostic_status_lines` retains
the engineering renderer. No input or stale input prompts the user to start the
laptop demo. Unavailable RNG and test-key mode remain visibly identified.
RNG assessment scope and limits are recorded separately in validation results;
the display change does not change RNG qualification or crypto logic.

Use Windows Python, WSL Ubuntu-24.04 and the pinned official Arm GNU13.2.Rel1
AArch64 toolchain already placed under a separate runtime directory. The builder
checks archive SHA256
`7fe7b8548258f079d6ce9be9144d2a10bd2bf93b551dafbf20fe7f2e44e014b8`.
It performs no install, FPGA programming or UART operation.

```text
python "Source Code/Display/firmware/build_ocram.py" --runtime-root ABSOLUTE_RUNTIME_DIRECTORY --output-dir NEW_OUTPUT_DIRECTORY --strict-align
```

Use `--strict-align` for the customer payload and preserve old build directories.
The global target flag prevents unaligned accesses during MMU-off execution.
Actual hardware without it raised alignment fault ESR0x96000061 at an odd-address
halfword stack store. No SCTLR/MMU/cache or clock workaround is used.

Output conversion is ELF→raw binary→Intel HEX at address0. This preserves every
linked byte/address and emits aligned download records. Direct section-based HEX
previously made the native programmer reject a data-group start at0x2e88.
The canonical strict binary remains byte-identical to the strict compiler output.

Runtime-validated HEX SHA256:
`ac99cb165cd4ffdce411d1e7e1ac761f107b29e6cf785354698821971f1b76b2`.
Raw binary SHA256:
`97372323a13d0c3923873cdac0a56c8fa139cd63681f8129894d3f1100e697c6`.
Target code/builder are equivalent to owner commit
`1008ce165f6cc1d72112a69fe460a3194979e7fe`; later integration docs do not alter code.
Debug ELF/map hashes depend on build paths; use each build's matching symbols.
The builder passes225 cold-init,1087 board/diagnostic and176 parser/render checks.

## Cold initialization and transport

Before peripheral writes, software validates the actual fixed big-endian SDM
handoff in OCRAM at0x7f000, sparse pin offsets, clock fields and disabled bridges/
DDR. Initialization uses the DE25-specific generated clocks, not a generic board
recipe. Main NOC is400MHz and L4_SP/UART100MHz; UART requests1152008N1 and
SPIM0 requests500kHz. All waits have iteration/time guards; one stalled MMIO bus
transaction cannot be bounded by a software loop.

SPIM0 uses mode0,8-bit transmit-only data. GPIO34/35/42 control LCD reset, D/C
and backlight. Initialization clears all132 columns before display-on; frames
use128×64 pixels. UART receives the three actual FPGA uint32 snapshot fields
`status_word`, `operation_id`, `sequence`. Duplicate genuine heartbeats are valid;
no valid input for two seconds redraws STALE. Host/software state is not invented.

The fatal exception reporter is integer-only, has no timer/parser dependency,
and attempts UART reporting only after stage2 initialization, once. Diagnostic
checkpoints quiet after the first completed frame. `FRAME_SENT <sequence>` means
software completed its write path; it cannot establish visible pixels.

## File packaging and runtime proof

Only combine the checked HEX with a fitted HPS-enabled SOF after full FPGA
source/timing/reset/pin/clock review. File-only Quartus Pro26.1 commands:

```text
quartus_pfg -c -o hps_path=CHECKED_HEX FITTED_COMBINED_SOF NEW_PACKAGED_SOF
quartus_pfg -i NEW_PACKAGED_SOF
quartus_pfg -c -o hps_handoff=ON NEW_PACKAGED_SOF NEW_HANDOFF_BIN
```

Inspect actual device/HPS/boot-order metadata and extracted handoff. The lead's
strict file preflight checks exact candidate HEX, checksums,16-byte record starts,
ELF load bytes/addresses, memory bounds and fitted pin/clock/power layout before
a memory-bounded volatile load. No flash/SD/QSPI/boot-switch changes are required.

Actual final packaged-image execution passed original PhaseI8suites/84assertions/
0failures and fresh AES/RSA2048 laptop-encrypt/FPGA-decrypt operations. An independent
log audit matched246 actual FPGA status tuples to246 raw UART frame ACKs. Held
AES DONE, two-second no-input redraw and resumed actual input were checked.
**Visible glass, orientation and contrast remain unverified.** Exact separate
FPGA/firmware/packaged-SOF identities and host replay are documented in
`Testing/Host/DE25_CUSTOMER_DEMO.md`.
