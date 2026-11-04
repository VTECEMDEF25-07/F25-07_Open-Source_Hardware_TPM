<!--
Filename: README.md
Authors: Project contributors; see Git history.
Date: 2026-10-14
General Description: Documents DE1-SoC Phase 1 project.
AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.
-->

# DE1-SoC Phase 1 project

Open `de1_soc_top.qpf` in Quartus Prime Lite or Standard with Cyclone V device
support installed. Target: `5CSEMA5F31C6`. Quartus Pro does not support this target.
From this directory, the command-line build is:

```text
quartus_sh --flow compile de1_soc_top
```

This project uses the board-local `de1_soc_top.v` and the same portable
`Source Code/IO Interface/spi_slave.v` as DE25. SPI shifts on external SCK and the TPM uses the board
50 MHz clock; the old serializer's 100 MHz PLL is no longer needed. No DE25
fan controller or key-generation integration is included. LED0 shows the
active-low interrupt signal; the remaining LEDs are off.

| Signal | Connection | FPGA pin |
|---|---|---|
| CLOCK_50 | Board 50 MHz clock | AF14 |
| RESET_N | FPGA KEY0 (active low) | AA14 |
| SPI clock | Orange, GPIO_1[2] | AB21 |
| MOSI | Yellow, GPIO_1[3] | AC23 |
| MISO | Green, GPIO_1[4] | AD24 |
| Chip select | Brown, GPIO_1[5] | AE23 |
| SPI reset | Gray, GPIO_1[6] | AE24 |
| Interrupt | Purple, GPIO_1[7] | AF25 |

GPIO indices are signal indices, not physical header contact numbers. Connect
adapter ground to a GPIO-header GND contact. This mapping follows the existing
top's signal names; it is not evidence of the old team's actual cable placement.

Pin/device reference: [Terasic DE1-SoC User Manual, January 28, 2019](https://community.altera.com/t5/s/jgyke29768/attachments/jgyke29768/fpga-device/73098/1/DE1-SoC_User_manual_revf.pdf),
tables 3-5, 3-7, 3-8 and 3-11. Software support:
[Altera device support](https://www.altera.com/design/guidance/software/device-support).

## Validation

See [VALIDATION.md](VALIDATION.md) for fresh simulation/build results. Both boards are selected through `Project/board_config.json` and `Project/build.py`; [board setup](../README.md) describes the common commands.

QSF pin targets use quoted names accepted by Quartus Lite. The build selector
requires zero PLLs for this direct-clock target and checks the physical pin map.
SPI SCK clocks the pin interface; held-data mailboxes cross to 50 MHz.
Local SCK routing and input/output register packing are board-specific.
Synchronizer interstage and functional paths remain timed. The host timing contract and common regression commands are in
[SPI documentation](../../Source%20Code/IO%20Interface/SPI.md). Physical-board acceptance is
separate from internal timing and functional simulation.
