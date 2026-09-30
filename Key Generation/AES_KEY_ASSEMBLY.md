# AES-128 and AES-256 key assembly

AI-authored RTL and tests, pending Aaron's review. `aes_key_assembler.v` implements
key assembly from supplied RNG words. It implements no cipher, round expansion,
RSA, entropy source, protected store, object handles, or complete TPM command.
Both AES sizes are user-confirmed scope; detailed interfaces remain team proposals.

## Actual worker boundary

All transfers occur on rising `clock` edges in one clock domain. `reset_n` is
asynchronously asserted low; the integration must synchronize its release.

| Signals | Direction | Contract |
| --- | --- | --- |
| `work_valid`, `work_ready` | in, out | Accept once when both high. Sample low valid after reset to arm; a held high cannot retrigger. A low during busy can rearm the next request. |
| `work_id[31:0]`, `work_key_bits[11:0]`, `work_public_exponent[31:0]` | in | Capture at acceptance. Bits must be 128 or 256; exponent must be zero. Unknown ID/exponent and invalid/unknown size fail without accepting RNG. |
| `work_cancel`, `busy` | in, out | Level cancellation of current work; busy includes held terminal status. No separate cancel acknowledgment: terminal status acknowledges cleanup. |
| `rng_data[31:0]`, `rng_valid`, `rng_error`, `rng_ready` | in, in, in, out | Consume valid/ready beats outside reset/error/cancel. Exactly four words for AES-128 or eight for AES-256. Ready stays low during output and terminal phases. |
| `out_valid`, `out_ready`, `out_word[31:0]` | out, in, out | Protected internal stream; stable word under backpressure. Invalid output payload is zero. Never route raw keys to CPU/debug/CRB response. |
| `out_id[31:0]`, `out_component[3:0]`, `out_index[6:0]`, `out_bits[11:0]`, `out_last` | out | Captured ID, component 1, zero-based word index, actual size, last word. Metadata is zero while invalid. |
| `done_valid`, `done_ready`, `done_id[31:0]`, `done_status[7:0]` | out, in, out, out | Held immutable terminal until acknowledgment or reset. Unknown request ID sanitizes terminal ID to zero. |

Status codes: 0 = successful stream handoff; 1 = unsupported size;
2 = RNG failure; 3 = cancellation; 4 = bad metadata. These are internal worker
codes, not TPM response codes. Success is published only after the last output
beat is accepted and local material is cleared. It does **not** establish storage
commit or a TPM object. Late faults/cancel cannot rewrite published status;
subsystem health/recovery must be tracked separately upstream.

## Order, clearing, and RNG ownership

First accepted word is the most significant word of the actual key. AES-256 uses
internal bits 255:224 first; AES-128 uses 127:96 first, leaving upper 128 bits zero.
Output preserves this order. Byte interpretation is highest byte first within
each word (for example, word `0x01234567` represents bytes 01, 23, 45, 67);
there is no separate byte serializer in this worker. Ordering needs team approval.

Equal consecutive word values are legal. The RNG owner must provide suitable
cryptographic output, seeding/readiness and health assurance; assembly tests do
not prove entropy quality. RNG must hold data/valid while stalled and advance only
on acceptance. A CDC adapter/arbitration belongs outside this shared-clock worker.

Each accepted output word is cleared locally. Completion, failure, cancellation,
and reset clear the whole buffer. Reset suppresses all transfers and terminal
validity, and requires a low-valid sample before new acceptance. While active,
RNG error dominates cancellation, which dominates input/output transfer; both
suppress output combinationally before the edge. Simulation also fails closed on
unknown fault/cancel or accepted data. This is not a physical fault, zeroization
timing, side-channel, synthesis, or hardware assurance result.

An abort after some output words have been accepted cannot retract those words.
A protected sink must stage a transaction, roll back on any abort/reset, clear its
copies, and acknowledge committed storage before the controller reports TPM
success. Sink rollback, reset reconciliation, timeout, health and actual storage
are unimplemented. Do not connect worker success directly to backend object success.

## Integration and validation

The dispatch adapter permits AES-128 and AES-256 descriptors only in externally
enabled mode. Its default remains unavailable, and `TPM_TOP` still disables the
backend. The worker is deliberately not connected to a fake RNG/store/TPM result.
Future backend must latch descriptor ID/size, arbitrate the RNG, translate worker
status, and require protected-store commit/cleanup before its terminal response.

Run `& './Key Generation/Testbenches/run_questa.ps1'` from the repo in PowerShell.
Three self-checking benches cover inherited plumbing, unavailable AES128/256,
and assembly counts/order/gaps/stalls, equal words, latched inputs, held valid,
size alternation, invalid metadata, errors/cancel/reset across phases and clearing.
Only deterministic synthetic words are used; no payload values are printed and
waveforms are discarded with `-wlf NUL`. Generated libraries/logs stay under
class `AI/tmp`. Independent AI tester probes are additional simulation evidence.
No statistical RNG, AES cipher, synthesis/timing, FPGA, secure-store or end-to-end
TPM validation is claimed. Review this PR after its two parent drafts; no merge
or interface approval is implied by publication.
