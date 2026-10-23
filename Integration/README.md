# RNG / keygen integration

Isolated branch `aaron/rng-keygen-integration`, created from Aaron's PR #35 head
`c90610165605cac55243522847c5e5f50f60ef08`, with Jungyeon's `rng` head
`092bac8a4e481e214e26578b8e4d1b4af9176411` merged as `3cae86c`.
The existing working checkout and PR branch are not modified.

## Entry points

- `rtl/rng_keygen_system.v`: shared RNG + unchanged portable keygen, accepts
  **qualified seed material** on a protected internal channel. Useful for
  system integration and deterministic simulation with the actual DRBG.
- `rtl/rng_keygen_physical.v`: connects Jungyeon's raw entropy sampler and the
  health/conditioning pipeline to that system. `VALIDATED_ENTROPY=0` by default.
- `../RNG Module/RNG.v`: standalone GetRandom frontend with the new pipeline;
  adds a real `tpm_initialized` input and a `health_fault` output. Its command
  byte interfaces retain the old names. Use the shared system when keygen and
  GetRandom coexist; do not instantiate two unrelated RNG stacks for them.

New synthesizable sources are Verilog-2001; testbenches are SystemVerilog.
No new source compilation requires SystemVerilog. Keygen arithmetic, firmware,
word ordering and protected-result format are unchanged.

## Implemented behavior

- Exclusive round-robin arbitration between pending keygen and GetRandom jobs.
- Open/setup response, held 32-bit words, sticky context faults, explicit close
  after erasing source state. Failed open erases before responding and requires
  no subsequent close.
- Real SHA-256 Hash_DRBG: 440-bit internal state; 256-bit entropy plus 128-bit
  nonce on instantiate; 256-bit Generate; no personalization/additional input.
  Unit-level reseed is implemented and checked. Service contexts instantiate
  afresh and close/erase; if the reseed limit is reached, the service fails the
  operation rather than silently reusing output or falling back to test data.
- Startup sampling, repetition-count and adaptive-proportion checks, and two
  disjoint SHA-256-conditioned windows. Health faults survive operation abort.
- GetRandom buffers its entire response and releases the source before host
  transmission; zero-byte requests require no entropy. Unsupported session
  tags are rejected, as in the original frontend.
- Coordinator holds core status until source and unowned receiver cleanup.
  `receiver_scrub_done_i` must be able to assert while discard remains high;
  ordinary receiver readiness alone is insufficient.
- Supervisor retains operation ID/ownership and affected-client flags across
  operation abort/timeout. Independent client deadlines prevent a new request
  from inheriting an older client's age. Final transfers at the deadline win
  over timeout for that client. Recovery must be acknowledged before new work.

The legacy pass-through `random_number_generation.v`, pulse-overwriting
`tpm2_get_random.v` and their old combined bench are replaced, not production
alternatives. Their history remains in the merged RNG commit. Raw UART capture
and its bench remain available for characterization.

## Contract details and limits

1. Fresh mode=0; primary mode=1 is **rejected** until the protected hierarchy and
   canonical derivation contract is supplied. Mode=2 is accepted only in a
   `TEST_BUILD=1` system. That build uses the existing predictable fixture
   provider, including for GetRandom; it must be labeled test-only. Physical
   entry points hardwire `TEST_BUILD=0`.
2. Seed input is 48 bytes, most significant byte first: 32 bytes of qualified
   entropy then a 16-byte nonce. A handshake consumes it once. The supplying
   trusted provider must not reissue it after reset. The physical wrapper
   discards pooled and partial seed state on operation reset.
3. Service open checks client/profile/procedure/context fields. Keygen uses
   procedure=1; GetRandom uses reserved profile/procedure=0. Context handles must
   currently be zero. Close is routed only to the current owner, so its public
   port does not repeat the ID/disposition fields proposed in the plan.
4. `status_code_o` preserves core status values; setup rejection maps to invalid
   request (1), RNG/setup failure to generation failure (2). Ownership remains
   committed after acceptance. `source_fault_after_commit_o` reports a late
   source alarm separately; it does not pretend ownership was revoked.
   `teardown_failed_o` is reserved: local close acknowledgment means erasure
   completed. A stuck teardown is reported through supervisor recovery instead.
5. Operation reset suppresses transfers, clears core/source/unowned staging,
   and does not revoke receiver-owned keys. The receiver's ownership journal
   must live outside `operation_reset_n_o`. The supervisor record survives
   operation reset, not power loss. A full TPM/object store must reconcile
   persistent commits after power loss. Board cooling is outside this module.

Default setup bound: 500,000,000 clocks (10 s at 50 MHz). Default operation
bound: 9,000,000,000 clocks (180 s at 50 MHz), independently per client. These
are configurable engineering/demo limits, not TPM specification deadlines.
An operation abort also aborts a concurrent stalled GetRandom response;
transport must discard that incomplete frame when operation reset asserts.

## Physical acceptance is still required

**Enabling the physical gate is not an entropy assessment.** The two 768-sample
windows and RCT=32/APT=187..325 per 512 samples are provisional engineering
settings. Measure the actual board source, derive defensible entropy/nonce
budgets and health thresholds, and verify synthesis preserves the ring
oscillators before enabling `VALIDATED_ENTROPY`. Sample count is not entropy
bit count; passing simulation does not qualify the source.

The inherited ring-oscillator technology mapping must be checked for the actual
FPGA target. No FPGA build/programming or physical entropy validation is claimed
by the simulation evidence. No complete-TPM, certification, primary-generation
or four-backend acceptance claim is made.

Reference mechanisms: [NIST SP 800-90A Rev. 1](https://csrc.nist.gov/pubs/sp/800/90/a/r1/final)
and [NIST SP 800-90B](https://csrc.nist.gov/pubs/sp/800/90/b/final).

## Reproduce the tests

Use Linux/WSL with Python 3, Verilator, g++ and its C++20 support. All generated
files stay under ignored `Integration/build/`; sources may live in a path with
spaces. The runner avoids GNU make for that reason. It records source/fixture
hashes and simulator version with each passing run.

```sh
python3 'RNG Module/scripts/check_hdl.py'
python3 'RNG Module/scripts/test_integration.py'
python3 'RNG Module/scripts/test_integration.py' --suite tb_rng_entropy
python3 'RNG Module/scripts/test_integration.py' --suite tb_rng_system
python3 'RNG Module/scripts/test_integration.py' --suite tb_rng_system --fresh
python3 'RNG Module/scripts/test_integration.py' --suite tb_rng_system --fresh --watchdog
python3 'RNG Module/scripts/test_integration.py' --suite tb_rng_system --fresh --softcore
python3 'RNG Module/scripts/test_integration.py' --suite tb_rng_system --rsa
python3 'RNG Module/scripts/test_integration.py' --suite tb_rng_system --rsa --fresh --softcore
```

Before soft-core runs, build the unchanged firmware with the existing pinned
toolchain using `Key Generation/scripts/softcore/build_rsa.py`, outputting to
`Key Generation/build/full`. The existing checked firmware manifest must match.
Full RSA simulations are substantially slower than the small control tests.
Do not run two invocations of the same suite/flags in the same build directory.

See `docs/VALIDATION.md` for completed evidence and remaining gates.
