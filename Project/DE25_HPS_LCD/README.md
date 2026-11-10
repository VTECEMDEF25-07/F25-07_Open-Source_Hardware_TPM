# DE25 RevD HPS-only LCD island

Approved boundary: `AI/OVERNIGHT_LCD_ISLAND_AGREEMENT_2026-11-10.md` at the class root. This is a new isolated subtree. Do not add it to a shared board project without the lead's integration/build decision.

Actual generation: Quartus Pro26.1 build110, `intel_agilex_5_soc`14.0.0, target `A5ED013BB32AE4SCS`. Input clock/pin selections derive from the saved RevD vendor GHRD25.1.1; unrelated peripherals/DDR/bridges are disabled. No vendor precompiled board image or Premium PLL recipe is used.

From this directory, with installed Quartus tools on PATH (or their full paths):

```powershell
qsys-script --quartus-project=hps_lcd_subsys.qpf --script=generate_hps_lcd.tcl --jvm-max-heap-size=512m
qsys-generate hps_lcd_subsys.qsys --synthesis=VERILOG --parallel=off --quartus-project=hps_lcd_subsys.qpf --jvm-max-heap-size=512m
python audit_handoff.py
```

These commands generate IP HDL, not a device synthesis/fit or bitstream. No board access. Initial inspection exposed the tool's incorrect automatic target default and old Tcl lacking `lrepeat`; the final script uses an explicit local QPF/device and supported Tcl list operations. It saves the derived report before conversion to a generic component. Generated XML/QIP remain the authoritative fact source.

Generated IP filename is `ip/hps_lcd_subsys/hps_lcd_subsys_agilex_hps.ip` (the tool prefixes the instance name). Generated source/QIP live alongside it. The system QIP is `hps_lcd_subsys/hps_lcd_subsys.qip`; it carries the subordinate QIP and dedicated `HPS_LOCATION`/1.8V assignments. The source wrapper is `Source Code/Display/hps_lcd_island.v` at repository root. It exposes exactly the accepted9 scalar ports, binding the actual generated `hps_io_gpio34/35/42` spellings. Generated `h2f_reset` is unconnected. No fabric bus/clock/reset port exists.

`generate_hps_lcd.log` and `generate_hdl.log` preserve actual commands/results. `handoff_audit.json` records input/output hashes, pins, clock fields, sparse register offsets and remaining limits. `hps_handoff.txt` is actual generated metadata, **not** the fitted SDM binary handed to software. `derived_parameters.json` preserves all generated component parameters. Audit checks exact9 pins/voltages, DDRoff, bridgeoff, all22 USEFPGA routesoff and48 pin selections. It emits the firmware's `de25_handoff_facts.h` from this QIP and installed `agilex5_hps.svd`, including sparse IO-register offsets.

Actual clocks:25MHz EOSC; main PLL M128, C0=4/C1=4/C2=6/C3=8, giving3.2GHz VCO and400MHz NOC; peripheral M120, C0=5/C1=5/C2=125/C3=6, giving3GHz VCO. L4_SP/UART=100MHz. The exported FPGA reference-rate metadata125MHz is unused because all FPGA clock sources/user clocks/bridges are disabled. It is not a new fabric clock. Main NOCDIV is0x28260098, distinct from the library's fixed recipe. CPU boot core0 and all powered-core options come from the generated handoff.

Firmware source/build/limits are documented under `Source Code/Display/firmware/README.md`. Lead still needs a combined fit/timing/configuration review, actual fitted SDM handoff and controlled volatile startup/UART/pin/glass tests. This generated subsystem alone proves none of those outcomes. Shared top/QSF/SDC, crypto clocks, RO/SPI logic and fan were not edited.
