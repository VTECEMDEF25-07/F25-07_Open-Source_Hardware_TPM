# SPI restoration onto develop — November 18, 2026

Base: `e1f9f74d8c751e542153fadaa62bfb0207b7c161` (merged PRs 51–55).
Restoration source: `8f44d986fcfbf5ab2a03383621b64f89ddbfc932` (restored PR37).

The portable pin-clocked SPI serializer and board constraints are restored.
TPM_TOP retains captured locality and every merged command connection; only its
obsolete 100 MHz SPI port is removed. Both board source lists retain Hash, PCR
and RNG dependencies. Board replay snapshots include all execution workers and
RNG sources. Existing benches lose only obsolete clock-port connections.

The execution engine, Hash/PCR subsystem, RNG, symmetric and key-generation
implementation files are unchanged from develop. Feature gates and authorization
masks are unchanged. No demo sources, branch-rule changes or release promotion
are included.

## Fresh validation

- Questa Intel Starter 2024.3: serializer PASS at 100k/500k/1M/10M/15M/24M/30MHz,
  20 asynchronous phase offsets, abort/reset/boundary cases.
- Full `run_tpm2_hash_command.do`: PASS. Hash, PCR discovery/Read/Extend,
  GetRandom, real RCT/APT propagation, owner/timeout/reset, shared SHA contention,
  AES fixture routing, enabled/disabled gates, mixed traffic and four Extend
  generations pass. Original SPI regression: entry 240, errors 0.
- Ideal board-model replay: DE1 and DE25 PASS at simulated 30MHz. This is
  simulation, with inactive Generic keygen and test clock/reset/fan models.
- Default board builds: DE25 Quartus Pro 26.1 and DE1 Lite 24.1 compile/fit PASS.
  GetRandom, PCR Extend and AES remain disabled in these board builds; enabled
  command configurations are covered by simulation, not an enabled-image fit.

| Four-corner worst slack, ns | DE25 | DE1 |
|---|---:|---:|
| Setup | +0.380 | **−9.924** |
| Hold | +0.072 | +0.146 |
| Recovery | +1.041 | +4.354 |
| Removal | +0.047 | +1.480 |
| Minimum pulse width | +4.531 | +8.434 |

DE25's full SPI audit passes. DE1's audit fails setup in both slow corners:
the worst path runs from `command_response_buffer|fsm_ci|addr_o[3]` to
`command_response_buffer|rspByteOut_o[7]`. The command-response-buffer RTL is
unchanged from develop; this observation does not establish whether develop
already failed an identical fit. Closing this command-path timing failure needs
separate work; DE1 is not timing accepted. All SPI mailbox budgets and five
synchronizer interstage checks pass on both boards. Both audits report zero
unconstrained setup/hold paths. No constraints were relaxed to hide failures.

DE25 uses 9,153 ALMs, 13,298 registers, four RAM blocks and one PLL; DE1 uses
9,312 ALMs, 13,286 registers, eight RAM blocks and no PLL. Compile warnings remain
(DE25 63, DE1 268), including existing width/port and vendor diagnostics.

## Acceptance boundary

No hardware was accessed or programmed. Physical acceptance of this exact source
and image is pending. Candidate `d57da1a` and SOF SHA256
`1f7bf9b2fe8b058ac4aa0f6d2d7d308bebafb4f8bacb80f53972e499eebbe1d9`
passed 318 physical assertions at 100kHz on a different source tree; those results
do not transfer to this PR. Neither a simulated 30MHz replay nor default-off
board timing establishes enabled-image or high-speed physical acceptance.

Local logs and source/image manifests are retained in the class workspace at
`AI/tmp/develop-spi-20261118-evidence/`. This change follows feature PR → develop
review; protected release `main` is unchanged.
