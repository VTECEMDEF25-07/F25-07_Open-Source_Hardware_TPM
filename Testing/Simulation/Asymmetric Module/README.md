# Asymmetric Module simulations

The five original PR #40 Verilog testbenches are preserved unchanged here.
RTL is in [Source Code/Asymmetric Module](../../../Source%20Code/Asymmetric%20Module/README.md).

## Python vector tests

Requires Python 3.9 or newer, Verilator with `--binary` and `--timing` support,
and its C++ build tools (for example, Linux/WSL with Verilator, g++ and make).
Run from the repository root:

```text
python3 "Testing/Simulation/Asymmetric Module/scripts/test_montgomery_mult_2048.py"
python3 "Testing/Simulation/Asymmetric Module/scripts/test_rsa_modexp_2048.py"
```

Both scripts resolve source paths from their own location, so the working
directory can vary. They generate `vectors.txt` and simulator products in a
temporary directory and check the simulation exit status and pass summary.
The Montgomery runner checks 18 vectors; the RSA runner checks one 2048-bit
modular exponentiation against Python's `pow()` result.

## Small-width tests

`tb_montgomery_mult.v`, `tb_rsa_modexp.v` and `tb_rsa_controller.v` are
self-checking benches using WIDTH=8 by default. Compile with the four RTL
files and run the matching testbench top. Require `ALL TESTS PASSED` and no
`FAIL:` output; these benches use `$finish` even when a check fails.

The two `*_vectors.v` benches read `vectors.txt` from the simulator's working
directory; use their Python runners to generate the required vectors.
