# DE1 high-speed SPI validation

Validated November 3, 2026, against parent organization revision `a0f9bb4`.
PR #37 remains a draft while exact 24 MHz hardware acceptance is pending.

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
