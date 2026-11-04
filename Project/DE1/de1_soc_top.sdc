# Filename: de1_soc_top.sdc
# Authors: Project contributors; see Git history.
# Date: 2026-10-14
# General Description: Defines board clocks and timing constraints, with remaining limitations documented.
# AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

# Original Phase 1 clock pair: direct board 50 MHz and PLL-generated 100 MHz.
create_clock -name board_clock -period 20.000 [get_ports CLOCK_50]
derive_pll_clocks
derive_clock_uncertainty

# Empirical SPI test envelope <=1 MHz. Preserve the original asynchronous paths;
# no blanket clock groups/false paths claim these crossings are correct.
create_clock -name spi_clock -period 1000.000 -waveform {0.000 500.000} [get_ports GPIO_1_2]
set_false_path -from [get_ports {RESET_N GPIO_1_6}]

# Legacy logic-generated det_clock/TX_temp, binary counter crossings and CS
# fanout need separate timing/CDC review. External SPI input/output delay budgets
# are not established. This file is a starting constraint set, not full signoff.
