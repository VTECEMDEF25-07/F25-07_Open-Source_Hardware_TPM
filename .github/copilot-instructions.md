# Senior design TPM review guidance

Review changes in this open-source FPGA TPM project against existing module documentation and approved interfaces. Apply conventions to new or changed HDL, avoiding unrelated rewrites of inherited code.

## Established coding standards
- Descriptive underscore-separated signal names; `_n` for active-low, `_i` for input ports, `_o` for outputs, `_reg` for stored state and `_en` for enables. Examples: `reset_n_i`, `load_en_i`, `state_reg`.
- Uppercase parameters and command names; preserve standard-defined external identifiers.
- Comments explain HDL behavior; module instances use explicit named port connections.
- Synthesizable HDL uses Verilog `.v`/`.vh`, validated separately in Verilog-2001 mode. SystemVerilog testbenches are permitted. Synthesizable SystemVerilog, including IP behind Verilog wrappers, requires explicit section-scoped approval.
- These conventions mirror `Source Code/Key Generation/CODING_STANDARDS.md` (or root `CODING_STANDARDS.md` if relocated). Additional style preferences are suggestions, not established requirements.

## Correctness priorities
- Flag demonstrable width, signedness, overflow, indexing, latch, multiple-driver, reset and sequential assignment bugs. Check handshake stability, FIFO boundaries and clock-domain crossings against actual interfaces. Explain the failing scenario.
- Check TPM/transport lengths, bounds, byte ordering, response sizes and errors against documented interfaces. Do not invent pending teammate contracts or infer full TPM compliance from a demo.
- Check cryptographic secret lifetime/clearing, result ownership, error paths, entropy assumptions and independent reference checks. Simulation randomness or statistical tests alone do not prove security. Scope keygen architecture requirements to keygen.
- Verify board pins, clocks, constraints and vendor primitives against the selected board and wrappers. DE1-SoC and DE25 are not interchangeable.
- Look for self-checking tests of changed behavior and relevant boundary/error/reset cases. Distinguish simulation, synthesis and hardware validation; never claim checks ran without evidence.

## Feedback
Give actionable findings on changed lines with severity, concrete impact and suggested corrections. Distinguish confirmed defects, convention violations and optional suggestions. Prioritize correctness over cosmetics; avoid duplicates and speculative requirements. Human review remains necessary.
