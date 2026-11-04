# DE25 board support for the existing TPM

This project targets DE25 Standard RevD (A5ED013BB32AE4SCS) and integrates the existing main-branch TPM without changing its command path. Open de25_soc_top.qpf in Quartus Pro 26.1, or run `quartus_sh --flow compile de25_soc_top` here.

- `de25_soc_top.v`: TPM wiring, reset separation and autonomous cooling.
- `de25_phase1_clock.v`: related 50/100 MHz PLL outputs for the existing TPM.
- `Fan Controller/`: board-resource I2C, temperature and fan logic, configuration-reset wrapper and freshness guard. No keygen or demo dependency.
- `../../Simulation/DE25/tests/`, `../../Simulation/DE25/simulate_fan.py`, `../../Simulation/DE25/simulate_fan_bus.py`: focused cooling regressions under Linux/WSL with Verilator. Pass a fresh absolute `--build` directory.

Cooling uses the raw 50 MHz board clock and remains active during SPI reset. Startup, invalid frames or stale readings request full-on mode through the fan-controller chip. See FAN_MONITOR.md for the conversion/fault contract and provenance. The optional read-only JTAG probe observes reset/temperature/fan state without changing the TPM SPI protocol.

Pin assignments and electrical standards are explicit in the QSF. Both boards use the same portable 50 MHz SPI serializer. See [common SPI documentation](../../IO%20Interface/SPI.md) for the mode-0, <=1 MHz host contract, isolated/protocol regressions and routed timing audit. This does not claim TPM certification or physical-board acceptance.

Fresh validation results are recorded in VALIDATION.md.

Use the `Project/board_config.json` / `Project/build.py` selector for this target or DE1; see [board setup](../README.md). The top is board-local at `Project/DE25/de25_soc_top.v`.
