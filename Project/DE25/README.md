# DE25 board support for the existing TPM

Author: Aaron Grossman

This project targets DE25 Standard RevD (A5ED013BB32AE4SCS) and integrates the existing main-branch TPM without changing its command path. Open de25_soc_top.qpf in Quartus Pro 26.1, or run `quartus_sh --flow compile de25_soc_top` here.

The board wrapper's single `IP_TYPE` parameter defaults to Altera (1). It reaches both keygen resources and RNG through an inactive keygen placeholder: clock/reset are connected, request/source inputs are inactive and outputs unused. Fixed Agilex 5/M20K family metadata reaches keygen RAM. The QSF includes all required module sources. Unsupported resource backends fail in their implementation wrappers. Synthesis may remove the placeholder; this does not enable TPM crypto commands or establish active full-core fit/performance.

- `de25_soc_top.v`: TPM wiring, reset separation and autonomous cooling.
- `de25_clock.v`: related 50/100 MHz PLL outputs for the existing TPM.
- `Fan Controller/`: original Terasic example I2C, temperature and fan logic, plus the configuration-reset wrapper. No keygen or demo dependency.
- `../../Testing/Simulation/DE25/tests/`, `../../Testing/Simulation/DE25/simulate_fan.py`, `../../Testing/Simulation/DE25/simulate_fan_bus.py`: normal-operation vendor-example regressions under Linux/WSL with Verilator. Pass a fresh absolute `--build` directory.

Fan control uses the raw 50 MHz board clock and remains active during SPI reset. The seven Terasic fan-example files are copied unchanged; see [Fan Controller/README.md](Fan%20Controller/README.md) for their exact origins and the required board-wrapper connections.

Pin assignments come from the QSF and `de25_spi_pins.tcl`; electrical standards remain explicit in the QSF. The existing SPI serializer has inherited asynchronous crossings and a logic-generated transmit clock; full SPI timing/CDC signoff is not established. SDC documents these limitations. This change does not claim TPM certification or physical-board acceptance.

## SPI wiring selection

In `de25_spi_pins.tcl`, set **`DE25_SPI_TARGET`** to `usb_adapter` (default) or `lenovo_tester`, then recompile `de25_soc_top.qpf` and load the resulting SOF. This is a build-time Tcl setting rather than a Verilog define because Quartus constraints select the physical FPGA pins. Invalid targets stop project loading. The Lenovo target is the Raspberry Pi running Lenovo's TPM tester; selecting its pins does not establish Linux/UEFI TPM compatibility.

| Signal / wire | USB adapter JP1 / FPGA pin | Lenovo tester JP1 / FPGA pin | Pi physical pin (BCM) |
|---|---|---|---|
| MISO / green | 4 / BF40 | 3 / BF29 | 21 (9) |
| MOSI / yellow | 6 / BM31 | 5 / BK28 | 19 (10) |
| CS_n / brown | 8 / BP31 | 7 / BM28 | 24 (8 / CE0) |
| SCLK / orange | 10 / BU28 | 9 / BR31 | 23 (11) |
| RESET_n / gray | 14 / BW28 | 13 / BU31 | 7 (4) |
| Ground / black | 12 / GND | 30 / GND | 9 (GND) |
| IRQ_n / purple | 2 / BE43 | Disconnected; FPGA output stays on JP1 2 | Disconnected |

JP1 and Pi numbers above are physical header contacts. Both profiles use 3.3 V logic; CS, reset and IRQ are active low. Power off while wiring. Leave Pi power pins and purple/blue/white/red disconnected for the Lenovo tester; power the DE25 separately. JP1 pin 11 is +5 V; pins 12 and 30 are ground. Select one bus master: the inactive row's SPI inputs are unused tri-stated pins, while MISO is driven only on the selected row. IRQ remains assigned to JP1 2 in both builds.

Wiring reference: [shared pin assignments, DE25 USB/Pi sections](https://docs.google.com/document/d/1Eylg2XuQ-H1bI_WXwmYC9IKuTvtMnYH5k5sPCp9v7NM/edit), updated October 21, 2026. The Pi mapping still requires physical validation; see [Lenovo tester requirements](https://docs.google.com/document/d/1C-uRUMdw5d2tX32eHeYCeti6NYrUwDta6_XHYEqaP7w/edit).

In Quartus, open `de25_soc_top.qpf` and select **Processing > Start Compilation**. See [board setup](../README.md) for both boards. The top is board-local at `Project/DE25/de25_soc_top.v`.

See [shared implementation selection](../../Source%20Code/Key%20Generation/README.md#resource-selection) and the
[vendor verification suite](../../Testing/Simulation/Key%20Generation/Vendor/README.md).
