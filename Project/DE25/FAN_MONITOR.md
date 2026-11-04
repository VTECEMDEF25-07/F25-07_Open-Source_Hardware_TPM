# DE25 vendor fan control

Author: Aaron Grossman

The DE25 wrapper uses the original Terasic Board_Info_RTL fan-management example. See [Fan Controller/README.md](Fan%20Controller/README.md) for the exact archive paths, file hashes and required integration edits.

`BOARD_MANAGEMENT.v` configures the TMP442 for continuous conversion, reads the FPGA/board temperatures and fan tachometer, and writes MAX6650 closed-loop fan settings selected by `auto_fan.v`. The original example's speed curve and startup behavior are preserved.

The seven fan-example files are unmodified. Board wiring and synchronized board reset stay in `de25_soc_top.v`; the raw 50 MHz clock keeps fan management independent of TPM PLL and SPI reset.

Run `Simulation/DE25/simulate_fan.py` and `Simulation/DE25/simulate_fan_bus.py` under Linux/WSL with fresh absolute `--build` directories. These cover normal example behavior, not the removed custom guard/fault contract. Earlier custom-fan validation results do not apply to this revision.
