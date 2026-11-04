# Common SPI transport for DE1 and DE25

Both projects instantiate one portable `spi_slave.v` through `tpm_io`.
External SCK clocks the mode-0 pin interface; the TPM runs at 50 MHz.
There is no board selector or vendor SPI core in the shared source.

## Interface and host contract

- Mode 0, MSB first. Required operating range: 10--24 MHz; slower rates are
  supported. Routed constraints additionally target 30 MHz, with equal high/low
  SCK intervals. MISO is constrained to <=0.7 of the half-period (11.667 ns
  at 30 MHz), reserving 5 ns for capture setup at that extra test rate.
  Unit and protocol simulations include exact 24 and 30 MHz.
- MOSI setup >=2 ns and hold >=3 ns at the FPGA pads. MOSI changes on falling
  SCK. For the complete legacy TPM, retain CS setup, hold and deselected
  intervals >=100 ns. The serializer alone is tested at 5/5/50 ns; those
  minimum intervals are not accepted for the entire TPM command path.
- Keep CS high and SCK low during global reset and for >=1 us after reset
  release. An interrupted transfer must be restarted as a new frame.
- TX valid/data stay stable until acknowledged. Each request asks for the next
  byte while the current byte shifts; the producer must supply it before its
  boundary. This interface does not provide unlimited backpressure.
- RX valid, TX request and TX received are one-core-cycle pulses. MISO is
  tri-stated directly by raw CS. The first transmitted byte after CS is zero.

RX shifts on rising SCK; a completed byte is snapshotted on the following
falling edge. That mailbox and its event toggle survive CS deassertion, so the
last byte can reach the core after a short frame. TX shifts on falling SCK.
A held-data offer is acknowledged only when consumed at a byte boundary.

Two-register toggle synchronizers transfer RX events, TX requests, offers and
consumption acknowledgements. Each data mailbox remains stable across its
capture window. CS has its own two-register synchronizer. An additional eight
50 MHz cycles delay both transaction-controller CS edges equally, letting the
existing controller drain the final RX byte while preserving frame gaps.

The transaction controller, FIFO/registers, TPM commands, execution, management
and crypto logic are unchanged. This PR targets PR #36's board-support branch.

## Board and ASIC boundary

DE1 uses raw 50 MHz with no PLL. DE25 retains its board PLL, reset, fan and
read-only JTAG support; its 100 MHz output serves reset release. The shared
TPM/IO interface takes no 100 MHz clock or board-specific SPI parameter.
Pin-register packing and SCK routing settings belong in each board QSF.

The serializer is Verilog-2001 without vendor primitives, generated FPGA IP or
proprietary simulation models. Vendor IP may be used behind board wrappers;
reusable functionality must retain an open-source ASIC alternative. ASIC
integration must supply pad/clock/reset cells, map synchronizers appropriately,
and repeat CDC, reset and physical timing signoff for its own library.

## Reproduce verification

Run from the repository root with fresh output directories:

```text
python "Simulation/IO Interface/simulate_spi.py" --build FRESH_UNIT_DIR --questa-bin QUESTA_BIN
python "Simulation/IO Interface/simulate_tpm_spi.py" --board DE1 --spi-hz 24000000 --build FRESH_DE1_DIR --questa-bin QUESTA_BIN
python "Simulation/IO Interface/simulate_tpm_spi.py" --board DE25 --spi-hz 24000000 --build FRESH_DE25_DIR --questa-bin QUESTA_BIN
python Project/build.py --board DE1 --compile --quartus QUARTUS_LITE_SH
python Project/build.py --board DE25 --compile --quartus QUARTUS_PRO_SH
quartus_sta -t Project/verify_spi_timing.tcl DE1
quartus_sta -t Project/verify_spi_timing.tcl DE25
```

Repeat protocol tests at 100 kHz, 1, 10, 15 and 30 MHz. The isolated bench also
covers 500 kHz, 20 asynchronous phase offsets at each rate >=1 MHz, duplex and
consecutive bytes, delayed TX acknowledgement, stopped-high SCK, 5 ns CS
setup/hold with 50 ns gaps at 24/30 MHz, partial-frame abort and reset/replay.
Protocol runners retain the original checked-in assertions and use ideal board
clock/reset models, without proprietary simulation IP.

`Project/spi_timing.sdc` constrains SCK at 30 MHz, MOSI at 2/3 ns setup/hold
and MISO at <=0.7 of the half-period. The physical tester run at 30 MHz is
additional lab evidence, not a new standards rating or a measured 24 MHz test.
Exceptions are restricted to first synchronizer stages, held-data mailbox hold
checks between unrelated clocks, and asynchronous startup reset pins. The
mailboxes retain maximum-delay constraints; the audit also checks physical
bus delay <=20 ns independently of clock skew. CS framing recovery/removal,
synchronizer interstage timing, MISO data and core reset release remain timed.
The DE25 reset exception requires the explicit inactive-CS startup contract.
CS startup is modeled with a virtual frame-start event: 10 ns before first
SCK on DE1 and 5 ns on DE25. The full-TPM host contract remains >=100 ns
setup/hold/high on both boards; minimum 5 ns board compliance is not claimed.

The audit checks setup, hold, recovery, removal and pulse width at every
available corner, verifies all five synchronizer chains and mailbox paths,
and rejects legacy serializer registers. It exports detailed timing,
metastability and unconstrained-path reports. Pro additionally exports
structural CDC and ignored-exception reports; Lite exports its exception report.
Structural CDC classification alone does not prove the mailbox protocol.

A diagnostic full-TPM replay with 5/5/50 ns CS framing fails 13 existing
assertions (locality and command responses), despite the isolated serializer
passing that framing. Retain the legacy 100 ns framing contract; resolving
minimum-frame-gap behavior needs separate investigation.

See each board's `VALIDATION.md` for actual results and hardware limitations.
Generated transcripts, manifests and programming images remain outside tracked
source. Simulation and routed timing do not establish measured pad waveforms,
full TPM certification or ASIC signoff.

AI disclosure: Codex authored the shared transport, integration, constraints,
validation tooling and documentation with project contributor review pending.
