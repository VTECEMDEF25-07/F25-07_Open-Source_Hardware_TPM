# Volatile demo memory

Implements the protected-store and byte-memory boundaries frozen in
`AI/DE25_DEMO_INTERFACES.md` v0.1, November 9, 2026. Codex assisted with the RTL,
testbench and runner. These modules add no persistent TPM objects or host key-read
endpoint. They use the existing crypto clock, asynchronous reset assertion and an
internal two-edge synchronized reset release. Every endpoint sharing an untagged
transaction must reset together.

## Protected object

`demo_volatile_store.v` holds one 129-word slot: AES128 words 0..3, AES256 0..7,
or RSA n 0..63, e 64, p 65..96, q 97..128. Ordered words and all flags/IDs are
validated. RSA e must equal 0x10001. No d is exported or invented. RSA contents
are currently staging/test support; this module has no generic component reader.

Reservation admits one descriptor. `receiver_ready_o` indicates the prepared
reservation and stays asserted through staging/decision, independently of stalls.
Word transfers alone do not grant ownership. `decision_valid_i` and the core's
`ownership_ready_i` must handshake together through the store after complete
staging. The matching rising edge atomically owns the object and creates a held
commit report. Report consumption does not change ownership. A decision rejection
scrubs without issuing a commit. The receiver detects malformed accepted words
and reports error 7; invalid profile/mode reservations report error 1. These are
local nonsecret reasons, not cryptographic validation results.

The operation owner must route receiver faults and observed source faults into
the same `abort_i` predicate that qualifies core handshakes. Abort/discard before
ownership beats all transfers. Scrub-done can assert while abort/discard remains
high, so the operation owner can acknowledge cleanup without a readiness cycle.
Errors remain asserted through that held-abort cleanup and clear on return to
EMPTY after abort/discard deasserts. Source faults after ownership leave ownership
intact; failed overall jobs must explicitly release the object.

Handles increment per ownership from 0x80000001 through 0xffffffff; exhaustion
blocks new reservations rather than wrapping. Full reset clears the counter and
all objects, so handles can numerically repeat after reset. Host references must
be dropped on reset/reconnect. Handle metadata is not a persistent capability.

AES lookup is a registered held reply with an internal 256-bit key bus. Success
requires owned AES256, matching handle, reserved demo permission and per-request
`use_allowed_i`. Invalid handles return 0x18b; type/policy denials return 0x12f.
AES128 is stored correctly but denied by this AES256 client. The key reply latch
is erased on consumption; the public output is zero outside a successful held
reply. A permission change after request acceptance does not mutate the reply.
The trusted coordinator must keep `client_active_i` high through AES completion
and worker/key-schedule reset, not merely through reply consumption.

Release waits for client lease, commit-report and key-reply completion. Accepted
valid release invalidates the handle immediately, wipes all 129 words and reply
latches, then produces a held success reply. Invalid release returns 0x18b and
preserves the current object. Reserve beats lookup in EMPTY; release beats both.
Ready signals reflect priorities, so no accepted request disappears.

Full reset immediately suppresses transfers, destroys owned/unowned metadata and
restarts the sweep. After synchronized release there are 129 write edges, one
scrub-done/latch-clear edge, and one EMPTY edge (131 to reservation-ready).
Release acknowledgment follows 130 edges after its accepting edge. New admission
also waits for discard/abort deassertion and held release-response consumption.
`receiver_scrub_done_o` means physically zeroed, and is false while occupied;
successful retained ownership does not require it to assert.

## Public byte scratch

`demo_byte_ram.v` supplies 1024 bytes with 12-bit byte addresses. Validate before
address narrowing: 1024..4095 return error with zero data and no side effect.
Permission is sampled on request acceptance. Every read/write receives exactly
one registered held response; write data replies are zero. The output latch is
zeroed after consumption. Only one transaction is outstanding; a bubble is
permitted. Clear cannot interrupt an outstanding reply. Clear has priority over
a simultaneous request and sweeps 1024 bytes plus one latch-clear/completion
edge, then holds `clear_done_valid_o` until consumed. Reset startup performs the
same sweep without an unsolicited clear completion. `scrub_done_o` deasserts
on a valid write or explicit clear and asserts after the full physical sweep.

The integrator owns the external single-owner mux and access lease. No keys,
seeds, d, p or q belong in scratch. At WIDTH=2048, fixed public MODEXP offsets
are base 0, exponent 256, modulus 512 and result 768. Increasing addresses are
MSB-first operand bytes. Packet RAM is a different existing memory and needs
its separately assigned lifecycle/transport cleanup; these modules do not clear it.

## Validation and integration

Add both `.v` sources to the board manifest; no includes or vendor primitives are
needed. Production sources compile in Verilog-2001 mode. RTL arrays are written
by sequential scrub, never presumed zero from primitive reset. The protected
AES parallel reply may infer registers; no fitted resource/timing claim is made.

Run the standalone test in an isolated output directory:

```text
python "Testing/Simulation/Demo Memory/run_demo_memory.py" --build <output-directory> --seed 1
```

`--questa <bin-directory>` selects another Questa install. An Icarus alternative
is supported by `--iverilog <executable> --vvp <executable>`; it is not a claim
that Icarus was executed. Logs are preserved and pass requires a completion
marker plus no simulator errors/fatals. The bench checks physical array/latch
zeroing, independent expected stream placement and a software byte scoreboard;
random stalls/accesses are seeded with `--seed`. It includes malformed fields,
missing terminal flags, ownership rejection, fault/reset edge priority, denied
and unknown handles, lease/release, incarnation exhaustion, clear stalls,
bounds, and outstanding-transaction reset/reuse. This is component simulation,
not combined SPI, synthesis, timing, physical entropy or hardware acceptance.
