<!--
Filename: BUILD_AND_TEST.md
Authors: Project contributors; see Git history.
Date: 2026-10-13
General Description: Documents Build and test the portable key generator.
AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.
-->

# Build and test the dedicated-logic key generator

Run commands from `Key Generation`. Source is Verilog-2001; testbenches may use SystemVerilog. Generic resources are the default; `KEYGEN_ALTERA` selects real Altera primitives. No firmware compiler or ROM is needed.

## Offline Python checks (Windows or Linux)

```sh
python -m unittest discover -s scripts -p 'test_*.py'
python -m unittest discover -s reference -p 'test_*.py'
python -m unittest discover -s demo/de25_revd/tests -p 'test_*.py'
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

## DE25 projects (Windows/Quartus Pro)

```powershell
python demo/de25_revd/prepare_build.py --build-root build/advisor-board --variant all
```

This prepares only `rtl_generic` and `rtl_altera`, with immutable source snapshots, constraints and fingerprints. Add `--compile` for synthesis/place-and-route. Use a fresh build directory per revision. The script never programs hardware. Inspect timing/resource reports before physical testing; build success alone is not acceptance.

The tool environment previously used Quartus Pro 26.1, Questa 2024.3 with Quartus 24.1 models and Verilator 5.020. Actual run evidence must record actual versions. [Dependencies](DEPENDENCIES.md) lists provenance; [validation](RTL_REVIEW_VALIDATION.md) records the present split checks.

Keep generated products in ignored `build/` or class `AI/tmp/`. Physical acceptance still requires the 20-seed corpus, AES, three SPI rates, reset/fault/stall recovery, healthy cooling and the documented soak gate. See [completion](COMPLETION_MATRIX.md) and [release](RELEASE.md).
