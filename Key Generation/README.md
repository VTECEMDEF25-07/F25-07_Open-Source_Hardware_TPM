# Key Generation: architecture and review baseline

Updated October 13, 2026. This is a documentation-only review chunk for the revised standalone core. It supersedes the September proposed cancel/staged-store protocol; it does not make the historical implementation conform to this design.

## Agreed system

- Assemble AES-128/AES-256 from supplied generation words.
- Generate RSA-2048 from two 1024-bit primes, with public exponent 65537.
- Use FIPS 186-5 Appendix A.1.3 as the generation baseline; finish the precise standards/errata mapping before algorithm implementation.
- Evaluate dedicated RTL and soft-core-driven RSA; both execute inside FPGA fabric.
- Accept one operation at a time and capture its parameters.
- Transfer validated complete results to a protected receiver, obtain whole-result ownership acknowledgment, clear temporary local secrets, then report success.
- Preserve generated RSA primes through protected handoff. Internal full-exponent/CRT preparation is deferred; required private-key validation is not.
- Use reset-only abort for the first version; no separate core cancel interface is selected.
- Consume an external fresh or isolated repeatable generation stream. Raw hierarchy seeds stay outside keygen. The detailed teammate contract is pending.
- Use generic Verilog only, including HDL testbenches. SystemVerilog requires Aaron's explicit approval for a specific section before it is used.

## Boundaries

```text
External request controller + generation service
                     |
             Portable keygen controller
              /                    \
       AES assembler           RSA candidate
                                     |
                          Arithmetic + scratch RAM
              \                    /
              Protected complete-result handoff
                     |
             External object/receiver service
```

TPM parsing, authorization, hierarchy seeds, object wrapping/handles, durable storage and host responses stay outside this core. A keygen demo is not complete TPM command support.

## Portability

Common resource wrappers select generic, Altera or Xilinx implementations. Every vendor implementation must have a synthesizable generic equivalent and match its defined cycle-level interface. Board clocks, pins, SPI transport and vendor primitives stay in wrappers/backends.

Directory proposal: `rtl/`, `IP/wrappers/`, `IP/generic/`, `IP/altera/`, `IP/xilinx/`, `firmware/`, `Testbenches/`, `reference/`, `demo/` and `scripts/`. Preserve existing organization until moves are intentional review chunks. [Coding and language rules](CODING_STANDARDS.md) apply to new/updated work.

## Existing draft review disposition

| Existing chunk | Disposition |
| --- | --- |
| This architecture outline | Review the current requirements/boundaries; exact interfaces remain open. |
| Execution/keygen plumbing | Hold from merge. Captured-request/wait/error fixes are reusable, but should be separated from legacy Create adapter integration. |
| AES assembly | Most reusable code chunk. Review counts, ordering and clearing after language/naming cleanup; reset-only and explicit complete-result handoff still require redesign. |
| AES staged-store backend | Historical prototype; do not merge as the new core. Redesign around the selected handoff boundary instead of durable-store commit/cancel. |

The legacy branches are preserved. Their original tests demonstrate historical behavior only. Style and Verilog migration must not be confused with architectural acceptance.

## Next progressive review chunks

1. Agree exact request/generation/result/reset contracts.
2. Generic resources and Verilog-only regression runner.
3. Standalone AES worker under the new contract.
4. Independently checked RSA arithmetic.
5. Complete dedicated RTL RSA generation.
6. Soft-core feasibility and RSA firmware/accelerator integration as separate chunks.
7. Shared controller/protected handoff/reset integration.
8. DE25 SPI/demo wrapper and host checker.
9. Later TPM command/object adapter integration.

Each request states behavior, dependencies, actual checks and untested limitations. Keep requests draft until review; do not merge automatically. AI contributions and independent verification are disclosed.

The canonical living spec and plan stay in the class workspace `AI/KEY_GENERATION_SPEC.md` and `AI/KEYGEN_IMPLEMENTATION_PLAN.md`. This summary is self-contained for repository reviewers.
