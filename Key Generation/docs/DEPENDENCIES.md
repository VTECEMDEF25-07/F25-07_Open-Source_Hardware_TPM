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
| Altera simulation models | Unchanged installed Quartus 24.1 `220model.v` and `altera_mf.v`, executed with Questa 2024.3. Individual run manifests retain model paths/hashes. Proprietary models and tool installations are excluded from the release package. |
| FPGA build tool | Quartus Prime Pro 26.1.0 Build 110, Agilex 5 A5ED013BB32AE4SCS. Each snapshot records the actual version and all settings. A different tool version creates a new build identity and needs fresh acceptance. |
| Generic simulation | Verilator 5.020 under Ubuntu 24.04/WSL, with project `.v` files compiled in Verilog-2001 mode and `.sv` tests separately. Run manifests/logs retain exact commands and inputs. |

Board-management imports, notices and board-specific verification belong to the separate DE25 board-support PR. Demo/release packaging is local-only and does not redistribute installed proprietary simulation libraries or tool installations.
