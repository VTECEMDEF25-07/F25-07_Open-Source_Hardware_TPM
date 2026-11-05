<!--
Filename: CODING_STANDARDS.md
Authors: Project contributors; see Git history.
Date: 2026-10-13
General Description: Documents Coding and HDL language rules.
AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.
-->

# Coding and HDL language rules

Effective October 13, 2026. Aaron's supplied naming/commenting/wiring conventions apply to contributed HDL.

- Descriptive signal names with words separated by underscores.
- `_n` for active-low signals.
- `_i` on input ports; `_o` on output ports.
- `_reg` identifies stored sequential state; `_en` identifies enables.
- Parameter names in capitals.
- Command names in CAPS; retain external standard identifiers when quoting them.
- Comments explain the HDL sufficiently for a reviewer to understand it.
- Use explicit named module port connections.

Combined markers must remain legible, e.g. `reset_n_i`, `load_en_i`, `state_reg`. These examples implement the supplied markers; they do not add a broader style guide.

## Verilog source; SystemVerilog tests permitted

All contributed synthesizable HDL must use Verilog, not SystemVerilog. Use `.v`/`.vh` and compile source in Verilog mode. Aaron explicitly permits SystemVerilog testbenches for simplicity; keep `.sv` tests and compile them separately in SV mode. Ordinary C/Python firmware/host tools are not HDL exceptions.

Do not add synthesizable SystemVerilog IP or compile source in SV mode without specific approval. Test-only SV is already approved. If a specific section genuinely requires it, stop that section, explain the need and alternatives, and obtain Aaron's explicit section-scoped approval before proceeding. A Verilog wrapper does not waive this rule for SystemVerilog internals.

Source validation uses Verilog-2001 mode as a concrete portable baseline. The runner compiles source separately from testbenches so approved SV tests cannot hide SystemVerilog dependencies in source. Existing self-checking SV failure reporting is retained.

Additional assistant-proposed coding standards remain deferred. This file does not approve any cryptographic algorithm or old interface contract.
