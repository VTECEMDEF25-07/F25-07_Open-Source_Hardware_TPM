# Board-local implementation selection

Set the commented define near the top of the selected board's top-level file:

```verilog
// 0 = Generic (RNG simulation only), 1 = Altera, 2 = Xilinx (not implemented).
`define FPGA_IP_TYPE 1
```

This supplies the board's `IP_TYPE` parameter default. There is no shared vendor
header. The macro is undefined at the end of the board file so compiling both
board sources does not leak one board's default into another compilation unit.
The parameter passes through `TPM_TOP` into both
keygen and RNG, including every RAM/multiplier wrapper and entropy oscillator.
Legacy RNG vendor macros are explicitly rejected. Portable logic does not need a vendor
parameter. Selection remains explicit per instance so simulation can compare
implementations in one compilation.

| Implementation | Value | Meaning |
| --- | --- | --- |
| Generic | 0 | Portable RTL implementation |
| Altera | 1 | Altera/Intel-specific implementation |
| Xilinx | 2 | Reserved identity; currently rejected by all implementation wrappers |

These identify implementations, not support for every FPGA in a vendor's product
range. Unsupported values fail elaboration in Questa/Quartus and terminate
Verilator with a fatal error. The behavioral RNG model still validates selection.
Generic is supported by portable keygen RTL and functional RNG simulation; a
Generic **physical entropy source is rejected by synthesis**.

Board wrappers contain no extra backend check; implementation wrappers reject
unsupported resource selections. Board PLL/reset/fan circuitry remains specific
to its physical board. The board fixes
`DEVICE_FAMILY` metadata: DE1 passes `"Cyclone V"` for M10K and DE25 passes
`"Agilex 5"` for M20K. This is not a second vendor selector. Other Altera RAM
families are explicitly rejected. Pins, PLLs and cooling stay specific to the
physical board and cannot become Xilinx circuitry by changing a parameter.

Xilinx hardware support requires implemented/validated wrappers and a matching
board build before value 2 can be accepted. Legacy Xilinx/iCE40 oscillator
branches are not offered as partial backend support.

`TPM_TOP` contains inactive keygen and RNG resource placeholders. Selection
propagates, but command dispatch, entropy admission and response integration are
not enabled by this change. Synthesis may remove the placeholders.

Run `Testing/Simulation/Project Vendor/test_project_vendor_questa.py --build PATH`
and `test_project_vendor_quartus.py --build PATH` for behavior, propagation and
synthesis rejection checks. See that directory's README for exact scope.
