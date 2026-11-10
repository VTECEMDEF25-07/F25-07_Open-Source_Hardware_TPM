# DE25 demo coordinator v0.1

Codex-assisted implementation of the frozen project demo contract. This is a
bounded crypto-engine demo, not complete TPM authorization/object management.

## Integration

Instantiate `execution_engine_demo_packet` with WIDTH=2048 and immutable
DEMO_PROVIDER_MODE (1 TEST, 0 experimental FRESH_UNQUALIFIED). The module header
is the authoritative complete port manifest. It encapsulates
`demo_aes_coordinator`; neither module has a private-key/result-word input.

Connect gen_job/done to `demo_keygen_operation`; connect release to the store
through the single-job release mux. Connect `store_use_allowed_o` to store policy.
Connect existing AES packet busy to both `aes_client_active_i` and store
client_active. Generation success requires matching id/profile/mode, ownership,
all three status domains zero and gen_scrub_done. Denial cannot enable usage.

Connect modexp job/status plus native memory to the adapter; coordinator owns the
single native RAM mux with operand staging and result reads. Connect ram request,
reply and clear ports to `demo_byte_ram`. Public destination data is cleared
before a result is published; the packet retains a private public-result copy
only through final FIFO copy. Adapter arithmetic is external and unchanged.

CRB supplies synchronous command bytes and indexes response payload excluding the
10-byte header. `response_valid_o` is a one-cycle announcement. Assert
`response_consumed_i` only after the final response byte is copied to FIFO.
Keep global transport admission blocked until host drain/release and handler
scrub complete. Timeout/recovery requests reset the shared transaction context;
they do not fabricate ordinary responses. Supervisor metadata inputs overlay
CAPS only and never affect current readiness. Detailed supervisor reason remains
supervisor-owned; wire status reports setup=6/teardown=4.

Instantiate `execution_engine_aes_packet` with ENABLE_DEMO_LIFECYCLE=1 for this
build. The default0 retains old standalone behavior/benches. In demo mode it
sweeps all1024 payload bytes on reset, failure and response release. Registered
local worker reset erases key copies/schedule, captures public IV/length before
reset, and delays readmission through release. Payload is retained while CRB
copies the result. Partial CFB feedback uses the existing zero-filled worker
contract and must not be continued as a full CFB block.

## Reproducible verification

Run `python run_demo_coordinator.py --legacy` with Questa executables in PATH and
Python cryptography installed. Build/logs default to a sibling unit-build folder
outside the checkout. `--build` overrides it. Production source is compiled as
Verilog2001, benches as SystemVerilog. Checks require explicit pass markers and
reject simulator assertion/fatal errors; exit0 alone is insufficient.

- Packet bench: generation, denied setup/mismatched ID, FLUSH/invalid handle,
  supervisor provenance, malformed opcode, MODEXP operand layout/staging/result,
  scratch write-error response before remaining input, held response and reset.
  Generation/store/modexp are controlled interface models in this bench. The
  full-width arithmetic and complete real-provider/store composition are separate
  integrator/peer gates; a32-bit mock descriptor test is not a2048-bit pass.
- AES lifecycle: real symmetric datapath; 18 cryptography-reference ciphertext,
  plaintext and final-IV checks (0,1,15,16,17,31,32,1023,1024 each enc/dec); denied
  lookup never launches AES; all15 AES round-key slots and controller key copies
  zero at publication; entire scratch/read latch zero before reuse; active reset.
- Timeout: shortened test deadline, no synthetic completion, blocked admission
  until shared reset. Hardware generation bound remains64-bit180s.
- Legacy replay: Hash command, default SPI Hash/disabled AES, keygen-to-AES,
  enabled AES SPI, and original SPI counter240/errors0 completion.

`Testing/Host/de25_crypto_demo.py --self-test` checks public NIST fixture,
fixed-seed derivation, framing and malformed-response rejection in software.
Device/simulation usage accepts `--transport module:factory`; factory returns an
object with `transact(packet, timeout_s=...) -> complete reply bytes`. Integration
owner supplies existing FIFO/SPI transport, locking and reset. The host script
executes repeated internal-key AES/Hash/flush-denial flows plus independently
checked full2048-bit public modexp and visibly identifies TEST versus unqualified
fresh. It has no key-read or host-seed command. This change makes no physical,
synthesis, timing or entropy-qualification claim.
