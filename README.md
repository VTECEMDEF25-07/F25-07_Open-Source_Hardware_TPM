# Open-source hardware TPM

Virginia Tech Lenovo-sponsored senior design project.

## Layout

- `Project/DE1/`: DE1-SoC Quartus project, board wrapper, PLL, pins and constraints.
- `Project/DE25/`: DE25 Quartus project, board wrapper, PLL, pins, constraints and Fan Controller.
- `Source Code/`: shared TPM top and reusable module folders, including the standalone RNG sources.
- `Simulation/`: module testbenches, RNG benches and DE25 cooling regression scripts/models.
- `Project/DE25/Entropy Capture/`: standalone physical-board entropy capture top, pin script and PC serial tool.

## Open and compile

1. Open the board's Quartus project:
   - DE1-SoC: `Project/DE1/de1_soc_top.qpf` in Quartus Lite/Standard with Cyclone V support.
   - DE25 Standard RevD: `Project/DE25/de25_soc_top.qpf` in Quartus Pro 26.1 with Agilex 5 support.
2. Select **Processing > Start Compilation** in Quartus.

Keep the complete repository together: project source paths are relative. Generated outputs are ignored; source, constraints, project settings and required test inputs remain tracked.

See [board setup](Project/README.md) for board details and [simulation instructions](Simulation/README.md) for simulations. Each board's VALIDATION.md records build results and timing/hardware limitations.
