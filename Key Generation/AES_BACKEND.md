# AES backend controller

AI-authored implementation and tests, pending human review. `keygen_aes_backend.v`
instantiates the actual AES128/256 assembler and implements the adapter's external
request/cancel/result boundary. External RNG and protected-store contracts below
are proposals needing their owners' approval. No real RNG/store is supplied and
production `TPM_TOP`/default adapter remain disabled. RSA is rejected, never routed
to AES. Review after outline, plumbing and assembly drafts.

## Actual ports and protocol

One shared `clock`; asynchronous low `reset_n`, synchronized release required
outside this module. Transfers occur on rising edges. No request queue.

| Port group (direction at backend) | Width | Meaning |
| --- | --- | --- |
| `req_valid` in, `req_ready` out | 1 each | One accepted request; sample low valid after reset/between requests to rearm. Ready requires reconciled available store and no sticky health fault. |
| `req_id`, `req_context`, `req_destination`, `req_exponent` in | 32 each | Capture at acceptance. Upstream owns authorized, pinned context/destination and token uniqueness/recovery. AES exponent must be zero; unknown descriptor fields reject. |
| `req_alg`, `req_mode`, `req_bits` in | 2, 2, 12 | Only AES alg1, fresh-child mode0, bits128/256. No primary derivation or RSA. |
| `cancel_valid` in, `cancel_ready` out, `cancel_id` in | 1, 1, 32 | Matching cancellation accepted before store finish acceptance. Wrong ID/unknown active control is a protocol fault. After finish acceptance, ready stays low: cancellation too late. |
| `rsp_valid` out, `rsp_ready` in | 1 each | Hold immutable result until acknowledgment except reset. |
| `rsp_id`, `rsp_code`, `rsp_object` out; `rsp_fail` out | 32 each, 1 | Captured ID; code0 on success, 0x143 unsupported descriptor, 0x101 transaction failure. Object is known nonzero store reference on success, zero on failure. Unknown request ID sanitizes response ID to zero. Codes are a proposed TPM mapping. |
| `busy`, `health_fault`, `health_status` out | 1, 1, 8 | Busy through cleanup/response. Sticky independent health: bit0 RNG/worker RNG failure; bit1 store_error; bit2 protocol/unexpected worker/finalization acknowledgment failure. Other bits zero. Reset clears health; recovery must precede store availability. |
| `rng_data`, `rng_valid`, `rng_error` in; `rng_ready` out | 32, 1, 1, 1 | Teammate cryptographic RNG stream, accepted only by active selected assembler. Quality/seeding/health/CDC/arbitration remain RNG-owner obligations. |
| `store_available`, `store_error` in | 1 each | Availability gates new admission after reconciliation; may go low during a healthy busy transaction. Active failure uses store_error/final status. Error/unknown error latches health even outside a transaction. |
| `store_begin_valid` out, `store_begin_ready` in | 1 each | Reserve/open one staging transaction before worker launch. Stable under backpressure except abort/reset/fault. |
| `store_begin_id`, `store_begin_context`, `store_begin_destination` out | 32 each | Captured token/context/destination. |
| `store_begin_alg`, `store_begin_key_bits` out | 2, 12 | AES1 and actual128/256-bit manifest. |
| `store_data_valid` out, `store_data_ready` in | 1 each | Protected staged stream, not CPU/debug/CRB plaintext. Stable under backpressure; fault/cancel/reset suppresses transfer and zeroes payload. |
| `store_data_id`, `store_data_word` out | 32 each | Captured ID and secret word. |
| `store_data_component`, `store_data_index`, `store_data_bits`, `store_data_last` out | 4, 7, 12, 1 | AES component1, zero-based most-significant-word-first index, actual bits, last beat. Invalid data/metadata zero. Four/eight words; see AES_KEY_ASSEMBLY.md for byte interpretation. |
| `store_finish_valid` out, `store_finish_ready` in | 1 each | Finalize transaction after worker local clearing. Held until accepted. Cancellation/fault can convert pending commit into abort. |
| `store_finish_id`, `store_finish_abort` out | 32, 1 | Same token; 1 rollback, 0 commit. No repeated finish after acceptance. |
| `store_rsp_valid` in, `store_rsp_ready` out | 1 each | Finalization acknowledgment only after accepted finish. Unsolicited responses are drained and quarantine health; cannot acknowledge a later finish. |
| `store_rsp_id`, `store_rsp_object`, `store_rsp_status` in | 32, 32, 8 | Matching token, known nonzero object for commit / zero for abort; status0 means definite requested action completed. Other/unknown status, wrong token or invalid object is failure with quarantine, not proof of rollback. |

## Transaction and failure behavior

Accepted request -> store begin -> worker launch -> 4/8 RNG words -> protected
store stream -> worker cleared terminal -> store commit -> matching successful
commit acknowledgment -> backend success. The store must independently validate
the full manifest, stage words without visibility, and provide definite outcomes.
Worker success alone never reports backend success.

Before store begin acceptance, cancellation/fault reports failure without waiting
for nonexistent peer cleanup. After begin but before worker launch, request abort
directly. With worker active, suppress transfers, wait for worker clearing, then
request rollback. Normal failure/cancellation waits for matching successful abort
acknowledgment before terminal failure. This clears only the modeled sink in tests;
actual protected-store zeroization is still an integration obligation.

Once finish is accepted, the requested storage decision cannot be withdrawn.
Matching cancellation is too late and not acknowledged. A pre-publication fault
still suppresses successful backend status and quarantines new work; a durable
object may already exist. Failed/malformed/mismatched finalization acknowledgments
also publish failure and quarantine: they provide **no cleanup/rollback proof**.
Recovery must reconcile storage independently. A published result never changes
under late faults; sticky health prevents new backend requests. Upstream execution
must observe health independently and block/report unavailable commands, rather
than indefinitely queueing another request at a quarantined backend.

RNG/store/protocol fault dominates cancel and normal transfers. No timeout is
fabricated: a peer that never accepts begin/finalize or never acknowledges cleanup
can hold busy indefinitely. Coordinated reset/recovery is required. Reset clears
worker/control state and validity, not durable objects; the store must clear
uncommitted staging and reconcile any accepted commit before `store_available=1`.
Token ownership must exclude stale acknowledgments across reset. CDC, reset release,
storage durability, physical clearing and side-channel assurance are unverified.

## Validation and scope

`Testbenches/run_questa.ps1` runs five self-checking benches in Questa: three parent
regressions plus controller with test-only staged sink and adapter->controller->
actual assembler integration. Tests cover both sizes, manifest/order/accepted-word
counts, captured metadata, backpressure, no success before commit acknowledgment,
held request/result, cancel before begin/launch/collection/output/commit, too-late
cancel, RNG/store faults, failed/wrong-ID acknowledgment, potentially durable object
after postcommit fault, health quarantine, reset and recovery availability.

Synthetic RNG words and staged-store models exist only in benches. Models test
protocol behavior, not real entropy/storage security. No secret payload logging;
waveforms discarded with `-wlf NUL`; logs/libraries stay in class `AI/tmp`.
Independent AI tester separately reviews/probes; Aaron remains the human reviewer.
No synthesis/timing/FPGA, full execution/management/TPM integration, RSA/cipher,
cryptographic compliance or secure-store certification is claimed. Canonical
specification and review queue stay outside repository in class `AI/`.
