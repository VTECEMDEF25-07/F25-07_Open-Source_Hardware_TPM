<!-- Authors: Aaron Grossman (changes in this PR); existing project contributors; see Git history. -->
# Open-source hardware TPM

Virginia Tech Lenovo-sponsored senior design project.

## Layout

- `Project/DE1/`: DE1-SoC Quartus project, board wrapper, PLL, pins and constraints.
- `Project/DE25/`: DE25 Quartus project, board wrapper, PLL, pins, constraints and Fan Controller.
- `Source Code/`: shared TPM top and reusable module folders, including the standalone RNG sources.
- `Testing/Simulation/`: module testbenches, RNG benches and DE25 cooling regression scripts/models.
- `Testing/Hardware/`: physical-board capture assets, host testers and testing procedures.

## Open and compile

1. Open the board's Quartus project:
   - DE1-SoC: `Project/DE1/de1_soc_top.qpf` in Quartus Lite/Standard with Cyclone V support.
   - DE25 Standard RevD: `Project/DE25/de25_soc_top.qpf` in Quartus Pro 26.1 with Agilex 5 support.
2. Select **Processing > Start Compilation** in Quartus.

Keep the complete repository together: project source paths are relative. Generated outputs are ignored; source, constraints, project settings and required test inputs remain tracked.

See [board setup](Project/README.md) for board details and [simulation instructions](Testing/Simulation/README.md) for simulations. Each board's VALIDATION.md records build results and timing/hardware limitations.

Key generation: [design and review](Source%20Code/Key%20Generation/README.md), [simulation runners](Testing/Simulation/Key%20Generation/README.md). The portable core remains separate from TPM command integration.
