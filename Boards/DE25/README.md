# Phase 1 TPM migration to DE25

## Purpose

`de25_soc_top.v` is the DE25 Standard RevD board entry point for the existing
`tpm_top`: SPI I/O, management module, and execution engine. It does not connect
the key-generation subsystem or implement missing TPM functions.

The migration is complete only after the original tester's applicable assertions
pass on the DE25 and reset, cooling, resource use and timing have been checked.
A simulation pass or successful FPGA compile alone is not hardware acceptance.

## Board layout

The 50 MHz oscillator clocks Phase 1 and autonomous cooling. Configuration
completion, KEY0 and SPI reset qualify TPM reset; SPI reset does not reset
cooling. No HPS processor is used despite the conventional `soc_top` name.

This top selects `DE25_SPI=1`: a synchronous 50 MHz mode-0 SPI serializer,
supporting host clocks up to 1 MHz. Its two-stage synchronized clock, MOSI and
chip-select inputs feed ordinary clocked logic. Chip select is synchronized for
the transaction controller as well. The old serializer remains selected by
default (`DE25_SPI=0`) in `tpm_top`/`tpm_io`, preserving the existing board path.
That legacy path still requires its original 100 MHz sampling clock. The DE25
path does not consume that port, so it is tied to the existing clock and requires
no PLL. All contributed synthesizable sources are Verilog-2001.

Why this adaptation: the old serializer used a combinational transmit pulse
clock and mixed raw SPI, rising/falling-100-MHz and 50-MHz state. The DE25 path
removes those crossings without changing the TPM register or command protocol.
SPI half-period and CS setup/hold must each be at least five 50-MHz cycles.
Start hardware testing at 100 kHz; 24 MHz is not supported here.

The shared fan-management implementation and fan guard come from the already
verified board support under `Key Generation/demo/de25_revd`; no cryptographic
core or keygen SPI protocol is included. Optional read-only JTAG diagnostics use
the standard vendor probe macro (installed vendor JTAG implementation includes
VHDL). Our project sources remain Verilog.

| Top port | Board connection | FPGA pin |
|---|---|---|
| `clock_i` | CLOCK0_50 | CH128 |
| `board_reset_n_i` | KEY0 | BW59 |
| `spi_clock_i` | Orange, JP1 pin 10 / GPIO_D9 | BU28 |
| `spi_mosi_i` | Yellow, JP1 pin 6 / GPIO_D5 | BM31 |
| `spi_miso_o` | Green, JP1 pin 4 / GPIO_D3 | BF40 |
| `spi_cs_n_i` | Brown, JP1 pin 8 / GPIO_D7 | BP31 |
| `spi_reset_n_i` | Gray, JP1 pin 14 / GPIO_D11 | BW28 |
| `interrupt_n_o` | Purple, JP1 pin 2 / GPIO_D1 | BE43 |
| Ground | Black, JP1 pin 12 | Ground |
| `fan_i2c_scl` | Board-management SCL | BF120 |
| `fan_i2c_sda` | Board-management SDA | BH118 |

Blue is unused; red and white remain disconnected. Pin assignments are verified
against the retained Terasic RevD reference before preparing each build.

## Review order

1. `../../de25_soc_top.v`: physical interfaces, reset boundary, cooling.
2. Existing `../../TPM_TOP.v` and `../../IO Interface/tpm_io.v`: Phase 1 wiring.
3. `../../IO Interface/de25_spi_slave.v`: synchronous SPI serializer and regression.
4. `prepare_phase1.py`, `de25_soc_top.sdc`: snapshot contents and timing assumptions.
5. `tester/`: bounded launcher and minimally adjusted original C tester.

The `GENERIC_BUFFER` address-width calculation now uses a constant function
instead of `$clog2`, allowing strict Verilog-2001 compilation with the same
address width for its existing buffers.

## Reproducible checks

From the repository in WSL/Linux:

```sh
python3 Boards/DE25/simulate_phase1.py --build /absolute/new/test-directory --spi-hz 1000000
```

The runner snapshots the real Phase 1 source and the checked-in generated SPI
vectors. It adjusts startup settling and SPI period, converts interactive stops
to bounded exits, and requires the original assertions and a final pass marker.
RTL is compiled in Verilog-2001 mode; only the bench/models use SystemVerilog.
Configuration and fan models are behavioral: this test does not validate
the physical I2C bus or actual board timing.

On Windows, prepare a new isolated build (no USB access):

```powershell
python Boards/DE25/prepare_phase1.py --build '<class-root>/AI/tmp/phase1-build-NEW' --compile
```

The build captures source/configuration hashes and includes no keygen RTL or
firmware. Full fit and clock/reset review must precede programming. The initial
timing constraints are not marked accepted until fitted reports are reviewed.
Only raw inputs feeding synchronizer first stages are excluded from synchronous
input timing; internal paths and reset release remain timed.

`DE25_PHASE1_DIAGNOSTICS` enables read-only JTAG identity/cooling telemetry without
changing the TPM SPI register map. Its 96-bit probe is `{32'h50315450,
health[7:0], fan_rpm[15:0], fpga_temperature[15:0], board_temperature[15:0],
5'b0, de25_spi_selected, tpm_reset_released, board_reset_released}`. Health bits 2:0 are
failsafe, temperature-valid, I2C-ready. Probe data is observational, not an atomic
sensor snapshot. The unused source output cannot control the hardware.

## Acceptance checklist

- [x] Original tester built with genuine FTDI library and pinned provenance (offline and hardware runs).
- [x] DE25-selected SPI path passes checked-in original protocol assertions at 1 MHz in simulation.
- [x] Full fit; reviewed setup/hold/recovery/removal and clock crossings.
- [x] Correct SOF programmed; Phase 1 identity and healthy cooling read back.
- [x] Original tester passes at 100 kHz, then 500 kHz and 1 MHz.
- [x] SPI reset recovery passes while cooling remains healthy.
- [x] Hardware limitations and Phase 1 placeholders recorded honestly.

Existing `tpm_top` ties several authorization, memory, self-test and command
completion inputs to constants. Passing these tests is evidence of the inherited
Phase 1 behavior, not complete TPM 2.0 or cryptographic compliance.

## Validated board result

The Phase 1 baseline passed all eight original hardware suites on 2026-10-13.
The final tester retains the original assertions and uses a documented 2 ms USB
latency timer, reducing host overhead without changing the FPGA protocol.

| SPI clock | All eight suites | Elapsed host time |
|---|---|---|
| 100 kHz | PASS | 4.095 s |
| 500 kHz | PASS | 2.869 s |
| 1 MHz | PASS | 2.891 s |

Quartus reports 1,538 / 46,800 ALMs (3%), 1,798 registers, two M20Ks and no
DSPs or PLLs. The 50 MHz core has 13.089 ns setup slack. All four timing
corners pass setup, hold, recovery, removal and pulse width; minimum hold
slack is 0.004 ns. No unconstrained paths or ignored exceptions remain in
the corrected analysis. Review the retained advisory dispositions in
[`validation/phase1_de25_2026-10-13.json`](validation/phase1_de25_2026-10-13.json).

The tested image is build v4. Its original configuration is preserved; JTAG
constraints were corrected and independently applied to the same fitted
netlist before programming. The reviewed SDC and bitstream are hash-bound in
the evidence. New builds consume the corrected SDC directly and need their
own fit/timing review. JTAG must read back **15M**, using the onboard adapter
and unchanged sampling mode. The output budget derives from the vendor's
30 MHz timing window plus the extra half-cycle at 15 MHz, with a 1 ns board
allowance; this is a documented operating assumption, not a trace measurement.

The final cooling readings and exact source, bitstream, tester and log hashes
are in the validation JSON. Repeated readings showed healthy cooling after
the test/reset sequences. The tester intentionally asserts gray/DBUS4 reset
when it closes, so idle monitor status **5** is expected. Reopening initializes
DBUS4 high and releases TPM reset; consecutive passing runs verify recovery.
Cooling is independent of that reset. The earlier monitor result marked FAIL
only because its checker incorrectly expected idle status 7; retained raw
readings show healthy cooling. JTAG capture is asynchronous, so use repeated
plausible readings rather than treating one word as an atomic sensor snapshot.

For the original suite on this workspace's pinned tester:

```powershell
python Boards/DE25/tester/run_original.py --exe '<class-root>/AI/tmp/original-tester-build-v2/tester.exe' --output '<class-root>/AI/tmp/NEW-run' --hardware --serial FTA6H280 --hz 1000000
```

For a saved-netlist audit using an optional corrected SDC without editing the
snapshot (omit the third argument for the snapshot's SDC):

```text
quartus_sta -t Boards/DE25/audit_timing.tcl <build-directory> <fresh-report-directory> <corrected-SDC>
```

## Earlier evidence

Class-workspace `AI/tmp/phase1-sim-v3` records the old serializer vectors passing
against the board wrapper with behavioral board models. `AI/tmp/phase1-sim-sync-v1`
records the new DE25 serializer passing the same checked-in assertions at 1 MHz.
Both require the final `PASS PHASE1 LEGACY VECTORS` marker and a zero process exit.
`AI/tmp/phase1-clock/probe_modern` records real Quartus 26.1 synthesis of the
supported PLL macro (one IOPLL). `AI/tmp/original-tester-build` and
`AI/tmp/original-tester-offline-v4` record the real tester build and offline run.
None of those artifacts alone proves a completed DE25 hardware migration.

The first clock feasibility probe synthesized a supported vendor PLL (with
Aaron's approval for its internal SV), but the final synchronous serializer
does not need it. Build v3 rejected the unused PLL; v4 removes it. This approved exception is not needed by the delivered RTL.

Inherited warnings remain visible: a constant-zero 32-bit connection feeds a
legacy one-bit execution response input, and a legacy combinational sensitivity
list omits an `initialized` input that this top ties high. Those placeholders
must be revisited during future TPM integration; this migration does not claim
to resolve every Phase 1 design limitation.
