# Common SPI transport

Both board projects instantiate one portable Verilog-2001 `spi_slave` through
`tpm_io`. External SCK clocks the pin interface; TPM processing stays at 50 MHz.
The shared interface has no 100 MHz clock or board-specific SPI selector.

## Host and producer contract

- Mode 0, MSB first, equal SCK high/low intervals. The required operating range
  is 10â€“24 MHz; verification also covers slower clocks and 30 MHz.
- MOSI setup/hold at the FPGA pads must be at least 2/3 ns. MISO output-valid
  is constrained to â‰¤0.7 half-period, leaving 5 ns host setup at 30 MHz.
- For the complete TPM, keep CS setup, hold and deselected intervals â‰¥100 ns.
  The isolated serializer's 5/5/50 ns tests do not establish that framing for
  the complete command path.
- Keep CS high and SCK low during global reset and for â‰¥1 Âµs after release.
  Restart interrupted transfers as new frames.
- Hold TX valid/data until acknowledged and supply the requested next byte
  before its boundary. The interface has no unlimited backpressure. RX valid,
  TX request and TX received are one-core-cycle pulses. The first TX byte is
  zero; raw CS directly tri-states MISO.

RX shifts on rising SCK and snapshots a complete byte on the following falling
edge. The held byte/event survives CS deassertion. TX shifts on falling SCK;
offers are acknowledged only when consumed at a byte boundary. Two-register
toggle synchronizers carry RX events, TX requests, offers and acknowledgements.
CS has a two-register synchronizer and eight additional core cycles of equal
delay on both edges, allowing the transaction controller to drain the last byte.

DE1 uses raw 50 MHz without a PLL. DE25 retains its PLL and autonomous vendor
fan logic; its 100 MHz output serves reset release. Pin packing and clock routing
remain board-local. ASIC integration must supply appropriate pad/clock/reset
cells and repeat CDC and physical timing verification for its library.

## Verification

Run from the repository root with fresh output directories:

```text
python "Testing/Simulation/IO Interface/simulate_spi.py" --build UNIT_DIR --questa-bin QUESTA_BIN
python "Testing/Simulation/IO Interface/simulate_tpm_spi.py" --board DE1 --spi-hz 24000000 --build DE1_DIR --questa-bin QUESTA_BIN
python "Testing/Simulation/IO Interface/simulate_tpm_spi.py" --board DE25 --spi-hz 24000000 --build DE25_DIR --questa-bin QUESTA_BIN
```

The unit suite covers 100/500 kHz and 1/10/15/24/30 MHz, asynchronous phase
offsets, consecutive duplex bytes, delayed acknowledgement, paused SCK, CS abort
and reset/replay. Repeat full-TPM replays at the desired rates. Original assertions
are retained; board clock/reset adapters are ideal simulation models. SPI replay
selects Generic resources for the inactive keygen placeholder so it does not need
proprietary memory models. Board synthesis retains its Altera default.

Build each board from its project folder using the matching Quartus edition
(Lite/Standard for DE1, Pro 26.1 for DE25):

```text
quartus_sh --flow compile de1_soc_top
quartus_sh --flow compile de25_soc_top
```

Then, from the repository root with the same matching edition:

```text
quartus_sta -t Project/verify_spi_timing.tcl DE1
quartus_sta -t Project/verify_spi_timing.tcl DE25
```

`Project/spi_timing.sdc` constrains SCK at 30 MHz, MOSI/MISO windows and CS
frame start (10 ns on DE1, 5 ns on DE25). The full-TPM contract remains â‰¥100 ns.
Exceptions cover first synchronizer stages, held-mailbox hold checks between
unrelated clocks and specified asynchronous reset pins. Mailbox maximum-delay,
synchronizer interstage, CS framing and core reset-release paths remain timed.
The audit checks all available corners, five synchronizer chains and mailbox
routes, and rejects the old logic-clocked serializer. Review its detailed timing,
metastability and unconstrained-path reports; CDC classification alone does not
prove the mailbox protocol.

See [DE1 validation](../../Project/DE1/VALIDATION.md),
[DE25 validation](../../Project/DE25/VALIDATION.md) and
[open follow-ups](../../FUTURE_WORK.md). Simulation/timing results do not imply
physical acceptance of a different bitstream. Generated outputs are not tracked.

AI disclosure: Codex assisted with the SPI implementation, integration,
verification tooling and documentation; contributor review remains required.
