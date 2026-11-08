<!--
Filename: README.md
Author: Aaron Grossman
Date: 2026-10-14
General Description: Documents DE1-SoC TPM project.
-->

# DE1-SoC TPM project

Open `de1_soc_top.qpf` in Quartus Prime Lite or Standard with Cyclone V device
support installed. Target: `5CSEMA5F31C6`. Quartus Pro does not support this target.
From this directory, the command-line build is:

```text
quartus_sh --flow compile de1_soc_top
```

This project uses the board-local `de1_soc_top.v` and TPM
and SPI modules. `de1_clock.v` supplies the previously missing 50-to-100 MHz
clock module through the Cyclone V `altera_pll` macro. There is no DE25 fan
controller or functional keygen command integration in this project. LED0 shows the original
active-low interrupt signal; the remaining LEDs are off.

`de1_soc_top.IP_TYPE` defaults to `IP_ALTERA` (1), propagating through `TPM_TOP` to both keygen and RNG. Fixed Cyclone V family metadata selects M10K RAM. Non-Altera board settings fail explicitly. Request/enable inputs to both resource placeholders are inactive and their outputs unused; synthesis can remove them. The QSF includes their sources and shared header search path. This establishes configuration wiring, not TPM command integration or full-core resource-fit acceptance.

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
