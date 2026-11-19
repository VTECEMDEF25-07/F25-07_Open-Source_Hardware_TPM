# Protected internal RSA2048 consumer

Work in progress, stacked on PR57 `2f4e29a1a058fd7c30f715701f82ac7cb75b8015`.
AES owns the shared reservation implementation. This adapter uses that contract
without changes to slot memory, the engine or the board tops at this stage.
Adapter-only validation is not composed acceptance or review readiness.

## Format and arithmetic

The published slot remains 129 MSB-first 32-bit words: n[0..63], e[64],
p[65..96], q[97..128]. Public operations read only n/e. Private operations
copy n/e/p/q into local registers after successful acquisition, then reuse
`keygen_pair_check` to recompute n and canonical d modulo lcm(p-1,q-1).
This repeats the checked keygen math on a separate service instance; it does
not race keygen RAM or share its multiplier. The generated slot remains intact.

`PROTECTED_D_HANDOFF=1` adds an internal handoff AFTER the pair service's
existing bounds, distance, product, GCD/LCM, exact-division and d-bound checks.
The normal keygen instance keeps its default zero and has no d publication.
The protected service holds its d bus until accepted, clears that copy, reads
n, and performs the existing full 512-word RAM/multiplier/register scrub before
its ordinary result. The adapter waits for that scrubbed successful result,
requires recomputed n to match the reserved n, and only then launches RSA.
No known fixture d is present in synthesizable logic.

The team `rsa_controller`, `rsa_modexp` and `montgomery_mult` are imported from
`3afc1f6648c090e17b9d08c8c4f5d50d9192fe43`. Their current asymmetric-module
branch blobs were independently read through GitHub and match all three local
blobs recorded in `team_source.json`. Arithmetic remains provisional and has
large carry chains. Constant-schedule exponentiation is not a side-channel
qualification. No padding scheme or TPM command implementation is implied.

## Ownership and transfer

An enabled, idle adapter accepts one internal request ID, allow fixture and
operation (0 public, 1 private). Other operation values and denied fixtures fail
before acquisition or arithmetic. It requests type2/129 words through the
AES-owned acquire/reply handshake and begins key reads only after code0.
The containing engine must arbitrate the single consumer and its private read
port. Shared reset is mandatory. No private buses may reach host scratch.

The 64-word representative stream requires last exactly on word63. The modulus
must be full width and odd, e must be65537, and representative must be below n.
The captured request cannot be overwritten while active. The adapter observes
the core's done/error pulses explicitly, never busy deassertion. It captures a
successful result privately, clears operand/key registers, asserts a registered
local child reset, and waits for the derivation RAM's complete reset scrub.
Only then is the 64-word result stream visible, stable under backpressure.
Transferred result words are shifted out and cleared. A held completion follows
the last result word; error completions have no result stream.

The reservation extends through computation, cleanup, result transfer and held
terminal ownership. Completion acknowledgment relinquishes it one cycle later;
this never destroys the key slot. Destroy while reserved is rejected by the
shared slot, not queued. Explicit destruction after relinquish sweeps all129
words before reuse. Reset masks every transfer immediately and starts full
child/slot erasure, with no stale completion or recovery.

`WAIT_LIMIT` bounds work/input/output waiting, including arithmetic and cleanup.
Acquisition cannot be abandoned after acceptance: the slot's one-cycle, held
reply is mandatory. On timeout the adapter resets/scrubs its children before
an error completion. `TERMINAL_LIMIT` bounds unacknowledged terminal ownership:
expiry withdraws the completion and relinquishes the lease, with no second
completion. The internal owner must treat this as abandonment, not success.
Defaults are100,000,000 work cycles and1,000,000 terminal cycles. Successful
result data must not be committed by an internal caller without its matching
successful terminal acceptance. These are internal fixtures, not production
authorization or host-visible result/key endpoints.

`ENABLE=0` uses a generate gate that omits adapter arithmetic hardware.
The module has no memory writes into command/response scratch.

## Phase Three and acceptance limits

Real objects/handles/Names, authorization/sessions/policy, padding and TPM RSA
commands, wrapping/loading, hierarchy/primary seeds and persistence remain
outside this work. No RSA_Encrypt/Decrypt/Sign/VerifySignature host commands are
added. Exact enabled-image fit/timing and physical entropy acceptance remain
separate. Default-image and historical demo measurements do not qualify this
enabled RSA consumer. The existing portable Generic/vendor math wrappers remain.
