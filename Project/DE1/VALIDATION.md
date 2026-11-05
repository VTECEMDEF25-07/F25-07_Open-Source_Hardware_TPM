# DE1 validation (October 23, 2026)

Author: Aaron Grossman

The DE1 project uses unchanged shared TPM logic from main `4fd41b608554deaa0c3b520933bcabafc4755e92`.

- Existing TPM SPI vectors at 1 MHz pass with an ideal test PLL. This is functional simulation, not vendor-model or physical-board validation.
- Quartus Prime Lite 24.1 full compilation/bitstream succeeds: 912 ALMs (3%), 4 RAM blocks, 0 DSPs, 1 hardware PLL.
- Timing reports confirm the generated PLL output is 100 MHz. All 18 physical pin assignments match the QSF, including clock AF14 and reset AA14. The root build script checks the PLL and complete pin map after a successful compile.
- The first full build exposed two issues in the old, uncompiled project: brace-wrapped pin targets were interpreted as invalid names, and PLL type `auto` generated no clock. Pin targets now use quotes; ALTERA_PLL uses its supported General mode to map onto the selected Cyclone V device. Family-specific low-level mode is not used because it requires generated analog parameters.
- Reported constrained paths have positive slack (for example 100 MHz setup +1.229 ns at slow 85 C). Whole-board signoff is NOT established: existing SPI clock-domain crossings, logic-generated transmit clock and incomplete I/O constraints remain. No new physical-board testing was performed.

SOF SHA256: `747b69643ad80e1bac69eed2744bfda71288fed8ff06773ab20b82f3343d31c1`.

Local evidence: `AI/tmp/dual-board-DE1-corrected-compile.log`, `dual-board-DE1-corrected-result.json`, `dual-board-de1-final-sim/`, and this checkout's ignored `Project/DE1/output_files/`. The earlier zero-PLL build is rejected evidence, not a valid hardware implementation.


## Main/RNG merge follow-up - November 4, 2026

Merged main `847341411dae1319951a0198ed7ce99630b6bf65`, preserving its `TPM_TOP` module name under `Source Code/` and updating the board instantiation to match. The unchanged standalone RNG sources, hardware capture assets and benches were moved into the agreed folders; they are not instantiated by this TPM project.

Fresh full compilation PASS; required PLL, physical pins and SOF verified with the local-only helper. Local build evidence: class-workspace `AI/tmp/pr36-rng-merge-de1-build.log`.
SOF SHA256: `b42e389471b2796a385ebcea3333b9c7b83ab2b4f6bc232db2afc44527ba55bd`.

Both relocated RNG benches also print `ALL TESTS PASSED` in Questa using their new source paths. Evidence: `AI/tmp/pr36-rng-relocation-tests/`. They use behavioral entropy simulation and do not establish physical entropy quality or TPM integration.


## Clock wrapper naming - November 5, 2026

Renamed the board PLL wrapper file/module to `de1_clock.v` / `de1_clock` and updated project, top, legacy simulation model and generator references. PLL parameters and ports are unchanged. A fresh Quartus Lite 24.1 full compile passes; the local-only build check verifies the required PLL, physical pin assignments and SOF. Evidence: class-workspace `AI/tmp/pr36-de1-clock-rename-build.log`.
SOF SHA256: `3d69e01ab017d1dfcf75be9cbe503907589ad58802e5af2a182b104a0f0829bf`.
