# DE1 validation (October 23, 2026)

The DE1 project uses unchanged shared TPM logic from main `4fd41b608554deaa0c3b520933bcabafc4755e92`.

- Existing TPM SPI vectors at 1 MHz pass with an ideal test PLL. This is functional simulation, not vendor-model or physical-board validation.
- Quartus Prime Lite 24.1 full compilation/bitstream succeeds: 912 ALMs (3%), 4 RAM blocks, 0 DSPs, 1 hardware PLL.
- Timing reports confirm the generated PLL output is 100 MHz. All 18 physical pin assignments match the QSF, including clock AF14 and reset AA14. The root build script checks the PLL and complete pin map after a successful compile.
- The first full build exposed two issues in the old, uncompiled project: brace-wrapped pin targets were interpreted as invalid names, and PLL type `auto` generated no clock. Pin targets now use quotes; ALTERA_PLL uses its supported General mode to map onto the selected Cyclone V device. Family-specific low-level mode is not used because it requires generated analog parameters.
- Reported constrained paths have positive slack (for example 100 MHz setup +1.229 ns at slow 85 C). Whole-board signoff is NOT established: existing SPI clock-domain crossings, logic-generated transmit clock and incomplete I/O constraints remain. No new physical-board testing was performed.

SOF SHA256: `747b69643ad80e1bac69eed2744bfda71288fed8ff06773ab20b82f3343d31c1`.

Local evidence: `AI/tmp/dual-board-DE1-corrected-compile.log`, `dual-board-DE1-corrected-result.json`, `dual-board-de1-final-sim/`, and this checkout's ignored `Boards/DE1/output_files/`. The earlier zero-PLL build is rejected evidence, not a valid hardware implementation.
