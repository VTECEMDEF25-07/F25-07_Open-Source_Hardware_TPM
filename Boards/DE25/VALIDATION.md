# DE25 common-SPI validation — November 3, 2026

Both boards use the same portable `IO Interface/spi_slave.v`. This supersedes
the parent board-support baseline and the initial DE25-only opt-in revision.
The transaction controller, FIFO/registers, execution, management and crypto
behavior are unchanged. PR #37 still targets PR #36's branch.

| Check | Result |
|---|---|
| Full board build and bitstream | PASS; expected 1 PLL(s) and complete physical pin map verified |
| Original TPM protocol vectors | PASS at 100k, 500k and 1MHz with ideal test-only board models; 21 inherited top-level warnings |
| Common serializer unit regression | PASS; all rates, 20 phase offsets, duplex, back-to-back/delayed TX, stopped SCK, CS abort, reset/replay |
| Four-corner worst setup | **+2.224 ns** |
| Four-corner worst hold | **+0.004 ns** |
| Four-corner worst pulse width | **+4.537 ns** |
| Three SPI synchronizer chains | Recognized; two registers per chain; all interstage setup paths timed and positive at every corner |
| UCP summary | Zero unconstrained clocks, ports or path pairs for setup/hold |
| Physical-board acceptance | Not performed for this revision |

Quartus Pro 26.1 build: 1,531 ALMs, 2 RAM blocks, one PLL, 10 physical pins
verified. Worst recovery/removal margins are +2.564/+0.107 ns.
The common SPI retains the +2.224 ns setup result of the tested DE25-only
prototype, replacing the parent's -2.700 ns legacy-detector failure.

The legacy dual-edge detector and logic-clocked shifter are absent. All three
SPI synchronizers are recognized; no ignored timing exceptions are reported.
Numeric timing passes do not waive Design Assistant findings for read-only
JTAG capture crossings, external I/O-delay conventions and board reset into
the PLL control register. The existing Reset Release IP warning is retained.
Fan and board-reset/JTAG implementation are unchanged by this common-SPI revision.

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
