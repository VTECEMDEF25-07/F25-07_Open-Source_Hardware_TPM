# Common SPI transport for DE1 and DE25

Both board projects instantiate the same `spi_slave.v` through `tpm_io`.
There is no board selector, legacy serializer or vendor-specific SPI module.
All serializer state runs at 50 MHz, with SCK/MOSI/CS each crossing through
two-register synchronizers before use. SCK edges act as enables, never clocks.
The transaction controller receives the serializer's synchronized CS.

## Interface and host contract

- SPI mode 0, MSB first, <=1 MHz; SCK high and low intervals each >=500 ns.
- Change MOSI on falling SCK and hold it through rising SCK.
- CS setup, hold and deselected interval each >=100 ns (five 50 MHz clocks).
- A producer holds TX valid/data until acknowledged and supplies a requested
  next byte before its boundary. The first response byte is prepared while
  the current byte shifts; the serializer does not add unlimited backpressure.
- RX-valid and next-byte request are one-cycle pulses. Deselect/reset clears
  partial serializer state. Allow synchronization latency after reset.

The original transaction controller, FIFO/registers, TPM commands, execution,
management and crypto functionality remain unchanged. This is a transport
replacement in PR #37, targeting PR #36's board-support branch.

## Board and ASIC boundary

DE1 uses its raw 50 MHz clock, without the old unused 100 MHz PLL. DE25 retains
its board PLL/reset/fan/JTAG support; its 100 MHz output serves reset release,
not SPI serialization. The shared TPM/IO interface no longer takes a 100 MHz
clock or a board-specific SPI parameter.

Vendor IP is permitted behind board wrappers, provided reusable functions
retain an open-source alternative for ASIC use. This common serializer is
portable Verilog, without vendor primitives, generated FPGA IP or proprietary
models. ASIC integration supplies clock/reset wrappers and maps synchronizer
registers to suitable standard cells. ASIC physical signoff is not claimed.

## Verification

From the repository root, using fresh output directories:

```text
python "IO Interface/simulate_spi.py" --build FRESH_UNIT_DIR --questa-bin QUESTA_BIN
python "IO Interface/simulate_tpm_spi.py" --board DE1 --spi-hz 1000000 --build FRESH_DE1_DIR --questa-bin QUESTA_BIN
python "IO Interface/simulate_tpm_spi.py" --board DE25 --spi-hz 1000000 --build FRESH_DE25_DIR --questa-bin QUESTA_BIN
python build.py --board DE1 --compile --quartus QUARTUS_LITE_SH
python build.py --board DE25 --compile --quartus QUARTUS_PRO_SH
quartus_sta -t Boards/verify_spi_timing.tcl DE1
quartus_sta -t Boards/verify_spi_timing.tcl DE25
```

Use the matching Quartus edition's `quartus_sta` for each audit. Repeat protocol
tests at 100000 and 500000 Hz. The unit bench covers 20 one-nanosecond phase
offsets at 1 MHz, duplex/back-to-back bytes, delayed TX acknowledgement, stopped
SCK, partial-CS abort, mid-bit reset and replay. Protocol runners preserve the
original checked-in vector assertions, adjust host rate/startup settling and
convert interactive stops into failing exits. Ideal board models are test-only.

Each SDC excepts only the asynchronous pads into their respective first-stage
register. Interstage and functional paths remain timed. The audit requires
each chain to exist and remain timed, checks every available timing corner,
rejects remaining legacy detector/shifter registers and exports CDC,
metastability, UCP, ignored-exception and detailed timing reports.

See each board's `VALIDATION.md` and `Boards/spi_validation.json` for current
results and hashes. Internal timing and functional simulations do not replace
physical adapter setup/hold measurements or full TPM/ASIC signoff. Board reset,
fan and read-only JTAG findings remain explicitly reported, without broad
exceptions being added to suppress them.

AI disclosure: Codex adapted the earlier project synchronous SPI implementation
into the common source, removed the legacy transport/selector and authored
the integration, constraints, validation tooling and documentation.
