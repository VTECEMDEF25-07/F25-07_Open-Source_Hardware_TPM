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
packet sizes return `0x142`. For these read/discovery commands only the no-session form is supported; sessions
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
The host PCR_Extend path described below uses this same controller and bank.
It remains disabled in default builds. The counter and reply digests are captured together. If a backend
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
the read/discovery and gated Extend wire commands use the existing bank.

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
ports issue real SHA-256 Extends; the original read-only bench keeps the default host Extend gate disabled.
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

## Gated TPM2_PCR_Extend profile (follow-up to PCR Read #54)

`TPM_CC_PCR_Extend=0x182` is owned by the same Phase One PCR packet handler.
Phase One captures the header, operational state and submitted locality,
dispatches in state 10, waits in state 11, and publishes in post-process state 9.
The handler validates the entire supported packet before pulsing the existing
`hash_subsystem.pcr_extend_start_en_i`. It waits for Phase Two `pcr_done_o`;
the bank and update counter have committed before a success response appears.
No second PCR bank, SHA implementation or counter is introduced.

This is an explicitly configured **volatile development profile**, not a
Lenovo/PC Client policy or platform-compliance claim. At TPM_TOP and engine:

| Build parameter | Default | Contract |
| --- | --- | --- |
| ENABLE_PCR_EXTEND | 0 | Disabled returns COMMAND_CODE (0x143), never mutates |
| PCR_EXTEND_EMPTY_AUTH_MASK | 24'h000000 | Each set bit explicitly declares that PCR's immutable authValue empty for this development profile; unset PCRs reject |
| PCR_EXTEND_LOCALITY_MASK | 5'b00001 | Allowed one-hot localities; default permits locality 0 only |

Opt-in requires both enabling Extend and choosing an eligible PCR mask.
For example, `ENABLE_PCR_EXTEND=1, PCR_EXTEND_EMPTY_AUTH_MASK=24'h0000ff`
permits the static empty-password path for PCR0..7 at locality0. This is a
build-time authorization declaration, not a lookup of a protected authValue
or an assertion that every PCR's authValue is empty. No PCR authValue mutation
command is implemented by this path. Other commands and the existing Phase
Three authorization ports (`auth_done_i`, `auth_success_i`,
`auth_response_code_i`) are retained unchanged. Their existing top-level
stub values do not authorize this parser's PCR writes.

Supported requests have one `TPM_RS_PW=0x40000009` authorization record,
`authorizationSize=9`, empty nonce, empty password and attributes 0 or 1
(continueSession). HMAC/policy sessions, nonempty passwords, nonempty nonces,
extra authorization records and other attributes are rejected. Authorization
is required: a no-session Extend returns AUTH_MISSING (0x125). An unsupported
record or PCR outside the explicitly configured empty-auth mask returns
session-one AUTH_FAIL (0x98e); a non-nine-byte authorization area returns
AUTHSIZE (0x144). These scoped failures do not claim a general TPM session
implementation or dictionary-attack policy.

The SHA-256-only `TPML_DIGEST_VALUES` is count 0 or 1. Count 1 is exactly
`UINT32 count=1, UINT16 hashAlg=0x000b, BYTE digest[32]`, in that order.
The complete session-tagged packet is 65 bytes. Count 0 is a 31-byte no-op.
Counts above the single implemented bank (including duplicate/extra entries)
return SIZE for parameter one (0x1d5); other algorithms return HASH for
parameter one (0x1c3). Truncated/extra bytes or inconsistent lengths return
COMMAND_SIZE (0x142). PCR handles 0..23 select that bank; invalid handles
return handle-one HANDLE (0x18b). `TPM_RH_NULL=0x40000007` is accepted as
an empty-auth no-op after the same packet and configured-locality validation.
Count-zero and NULL-handle success do not launch SHA or advance the counter.

Locality originates in the real SPI ACCESS ownership state machine.
`tpm_reg_space.locality_out_o` is one-hot (01,02,04,08,10), not the numeric
locality ID. `tpm_io` captures it when the FIFO submits the command, before
CRB packet copying; Phase One captures that command-bound value at admission.
Later active-locality changes cannot relabel an already submitted command.
Absent, unknown, out-of-range, multi-hot or disallowed localities return
LOCALITY (0x907) without launching the backend. This static mask is scoped
to Extend. It does not impose locality restrictions on PCR_Read.

Success is the standard session response:
`8002 00000013 00000000 00000000 0000 01 0000`
(header, parameterSize=0, empty nonce, continueSession=1, empty HMAC).
Errors use a ten-byte no-session response; BAD_TAG retains the standard
0x00c4 response tag. The PCR FIFO-ready status completion path now includes
Extend. Backend error returns FAILURE (0x101); accepted work waits for actual
completion rather than returning an optimistic status.

### Validation and integration boundaries

`tb_tpm2_pcr_extend_command` uses CRB, Phase One and the actual Phase Two SHA
controller/bank. Literal expected values were independently generated with
Python hashlib: `SHA256(oldPCR || measurement)`. It performs repeated Extends
to PCR0 with different measurements, separate PCR8/PCR15 Extends, and all-24
host reads after each success/rejection to verify untouched PCRs, exact
commit count and pcrUpdateCounter. It checks disabled and zero-mask builds,
malformed lengths/tags/digest lists, invalid handles/bank, unsupported auth,
all other localities plus absent/multi-hot/unknown, retained locality, an
in-flight reset and a successful clean recovery. One reset-aborted command
must never complete. No expected digest comes from DUT readback.

`tb_tpm2_pcr_extend_spi` uses host bytes over real simulated SPI, no forced
mutation controls, through management/CRB/Phase One/Phase Two. It Extends
PCR0/8/16/23, independently compares complete read replies (including 300-byte
pages), and rejects bad password, bank, handle, truncated digest and ineligible
PCR. It relinquishes locality0 and acquires locality1 through ACCESS registers,
proves Extend rejection there, and verifies PCR_Read still works with an
unchanged bank/counter. Hardware reset clears this volatile profile; management
Startup retains it, exactly as the PCR Read base documents.

The runner also preserves PCR Read command/SPI, Hash command/SPI, generated-key
AES integration, optional AES SPI, and the unchanged original SPI benchmark
(entry 240, zero errors required). This is simulation evidence only. No board
programming, Lenovo boot, physical SPI capture, Quartus fit/timing or resume/NV
validation has been performed. Before enabling on Lenovo hardware, the target
platform must establish the correct eligible-PCR/authValue contract and
locality policy and supply its lifecycle/NV behavior; the defaults stay gated.

GetRandom #53 at `5ea744ad60a91622c29c854e69c420bda1511401` is separate.
It adds engine dispatch states 12/13 and response/address selection, CRB
routing/buffering and TPM_TOP RNG/shared-SHA wiring. These overlap the engine,
CRB and top-level areas touched by the PCR Read stack and Extend. No GetRandom
code is bundled here. Integration must preserve its random route alongside
PCR states 10/11, merge the address/response muxes and packet capture, preserve
all raw/PCR/RNG SHA requesters, and rerun the combined regressions. A merged
GetRandom/Extend combination has not been simulated in this PR.

### Phase Three handoff (required before production PCR mutation)

Phase Three must replace the narrowly scoped, configured empty-password path
with real authorization/session validation and locality policy **before PCR
mutation**. It owns external NV and profile-defined Startup, Reset, Shutdown,
save and restore behavior, including restart/resume. It must preserve atomic
bank/update-counter consistency and add end-to-end authorization/locality
rejection and resume testing. Preserve the Phase One authorization interface
and replace this static policy at the admission seam, without treating legacy
auth stubs as permission. This is a handoff only; Phase Three is not implemented
here. PCR_Reset, PCR startup-profile initialization, resume/NV and general
authorization remain separate work. PCR_Event and sequence commands are a
separate command inventory outside the Extend diff.
