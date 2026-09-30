# Execution-to-keygen plumbing (stacked draft)

Depends on [outline PR #1](https://github.com/VTECEMDEF25-07/F25-07_Open-Source_Hardware_TPM/pull/1), branch `aaron/key-generation`, commit `37ce16f514bf282c5cc413316752a6e37f7f1e2d`. This child targets that branch, not main. Neither PR is approved or merged. Aaron reviews the outline first, then this implementation. Retarget/rebase only after parent approval/merge, in later authorized work.

## Implemented boundary

The inherited Execution Engine could abandon a multi-cycle operation, lose/truncate its error code, and advance before prerequisite completion. It now captures a command, holds validation/execution, launches once, and retains a full-width terminal result until acknowledgment. A connected `keygen_dispatch_adapter` provides a declared backend request/cancel/result boundary. **No AES/RSA, RNG, protected storage or TPM object creation is implemented.**

`execution_engine` instantiates exactly one keygen orchestration path in `keygen_dispatch_adapter.v`. The unrelated `execution_engine_fsm` in `input_output_signal_structure.v` remains unconnected/unmodified; its unreachable state and lost errors are not claimed fixed. Future keygen code connects to the ports below instead of that old enable-only dispatcher.

Default `KEYGEN_EXTERNAL_BACKEND=0` returns `0x00000143` (unsupported), never backend success. An explicitly supplied external backend requires `KEYGEN_EXTERNAL_BACKEND=1`; testbench instances use isolated mocks. The existing top keeps descriptor/session approval low, supplies no backend, and returns definite authorization failure for its unavailable authorizer. It does not enable this path. Legacy management still receives unvalidated command events; full safe top-level integration is a separate gate.

## Actual new Execution Engine ports

Directions are relative to `execution_engine`. All signals share its `clock` and active-low `reset_n` (async assertion; synchronized release is the integrator's responsibility). Existing command inputs remain named as before. All command/session metadata and new descriptor/proof fields are captured on `command_accept` at a rising edge. Completion/policy inputs remain live and must belong to the active transaction.

| Ports | Direction / width | Contract |
| --- | --- | --- |
| `command_accept`, `command_busy` | O1 each | Acceptance event for `command_ready` while idle/rearmed; busy through validation/execution/held response. No command queue. |
| `response_ready` | I1 | Consume `response_valid`, `response_code[31:0]`, `response_length[15:0]`, `keygen_object[31:0]`. Result retained until accepted. |
| `command_cancel` | I1 | Cancel active prerequisite wait or request backend cancellation. Pulse is latched by adapter after backend request acceptance. Ignored once command terminal response is published. |
| `keygen_descriptor_valid`, `keygen_session_validated` | I1 each | Trusted upstream proof for this exact command/token/context: full template/parent/hierarchy validation and session processing. No validator is implemented here. Known one required; top binds both zero. |
| `keygen_id`, `keygen_context`, `keygen_destination`, `keygen_exponent` | I32 each | Token, immutable validated context reference, reserved protected destination, public exponent. Context/destination remain pinned through response retirement. |
| `keygen_alg`, `keygen_bits`, `keygen_mode` | I2, I12, I2 | Local proposed capability gate: alg1/AES256/e0 or alg2/RSA2048/e65537; mode0/fresh-random only. Not final team scope/format. |
| `keygen_busy`, `keygen_object` | O1, O32 | Adapter activity and terminal protected-object reference. Object is zero on failure; no raw private-key port. Overall command busy also includes prerequisite/response stages. |
| `kg_req_valid`, `kg_req_ready` | O1, I1 | One backend request transfer; stable descriptor while stalled. |
| `kg_req_id`, `kg_req_context`, `kg_req_destination`, `kg_req_exponent` | O32 each | Captured backend descriptor fields |
| `kg_req_alg`, `kg_req_bits`, `kg_req_mode` | O2, O12, O2 | Captured algorithm/size/mode |
| `kg_cancel_valid`, `kg_cancel_ready`, `kg_cancel_id` | O1, I1, O32 | Matching active token; pending cancellation persists until accepted or backend terminal result arrives. |
| `kg_rsp_valid`, `kg_rsp_ready` | I1, O1 | One stable backend terminal result/cleanup acknowledgment; accepted only after backend request acceptance. |
| `kg_rsp_id`, `kg_rsp_code`, `kg_rsp_object` | I32 each | Matching token, full-width result code, protected-object reference on success |
| `kg_rsp_fail` | I1 | Explicit failure. Failure with code zero maps to `0x101`; known zero plus matching ID and known zero code required for success. |

The adapter's source declaration lists its complete internal interface: `start`, descriptor fields, `cancel`, `busy`, held `terminal_valid/ready/code/object`, and corresponding `req_*`, `cancel_*`, `rsp_*` ports. No executable dummy `keygen_top` is added. A future module receives `kg_req_*`, drives ready and result fields, and accepts `kg_cancel_*`; it must implement the contract before external mode is enabled.

## Sequencing and failure rules

1. Sample low `command_ready` after reset and between commands to rearm. Accept one command while idle; held high cannot repeat. Upstream observes `command_accept`; command data may change after that event without retargeting the accepted command.
2. Reject malformed tag/size/unknown code/high command-code bits. Only exact `TPM_CC_Create=0x153` with both captured trusted proof bits may use the keygen path; CreatePrimary/CreateLoaded are unsupported. Fresh child generation must not substitute for primary derivation.
3. For creation, trusted descriptor proof covers the inherited broken handle/session parser; it does **not** bypass live `auth_done` plus known success/zero code, decrypt completion, or unmarshal completion. Proof bits must refer to the same accepted request; they are not a substitute for an implemented authorizer/parser. Failure suppresses launch; simultaneous preprocessing fail/success goes to failure. No fixed validation latency.
4. No-session commands whose captured `auth_necessary=0` can skip authorization. Legacy session-tagged commands outside the explicitly validated creation boundary are rejected with nonzero error, including password-session requests, until the parser is separately repaired. This deliberately removes unsafe purported session support; it does not implement password/HMAC/policy processing.
5. Adapter latches descriptor again on start, holds backend request through backpressure, waits any backend latency, and accepts one matching terminal result. No duplicate launch from held internal start. Legacy non-keygen `command_start` is a one-cycle launch pulse; execution now holds until `command_done`. Generic legacy command logic is still external/incomplete.
6. Full 32-bit code is captured only at terminal execution. Fail/nonzero code or wrong token cannot produce success; simultaneous **accepted** cancel and result success maps to failure. Terminal fields are immutable once offered, including while `response_ready=0`. Backend terminal acknowledgment is separate from final command-response acknowledgment.
7. Cancel before backend acceptance suppresses request on that edge and completes locally with `0x101`, no backend side effect. After acceptance, pulse cancel becomes pending until backend cancel acceptance. Do not report cleanup early: wait for backend terminal acknowledgment. If terminal result arrives before cancel is accepted (e.g. commit already irrevocable), that result wins and unaccepted cancellation retires. Thus a cancel request is not a promise that no object was committed. Backend must return error after accepted cancel and acknowledge only after cleanup/rollback.
8. Reset suppresses transfers, clears descriptor/object/control state, and requires low enable before rearming; it invalidates an unacknowledged response. External backend must share reset and invalidate/clear pending work/status; storage must reconcile accepted commits before reuse. Tokens must not be reused while stale traffic may remain. No crypto material is held or erased by this adapter; real secret clearing belongs to the future backend/store. No timeouts/reseed/health recovery is implemented, so an unresponsive backend waits indefinitely rather than fabricating success.
9. `initialized` can latch only after validated successful completed Startup, never a rejected command. Authorization hierarchy is exposed only with the same known-success predicate used for authorization progression. These are bounded control corrections, not completed TPM lifecycle semantics.

## Prerequisite corrections versus remaining gates

Corrected here: accepted-command snapshot/rearm; EXECUTE hold; held terminal acknowledgment; full-width execution error; delayed auth/decrypt/unmarshal waits; fail priority; session-free no-auth progression; malformed/rejected Startup initialization; nonzero rejection for untrusted legacy sessions; matching-token keygen dispatch and default unsupported backend. Header high-bit rejection and failure-mode diagnostic exclusion conjunction are also fixed.

Still blocked for production: implement real parsing/authorization and session responses; approve the descriptor/context allocator contract; management autonomous transaction timing/reset/result priority/validated side effects; replace remaining top constants/direct parameter authorization and coordinate I/O acceptance/response backpressure; provide secure RNG/arbitration/CDC and key storage/commit/health; select compliant RSA procedure and primary derivation; marshal dynamic object responses. The top still has a ten-byte response and demonstrator lifecycle wiring. This PR does not implement complete or secure TPM Create/CreatePrimary operations.

Outline deviations are deliberate: this PR implements only descriptor and terminal-object control, not the proposed store/RNG/worker component stream. Backend result code is already full-width, rather than the outline's unassigned internal 8-bit status; a future backend must map internal reasons here. Health/commit/storage interfaces stay inside a future backend. Local capability encodings and trusted proof gates are review proposals. Earlier [README.md](README.md) and [REVIEW.md](REVIEW.md) remain the parent outline snapshot.

Hardware: Aaron confirms **Terasic DE25-Standard Rev.D**, underside marking ending **D1** (2026-09-30, not independently inspected). Actual clocks, resources and tool project remain open. No existing DE1-SoC wrapper/pin/clock port is changed here.

## Tests and review

Run from repository root in PowerShell:

```powershell
& './Key Generation/Testbenches/run_questa.ps1'
# Optional: -QuestaBin 'path/to/questa/win64'
```

The example relative path assumes repository root; elsewhere invoke the runner by its absolute path. It creates a unique work library/logs under class `AI/tmp/keygen-plumbing/`, restores TEMP/TMP/location, and fails on compiler/simulator/log fatal errors. Unit sources compile and both self-checking simulations pass with Questa Intel Starter 2024.3: delayed prerequisites, snapshot mutation, backend backpressure/prolonged busy, held enable/repeated command, full-width error persistence, mocked success/object retention, cancel before/after acceptance and simultaneous result, reset/no replay, unsupported primary/unknown proof, malformed/spoofed Startup, legacy session rejection, and default unavailable backend. A simulated success is isolated mock behavior, not an implemented key generator.

Separate independent AI tester probes cover wrong token, explicit fail with zero code, unknown failure signal, immutable result, default-disabled execution and external-mode snapshot/cancel. Tester reproduced the durable runner and reviewed final source/diff. Findings corrected: pending cancel pulse loss, unknown response failure qualifying as success, reset-held command replay, inconsistent authorization hierarchy success, and the default-backend bench's low-start reset precondition.

Existing top and eight inherited benches compile with zero errors/four existing numeric-literal warnings. Top zero-time elaboration has zero errors/19 inherited connection/width warnings; it is only a connection smoke check. Legacy benches are not passing functional regressions: omitted new ports require migration and manual stimuli need assertions. No synthesis, static timing, CDC proof, hardware, TPM interoperability or cryptographic validation is claimed.

AI-authored: Codex wrote RTL, tests and documentation at Aaron's request; a separate AI tester reviewed and reproduced control tests. Aaron reviews before merge. Canonical outside-repo memory `AI/KEY_GENERATION_SPEC.md` traces this as **IMPL-01**, implementing parts of REQ-03/04 and IF-07 control only; DEC-01 RNG assumption and all algorithm/security proposals remain unimplemented.
