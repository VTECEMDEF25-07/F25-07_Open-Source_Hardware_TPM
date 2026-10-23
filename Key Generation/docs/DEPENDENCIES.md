<!--
Filename: DEPENDENCIES.md
Authors: Project contributors; see Git history.
Date: 2026-10-13
General Description: Documents Dependency and notice inventory.
AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.
-->

# Dependency and notice inventory

This records the inputs used for this delivery. Build manifests bind the exact
selected source bytes, tools and constraints. Version names alone
do not replace those hashes. No project-wide license is selected by this document.

| Dependency | Pinned input / retained evidence |
|---|---|
| Board resource package | Locally retained `DE25-Standard_revD_v1.2.0_ResourcePackage.zip`, 191,602,840 bytes, SHA256 `5e46ac11779b617f40d672acf1f2fed20db90b777ba7ad74d90dc8167043b0ad`. Class evidence location: `AI/tmp/de25-docs/`. The RevD pin reference is separately hashed in every build manifest. |
| Board-management source | Imported files remain under `demo/de25_revd/vendor`, with their source names and supplied notices. Local temperature/fan safety changes are documented in `FAN_MONITOR.md`; board-specific reset-wrapper changes are described in that source header. These files are outside the portable core. |
| Altera reset-release wrapper | `vendor/altera_s10_user_rst_clkgate.v` retains the supplied Altera copyright and applicable-license notice. Its board primitive is not part of the generic ASIC-facing core. |
| Altera simulation models | Unchanged installed Quartus 24.1 `220model.v` and `altera_mf.v`, executed with Questa 2024.3. Individual run manifests retain model paths/hashes. Proprietary models and tool installations are excluded from the release package. |
| FPGA build tool | Quartus Prime Pro 26.1.0 Build 110, Agilex 5 A5ED013BB32AE4SCS. Each snapshot records the actual version and all settings. A different tool version creates a new build identity and needs fresh acceptance. |
| Generic simulation | Verilator 5.020 under Ubuntu 24.04/WSL, with project `.v` files compiled in Verilog-2001 mode and `.sv` tests separately. Run manifests/logs retain exact commands and inputs. |

The board-management files do not all contain individual license headers. This
inventory preserves the notices actually supplied; it does not assign missing
permissions to unrelated files. The release
includes the source and notice inventory needed to review each dependency;
the vendor resource archive itself is not bundled.

The release packager copies this inventory and the selected source snapshots. It does not redistribute vendor
simulation libraries, Quartus databases or compiler installations.
