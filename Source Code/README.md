# Shared implementation selection

`ip_types.vh` belongs to the whole TPM project. Vendor/backend identifiers must
be defined here once, rather than owned or duplicated by an individual module.
Add `Source Code/` to the HDL compiler's include/search path and include
`ip_types.vh` by name. Both checked-in Quartus projects use this shared path.

The board top has one implementation parameter, `IP_TYPE` (default `IP_ALTERA`
on DE1 and DE25). Set that parameter once; it passes through `TPM_TOP` into both
keygen and RNG, including every RAM/multiplier wrapper and entropy oscillator.
Legacy RNG vendor macros are explicitly rejected. Portable logic does not need a vendor
parameter. Selection remains explicit per instance so simulation can compare
implementations in one compilation.

| Identifier | Value | Meaning |
| --- | --- | --- |
| `IP_GENERIC` | 0 | Portable RTL implementation |
| `IP_ALTERA` | 1 | Altera/Intel-specific implementation |
| `IP_XILINX` | 2 | Reserved identity; currently rejected by all implementation wrappers |

These identify implementations, not support for every FPGA in a vendor's product
range. Unsupported values fail elaboration in Questa/Quartus and terminate
Verilator with a fatal error. The behavioral RNG model still validates selection.
Generic is supported by portable keygen RTL and functional RNG simulation; a
Generic **physical entropy source is rejected by synthesis**.

Both physical board wrappers require Altera and reject Generic/Xilinx/unknown
values, including their fixed clock/reset/fan circuitry. The board fixes
`DEVICE_FAMILY` metadata: DE1 passes `"Cyclone V"` for M10K and DE25 passes
`"Agilex 5"` for M20K. This is not a second vendor selector. Other Altera RAM
families are explicitly rejected. Pins, PLLs and cooling stay specific to the
physical board and cannot become Xilinx circuitry by changing a parameter.

Xilinx hardware support requires implemented/validated wrappers and a matching
board build before `IP_XILINX` can be accepted. Legacy Xilinx/iCE40 oscillator
branches are not offered as partial backend support.

`TPM_TOP` contains inactive keygen and RNG resource placeholders. Selection
propagates, but command dispatch, entropy admission and response integration are
not enabled by this change. Synthesis may remove the placeholders.

Run `Testing/Simulation/Project Vendor/test_project_vendor_questa.py --build PATH`
and `test_project_vendor_quartus.py --build PATH` for behavior, propagation and
synthesis rejection checks. See that directory's README for exact scope.
