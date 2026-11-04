# DE1 validation

Author: Aaron Grossman

## PR #36 synchronization - November 4, 2026

PR #37 incorporates parent `de776b7` and remains ready for review. The
original vendor fan integration, removal of the optional JTAG monitor,
`de25_clock` name and direct Quartus workflow are retained. The common
SCK-clocked SPI transport and 50 MHz TPM processing remain in place.

- Full matching-edition Quartus build: PASS; 919 ALMs, 4 RAM blocks,
  0 PLL(s). All 18 physical pins checked. Both projects use six build processors.
- Original TPM protocol assertions: PASS at 1, 24 and 30 MHz using the updated
  board model. The test runner now matches the lowercase `tpm_types.vh`
  include on case-sensitive hosts. Simulation is not a physical-board test.
- Routed timing audit: PASS at all four available corners. All five SPI
  synchronizer chains and the mailbox data paths remain checked.
- The SPI serializer RTL is unchanged by this merge; its prior isolated
  unit results remain applicable. No legacy serializer or DE1 PLL is restored.

| Worst slack, ns | Result |
|---|---:|
| Setup | +1.428 |
| Hold | +0.127 |
| Recovery | +4.718 |
| Removal | +5.891 |
| Pulse width | +8.434 |

SOF SHA-256: `da5585f8bf5716a64801daff73df50c61980a7d2b43446153e3cd416475e62d7`.

Local evidence is under the class `AI/tmp/`: `pr37-sync36-de1-build.log`,
`pr37-sync36-de1-timing.log`, `pr37-sync36-de1-*` protocol
snapshots and `pr37-sync36-fit-check.json`. Fan logs use the
`pr37-sync36-vendor-fan*` names. Generated evidence is outside tracked source.

**Exact 24 MHz physical acceptance remains outstanding**, as recorded in
[FUTURE_WORK.md](../../FUTURE_WORK.md). The >=100 ns full-TPM CS framing
contract is unchanged. The results below describe the pre-synchronization
image and do not validate the new fan/monitor configuration.
Parent-only results are available in
[PR #36's validation record](https://github.com/VTECEMDEF25-07/F25-07_Open-Source_Hardware_TPM/blob/de776b747a3757f671b242f1e0848e5eea786254/Project/DE1/VALIDATION.md).

## DE1 high-speed SPI validation

Validated November 3, 2026, against parent organization revision `a0f9bb4`.
PR #37 is ready for review. Exact 24 MHz hardware acceptance remains pending
and is tracked in [FUTURE_WORK.md](../../FUTURE_WORK.md).

- Quartus Lite 24.1 full build: PASS; Cyclone V 5CSEMA5F31C6, 920 ALMs,
  4 RAM blocks, zero PLLs. All 18 physical pin assignments verified.
- Original TPM protocol assertions: PASS at 100 kHz, 1, 10, 15, 24 and 30 MHz
  using the DE1 test-only board model. The 21 inherited bench warnings remain.
- Shared serializer unit regression: PASS at 100/500 kHz and 1/10/15/24/30 MHz,
  including phase offsets, back-to-back bytes, short framing and reset/replay;
  zero simulator errors or warnings.
- Final routed audit: PASS at all four available corners. Five synchronizer
  chains remain timed. UCP reports zero unconstrained clocks, ports and paths.

| Worst slack, ns | Result |
|---|---:|
| Setup | +1.427 |
| Hold | +0.154 |
| Recovery | +4.477 |
| Removal | +6.120 |
| Pulse width | +8.434 |

SCK is constrained at 30 MHz, MOSI at 2/3 ns setup/hold, and MISO at <=0.7 of
its half-period. The frame-start model checks 10 ns CS setup on this GPIO
board. **The complete TPM host contract retains >=100 ns CS setup/hold/high.**
The isolated serializer's 5/5/50 ns simulation does not establish board-level
minimum framing compliance. A full-TPM minimum-framing diagnostic fails 13
existing assertions; that remains a separate investigation.

DE1 uses local SCK routing with input/output register packing and fitter seed 2.
Mailbox constraints include physical register duplicates; each logical bit is
checked, and the audit additionally bounds physical bus delay to 20 ns.
Worst measured routed bus delay is 4.528 ns. This is a timing-report value,
not a laboratory waveform measurement. External reset exceptions remain;
the synchronous core, SPI CS framing and synchronizer interstage paths stay timed.

No DE1 board was physically tested. See [the common SPI guide](../../Source%20Code/IO%20Interface/SPI.md)
for reproduction commands, reset/framing assumptions and ASIC integration limits.

Serializer SHA-256:
`dc6dfbc3f27fc5543616491bac09628cd5cbd25534b08c8e20938780e5f692f3`

SOF SHA-256:
`1988f9a072a4e5fad94fa410627b72229db8ff4aff42697185cbe48aae3bc08a`

Generated acceptance evidence remains in the class `AI/tmp/`: the
`spi24-accepted-v2-de1-*` simulation directories, `spi24-unit-accepted`,
`spi24-layout-de1-compile-v13-contract.log` and `spi24-de1-accepted-timing.log`.
These local artifacts are intentionally outside tracked source.
