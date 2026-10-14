<!--
Filename: CORE.md
Authors: Project contributors; see Git history.
Date: 2026-10-13
General Description: Documents Portable AES/RSA core.
AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.
-->

# Portable AES/RSA core

`rtl/common/keygen_core.v` is the integration boundary. It accepts one captured
profile and operation ID, delegates AES key assembly or RSA generation, and
delivers a protected result. `RSA_SOFTCORE=0` selects dedicated Verilog control;
1 selects RV32I firmware. `KEYGEN_ALTERA` independently selects resource macros.
There are no board pins, SPI registers or test-generation seeds in this module.

Read `INTERFACE.md`, this document, then the top-level state machine. Use
`AES.md` and `RSA_ENGINE.md` for the workers rather than reading all arithmetic
before understanding the public handshakes.

## One operation

1. Synchronize reset release and wait for local memory scrubbing and ready peers.
2. Capture the request. Later changes to profile or ID do not change this job.
3. Generate and validate the key. RSA private operands stay inside the engine.
4. Send result words with stable data and metadata under backpressure.
5. Wait for a separate whole-result accept/reject decision.
6. Clear local secret state, then hold terminal status until acknowledged.

For RSA, output is n(64 words), e(1), p(32), q(32), all most significant first.
For example, accepting the last q word does not yet transfer ownership. The
receiver can still reject the complete staged key. Only acceptance transfers
ownership; subsequent local reset cannot revoke what the receiver already owns.

Generation failure or loss of peer readiness before ownership stops transfers,
asserts discard and starts cleanup. The first recorded fault survives cleanup.
Reset invalidates transfers immediately, emits no cancelled status and blocks
new admission until cleanup finishes. External source/result/ownership stalls
are legal. Internal controller watchdogs are distinct from host deadlines.

## Integration evidence

`python3 scripts/run_integration_verilator.py` and the same command with
`--softcore` both passed **28 lifecycle checks** using real engine storage:
AES128/256, capture, source gaps, result stalls, ownership rejection, invalid
profile, source failure, first-fault preservation, peer failure, invalid internal
status mapping, partial RSA candidate reset, active modular-exponentiation reset,
AES result reset, cleanup reset, held-status reset and reuse. Additional cases
cover source failure and peer loss after public admission but before internal
AES/RSA dispatch, simultaneous fault priority and successful subsequent jobs.
Peer unavailability before admission remains a legal wait. The dispatch fix
suppresses the internal AES request on a fault, preventing an orphan worker job.

`scripts/run_full_verilator.py` compares every RSA word and component/index
against the independent corpus and requires exact source consumption. It fails
on error status, missing PASS, timeout or incomplete execution. `--directed`
tests known candidate inputs, `--stalls` adds source gaps/result backpressure,
and `--softcore` selects firmware. No option replaces vendor models: genuine
Altera runs use `scripts/softcore/run_full_altera_questa.py` and the installed
unmodified simulation library.

Use `--label` to preserve a distinct evidence directory. The generic full-key
runner records source, firmware, fixture, simulator and binary fingerprints and
rejects stale `--reuse-build` requests. The vendor runner independently hashes
its unchanged model files as well. Build labels are not test results: the runner
requires a complete-key PASS before writing successful runtime evidence.

The full-key directed tests passed both generic controller configurations.
Normal twenty-seed search, all four final fits and hardware soak remain
acceptance gates; see `ACCEPTANCE.md`. Fast lifecycle tests do not claim every
RSA internal reset phase is covered; arithmetic/CPU tests and board recovery
tests provide additional evidence.

## Registered reset control

The engine cleanup reset is driven by a registered request, not a combinational
comparison of the binary state register. It asserts on entry to RESET_ENGINE
and releases on entry to SCRUB, preserving the original cleanup schedule.
This avoids relying on FPGA state-machine recoding for glitch-free reset and
keeps the same behavior in generic Verilog and ASIC synthesis.

The lifecycle test injects a between-edge state-decode transient and requires
the engine reset to remain released. Both generic controllers pass this added
case; full vendor and routed acceptance must use the final reset-audited source.
