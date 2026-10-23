# Select a board

Change `board_config.json` at the repository root:

```json
{"board": "DE25"}
```

Use `DE1` for the DE1-SoC or `DE25` for the DE25 Standard RevD. From the repository root:

```text
python build.py
python build.py --compile --quartus PATH_TO_QUARTUS_SH
```

The first command checks the selected project and prints its top, FPGA and tool edition without compiling. The second compiles it and rejects missing hardware PLLs or ignored pin assignments; neither programs hardware. Use `python build.py --board DE1` for a one-run override without editing the config. `--config PATH` selects an alternate JSON config. Script paths are resolved relative to the repository, so it also works when invoked from another directory.

| Board | Top / project | FPGA | Quartus |
|---|---|---|---|
| DE1 | `DE1/de1_soc_top.v`, `DE1/de1_soc_top.qpf` | 5CSEMA5F31C6 | Lite or Standard with Cyclone V support |
| DE25 | `DE25/de25_soc_top.v`, `DE25/de25_soc_top.qpf` | A5ED013BB32AE4SCS | Pro with Agilex 5 support |

Each folder owns its top, pins, clocks and timing constraints. Both instantiate the shared root `TPM_TOP.v` and common TPM modules. DE25 alone includes temperature/fan management. Board selection chooses the entire project, not just the top name: devices, pins and PLL implementations differ. Quartus editions are not interchangeable; use the matching executable via --quartus or PATH.

Build outputs stay in each project's ignored output_files/db directories. Switching boards does not rewrite HDL or copy files over the other target. Directly opening either QPF remains supported. See each board README and VALIDATION.md for verification limits. Existing SPI timing/CDC and physical-board acceptance remain separate gates.

Validation: both targets compile with their matching installed Quartus editions and pass the existing TPM simulation vectors using ideal board models. Physical testing and complete timing/CDC signoff remain separate; see [DE1 results](DE1/VALIDATION.md) and [DE25 results](DE25/VALIDATION.md). Five local selector checks cover config/overrides, wrong-tool rejection, error propagation and rejection of missing PLLs or incorrect pin maps.
