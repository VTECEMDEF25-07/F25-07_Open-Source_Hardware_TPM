<!-- Authors: Aaron Grossman (changes in this PR); existing project contributors; see Git history. -->
# Key-generation simulations

Run commands from this directory (`Testing/Simulation/Key Generation`).
Production Verilog and design documentation live in
[`Source Code/Key Generation`](../../../Source%20Code/Key%20Generation/README.md).
Runners resolve those files relative to this checkout; keep the repository together.

- `testbench/`: core tests and the deterministic, test-only stream fixture.
- `reference/`: independent Python oracle, public corpus and reference tests.
- `scripts/`: core simulation, provenance and arithmetic fit runners.
- `IP/`, `Math/`: resource and arithmetic benches, vectors and runners.

```sh
python -m unittest discover -s reference -p 'test_*.py'
python scripts/check_repository_hygiene.py
python3 scripts/run_integration_verilator.py --suite lifecycle
```

See [build and test commands](../../../Source%20Code/Key%20Generation/docs/BUILD_AND_TEST.md)
for tool requirements and full-key regressions. Board projects under `Project/`
build the existing TPM; the standalone key generator is not wired into its command path.
