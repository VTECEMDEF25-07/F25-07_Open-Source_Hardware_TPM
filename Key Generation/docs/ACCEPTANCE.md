# Implementation and evidence ledger

Target: RTL/generic, RTL/Altera, softcore/generic, softcore/Altera. Xilinx deferred.
Every entry remains pending until reproducible evidence is recorded.

| Requirement | Acceptance | Status |
|---|---|---|
| SYS-01 | AES128/256 exact4/8word results, gaps/stalls/repeated words | Pending |
| SYS-02/03 | RSA2048 algorithm mapping and independent full-key checks | Pending |
| SYS-04 | Four combinations simulate, fit and run | Pending |
| SYS-05/06 | Captured request, ownership, scrub before status | Pending |
| SYS-07 | Prime retention and n/e/p/q transfer | Pending |
| SYS-08 | Reset every phase, scrub and recovery | Pending |
| SYS-09/10 | Isolated32bit stream, failure and replay | Pending |
| SYS-11 | Actual Altera models versus synthesizable generic | Pending |
| SYS-12/13 | Verilog2001 source, separate SV tests, naming review | Pending |
| SYS-14 | Focused documented MRs, Aaron merges | In progress |
| Fit | Routed50MHz; reviewed unconstrained paths;70% resource target | Pending |
| Speed | Each build median<=30s over fixed20seeds | Pending |
| Board | SPI3rates, reset/fault/replay,30min soak per build | Pending |

Measure accepted request through post-scrub terminal success with unstalled
source/receiver. Report SPI end-to-end time separately. Record every sample,
median and maximum, not inferred statistical tail guarantees.180s timeout fails
the host test, never weakens the algorithm.

Record source commit, configuration, tool versions, fixture/bitstream hashes,
command, explicit PASS/FAIL and report location. Generated reports stay outside
tracked source; commit concise reviewed summaries and reproducible scripts.

Review contracts/algorithm first, resources and AES next, arithmetic in small
chunks, then dedicated RSA and softcore independently. Review integrated board
evidence last. Each MR explains behavior/dependencies, an example, reading order,
tests actually run and limitations. Never merge automatically. Legacy AES is a
reference, not a dependency on the closed plumbing/store stack.
