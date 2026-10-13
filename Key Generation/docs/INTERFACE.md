# Portable keygen interface v1

Implements the approved October 13 plan. Direction is the last suffix
(`reset_n_i`, `request_valid_i`). Transfers occur on rising `clock_i` edges
when valid and ready are high. Producers hold payloads stable while stalled.

## Request and generation

| Ports | Meaning |
|---|---|
| `request_valid_i`, `request_ready_o` | Accept one operation per handshake. |
| `request_profile_i[1:0]` | 0 AES128; 1 AES256; 2 RSA2048; 3 invalid. |
| `request_id_i[31:0]` | Captured once and echoed with result/status. |
| `peers_ready_i` | Coordinator prepared isolated source and empty receiver. |
| `generation_valid_i`, `generation_ready_o`, `generation_data_i[31:0]` | Ordered words; count accepted transfers only. |
| `generation_failed_i` | Sticky operation failure until reset/status acknowledgment. |

Ready is low during scrub, execution, result and terminal status. An accepted
producer withdraws valid or presents a new request. Holding valid into the next
idle state legitimately requests a second job. No queue or seed register exists.
The coordinator establishes the fresh/repeatable stream before requesting work.
Peers-ready stays high until ownership acceptance; losing it is a peer fault.
It cannot revoke ownership afterward. Generation failure wins over a coincident
data or ownership handshake while the result is still unowned.

## Protected result

| Ports | Meaning |
|---|---|
| `result_valid_o`, `result_ready_i` | Transfer a word. |
| `result_data_o[31:0]` | Most significant word first; bytes MSB first. |
| `result_component_o[2:0]` | 1 AES key; 2 modulus n; 3 exponent e; 4 p; 5 q. |
| `result_index_o[6:0]` | Zero-based word index within component. |
| `result_component_last_o`, `result_last_o` | Last component/whole-result word. |
| `result_id_o[31:0]` | Accepted operation ID. |
| `ownership_valid_i`, `ownership_ready_o`, `ownership_accept_i` | Separate whole-result decision; accept=1 transfers ownership, 0 rejects. |
| `result_discard_o` | Invalidate unaccepted staged material, held during fault scrub. |

AES128 emits4words, AES256 emits8. RSA emits n(64), e(1), p(32), q(32),
in that order; each component restarts index0. e is 0x00010001. No padding.
d is internally validated, not exported. Ownership-ready is asserted after all
words transfer; an early ownership-valid must wait for ready. Stalled result
data/index/flags are stable. Accepting words alone does not transfer ownership.

After acceptance the receiver owns the result even if reset interrupts cleanup.
The coordinator reconciles that case. Before acceptance, reset discards staged
material through shared subsystem reset; ordinary faults assert result-discard.
The receiver must honor discard before declaring readiness for another operation.

## Status, reset and clearing

`status_valid_o`, `status_ready_i`, `status_code_o[3:0]`, `status_id_o[31:0]`
form a held terminal handshake. Codes:0success,1invalid profile,2generation
failure,3search exhausted,4arithmetic/key check,5receiver rejection,6CPU trap,
7internal watchdog,8peer unavailable. Preserve the first fault. Reset outranks
all faults. No success before ownership acceptance AND local secret cleanup.

Reset asserts asynchronously; release passes a two-flop synchronizer in the
core clock domain. Suppress all valid/ready handshakes during reset. Clear secret
registers; sweep memory sequentially before admission. Normal success/fault uses
the same sweep. Public terminal metadata survives cleanup. Reset emits no
cancelled terminal. Invalid profiles return error after cleanup without words.

External stalls have no core timeout. Host tests bound jobs to180seconds and
recover with reset. Internal watchdog bounds derive from operation dimensions.
Debug status must not expose secret storage.

## AES128 example

Accept ID42/profile0. Accept 01234567,89ABCDEF,10203040,50607080. Emit the same
four words with component1/index0..3 and last flags only on index3. Wait for whole
ownership acceptance, clear all local slots, then hold success/ID42 until status
acknowledgment. Source gaps and result stalls cannot change this result.

## Resource and build contracts

Default resources are generic; `KEYGEN_ALTERA` selects real Altera macros. Xilinx
is deferred. Unsigned32x32 multiplication has two enabled-cycle pipeline latency;
enable freezes data and valid together. Scratch RAM has one-cycle synchronous
read and explicit forwarding for new-data same-address write/read. Reset does
not clear RAM contents: its owner sweeps all slots before reuse.

Dedicated and softcore controllers are separate builds sharing little-endian
32-bit limb arithmetic. Reverse word ordering only at the external boundary.
The softcore normal MMIO interface has no secret-operand readback window.
