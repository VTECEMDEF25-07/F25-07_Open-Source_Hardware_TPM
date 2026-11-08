# Project-wide vendor verification

Set the commented `FPGA_IP_TYPE` define at the top of the selected board file; see `Source Code/README.md` for the
support matrix. Run from the repository root with a fresh absolute scratch path:

```text
python "Testing/Simulation/Project Vendor/test_project_vendor_questa.py" --build PATH
python "Testing/Simulation/Project Vendor/test_project_vendor_quartus.py" --build OTHER_PATH
```

The Questa runner checks lifecycle behavior for Generic and Altera, propagation
from TPM_TOP to every keygen resource and all four RNG oscillators, both board
RAM families, inactive placeholder admission, RAM/multiplier differential
behavior, and both existing RNG behavior suites with both supported selections.
It also requires explicit rejection of Xilinx, unknown/negative backend values,
unknown Altera RAM families and invalid oscillator lengths. Behavioral entropy
simulation does not measure physical entropy quality.
Legacy `RO_INTEL`, `RO_XILINX` and `RO_ICE40` build defines are rejected rather
than ignored; migrate their selection to the board-top `IP_TYPE` parameter.

The Quartus runner elaborates the actual DE1 and DE25 projects using their
installed Lite/Pro toolchains. It verifies that Xilinx is rejected by the resource wrappers without an extra board-level guard. A live
standalone entropy-ring elaboration must accept Altera and reject Generic and
Xilinx in synthesis, where the behavioral simulation model is absent.
It also maps an active standalone Cyclone V scratch RAM to validate the M10K
implementation independently of the TPM's unused resource placeholders.

Linux/WSL users can additionally run `test_rng_vendor_verilator.py --build PATH`
to check supported RNG startup and fatal rejection of Xilinx/unknown values
using Verilator's executable simulation path.

Logs and manifests stay under the supplied build paths. Source HDL is compiled
as Verilog-2001; only `.sv` benches use SystemVerilog. These checks do not fit or
program either FPGA, validate full-core capacity/timing or launch hardware tests.
