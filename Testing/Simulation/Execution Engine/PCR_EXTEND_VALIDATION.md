# PCR Extend validation

Codex-assisted implementation and tests, 2026-11-18, Windows Questa Intel
Starter FPGA Edition 2024.3. Base: PCR Read #54,
`67972a206f027321d1371b519c00cd0bf1bca323`.

## Executed checks

```powershell
vsim -c -do 'do {Testing/Simulation/Execution Engine/run_tpm2_hash_command.do}'
```

Passing candidate transcript markers:

```
TPM2_PCR_EXTEND_COMMAND_PASS accepted=140 dispatched=140 completed=139
TPM2_PCR_EXTEND_SPI_ENGINE_ROUTE starts=25 replies=25
TPM2_PCR_EXTEND_SPI_PASS
TPM2_PCR_COMMAND_PASS accepted=28 dispatched=28 completed=28 counter=6
TPM2_PCR_SPI_ENGINE_ROUTE starts=9 replies=9
TPM2_PCR_SPI_PASS
TPM2_HASH_ENGINE_ROUTE_RESET_PASS accepts=24 dispatches=24 replies=22 (two reset-aborted jobs)
TPM2_HASH_COMMAND_PASS
KEYGEN_ENCRYPTDECRYPT2_PASS
TPM2_ENCRYPTDECRYPT2_SPI_PASS
TPM2_PCR_EXTEND_DISABLED_PASS
TPM2_PCR_EXTEND_EMPTY_MASK_PASS
TPM_LEGACY_SPI_PASS entry=240 errors=0
```

The command test includes one deliberately reset-aborted mutation; accepted
and dispatched counts exceed completions by exactly one. Reset clears the
volatile bank/counter, and a fresh Extend completes correctly afterward.
Disabled and empty-mask runs independently verify configuration gating.
The SPI test exercises actual ACCESS locality ownership, not forced locality
or forced backend mutation inputs. Reads compare independent literal SHA-256
vectors and complete wire responses. All-24 reads in the command bench check
untouched PCRs after each accepted/rejected request. See the tracked
[PCR profile](../../../Source%20Code/Execution%20Engine/PCR_PROFILE.md) for
supported requests, policy defaults and the Phase Three handoff.

Raw candidate transcript is retained locally at
`AI/tmp/pcr-extend/evidence/questa-candidate.log` (outside the Git checkout),
SHA-256 `ffaede12e42f59d7ad09908ecc3a5395cb43042d1c4b6baf4b9823f4195e1caf`.
A final run is also required on the committed candidate before publication;
its commit and transcript are recorded in the PR description and local status.
Expected inherited simulator warnings include intentionally unconnected legacy
engine/session ports and existing FIFO address-width conversions. The runner
checks explicit pass flags, original SPI assertion count and completion entry;
simulator exit status alone is not treated as success.

## Scope and physical validation

Only Extend additions are compared against the PCR Read branch. No GetRandom
#53 code, new SHA/PCR implementation, reset/startup profile or NV/auth subsystem
is included. GetRandom overlaps engine mux/dispatch, CRB route and TPM_TOP
shared-SHA wiring; the combined GetRandom/Extend stack is not validated here.

No physical FPGA/Lenovo boot, logic analyzer trace, FPGA fit/timing or resume/NV
validation was performed. Extend stays off by default, with a zero eligible-PCR
auth mask. Real platform authorization, locality and lifecycle/NV contracts
are required before production use. Phase Three must replace the static
empty-password path before PCR mutation, own external NV plus profile-defined
Startup/Reset/Shutdown/save/restore, preserve bank/counter consistency and add
end-to-end authorization/locality rejection and resume tests. PCR_Event and
sequence commands remain a separate inventory.
