# PCR command profile

Codex-assisted implementation, 2026-11-18.

## Supported wire forms

`TPM_TOP` enables `ENABLE_PCR_COMMANDS` on the Phase One engine. The engine
captures header and operational state in IDLE, dispatches in state 10,
waits in state 11, and completes in state 9. The focused handler cannot
publish a response directly to the CRB. The existing optional AES route is
unchanged. On these two PCR routes, `tpm_io` delays status completion
until CRB reply transfer finishes, so dataAvail cannot precede FIFO readiness
for a 300-byte reply. The separate FIFO execution handshake is unchanged.
`TPM_CAP_PCRS` is the only GetCapability category implemented here;
other categories return a parameter-one VALUE error.

This build has one implemented hash algorithm/bank: SHA-256 (`0x000b`),
24 allocated PCRs, indices 0..23. `TPML_PCR_SELECTION.count` is 0 or 1
(`HASH_COUNT=1`), and `sizeofSelect` is exactly 3. Bitmap bytes select indices
0..7, 8..15, 16..23, least significant bit first. A different algorithm
returns `0x1c3`; count/bitmap-size violations return `0x1d5`. Inconsistent
packet sizes return `0x142`. Only the no-session form is supported; sessions
return `0x145`, with no session or authorization implementation added.

A PCR_Read response payload is:

- UINT32 pcrUpdateCounter, big endian.
- TPML_PCR_SELECTION: UINT32 count and, for one selection, UINT16 hash,
  BYTE sizeofSelect, three bitmap bytes.
- TPML_DIGEST: UINT32 count, then each UINT16 size=32 and 32 digest bytes.

At most eight selected PCRs are returned per reply, in ascending index order.
`pcrSelectionOut` marks exactly those returned; callers remove those bits and
repeat for the rest. The count-zero response contains no bank structure.
A count-one empty mask retains its empty bank structure and has zero digests.
These replies have total lengths 22 and 28 bytes respectively. An eight-PCR
reply is 300 bytes. Digest bytes retain the shared bank's most-significant-byte
first hash representation.

GetCapability parameters are UINT32 capability=5, property=0, propertyCount.
The full reply is exactly
`80010000001900000000 00 00000005 00000001 000b03ffffff`.
For propertyCount=0 it is
`80010000001300000000 01 00000005 00000000`.
Any nonzero count returns the complete single bank and moreData=0; the count
zero reply has moreData=1. A nonzero property returns `0x2c4`.

## Bank and counter

The source is `hash_subsystem.u_pcr_registers`, not a shadow or canned bank.
The counter lives with the bank and advances modulo 2^32 on each committed
valid-index write, including a write whose value equals the old value.
Reads, invalid-index writes and rejected commands do not advance it.
The existing backend Extend commits through this same write port.
No host PCR_Extend command is added; its production top-level input remains
inactive. The counter and reply digests are captured together. If a backend
commit changes the counter while the handler is collecting PCRs, collection
restarts at PCR0 to avoid returning mixed generations.

## Startup and platform limits

This preserves the existing volatile module-test bank profile: all 24 PCRs
and the counter initialize to zero on combined `RESET_n`/`SPI_RST_n` reset.
Management Startup currently neither reinitializes PCRs nor restores saved
PCR state. Repeated successful Startup(CLEAR) therefore retains the bank and
counter until hardware reset. Tests explicitly cover this behavior for PCR0,
PCR8, PCR16 and PCR23, both after reset and with distinct extended digests.

This is **not a PC Client platform PCR startup profile**: dynamic PCR initial
values, locality rules, RESET/RESTART/RESUME saved-state semantics, and NV
restore are not implemented or claimed. Startup(STATE) cannot establish a
saved PCR image. Extending the platform lifecycle requires a separate change;
this PR implements the read/discovery wire commands against the existing bank.

## Independent expected values and tests

Run the existing Windows Questa entry point from the repository root:

```powershell
vsim -c -do 'do {Testing/Simulation/Execution Engine/run_tpm2_hash_command.do}'
```

`tb_tpm2_pcr_command` checks complete response bytes and exact write counts,
using four distinct literal PCR fixtures, including PCR23 and noncontiguous
selections. It covers count-zero/empty/full selections, three pages of eight
PCRs, malformed lengths including 4095, unsupported hash, invalid selection
sizes/counts, tag/session rejection, pre-operational reads, backend read error,
invalid writes, same-value commits, overlapping updates and counter stability.
Its assertions require every accepted command to dispatch and complete
through Phase One.

`tb_tpm2_pcr_spi` runs real simulated SPI through TPM_TOP, management, CRB,
Phase One, and the actual shared PCR bank. Test-only forced backend input
ports issue real SHA-256 Extends; production host routing remains disabled.
For PCR index n in {0,8,16,23}, the literal expected digest is independently
computed as Python `hashlib.sha256(bytes(32) + bytes([n+1])*32).hexdigest()`.
No expected digest is read back from the DUT. SPI tests compare every response
byte for reset values, the four distinct digests, capability reporting,
Startup retention, and a second hardware reset. Two additional 300-byte SPI
replies test the eight-digest limit, first-page selection trimming, and the
last PCR page. Route assertions count nine
engine-owned SPI commands and their nine post-process replies.

The same runner reruns Hash command/Hash SPI, generated-key AES integration,
AES SPI, and the unchanged original SPI bench. The original bench must reach
entry 240 with zero assertion errors; simulator exit zero alone is insufficient.

Actual Windows simulator results and physical hardware limits are recorded
in the PR validation evidence. No FPGA programming, board SPI capture,
Quartus fit/timing result, physical PCR read, or platform compliance result is
implied by simulation.

Reference behavior was checked against the TCG reference implementation:
[command](https://github.com/microsoft/ms-tpm-20-ref/blob/main/TPMCmd/tpm/src/command/PCR/PCR_Read.c),
[PCR read/allocation](https://github.com/microsoft/ms-tpm-20-ref/blob/main/TPMCmd/tpm/src/subsystem/PCR.c),
and [GetCapability](https://github.com/microsoft/ms-tpm-20-ref/blob/main/TPMCmd/tpm/src/command/Capability/GetCapability.c).
