# DE25 synchronous SPI follow-up

This is a separate SPI implementation change based on board-support PR #36
(`aaron/de25-board-management`, `c86520528ae7c66228e2bc06266d6bf15fcaf1a0`).
The parent PR's board-support scope remains separate.

## Behavior and boundary

The original DE25 build reported -2.700 ns setup slack from external SCK into
the legacy dual-edge detector. Its transmit shifter also used a logic-generated
clock. DE25 now explicitly selects `DE25_SPI=1` through `tpm_top` and `tpm_io`.
`de25_spi_slave` synchronizes SCK, MOSI and CS through two-register chains,
detects edges synchronously and clocks all byte/handshake state at 50 MHz.
The transaction controller receives the same synchronized CS as the serializer.

Default `DE25_SPI=0` retains the existing DE1 serializer and raw-CS connection.
The original `spi_slave.v`, transaction controller, register/FIFO logic, TPM
commands, execution/management and cryptographic modules are unchanged.
No key-generation source, tester application, hardware programming or new
TPM command implementation is included.

## FPGA IP and ASIC portability

Board implementations may use vendor IP behind board-specific wrappers, but
reusable functions must retain an open-source alternative for ASIC use. The
SPI serializer here is portable Verilog with no Altera primitives, generated
IP, proprietary simulation models or FPGA-specific clocking constructs.
The existing PLL/configuration-reset/JTAG blocks remain board dependencies;
an ASIC integration supplies its technology clock/reset/debug wrappers and
maps the synchronizer registers to suitable standard cells. This is a source
portability boundary, not an ASIC implementation or physical-signoff claim.

The byte interface remains a one-cycle RX-valid/request with a level-valid TX
offer acknowledged by the serializer. The producer prepares the next byte
while the current byte shifts. Deselect/reset clears serializer partial data.

## Supported host timing

- SPI mode 0, MSB first, at most 1 MHz; each SCK high/low interval >=500 ns.
- Change MOSI on falling SCK and hold it through rising SCK.
- CS setup before first SCK, hold after last SCK and deselected interval each
  >=100 ns (five 50 MHz clocks). Allow synchronization latency after reset.
- A producer must supply the requested next byte before its byte boundary;
  the transport does not add arbitrary byte-level backpressure.

Only each asynchronous pad-to-first-stage path is excepted in SDC. Exact
hierarchy/count checks reject missing synchronizers. Interstage and functional
paths remain timed. SCK is data, not an STA clock in this design. QSF marks
both registers in each chain for synchronizer identification. The read-only
JTAG probe and independent fan/reset support retain their existing constraints.

## Reproduce

From the repository root, using fresh output directories:

```text
python Boards/DE25/simulate_spi.py --build FRESH_UNIT_DIR --questa-bin QUESTA_BIN
python Boards/DE25/simulate_tpm_spi.py --build FRESH_TPM_DIR --questa-bin QUESTA_BIN --spi-hz 1000000
python Boards/DE25/simulate_tpm_spi.py --board DE1 --build FRESH_DE1_DIR --questa-bin QUESTA_BIN
python build.py --board DE25 --compile --quartus QUARTUS_PRO_SH
python build.py --board DE1 --compile --quartus QUARTUS_LITE_SH
```

Repeat the DE25 protocol runner with 100000 and 500000 Hz. It preserves the
original vector assertions, changes the host rate, adds board-startup settling
and converts interactive stops into failing exits. Board PLL/configuration/fan
models are ideal test adapters, never synthesis inputs or vendor-IP validation.
The unit bench covers 20 one-nanosecond CS/SCK phase offsets relative to the
core at 1 MHz, delayed TX acknowledgements, high-clock pauses, partial-CS abort,
mid-bit reset and subsequent replay.

After a successful DE25 compile, from `Boards/DE25/`:

```text
quartus_sta -t verify_spi_timing.tcl
```

This audits setup/hold/recovery/removal and pulse width at every available
corner, requires timed interstage paths for all three chains and rejects
remaining legacy detector/shifter registers. It exports CDC, metastability,
unconstrained-path and ignored-exception reports for review.

## Evidence and limits

See the synchronous-SPI follow-up in `VALIDATION.md` for measured results and
`spi_validation.json` for source/report/bitstream hashes. Internal timing and
functional simulation do not establish physical-adapter acceptance, analog
metastability immunity or full TPM conformance. No fresh hardware run is claimed.
DE1's inherited serializer limitations remain outside this follow-up.

AI disclosure: Codex reused the earlier project synchronous SPI implementation,
adapted the opt-in integration/constraints and authored the regression tooling,
timing audit and documentation. Existing inherited warnings are recorded in
the retained logs; they are not silently treated as TPM correctness evidence.
