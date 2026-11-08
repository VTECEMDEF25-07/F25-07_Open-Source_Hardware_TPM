<!--
Filename: README.md
Authors: Aaron Grossman; Project contributors; see Git history.
Date: 2026-11-08
General Description: Collects reproducible keygen commands and concise verification scope.
AI Disclosure: Codex assisted with consolidation; see docs/AI_DISCLOSURE.md in the keygen source folder.
-->

# Key-generation simulations

Run the commands below from `Testing/Simulation/Key Generation`. Keep the repository together: runners locate reusable HDL under [`Source Code/Key Generation`](../../../Source%20Code/Key%20Generation/README.md). Source is Verilog-2001; SystemVerilog is used for tests. Generic resources are the default; `KEYGEN_ALTERA` selects vendor resources. There is no firmware compiler/ROM dependency.

`testbench/` contains core benches and a deterministic test-only stream. `reference/` contains the independent oracle and public corpus. `scripts/`, `IP/` and `Math/` contain runners, resource/math tests and vector generators. Products stay in ignored `build/` or explicitly supplied scratch directories.

## Offline Python checks (Windows or Linux)

```sh
python -m unittest discover -s reference -p 'test_*.py'
python scripts/check_repository_hygiene.py
```

## Generic HDL (Linux/WSL, Verilator and g++)

```sh
python3 scripts/run_integration_verilator.py --suite services
python3 scripts/run_integration_verilator.py --suite lifecycle
python3 scripts/run_full_verilator.py --directed --stalls --seeds 1 --label advisor-rtl
```

The complete-key test checks all 129 output words and exact source consumption against the independent corpus. Directed inputs use known candidates but execute the primality/pair checks; they are not a search-performance benchmark. Omit `--directed` for normal SHA-fixture prime search. Fresh labels preserve evidence; `--reuse-build` checks source, fixture, runner and binary hashes before reuse.

## Genuine Altera models (Windows/Questa)

```powershell
python scripts/run_full_altera_questa.py --directed --stalls --seeds 1 --label advisor-altera
```

Use `--questa-bin` and `--altera-models` for non-default installations. The runner compiles unchanged installed `220model.v` and `altera_mf.v`, records hashes and compiles project source separately in Verilog-2001 mode. Generic simulation is not vendor-model evidence.


## Focused regressions

Windows/Questa, from this directory:

```powershell
./scripts/test_aes.ps1
./scripts/test_rsa_services.ps1
./scripts/simulate_pair_check.ps1 -BuildDirectory '<absolute scratch>' -Backend generic
./IP/scripts/simulate_resources.ps1 -BuildDirectory '<absolute scratch>'
./Math/scripts/simulate_math.ps1 -BuildDirectory '<absolute scratch>' -Full -Small
```

Use a different scratch directory for each configuration. Pair/resource runners support installed genuine Altera models; pair `-Backend both` runs both configurations. Scripts with exposed `-QuestaBin`/vendor-path arguments support installation overrides; math's PowerShell runner retains its explicit installed-tool paths. Coordinate the installed Questa license rather than running vendor sessions concurrently.

Linux/WSL examples (invoke shell runners with `bash`):

```sh
bash scripts/test_pair_verilator.sh '<absolute scratch>' '<absolute corpus JSON>'
bash scripts/test_rsa_controller_verilator.sh '<absolute scratch>' '<absolute controller .v>'
bash Math/scripts/simulate_math_verilator.sh '<absolute scratch>'
python3 Math/scripts/simulate_small_verilator.py '<absolute scratch>' --source-root '<absolute Source Code/Key Generation>'
```

Fit helpers are `scripts/fit_pair_check.ps1`, `IP/scripts/fit_resources.ps1` and `Math/scripts/fit_math.ps1`. They use explicit scratch directories and virtual pins; they do not program hardware or establish full-board fit/timing. See the [resource](../../../Source%20Code/Key%20Generation/IP/README.md) and [math](../../../Source%20Code/Key%20Generation/Math/README.md) contracts for their detailed test scopes.

## Validation and limits

| Retained result | Scope |
|---|---|
| Python reference: 13 tests | Full-size procedure/replay and independent arithmetic checks; [reference README](reference/README.md). |
| Questa AES: 51 operations, five reset phases | Ordering, stalls, ownership, faults and clearing. |
| RSA services: 49 checks; lifecycle: 28 checks | Service boundaries and integrated abort/reset/ownership behavior. |
| Generic directed/stalled full RSA, seed 1 | All 129 n/e/p/q words matched; 384 input words, 136,232,057 cycles. Known candidates remove normal prime search. |
| Genuine Altera resource regression | 2,637 products, 2,750 reads, 596 collisions, 1,300 stalls; existing AUTO RAM-model warning. |

The integrated results above were recorded November 6, 2026, before later author-comment changes. The full-RSA source-manifest SHA256 was `720cb2a74cd28d7826fc321ed91dbb9a09a36fb7377789a67df40ec87ce9678c`; it identifies that tested snapshot, not the later comment-edited bytes. Reference/hygiene/syntax checks were rerun November 8. Documentation consolidation does not constitute a new HDL run.

Detailed historical development ledgers remain in Git at `6b92b8b`; a local copy is retained in the class workspace's `AI/tmp/keygen-docs-history-6b92b8b/`. Logs/manifests remain under ignored build directories. Historical vendor full-RSA and isolated math/pair fits apply only to their recorded inputs; no claim of fresh source-matched fit, physical acceptance, twenty-seed hardware performance, production entropy quality or certification is made here. Demo/packaging and old local SPI utilities are not distributed by this PR. See the source [README](../../../Source%20Code/Key%20Generation/README.md#integration-limits-and-remaining-work) for remaining work and [AI statement](../../../Source%20Code/Key%20Generation/docs/AI_DISCLOSURE.md) for attribution and course disclosure.
