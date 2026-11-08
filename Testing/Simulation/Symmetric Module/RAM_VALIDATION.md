# RAM-backed symmetric validation

Validated November 8, 2026 against parent `symmetric-module` commit
`4595a7b0546fdaebd8fb86dcae3d4615da9d0b6b`.

## Questa 2024.3 Intel Starter

Synthesizable files compiled separately with `vlog -vlog01compat`; testbench
files compiled with `vlog -sv`. Real, unchanged AES/CFB RTL was used. Python
`cryptography` independently generated expected encryption/decryption bytes;
final IVs follow the TPM reference's final-ciphertext/zero-padding rule.

| Payload capacity | Address width | Independent vectors | Total job/abort cases |
|---:|---:|---:|---:|
| 1 | 5 | 18 | 34 |
| 17 | 7 | 178 | 201 |
| 31 | 8 | 318 | 341 |
| 1024 | 12 | 358 | 381 |
| 2049 | 14 | 358 | 381 |
| 4096 | 12 | 344 | 367 |
| **Total** | | **1574** | **1705** |

All passed. Coverage includes every partial-block byte length, multi-block
and exact-capacity encrypt/decrypt, zero length, `capacity+1` and `0xffffffff`
rejection, non-power-of-two capacities, a payload filling the entire RAM address
space, exact-end and adjacent ranges, in-place and disjoint regions in both
address orders, invalid overlaps in both directions, base-plus-length overflow,
descriptor mutation after acceptance, held-start suppression and metadata retention.
The driver checks all RAM contents after jobs, including untouched regions.

The RAM model alternates un-stalled/short-latency service with variable response
latencies and request backpressure. Protocol assertions check stable stalled
requests, one outstanding request and response-qualified completion. Directed
failures cover read/write errors in first/later chunks, partial acknowledged
writes, worker failure, and reuse. Reset covers a stalled request, outstanding
read, AES execution, outstanding write and valid response, followed each time
by a successful new job. Controller and RAM responder are jointly flushed.

Existing unchanged suites also passed: CFB worker 7, EncryptDecrypt2 controller
9, session controller 12, KDFa 6, symmetric top 14 (**48 cases**), including the
standalone visual wrapper compile performed by the top runner. The separate
software-HMAC professor demo was not rerun; none of its sources were changed.

## Quartus Prime Lite 24.1std analysis and synthesis

The committed `synthesize_symmetric_ram.tcl` runner completed for Cyclone V
5CSEMA5F31C6 with virtual top-level pins and Verilog-2001 input mode:

| Capacity / address width | Estimated ALMs | Registers | Block RAM bits | Errors |
|---|---:|---:|---:|---:|
| 1024 / 12 | 3078 | 4139 | 0 | 0 |
| 2049 / 14 | 3080 | 4145 | 0 | 0 |

These totals include the AES worker. Both runs reported 11 warnings: inherited
AES key-memory integer narrowing and constant status-output bits (plus their
summary). No new controller narrowing warnings remain. Zero internal block RAM
is expected because payload storage belongs to the external adapter. ALMs are
pre-fit estimates, not final placed resources or incremental controller cost.

## Limits

No fitter, timing closure, bitstream, board test, gate-level simulation, formal
proof, physical-security assessment or production RAM/arbitration validation was
performed. No end-to-end TPM command was demonstrated. The execution-engine
adapter and its incomplete wait/dispatch logic, packet sizing/capability reporting,
authorization, real HMAC and session lifecycle remain outside this change.
The untagged RAM protocol relies on joint reset/flush; this suite does not make
controller-only reset with stale adapter responses safe.

Reproduce with the commands in [README.md](README.md). Keep generated evidence
in a scratch output directory; vectors, libraries and reports are not checked in.
