# Historical validation: inherited SPI transport

The records below describe the parent board-support PR before the synchronous SPI follow-up. See the final section for current results.

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

The DE25 top now lives beside its QPF/QSF in `Boards/DE25/`. A fresh compile through the root board selector completed successfully after relocation; 1 PLL and assigned physical pins were verified. Existing main TPM vectors also pass with the relocated top. Fan RTL is unchanged from the fault simulations above. Fresh SOF SHA256: `430011d4fe8c718b40cb8da9bf5e8a8524dbd7d51e586d7ac7b99591d7bb3a98`. The -2.700 ns SPI timing limitation remains. Local evidence: `AI/tmp/dual-board-DE25-compile.log`, `dual-board-de25-sim/`, and this checkout's ignored `Boards/DE25/output_files/`.

## Synchronous SPI follow-up — November 3, 2026

This separate PR is based on PR #36's branch, not main. It selects portable
single-clock SPI only on DE25; DE1 defaults to the original serializer.

| Check | Current result |
|---|---|
| Isolated serializer | PASS: 100k/500k/1MHz; 20 phase offsets at 1MHz; duplex/back-to-back/delayed TX, stopped SCK, partial abort, reset/replay |
| Existing full TPM protocol vectors | PASS on DE25 at 100k/500k/1MHz; PASS on DE1 at 1MHz; ideal board models, 21 inherited top-level warnings |
| DE25 full Pro 26.1 build | PASS: 1,531 ALMs, 2 RAM blocks, 1 PLL; 10 physical pins verified |
| DE1 full Lite 24.1 build | PASS: required PLL/18 physical pins verified; default transport retained |
| Four-corner routed setup | **+2.224 ns worst**, replacing the parent's -2.700 ns failure |
| Four-corner hold/recovery/removal/pulse width | **+0.004 / +2.564 / +0.107 / +4.537 ns** worst |
| SPI synchronizer chains | Three two-register chains recognized; all interstage paths timed and positive at every corner |
| Unconstrained clocks/ports/path pairs | Zero in setup and hold UCP summary; no ignored timing exceptions reported |
| Fresh physical-board acceptance | Not performed |

`verify_spi_timing.tcl` passes all four available timing corners. The legacy
dual-edge detector and logic-clocked shifter are absent from the DE25 netlist.
The asynchronous pad exceptions reach only the respective first-stage register;
they do not disable timing between synchronizer stages or within functional RTL.

The successful numeric timing audit is **not complete board/CDC signoff**.
Design Assistant still flags read-only JTAG capture crossings, external I/O
delay conventions (the SPI inputs are asynchronous; output constraints bound
routing rather than a measured host interface), and the inherited board-reset
input to the PLL control register. These remain explicit, unwaived limitations.
No physical SPI setup/hold measurements, TPM certification or ASIC signoff
are claimed. The source is portable Verilog; FPGA PLL/reset/JTAG IP stays in
board wrappers, with the ASIC portability boundary in `SPI_TIMING.md`.

`spi_validation.json` records hashes of the inspected compilation inputs,
reports, resulting SOF and simulation transcripts. Local detailed evidence is
under class `AI/tmp/pr36-spi-*` and the checkout's ignored output/report folders.
Reproduction commands and host timing limits are in `SPI_TIMING.md`.
