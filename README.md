# Open-source hardware TPM

Virginia Tech Lenovo-sponsored senior design project.

## Layout

- `Project/DE1/`: DE1-SoC Quartus project, board wrapper, pins and constraints (direct 50 MHz, no PLL).
- `Project/DE25/`: DE25 Quartus project, board wrapper, PLL, pins, constraints and Fan Controller.
- `Source Code/`: shared TPM top and folders for each reusable module.
- `Simulation/`: module testbenches and DE25 cooling regression scripts/models.

## Open or build

Open `Project/DE1/de1_soc_top.qpf` in Quartus Lite/Standard with Cyclone V support, or `Project/DE25/de25_soc_top.qpf` in Quartus Pro 26.1 with Agilex 5 support.

From the repository root:

```text
python Project/build.py --board DE1
python Project/build.py --board DE25
python Project/build.py --board DE25 --compile --quartus C:/altera_pro/26.1/quartus/bin64/quartus_sh.exe
```

`Project/board_config.json` supplies the default board. Keep the complete repository together: project source paths are relative. Generated outputs are ignored; source, constraints, project settings and required test inputs remain tracked.

See [board setup](Project/README.md) and each board's VALIDATION.md for evidence and timing/hardware limitations. See [simulation instructions](Simulation/README.md) for cooling regressions and legacy testbenches.

The shared SPI transport and ASIC portability boundary are described in [SPI documentation](Source%20Code/IO%20Interface/SPI.md).

Open project follow-ups are tracked in [FUTURE_WORK.md](FUTURE_WORK.md).
