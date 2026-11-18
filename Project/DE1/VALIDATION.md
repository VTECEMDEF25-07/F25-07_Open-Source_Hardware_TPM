# DE1 SPI validation

Author: Aaron Grossman; Codex assisted with verification and documentation.

Local integration check, November 8, 2026: main
`81b6968645e70669cc157c7709d111206f1f56dc` plus SPI PR #37 head
`dfcdaabd4a992e6f6972f6eb81a63bbdc904b8ee`, with current naming/layout and the reviewed SPI cleanup.
The merged image has **not been physically tested**.

- Complete matching-edition Quartus build: PASS; 0 PLLs.
- Original TPM assertion replays: PASS at 1, 24 and 30 MHz with ideal board
  clock/reset models. The common serializer unit suite also passes.
- All four operating-corner audits: PASS, including mailbox routing and all
  five synchronizer chains. Setup and hold are fully constrained; the audit rejects empty checks and
  nonzero unconstrained-path counts.

| Worst slack (ns) | Result |
|---|---:|
| Setup | +1.426 |
| Hold | +0.125 |
| Recovery | +4.084 |
| Removal | +6.227 |
| Minimum pulse width | +8.434 |

Tested SOF SHA256: `4811a198d55e9bddb77af7282724afc303d426e40e12915a059fb5fe211568f1`.

Current main's keygen resource selection is preserved, with the placeholder
inactive. Standalone RNG sources remain outside the TPM command path.
Compiler/DRC warnings remain; passing these checks is not full TPM or entropy
validation. Historical build/bitstream records remain in Git history.

Follow the [SPI timing/reset contract](../../Source%20Code/IO%20Interface/SPI.md)
and [physical follow-ups](../../FUTURE_WORK.md) before claiming board acceptance.
