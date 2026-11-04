# DE1 common-SPI validation — November 3, 2026

Both boards use the same portable `IO Interface/spi_slave.v`. This supersedes
the parent board-support baseline and the initial DE25-only opt-in revision.
The transaction controller, FIFO/registers, execution, management and crypto
behavior are unchanged. PR #37 still targets PR #36's branch.

| Check | Result |
|---|---|
| Full board build and bitstream | PASS; expected 0 PLL(s) and complete physical pin map verified |
| Original TPM protocol vectors | PASS at 100k, 500k and 1MHz with ideal test-only board models; 21 inherited top-level warnings |
| Common serializer unit regression | PASS; all rates, 20 phase offsets, duplex, back-to-back/delayed TX, stopped SCK, CS abort, reset/replay |
| Four-corner worst setup | **+8.648 ns** |
| Four-corner worst hold | **+0.128 ns** |
| Four-corner worst pulse width | **+8.434 ns** |
| Three SPI synchronizer chains | Recognized; two registers per chain; all interstage setup paths timed and positive at every corner |
| UCP summary | Zero unconstrained clocks, ports or path pairs for setup/hold |
| Physical-board acceptance | Not performed for this revision |

Quartus Lite 24.1 build: 924 ALMs, 4 RAM blocks, **zero PLLs**, 18 physical
pins verified. SPI and TPM state now run directly from the board 50 MHz input;
the old 100 MHz-only serializer and PLL are removed. Worst overall setup margin
was +1.229 ns in the parent baseline; the common implementation reports +8.648 ns.

The first candidate used brace-wrapped synchronizer assignment targets that
Quartus Lite ignored. Quoted targets fixed those warnings; only the final,
recompiled result is current evidence. Lite lacks Pro's structural CDC and
ignored-exception reporting options. The common audit exports the supported
exception and metastability reports and verifies each SPI chain's actual timing.
External reset inputs retain the inherited timing exceptions; no recovery or
removal paths are analyzed, so those checks are N/A rather than claimed passes.

Only pad-to-first-synchronizer paths are excepted; functional/interstage timing
remains enabled. External SPI setup/hold and host timing require physical
adapter acceptance. No whole-board CDC/reset signoff, TPM certification or ASIC
physical signoff is claimed. The common SPI has no vendor primitives; FPGA
clock/reset/debug support remains in board wrappers.

See [common SPI documentation](../../IO%20Interface/SPI.md) for limits and
reproduction commands, and [validation hashes](../spi_validation.json) for
source/report/SOF and transcript hashes. Detailed evidence is retained in class
`AI/tmp/common-spi-*` and the ignored board build/report directories. Historical
baseline evidence remains in Git history and the earlier local evidence folders.
