<!--
Filename: AES.md
Authors: Project contributors; see Git history.
Date: 2026-10-13
General Description: Documents Standalone AES assembly.
AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.
-->

# Standalone AES assembly

`keygen_aes_core` implements the v1 request/generation/result/ownership/status
contract for profiles0(AES128) and1(AES256). Other profiles return invalid-profile;
this module is not the complete AES/RSA top and does not fake RSA success.

The eight32-bit slots retain input ordering. Four slots are used forAES128,
eight forAES256. Transfer waits under backpressure. The receiver must accept the
complete result separately; then all eight slots are overwritten before success.
Reset gates off transfers immediately and sweeps slots before allowing a new job.
Source failures/peer loss abort before ownership; rejection discards the result.
Once ownership transfers, later source/peer changes cannot revoke it.

Read `INTERFACE.md`, the Verilog state machine, then `tb_keygen_aes_core.sv`.
States: SCRUB initializes/clears; IDLE accepts; COLLECT counts words; EMIT sends
the held key; OWNERSHIP waits for the complete-result decision; STATUS waits for
terminal acknowledgment. There is no cancel signal, store commit or TPM parser.

Run `scripts/test_aes.ps1` with installed Questa (`-QuestaBin` override available).
Project RTL compiles using Verilog2001; tests compile separately using SV.
The runner requires explicit PASS and checks process errors. Build output is
ignored. Simulation on2026-10-13 passed51operations plus reset in5phases, including
ordering, source gaps, result stalls, rejection, peer/source faults, fault versus
ownership priority, clearing, held status and recovery. Source/test compilation
reported zero warnings; simulator issued its expected optimization warning from
testbench visibility (`+acc`). This is simulation evidence, not board validation.
