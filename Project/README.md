# Quartus board projects

Author: Aaron Grossman

Open the `.qpf` file for your board in the matching Quartus edition:

| Board | Project, relative to this folder | FPGA | Quartus |
|---|---|---|---|
| DE1-SoC | `DE1/de1_soc_top.qpf` | 5CSEMA5F31C6 | Lite or Standard with Cyclone V support |
| DE25 Standard RevD | `DE25/de25_soc_top.qpf` | A5ED013BB32AE4SCS | Pro 26.1 with Agilex 5 support |

Use **File > Open Project**, select the QPF, and then **Processing > Start Compilation**. Make project assignments and edit source files in Quartus as usual. The QSF already lists the board-specific and shared source files.

Each folder owns its board top, PLL, pins and timing constraints. Both projects reference `Source Code/TPM_TOP.v` and the shared module folders at the repository root. DE25 also includes the original Terasic fan-controller example. Keep the full checkout in place so the relative source paths remain valid.

Quartus puts generated results under each board's ignored `output_files/`, `db/` and related directories. The Quartus editions are not interchangeable; open each project with its matching edition.

See [DE1 setup](DE1/README.md) and [DE25 setup](DE25/README.md) for board wiring and device details.
