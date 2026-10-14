# Dependency and notice inventory

This records the inputs used for this delivery. Build manifests bind the exact
selected source bytes, firmware image, tools and constraints. Version names alone
do not replace those hashes. No project-wide license is selected by this document.

| Dependency | Pinned input / retained evidence |
|---|---|
| PicoRV32 | Commit `ef203c2b0a3fb793280f5114941416c425c5b461`; vendored Verilog and ISC `COPYING` under `IP/third_party/picorv32`. Its README describes the local runtime-clearing patch and disabled configurations. Final source snapshots preserve the exact modified source. |
| Firmware compiler | xPack RISC-V GCC 15.2.0-1, RV32I/ILP32; archive hash and build flags in `firmware/TOOLCHAIN.md`. Firmware manifest pins source and padded ROM bytes. The external compiler installation and its licenses are not redistributed. |
| Board resource package | Locally retained `DE25-Standard_revD_v1.2.0_ResourcePackage.zip`, 191,602,840 bytes, SHA256 `5e46ac11779b617f40d672acf1f2fed20db90b777ba7ad74d90dc8167043b0ad`. Class evidence location: `AI/tmp/de25-docs/`. The RevD pin reference is separately hashed in every build manifest. |
| Board-management source | Imported files remain under `demo/de25_revd/vendor`, with their source names and supplied notices. Local temperature/fan safety changes are documented in `FAN_MONITOR.md`; board-specific reset-wrapper changes are described in that source header. These files are outside the portable core. |
| Altera reset-release wrapper | `vendor/altera_s10_user_rst_clkgate.v` retains the supplied Altera copyright and applicable-license notice. Its board primitive is not part of the generic ASIC-facing core. |
| Altera simulation models | Unchanged installed Quartus 24.1 `220model.v` and `altera_mf.v`, executed with Questa 2024.3. Individual run manifests retain model paths/hashes. Proprietary models and tool installations are excluded from the release package. |
| FPGA build tool | Quartus Prime Pro 26.1.0 Build 110, Agilex 5 A5ED013BB32AE4SCS. Each snapshot records the actual version and all settings. A different tool version creates a new build identity and needs fresh acceptance. |
| Generic simulation | Verilator 5.020 under Ubuntu 24.04/WSL, with project `.v` files compiled in Verilog-2001 mode and `.sv` tests separately. Run manifests/logs retain exact commands and inputs. |

The board-management files do not all contain individual license headers. This
inventory preserves the notices actually supplied; it does not assign missing
permissions or apply PicoRV32's ISC license to unrelated files. The release
includes the source and notice inventory needed to review each dependency;
the vendor resource archive itself is not bundled.

The release packager copies the pinned CPU notice, this inventory, firmware
provenance and the selected source snapshots. It does not redistribute vendor
simulation libraries, Quartus databases or compiler installations.
