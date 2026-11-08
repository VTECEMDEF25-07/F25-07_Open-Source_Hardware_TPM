<!--
Filename: CREDITS.md
Authors: Aaron Grossman; Project contributors; see Git history.
Date: 2026-11-08
General Description: Preserves contribution credit and dependency provenance.
AI Disclosure: Codex assisted with consolidation; see docs/AI_DISCLOSURE.md in the keygen source folder.
-->

# Credits and dependencies

Aaron Grossman is credited for the project-authored changes in this key-generation contribution. Existing project-contributor credit and Git history remain intact. AI involvement, including substantive coding assistance and public generated fixtures, is documented separately in [AI_DISCLOSURE.md](docs/AI_DISCLOSURE.md).

| Input | Provenance / use |
|---|---|
| Altera multiplier/RAM simulation models | Unmodified installed Quartus 24.1 `220model.v` and `altera_mf.v`, used with Questa 2024.3. Models and proprietary tool installations are not redistributed. |
| Generic simulation | Verilator 5.020 under Ubuntu 24.04/WSL and g++; project `.v` source is compiled as Verilog-2001, with `.sv` tests separately. |
| Historical device fits | Quartus Prime Pro 26.1.0 Build 110, Agilex 5 A5ED013BB32AE4SCS; isolated virtual-pin fits are not board signoff. |
| RSA procedure | [FIPS 186-5 mapping and source references](docs/RSA_ALGORITHM.md#standards-references). |

Exact run manifests, rather than version names alone, identify tested inputs. Source or tool changes invalidate prior source-matched claims. Board-specific Terasic imports and notices remain under `Project/`; original author/license notices must be preserved. This document does not select or replace a project-wide license.
