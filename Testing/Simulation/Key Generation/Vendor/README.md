# Keygen vendor verification

Set the commented `FPGA_IP_TYPE` define at the top of the selected board source:
0 = Generic, 1 = Altera, 2 = reserved Xilinx (unsupported). The parameter passes
through TPM_TOP's inactive keygen placeholder to the RAM/multiplier wrappers.
RNG belongs to another module owner and is outside this PR.

From the repository root, use fresh absolute scratch directories:

```text
python "Testing/Simulation/Key Generation/Vendor/test_vendor_questa.py" --build PATH
python "Testing/Simulation/Key Generation/Vendor/test_vendor_quartus.py" --build OTHER_PATH
```

Questa checks both backend lifecycles, propagation to all keygen resources,
both board RAM families, inactive placeholder admission and resource differential
behavior. Xilinx, unknown/negative backends and unsupported RAM families must fail.
Source is compiled as Verilog-2001; only `.sv` benches use SystemVerilog.

Quartus elaborates the actual DE1 and DE25 projects and verifies rejection of
Xilinx by keygen's resource wrappers. It also maps an active Cyclone V scratch
RAM to M10K, independently of the inactive placeholder. These checks do not fit
or program either FPGA, establish full-keygen capacity/timing or test hardware.

Logs and manifests stay under the supplied scratch paths.
