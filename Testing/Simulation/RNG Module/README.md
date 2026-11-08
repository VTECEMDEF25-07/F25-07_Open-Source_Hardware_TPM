# RNG simulations

Author: Aaron Grossman (organization notes; original source authorship preserved).

Both benches retain PR #38's executable test logic and original author notices. Their header compile examples now match the current repository layout.

From the repository root, use an empty scratch directory outside tracked source for the simulator outputs. With Icarus Verilog installed, substitute an absolute scratch path for OUTPUT:

```text
iverilog -g2005 -DSIMULATION -s tb_entropy_capture -o OUTPUT "Testing/Simulation/RNG Module/tb_entropy_capture.v" "Source Code/RNG Module/entropy_capture.v" "Source Code/RNG Module/uart.v" "Source Code/RNG Module/entropy_source.v" "Source Code/RNG Module/ring_osc.v"
vvp -n OUTPUT

iverilog -g2005 -DSIMULATION -s tb_tpm2_get_random -o OUTPUT "Testing/Simulation/RNG Module/tb_tpm2_get_random.v" "Source Code/RNG Module/RNG.v" "Source Code/RNG Module/tpm2_get_random.v" "Source Code/RNG Module/random_number_generation.v" "Source Code/RNG Module/entropy_source.v" "Source Code/RNG Module/ring_osc.v"
vvp -n OUTPUT
```

For Questa, compile the same source lists into a scratch `work` library with `vlog +define+SIMULATION`, load `work.tb_entropy_capture` or `work.tb_tpm2_get_random`, then `run -all`. The capture bench ends with `$stop`; the command bench ends with `$finish`. Both print `ALL TESTS PASSED` on success. Check that text and absence of failure/timeout messages; an exit code alone does not establish a pass.

The entropy-source simulation uses a behavioral oscillator model. These tests check the supplied capture/command behavior, not physical entropy quality, completed hash conditioning, or integration with the existing TPM command path.
