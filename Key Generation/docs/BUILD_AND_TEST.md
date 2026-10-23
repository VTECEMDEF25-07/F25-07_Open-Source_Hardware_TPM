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

## Scope

The DE25 demonstration and its packaging/host utilities are local-only under ignored `local_scripts/demo/`. Board management is reviewed separately. No board/demo build is required for the portable core tests above. The complete-key runners use `testbench/fixtures/keygen_test_source.v` as deterministic test input, never production entropy.

[Validation](RTL_REVIEW_VALIDATION.md) records earlier results and their limits. Production TPM integration and source-matched physical acceptance remain future work.
