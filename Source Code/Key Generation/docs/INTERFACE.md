<!--
Filename: INTERFACE.md
Authors: Aaron Grossman; Project contributors; see Git history.
Date: 2026-11-08
General Description: Defines the public keygen handshakes, lifecycle and cleanup contracts.
AI Disclosure: Codex assisted with consolidation; see docs/AI_DISCLOSURE.md in the keygen source folder.
-->

# Portable keygen interface v1

The integration boundary is `rtl/common/keygen_core.v`. One request captures the profile and operation ID; later input changes cannot change the accepted job. Direction is the last suffix
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

AES128 emits 4 words, AES256 emits 8. RSA emits n(64), e(1), p(32), q(32),
in that order; each component restarts index 0. e is 0x00010001. No padding.
d is internally validated, not exported. Ownership-ready is asserted after all
words transfer; an early ownership-valid must wait for ready. Stalled result
data/index/flags are stable. Accepting words alone does not transfer ownership.

After acceptance the receiver owns the result even if reset interrupts cleanup.
The coordinator reconciles that case. Before acceptance, reset discards staged
material through shared subsystem reset; ordinary faults assert result-discard.
The receiver must honor discard before declaring readiness for another operation.

## Status, reset and clearing

`status_valid_o`, `status_ready_i`, `status_code_o[3:0]`, `status_id_o[31:0]`
form a held terminal handshake. Codes: 0 success, 1 invalid profile, 2 generation failure, 3 search exhausted, 4 arithmetic/key check, 5 receiver rejection, 6 retained legacy/internal fault value, 7 internal watchdog, 8 peer unavailable. The dedicated implementation contains no CPU. Preserve the first fault. Reset outranks
all faults. No success before ownership acceptance AND local secret cleanup.

Reset asserts asynchronously; release passes a two-flop synchronizer in the
core clock domain. Suppress all valid/ready handshakes during reset. Clear secret
registers; sweep memory sequentially before admission. Normal success/fault uses
the same sweep. Public terminal metadata survives cleanup. Reset emits no
cancelled terminal. Invalid profiles return error after cleanup without words.

External stalls have no core timeout. Host tests bound jobs to180 seconds and
recover with reset. Internal watchdog bounds derive from operation dimensions.
Debug status must not expose secret storage.

## AES128 example

Accept ID 42/profile 0. Accept 01234567,89ABCDEF,10203040,50607080. Emit the same
four words with component1/index 0..3 and last flags only on index3. Wait for whole
ownership acceptance, clear all local slots, then hold success/ID42 until status
acknowledgment. Source gaps and result stalls cannot change this result.

## Resource and build contracts

Default resources are generic; `KEYGEN_ALTERA` selects real Altera macros. Xilinx
is deferred. Unsigned 32x32 multiplication has two enabled-cycle pipeline latency;
enable freezes data and valid together. Scratch RAM has one-cycle synchronous
read and explicit forwarding for new-data same-address write/read. Reset does
not clear RAM contents: its owner sweeps all slots before reuse.

The dedicated controller uses little-endian 32-bit limb arithmetic.
Reverse word ordering only at the external boundary.

## Worker lifecycle and reset topology

AES uses eight 32-bit slots and the states SCRUB, IDLE, COLLECT, EMIT, OWNERSHIP and STATUS. AES-128 uses four slots; AES-256 uses eight. Both sizes preserve source ordering and clear all eight slots before terminal success. There is no cancel or store-commit input. Source/peer faults before ownership abort the job; faults after accepted ownership cannot revoke the receiver's key.

For RSA the core captures the request, runs generation/pair validation, emits n/e/p/q, waits for ownership, resets/scrubs the engine and then holds terminal status. The engine cleanup request is registered in `engine_reset_reg`, asserting on RESET_ENGINE entry and releasing on SCRUB entry. The pair multiplier uses registered `multiplier_clear_reg`; reset control must not be replaced by a combinational binary-state decode. Lifecycle tests exercise between-edge state-decode transients.

Reset invalidates transfers immediately; release is synchronized in the core clock domain. Engine reset reaches the controller, services, arithmetic and resource wrappers. Owners sweep RAM and refresh its synchronous output latch before reuse; a RAM primitive's reset alone does not erase its contents. Integration holds arithmetic/RAM clock enables high, while wrappers retain their enable/stall contracts. The multiplier's asynchronous clear follows its supplied reset; synchronous clear remains zero.

The math allocation is 4,096 words (16 KiB), plus the pair checker's 512 words (2 KiB). Math reset scrub/read-latch cleanup takes 4,098 rising edges; pair cleanup takes 514. Do not expose either private memory port through external transport. See the [RSA implementation](RSA_ALGORITHM.md#implementation-reference) for layouts, pair status and cleanup sequencing.

No demo reset, fan control or board timing/CDC signoff is implied by these portable-core contracts. Tests and their scope are listed in the [simulation README](../../../Testing/Simulation/Key%20Generation/README.md).
