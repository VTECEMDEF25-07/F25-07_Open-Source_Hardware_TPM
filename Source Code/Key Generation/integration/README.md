# Demo generation and operation owner

Implements frozen `AI/DE25_DEMO_INTERFACES.md` v0.1. Aaron Grossman; Codex-assisted implementation and tests.

Instantiate **`demo_keygen_operation`** once. It contains `keygen_core` and `demo_generation_service`; connect its result/reservation/decision/ownership/commit/release ports to `demo_volatile_store`. Do not instantiate a second keygen/provider or duplicate its lifecycle in the host coordinator. Same 50 MHz clock and coordinated active-low reset for operation and store. Full reset clears all volatile objects; provider-local close does not reset the store. No secret word reaches the job/done facade.

Parameters: `DEMO_PROVIDER_MODE=1` (TEST default), `IP_TYPE=0`, `DEVICE_FAMILY="Agilex 5"`, `DEADLINE_CYCLES=64'd9000000000`, `CLEANUP_CYCLES=32'd4096`. IP_TYPE and family propagate unchanged to keygen. Boot admission waits 8192 running-clock edges to cover the existing core's documented 4098-edge private-memory scrub plus reset synchronization without adding a core port. This delay is outside the accepted-job watchdog. Core terminal status proves subsequent core cleanup; no fixed delay substitutes for it.

The source has exactly one context. Open success precedes core admission; faults qualify data/result/ownership at the same observation edge. Empty generation buffers are ordinary stalls. Terminal core status is not acknowledged until provider close and required receiver reconciliation complete. Accepted ownership is historical fact: late failure explicitly releases its handle, scrubs, and retains committed=true/handle in failed done metadata. No new job until held done is accepted. Receiver scrub-done is required for failed/unowned or released staging, **not** for a successfully retained object.

`recovery_required_o` is sticky, suppresses all new result/ownership/admission transfers and asserts abort. On operation/cleanup deadline, the integrator's supervisor must capture nonsecret request/cause/commit metadata and issue coordinated crypto reset. The operation emits no fabricated done on this path. `scrub_done_o` covers this facade's source/core copies; it does not claim the store's owned object has been erased. The host coordinator/integrator must withhold AES lookup permission until successful done, and mux operation failure-release against host FLUSH under the global job lock. Store commit reports are consumed before release. `receiver_error_code_i` remains receiver-local; category maps to setup=2. Store ownership handshake is authoritative; `decision_ready_i` need not be independently counted as another commit.

## Provider modes

* `1 TEST_DETERMINISTIC`: copied public fixture in `demo_test_source.v`, preserving provenance and the original fixture unchanged. SHA256(`KEYGEN-TEST-v1\0` || 32 zero bytes || 64-bit big-endian counter from0). First AES256 key is `3127189a1a42bcdcf45b4810b24d1c7ddd6c73cd5ea0053d34d5ae80db93bb22`. This predictable test key is never a fresh RNG substitute.
* `0 FRESH_UNQUALIFIED`: existing entropy source and Hash_DRBG plus a dedicated existing `hash_subsystem` with only RNG requester active. The wrapper retains each 256-bit result pulse and consumes MSW-first words only on ready/valid. Sampler, DRBG and dedicated SHA reset on every context teardown. SHA first-byte request/grant is already implemented by `hash_subsystem`.

Immutable build mode must match every requested mode. No runtime fallback or host seed. Always publish `entropy_health_qualified=0` and the build/accepted mode in host metadata. Current raw entropy has no completed health/accounting interface. `instantiated` means collected/seeding complete, not qualified randomness. The wrapper detects unexpected DRBG result pulses but cannot detect all native DRBG/SHA arithmetic faults or physical source failures: those cores expose no health/fault outputs. Supervised lack-of-progress is deadline recovery, not an invented health success.

The TEST generate branch excludes physical RNG/dedicated shared SHA hierarchy. For fresh builds add existing `Source Code/RNG Module/{ring_osc,entropy_source,random_number_generation}.v` and all existing Hash Module sources. Both builds need these three integration files and unchanged keygen rtl/IP sources. `run_demo_generation.py` provides the concrete compile manifest. No edits to TPM_TOP, board QSF/SDC, cooling, or existing core APIs are part of this change.

## Validation

From repo root, with Questa available (or `QUESTA_BIN` set):

```powershell
python 'Testing/Simulation/Key Generation/integration/run_demo_generation.py' --output '<scratch>' --store '<path-to-demo_volatile_store.v>'
```

Without `--store`, run the two source suites only. With real store RTL, run four suites: service TEST/fresh and operation TEST/fresh. Production RTL compiles as Verilog-2001; testbenches use SV. Runner checks pass markers and simulator failures and retains per-phase logs.

Python hashlib independently models Hash_df/440-bit state/Generate/reseed and the public fixture. Fresh tests replace only entropy blocks with visible deterministic stimulus; **real SHA/Hash_DRBG RTL remains active**. This is algorithm/handshake simulation, not physical entropy acceptance. Four blocks/32 words per provider are checked with word stalls; fresh reseed interval2 exercises instantiate and reseed messages of101/125 bytes and actual SHA backpressure. Source/entropy/DRBG/SHA schedule and result latches are checked erased at close. Faults, wrong mode/profile/close ID, held replies, partial-block discard, consecutive contexts and resets are exercised.

Operation suites connect the real protected store: AES128/256 exact words, stalled results, held status/lookup replies, occupied/denied/old handles, failed preparation, final generation/result/ownership-edge faults, late post-commit source and teardown failures with explicit release, RSA-profile draw failure and cleanup, reset during transfer/ownership/status, watchdog recovery and successful subsequent reset/retry. RSA2048 successful key generation is not claimed here; the agreed asymmetric demo is a separate public modular-exponentiation adapter. AES cipher/reference checking belongs to the coordinator/integration suite.

No synthesis, fit, timing, live programming, physical entropy estimate, or cryptographic RNG acceptance is established by these tests. Fresh RevD/D1 Agilex5 RO preservation, asynchronous sampling constraints, health/accounting, and board evidence remain explicit integration gates.
