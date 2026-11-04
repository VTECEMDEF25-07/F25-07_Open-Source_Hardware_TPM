# Validation against current main

Author: Aaron Grossman

## Current revision: TPM naming and monitor removal - November 4, 2026

- Optional JTAG probe, telemetry registers, enabling macro and probe timing constraints removed. The synthesized report has no `altsource_probe`/`phase1_monitor` instance.
- Clock wrapper renamed to `de25_clock.v` / `de25_clock`; PLL parameters and TPM port connections are unchanged. Board descriptions call the design TPM.
- Full Quartus Pro 26.1 compile PASS: 1,325 ALMs, 2 RAM blocks, 0 DSPs, 1 PLL. The local-only build helper verified all 10 pins and SOF generation.
- TPM 1 MHz SPI acceptance vectors PASS with the local ideal board/PLL adapters.
- The seven vendor fan files still match the archive byte for byte; fan-mode/reset/I2C inputs are unchanged. Their previously passed normal-operation tests remain applicable.
- Worst setup slack remains negative (-2.790 ns); full timing/CDC signoff is incomplete. No physical-board test performed.

SOF SHA256: `ef790303eb083729f50079b55e47e77a03ccb907e1e97dce46894aad4b81bb4c`.
Local evidence: class-workspace `AI/tmp/pr36-no-monitor-de25-build.log` and `AI/tmp/pr36-no-monitor-spi-DE25/`.

## Vendor-example revision before monitor removal - November 4, 2026

- All seven fan-example modules match the RevD v1.2.0 Board_Info_RTL ZIP entries byte for byte. Reset-release source differs only by `output logic` -> `output wire` and `.sv` -> `.v`; see [source provenance](Fan%20Controller/README.md).
- Full Quartus Pro 26.1 compile PASS: 1,501 ALMs, 2 RAM blocks, 0 DSPs, 1 PLL. Build selector verifies all 10 physical pins and the programming file.
- AutoFan normal-operation simulation PASS: startup speed, cold/hot ramp and the original invalid-temperature input behavior.
- Serial I2C simulation PASS: continuous-conversion configuration, three temperature channels, RPM readback and fan-speed writes.
- Existing 1 MHz TPM SPI acceptance vectors PASS with local ideal board/PLL adapters.
- Worst setup slack is -2.611 ns. Full timing/CDC signoff remains incomplete; no physical-board test was performed.

SOF SHA256: `af04d3f762c37f30e3cca76c14fc8d438544ecd1f73c2800622ab1824fc9d4f3`.
Local evidence: class-workspace `AI/tmp/pr36-vendor-de25-build.log`, `pr36-vendor-fan-test/`, `pr36-vendor-fan-bus-test-v2/`, and `pr36-vendor-spi-DE25/`.

## Historical custom implementation

Historical record: the custom fan implementation tested below has since been replaced by the original Terasic example. Its fault/guard results and bitstream hashes do not validate the vendor-example revision. See `Project/DE25/Fan Controller/README.md` from the repository root for the current source contract.

Base: `4fd41b608554deaa0c3b520933bcabafc4755e92` (October 23, 2026). Existing TPM, execution, management and SPI sources are unchanged from this base. No key-generation/demo source is in the project source list.

| Check | Result |
|---|---|
| Fan guard/decoded sensor regression | PASS: startup, unresponsive bus, full-on/closed-loop commands, invalid identity/readings, staleness and recovery |
| Serial I2C sensor/fan model | PASS: fresh conversion, adjacent high/low reads, eight fault/recovery cases; 29 shots, 96 paired reads |
| Existing main TPM SPI vectors at 1 MHz | PASS: no assertion errors; ideal PLL/configuration/fan adapters, not physical hardware or vendor PLL validation |
| Quartus Pro 26.1 complete compile/bitstream | PASS: 1,587 ALMs (3%), 2 RAM blocks, 0 DSPs, 1 PLL |
| Fan-clock timing | Setup +15.447 ns; hold +0.004 ns; recovery +17.446 ns; removal +0.079 ns |
| Whole-design timing signoff | NOT established: worst setup -2.700 ns at unchanged TPM SPI edge detector, from spi_clock_i to tpm/io/spi_serialzier/det_ff0/n |
| Physical board test | Not performed for this extracted revision |

The existing SPI input is asynchronous to the TPM clocks, and its serializer also creates a logic-generated transmit clock. This PR preserves those existing RTL paths and documents the unresolved timing/CDC limitations rather than hiding them with broad timing exceptions. Positive fan timing does not prove whole-board timing closure.

Run the two included fan runners under WSL/Linux with Verilator and a fresh absolute `--build` path. Compile `de25_soc_top.qpf` with Quartus Pro. The legacy-vector adapter and complete run evidence are local class-workspace helpers, not dependencies of the board project.

Local evidence: `AI/tmp/de25-board-fan-test/`, `de25-board-fan-bus-test/`, `de25-board-main-spi-v2/`, and `de25-board-main-build/`. `AI/tmp/de25-board-validation.json` binds fan/TPM simulation logs to the inspected source. The build manifest records source/configuration hashes. No hardware programming, TPM certification or approval to merge is implied by these checks.

Compiled SOF SHA256: `461f305a6d28c91b44185ff9b8df61ed57abe428a1351de1e5f0d183cf6b54c1`. Compilation completed successfully; timing acceptance remains false for the SPI limitations above. Imported HDL/testbench whitespace is preserved from the tested sources.

## Dual-board organization follow-up

The DE25 top now lives beside its QPF/QSF in `Project/DE25/`. A fresh compile through the root board selector completed successfully after relocation; 1 PLL and assigned physical pins were verified. Existing main TPM vectors also pass with the relocated top. Fan RTL is unchanged from the fault simulations above. Fresh SOF SHA256: `430011d4fe8c718b40cb8da9bf5e8a8524dbd7d51e586d7ac7b99591d7bb3a98`. The -2.700 ns SPI timing limitation remains. Local evidence: `AI/tmp/dual-board-DE25-compile.log`, `dual-board-de25-sim/`, and this checkout's ignored `Project/DE25/output_files/`.
