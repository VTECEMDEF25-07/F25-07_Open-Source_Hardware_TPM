# Terasic fan-controller example

Author: Aaron Grossman (integration and documentation; vendor HDL retains its original authorship).

Source: [DE25 Standard RevD v1.2.0 resource package](https://dl2.terasic.com/resources/de25-standard/DE25-Standard_revD_v1.2.0_ResourcePackage.zip).
Archive SHA256: `5e46ac11779b617f40d672acf1f2fed20db90b777ba7ad74d90dc8167043b0ad`.

The following seven files are copied byte for byte from `Demonstration/FPGA/Board_Info_RTL/board_management_ip/` inside that ZIP. No headers, timing values, register sequences or logic have been changed.

| File | SHA256 of original and local copy |
|---|---|
| `auto_fan.v` | `eca7ca7d6a2b2e320e7a7c7ecaa6ea0f0f8e5d38144951858356f432ce878c29` |
| `BOARD_MANAGEMENT.v` | `58c837aebf66db002320faf88fe698c4d036ca133eae5424b6249c61867fd12f` |
| `CLOCKMEM.v` | `d895e509055855732c076ed58b8b29a81c89d30fad2ddc2f6b19b27f5a663d49` |
| `fan_timer.v` | `f01a84764a7ff4a6bef0025df237c32799965f1328f8c664b93fda357196d4f3` |
| `I2C_READ_DATA.v` | `656c17acdc90848bb3f35bcaa79b8859a6a8091a39db017b94285c6dc0f7f72f` |
| `I2C_WRITE_BYTE.v` | `304dea53f7c9c3b80cd153532206ecb691700ce452304025962808e2f86ca3dd` |
| `I2C_WRITE_POINTER.v` | `8642fae9be4d930b8b22cbdf4009e765a90895395a7bc77c1b5e3c1bacbe4d3d` |

## Required integration changes

- `altera_s10_user_rst_clkgate.v` comes from `Demonstration/FPGA/DDR4_Test_RTL/reset_release/altera_s10_user_rst_clkgate_1949/synth/altera_s10_user_rst_clkgate.sv`. Its only content edit is `output logic` to `output wire`; its extension changes from `.sv` to `.v`. This keeps the supplied endpoint connection compatible with the project's Verilog-only hardware-source rule. It serves board configuration reset, not fan speed control.
- The project-owned `../de25_soc_top.v` connects the example's 50 MHz clock, reset and I2C ports. Automatic mode is enabled; the manual-speed input remains 4000 RPM, unused in automatic mode.
- The top uses only the clock/reset/I2C and fan-mode inputs required for fan operation. The optional JTAG telemetry probe and its project setting/constraints are removed; unused management outputs are not connected.
- The QSF lists the original example files and omits the removed project-specific `de25_fan_guard.v`. Pin assignments and the divide-by-128 fan-clock constraint stay unchanged.

No source changes are required in the seven fan-example modules. The example's continuous-conversion logic, speed curve, startup defaults and unused/unconnected signals (including its `invalid_temp` wire) are preserved. Custom one-shot validation, timeouts and stale-reading logic are removed.

The normal-operation simulations are project tests, not imported vendor tests. They check the original AutoFan curve and serial I2C configuration/read/write behavior. Former custom fault/guard assertions have been replaced because they describe functionality no longer present.
