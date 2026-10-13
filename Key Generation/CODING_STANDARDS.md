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

## Verilog only

All contributed synthesizable HDL and HDL tests must use Verilog, not SystemVerilog. Use `.v`/`.vh` and compile in Verilog mode. A renamed `.sv` file with unchanged SystemVerilog syntax is not an acceptable conversion. Ordinary C/Python firmware/host tools are not HDL exceptions.

Do not add SystemVerilog IP, tests or compiler mode without approval. If a specific section genuinely requires it, stop that section, explain the need and alternatives, and obtain Aaron's explicit section-scoped approval before proceeding. A Verilog wrapper does not waive this rule for SystemVerilog internals.

The migration targets Verilog-2001 syntax to provide a concrete portable dialect. No SystemVerilog constructs or system tasks are needed for the current procedural regressions. Verilog tests use explicit failure messages/finish plus runner-enforced failure detection.

Additional assistant-proposed coding standards remain deferred. This file does not approve any cryptographic algorithm or old interface contract.
