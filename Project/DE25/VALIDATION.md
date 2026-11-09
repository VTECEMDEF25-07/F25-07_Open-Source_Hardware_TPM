# DE25 SPI validation

Author: Aaron Grossman; Codex assisted with verification and documentation.

Local integration check, November 8, 2026: main
`81b6968645e70669cc157c7709d111206f1f56dc` plus SPI PR #37 head
`dfcdaabd4a992e6f6972f6eb81a63bbdc904b8ee`, with current naming/layout and the reviewed SPI cleanup.
The merged image has **not been physically tested**.

- Complete matching-edition Quartus build: PASS; 1 PLL.
- Original TPM assertion replays: PASS at 1, 24 and 30 MHz with ideal board
  clock/reset models. The common serializer unit suite also passes.
- All four operating-corner audits: PASS, including mailbox routing and all
  five synchronizer chains. Setup and hold are fully constrained; the audit rejects empty checks and
  nonzero unconstrained-path counts.

| Worst slack (ns) | Result |
|---|---:|
| Setup | +0.379 |
| Hold | +0.024 |
| Recovery | +2.994 |
| Removal | +0.030 |
| Minimum pulse width | +4.537 |

Tested SOF SHA256: `56e28b3ded10ea1d856d4ff6c3a1dac5652e1e00954749a08f3efdd87a2ba573`.

Current main's keygen resource selection is preserved, with the placeholder
inactive. Standalone RNG sources remain outside the TPM command path.
Compiler/DRC warnings remain; passing these checks is not full TPM or entropy
validation. Historical build/bitstream records remain in Git history.

Follow the [SPI timing/reset contract](../../Source%20Code/IO%20Interface/SPI.md)
and [physical follow-ups](../../FUTURE_WORK.md) before claiming board acceptance.

The vendor fan files are unchanged. This image has no JTAG telemetry monitor.
Earlier PR-image 30 MHz failures and later unmodified-main physical passes
apply to their own bitstreams, not this merge. A 24 MHz FTDI request configures
30 MHz; exact 24 MHz hardware acceptance remains outstanding.
