# Phase Two: internal RNG-to-keygen lifecycle

This milestone adds zero TPM command codes. `execution_engine` owns an internal
`execution_engine_keygen` worker and one protected volatile result slot. It
preserves the existing AES128/AES256/RSA2048 algorithms and RSA n/e/p/q format.
It does not implement objects, handles, Names, sessions, authorization, parents,
wrapping, persistence, or repeatable primary generation. RSA arithmetic consumers
and n/e/p/q-versus-d adaptation remain a separate task.
ReadPublic, FlushContext, Create, Load, CreateLoaded and CreatePrimary are not
added by this milestone.

## Admission and private interface

`ENABLE_INTERNAL_KEYGEN=0` by default in engine and TPM_TOP. The top connects no
requester or consumer: request/allow/release are constant inactive and private
outputs are unconnected. There is no host register, packet route or secret
readback endpoint. An enabled internal integration/test instantiates the engine
with the following protected signals. The `allow` input is an **authorization
fixture**, not production authorization. Only trusted internal logic may drive it.

* `keygen_request_i && keygen_ready_o` captures profile (0 AES128, 1 AES256,
  2 RSA2048), ID and allow once. Denied requests return code9; invalid profiles
  return code1. Neither starts generation. Busy requests are not accepted and
  receive no completion; `keygen_busy_o` reports this. A producer may withdraw
  an unaccepted request or hold it until ready; holding it requests a new job
  when the slot is eventually released and cleared.
* `keygen_completion_o/ready_i` is one held completion with ID and status.
  Codes0..8 retain the core contract; code9 is fixture denial. Matching success
  publishes `keygen_slot_valid_o`, `slot_type_o` and `slot_words_o` atomically.
  Sizes are 4, 8, 129 words respectively. A completed slot survives completion
  acknowledgment, until explicit release or shared reset.
* `keygen_private_address_i[7:0]` reads only a valid slot and in-range address;
  all other reads return zero. The containing engine hides this fixture read
  port while AES owns the reservation and routes the one address port to AES.
  AES is key words; RSA is n[0..63], e[64],
  p[65..96], q[97..128]. All words/bytes are MSB first. No partial result is
  visible. These are private consumer wires, not a transport API.
* When unreserved, `keygen_release_i` immediately masks validity/data; 129 sequential writes
  clear every slot address before reuse. Failure and reset use the same full
  sweep. Reset suppresses transfers/metadata immediately; RAM clearing then
  completes synchronously. Reset emits no synthetic completion. No retained
  recovery record survives this volatile subsystem reset.
  While reserved, destruction is rejected, never deferred. Relinquishing a
  consumer reservation does not destroy the slot. See
  [AES_SLOT_CONTRACT.md](AES_SLOT_CONTRACT.md) for the shared acquire/held-reply,
  expected type/size, fixture denial, reset and RSA reuse contract.

The current slot is register-backed in Quartus synthesis; no inferred block-RAM
area or timing benefit is claimed. Release is a private consumer operation for
an occupied slot, not a cancellation handshake for an in-progress core.
* `keygen_result_enable_i`, `keygen_ownership_enable_i`, and
  `keygen_terminal_enable_i` are bounded internal backpressure fixtures;
  production containing logic ties them high. The operation watchdog overrides
  a held terminal fixture after failure so cleanup can progress. Completion
  acknowledgment may remain stalled indefinitely without holding the RNG.

## Ownership and publication

The existing core cannot reach terminal success until its receiver accepts
whole-result ownership. The worker therefore stages each consistent word in
private RAM and validates ID, component, index and last flags. It grants
**provisional private ownership** only after exactly the expected complete
result. This lets the core erase its working storage and produce terminal status;
it does not enable slot reads. A matching successful terminal status, retained
ownership/count, no observed fault, and completed source close are all required
before publication. Last-word arrival alone cannot publish a slot.

Health failure, timeout or reset before the publication edge prevents publication,
including after provisional ownership or on terminal acceptance. Failures clear
the receiver before publishing error completion. A fault after publication blocks
future RNG use but does not invalidate an already committed slot. Release/reset
owns that slot's remaining lifetime. Core cleanup is never aborted merely to
shorten a stalled external transaction.

## Shared RNG contract

`rng_word_service` reserves the existing persistent conditioned Hash_DRBG stream
for one client: keygen or GetRandom. A grant means exclusive reservation, **not
that instantiation has finished**; data-valid supplies actual source readiness.
There is no per-key DRBG instantiation or guaranteed reseed-before-every-key.
The existing SHA-256 Hash_DRBG collects three 256-bit raw-source blocks at startup
and two on reseed, with a default 1024-block reseed interval. Its entropy-credit
assumption and final-image physical assessment remain separate acceptance gates.
Generation remains production entropy/DRBG-backed; public deterministic fixtures
exist only in simulation benches.

A level Generate request stays asserted until one fault-qualified 256-bit pulse
is received. Keygen buffers that block atomically and consumes bits[255:224]
first, shifting/zeroing one 32-bit word per ready/valid transfer. There is no
prefetch while the buffer is full; refill is demand driven and does not depend
on elapsed stall time. Unused words are discarded/cleared at close, never reused
by GetRandom or another key. An issued request is drained before ordinary close;
no ownership switch can relabel a late response. DRBG V/C/counter remain private
persistent state between reservations; closing is not uninstantiation. The
existing DRBG clears its handed-off output and transient generation registers.

Reservations span the whole keygen operation through core terminal cleanup,
including RSA arithmetic. GetRandom holds its request while waiting. Selection
alternates priority when both requests are pending; this bounds overtaking to
one other reservation, not elapsed time under arbitrary stalls. There is no
queue beyond the clients' held requests. GetRandom's collection watchdog pauses
while another reservation owns the source. The source watchdog still bounds an
issued block (default 1,000,000 cycles), including startup/reseed and SHA contention.
The internal lifecycle has a configurable default 9,000,000,000-cycle watchdog
(180 seconds at 50MHz); this is an engineering bound, not a TPM deadline or a
prime-search performance guarantee. Individual board profiles must tune/validate
these bounds.

Every word/result/ownership transfer is qualified by the same current fault
condition; a synchronous health/timeout observation wins at that edge. Source
health failure or timeout clears the service buffer and quarantines RNG admission
until shared reset and startup collection. Already-issued SHA messages continue
draining in `phase_one_rng`; this change never locally resets DRBG/SHA or strands
a message when another Hash/PCR request needs the shared core. Recovery requires
shared reset, full slot clearing and healthy startup. Independent Hash/PCR routes
remain usable after an RNG fault.

`entropy_health.reject_sample_o` exposes the existing RCT/APT decision before
the edge that records its sticky fault. That decision qualifies slot publication
and transfers on the same raw-sample edge. Entropy sampling is stopped by the
registered faults, rather than feeding this lookahead back to sample-valid;
the detector still records the rejected sample and no combinational loop is
introduced. Thresholds and entropy-credit assumptions are unchanged.

GetRandom receives its own whole block only during its reservation, retaining
existing framing and maximum 32-byte behavior. Its eligibility point is the
worker's REPLY edge: the complete private response has been collected and its
health check runs on that edge. Source release occurs there. Later health failure
does not rewrite an already committed host response, so host backpressure cannot
extend the health window or RNG reservation indefinitely. Existing response-buffer
lifetime/transport handling is unchanged. No keygen result reaches this buffer.

## Evidence and handoff

See `Testing/Simulation/Execution Engine/KEYGEN_VALIDATION.md` for reproducible
commands, exact evidence and coverage limits. Simulation does not establish
physical entropy, side-channel resistance, complete TPM security or final-image
board acceptance. Phase Three must replace the allow fixture with authorization,
assign real objects/handles/Names, integrate protected consumers and implement
object lifetime/persistence. Fresh RNG is not repeatable CreatePrimary.
