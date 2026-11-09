# RNG simulations

Author: Aaron Grossman (organization notes; original source authorship preserved).

The capture bench retains PR #38's executable test logic and original author notices.
The GetRandom bench connects the RNG to the production `hash_subsystem` through
its dedicated requester lane. The standalone SHA model remains a separate
simulation check against Python `hashlib`.

Preferred GetRandom runner (Python standard library plus Questa on PATH, or `QUESTA_BIN` pointing to its binary directory):

```text
python "Testing/Simulation/RNG Module/run_getrandom.py" --output OUTPUT_DIRECTORY
```

Use a scratch output directory outside tracked source. The runner compiles production RTL in Verilog-2001 mode, compiles the tests separately in SystemVerilog mode, checks the behavioral SHA model against 142 independent Python `hashlib` digests (including empty input and padding boundaries), runs the shared-engine arbitration test, and runs all GetRandom success/error/freshness/backpressure checks. It requires explicit success markers and propagates compilation/simulation failures. Logs remain in the output directory.

From the repository root, use an empty scratch directory outside tracked source for the simulator outputs. With Icarus Verilog installed, substitute an absolute scratch path for OUTPUT:

```text
iverilog -g2005 -DSIMULATION -s tb_entropy_capture -o OUTPUT "Testing/Simulation/RNG Module/tb_entropy_capture.v" "Source Code/RNG Module/entropy_capture.v" "Source Code/RNG Module/uart.v" "Source Code/RNG Module/entropy_source.v" "Source Code/RNG Module/ring_osc.v"
vvp -n OUTPUT

```

For manual Questa runs, compile RNG and hash production sources with `vlog -vlog01compat +define+SIMULATION` and the GetRandom test/model with `vlog -sv`. Load `work.tb_entropy_capture` or `work.tb_tpm2_get_random`, then `run -all`. The capture bench ends with `$stop`; the command bench ends with `$finish` on success and `$fatal` on failure. Both print `ALL TESTS PASSED` on success. The capture bench still requires checking that text and absence of failure/timeout messages; its exit code alone does not establish a pass.

The entropy-source simulation uses a behavioral oscillator model. These tests check the supplied capture/command behavior and shared SHA/DRBG wiring in simulation. Physical entropy quality, entropy health monitoring, and the board TPM command path are outside these tests. Hash_DRBG is no longer a passthrough placeholder; production cryptographic acceptance remains blocked by the documented entropy/health/integration gaps.
