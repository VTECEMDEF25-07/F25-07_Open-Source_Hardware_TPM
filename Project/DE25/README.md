# DE25 board support for the existing TPM

Author: Aaron Grossman

This project targets DE25 Standard RevD (A5ED013BB32AE4SCS) and integrates the existing main-branch TPM without changing its command path. Open de25_soc_top.qpf in Quartus Pro 26.1, or run `quartus_sh --flow compile de25_soc_top` here.

The board wrapper's single `IP_TYPE` parameter defaults to Altera (1). It reaches both keygen resources and RNG through inactive placeholders: clock/reset are connected, request/enable inputs are inactive and outputs unused. Fixed Agilex 5/M20K family metadata reaches keygen RAM. The QSF includes all required module sources. Unsupported resource backends fail in their implementation wrappers. Synthesis may remove the placeholders; this does not enable TPM crypto commands or establish active full-core fit/performance.

- `de25_soc_top.v`: TPM wiring, reset separation and autonomous cooling.
- `de25_clock.v`: related 50/100 MHz PLL outputs for the existing TPM.
- `Fan Controller/`: original Terasic example I2C, temperature and fan logic, plus the configuration-reset wrapper. No keygen or demo dependency.
- `../../Testing/Simulation/DE25/tests/`, `../../Testing/Simulation/DE25/simulate_fan.py`, `../../Testing/Simulation/DE25/simulate_fan_bus.py`: normal-operation vendor-example regressions under Linux/WSL with Verilator. Pass a fresh absolute `--build` directory.

Fan control uses the raw 50 MHz board clock and remains active during SPI reset. The seven Terasic fan-example files are copied unchanged; see [Fan Controller/README.md](Fan%20Controller/README.md) for their exact origins and the required board-wrapper connections.

Pin assignments and electrical standards are explicit in the QSF. The existing SPI serializer has inherited asynchronous crossings and a logic-generated transmit clock; full SPI timing/CDC signoff is not established. SDC documents these limitations. This change does not claim TPM certification or physical-board acceptance.

In Quartus, open `de25_soc_top.qpf` and select **Processing > Start Compilation**. See [board setup](../README.md) for both boards. The top is board-local at `Project/DE25/de25_soc_top.v`.

See [shared implementation selection](../../Source%20Code/README.md) and the
[vendor verification suite](../../Testing/Simulation/Project%20Vendor/README.md).
