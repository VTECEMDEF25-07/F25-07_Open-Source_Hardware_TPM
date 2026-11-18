# PCR Windows simulation evidence

Run date: 2026-11-18, America/New_York.
Tool: Questa Intel Starter FPGA Edition-64 2024.3 (win64).
Base: `7736928a89892052a32b92b633fb0bb10cbcf9e7` (develop, routing #51 and Hash #52).

Command from repository root:

```powershell
vsim -c -do 'do {Testing/Simulation/Execution Engine/run_tpm2_hash_command.do}'
```

## Observed results

```text
TPM2_PCR_COMMAND_PASS accepted=28 dispatched=28 completed=28 counter=6
TPM2_PCR_SPI_ENGINE_ROUTE starts=9 replies=9
TPM2_PCR_SPI_PASS
TPM2_HASH_ENGINE_ROUTE_RESET_PASS accepts=24 dispatches=24 replies=22 (two reset-aborted jobs)
TPM2_HASH_COMMAND_PASS
TPM2_HASH_SPI_ENGINE_ROUTE starts=4 replies=4
TPM2_HASH_SPI_PASS
KEYGEN_ENCRYPTDECRYPT2_PASS
TPM2_ENCRYPTDECRYPT2_SPI_PASS
TPM_LEGACY_SPI_PASS entry=240 errors=0
```

The final original SPI simulation reported `Errors: 0, Warnings: 46`.
Warnings include inherited port-width/connection warnings and vendor library
port coercions; this is not a warning-free build. The runner verifies each
bench's `passed` flag and checks the original bench's actual final entry and
error counter rather than trusting the process exit status.

PCR command tests compare complete wire replies and response write counts.
The full SPI test includes two 300-byte replies, test-only real backend
SHA-256 Extends for four distinct PCRs, an independently computed digest
oracle, startup retention, and hardware-reset reinitialization. The production
host Extend input stays inactive. See [profile](../../../Source%20Code/Execution%20Engine/PCR_PROFILE.md)
for the exact supported scope and startup limitations.

## Retained raw evidence

The complete successful local transcript is retained under the class project
at `AI/tmp/pcr-read/evidence/windows-questa-final.log` (outside the Git checkout).
SHA-256: `bd6f5da3ddeefdc080ffad4dd0442af64859de2e2c3c860888a2bfc2a3806c7f`.
Earlier failing diagnostics and simulator-license contention logs are retained
alongside it. The successful run above is the evidence for this candidate.

## Physical hardware validation

Not performed: FPGA programming, physical SPI/PCR transactions, Quartus
synthesis/fit/timing, locality policy, PC Client startup PCR values, and NV
saved-state restore. The existing bank is a volatile, all-zero reset profile;
management Startup does not currently initialize or restore PCR state.
No host PCR_Extend, unrelated capabilities, or authorization implementation
is included. These simulator passes do not establish TPM platform compliance.
