# Symmetric module organization

Author: Makeda Solomon 
Date: October 13, 2026

`symm_top` accepts one internal job at a time. It does not parse SPI packets; it assumes
the execution engine will handle the host's incoming bytes and organizing that information for the 
symmetric module. This module does not take a TPM handle, such as the key's handle, to identify 
the location of the key; for the EncryptDecrypt2 command, it assumes the key is directly fed into
the symmetric module. It also does not check if a key is valid; it assumes the execution engine will
communicate with the symmetric module to idenitfy if a key cannot be used for the symmetric module.
The symmetric module does not create a key obkect. It assumes that has been created and the necessary 
fields from the object is sent directly to the symmetric module.

```text
symm_top
  |
  +-- session_parameter_controller
  |     |
  |     +-- CFB: kdfa_control + HMAC -> AES key and initialization vector (IV) -> shared cfb_block
  |     |
  |     +-- XOR: kdfa_control + HMAC -> mask -> XOR data here (no AES)
  |
  +-- encrypt_decrypt2_controller
        |
        +-- supplied object key and command IV -> shared cfb_block
```

## Read these files in order

1. `symmetric_top.v`: selects and remembers which controller owns the job.
2. `session_parameter_controller.v`: captures and protects a complete session parameter.
3. `encrypt_decrypt2_controller.v`: validates the decoded cipher job.
4. `cfb_block.v`: performs one AES-256/CFB chunk using supplied key/IV.
5. `kdfa_control.v`: builds variable-length HMAC messages and collects derived material.
6. `aes_core.v, aes_decipher_block.v, aes_encipher_block.v, aes_inv_sbox.v, aes_key_mem.v, aes_sbox.v, aes.v`:
Advanced Encryption Standard derived from the [secworks](https://github.com/secworks/aes) open-hardware cryptography project managed by Joachim Strombergson.

## What the caller supplies

For session-based encryption/decryption, set `session_protect_i=1`. Supply a validated session,
the actual session value, correctly ordered newer/older nonces, direction,
data and byte count. Set `session_use_xor_i` to choose XOR; otherwise select
CFB (`mode_i=1`). This controller derives material internally. The legacy
`session_mask_i` port is ignored. For XOR, `iv_out_o` passes through `iv_i`
only for interface compatibility; XOR does not use an IV.

For primitive encryption/decryption, set `session_protect_i=0`, `command_code_i=16'h0193` and
`mode_i=1`. Supply an authorized, loaded AES-256 object's secret key through
`key_i`, the command IV through `iv_i`, direction, data and byte count.
Upstream logic must resolve the handle and effective mode before this job.
The small mode/command ports here are internal conventions, not wire-format
TPM structures.

Present all inputs before a rising edge with `start_i=1` and `wait_o=0`.
Inputs are captured on that edge. `done_o` pulses for one cycle with the
result/status available. Lower `start_i` and wait for `wait_o=0` before the
next job. A held start does not replay the completed job. Reset aborts all
controllers and the shared worker. These internal controllers are owned
by the wrapper and their CFB requests are issued only when its worker is idle.

All byte buffers are left aligned, with the first valid byte at the bus MSB.
Set `session_value_bytes_i`, `nonce_newer_bytes_i`, `nonce_older_bytes_i`, and
`data_bytes_i` explicitly. Unused bytes are excluded from HMAC and the returned
parameter. A zero-length secret or nonce uses length zero. Secret and nonce
lengths are byte counts, excluding any TPM2B size prefix. The caller assembles
the actual session value, including `sessionKey || authValue` when required.

The defaults provide capacity for 1024 data bytes, 128 secret bytes, and 64
bytes per nonce. These are configurable `MAX_DATA_BYTES`, `MAX_SECRET_BYTES`,
and `MAX_NONCE_BYTES` parameters. `symm_top` requires `MAX_DATA_BYTES >= 16`.
The current top-level compatibility buffer and derived XOR mask use registers.
Device resource usage and timing need synthesis review for the target board.
The supported session algorithms remain SHA-256 and AES-256/CFB128 or XOR.
Upstream session validation must enforce those negotiated algorithms and their
nonce constraints. Buffer capacity does not advertise additional algorithms.

## Connecting the HMAC service

Instantiate one `symm_top` beside the shared `hash_subsystem`. Connect matching
`hmac_*` signals, removing the `_i`/`_o` suffix at the hash subsystem boundary.

| Symmetric port | Hash subsystem port | Direction from symmetric |
|---|---|---|
| `hmac_start_o` | `hmac_start` | Output |
| `hmac_busy_i` | `hmac_busy` | Input |
| `hmac_key_data_o`, `hmac_key_valid_o`, `hmac_key_end_o` | `hmac_key_data`, `hmac_key_valid`, `hmac_key_end` | Output |
| `hmac_key_ready_i` | `hmac_key_ready` | Input |
| `hmac_message_data_o`, `hmac_message_valid_o`, `hmac_message_end_o` | `hmac_message_data`, `hmac_message_valid`, `hmac_message_end` | Output |
| `hmac_message_ready_i` | `hmac_message_ready` | Input |
| `hmac_digest_i`, `hmac_digest_valid_i` | `hmac_digest`, `hmac_digest_valid` | Input |
| `hmac_digest_ready_o` | `hmac_digest_ready` | Output |

The KDFa controller waits for `!hmac_busy`, pulses start once, then transfers key bytes
and message bytes on their respective `valid && ready` handshakes. End is sent
with the final byte. An empty key sends end alone. Stalled bytes/end remain
stable. KDFa consumes the digest on the digest handshake. Both
subsystems must share a clock and reset. Reset aborts ownership and requires
the coordinator to retry the job.

The HMAC port has a single start/busy interface. Give it exclusive ownership
from start through digest acceptance. Other HMAC clients, such as authorization,
need a coordinator or transaction arbiter. The SHA request arbiter inside
`hash_subsystem` arbitrates PCR/HMAC/raw SHA requests. It does not arbitrate
multiple callers of the HMAC front end. PR #39 exposes no HMAC error signal,
so its declared interface provides completion and reset recovery. Service
failure/timeout policy belongs to the coordinator.

The local `../Hash Module/hmac_sha256.v` now implements the HMAC interface
declared at hash commit `a0a5986`. It buffers up to one 64-byte key block,
streams longer keys through SHA-256 for normalization, then hashes the inner
and outer HMAC messages through the shared engine. It holds its final digest
until accepted and clears its own key/intermediate registers before publishing
that result. Reset the HMAC client and shared SHA engine together.

Add `hmac_sha256.v` to the appropriate production
source lists alongside the shared SHA files. The complete `hash_subsystem`
wrapper also needs `pcr_controller` and `pcr_registers`, which remain absent
from the reviewed hash branch. The placeholder is used only by legacy standalone
KDFa control tests. The board-only demo rejects session requests because it has
no connected HMAC service.

## Current scope

- AES-256 and CFB128 only for the cipher operation.
- Session jobs contain 0 through `MAX_DATA_BYTES` bytes. Primitive
  EncryptDecrypt2 jobs retain their 0 through 16 byte limit.
- CFB derives 384 bits using the `CFB` label. XOR requests `data_bytes*8`
  bits using the `XOR` label and consumes the leading digest bytes.
- CFB derives once per complete parameter and carries ciphertext feedback
  through successive full blocks. Only the last chunk may be partial. Final
  `iv_out_o` contains ciphertext feedback, padded with zeros after a short chunk.
- XOR uses the full parameter bit count in every KDFa message and advances
  the counter for each SHA-256 digest. It consumes the continuous mask once.
- Empty parameters return immediately without HMAC or AES work.
- Session decrypt/encrypt flags describe this one internal job's direction;
  they are not the full command's session-attribute field.

## Command scheduling

The execution engine now has a primitive EncryptDecrypt2 worker handshake.
Connect it to `symm_top` when the decoded object and parameter inputs are ready.

| Execution engine port | Connection |
|---|---|
| `execution_ready_i` | Decoded job valid AND `!symm_top.wait_o` |
| `command_start_o` | `symm_top.start_i`; one acceptance pulse for EncryptDecrypt2 |
| `command_done_i` | `symm_top.done_o` for the selected primitive operation |
| `execution_response_code_i[31:0]` | Zero-extended `symm_top.tpm_rc_o[11:0]` |
| `execution_data_i[127:0]`, `execution_iv_i[127:0]` | Primitive result data and IV |
| `execution_result_valid_o` | Captured completion record, including errors |
| `execution_result_code_o`, `execution_data_o`, `execution_iv_o` | Held status/data/IV for the response writer |

The response writer consumes the captured record. A worker error clears the
captured data and IV. The record survives worker-output changes and is cleared
on reset or admission of the next command. Keep command metadata stable until
command completion. For a wide `symm_top` instance, connect its most significant
128 result bits to the primitive data input, or use `MAX_DATA_BYTES=16` for a
primitive-only instance. Other engine commands retain their existing launch
behavior.

`TPM_TOP.v` currently holds primitive `execution_ready_i` low because decoded
key/parameter and response-buffer wiring are still pending. Complete that
wiring before exercising this command on the board. The engine regression
uses decoded object/session fixtures and real AES through normal command
admission; it does not test SPI parsing, real authorization, or response bytes.

```powershell
python 'Execution Engine/Testbenches/run_execution_primitive.py' --build C:/MDE/review_work/execution_primitive_test
```

A command can require several jobs: session-decrypt its input parameter,
execute the command using the object key, then session-encrypt its output.
Upstream command logic schedules these jobs sequentially. The wrapper does
not perform that entire sequence automatically.

Key generation is separate: it supplies material for creating a new key
record. Later object lookup can provide that record's key to `key_i`.

## Specification references and verification

TPM 2.0 revision 1.59 Part 1, clauses 11.4.7.3 and 21, define XOR masks and
session protection. Part 3, clause 15.3, defines EncryptDecrypt2 inputs.

Use the Revision 1.59 Parts 1, 3 and 4 documents in the previous versions
section of the [TCG TPM library](https://www.trustedcomputinggroup.org/resources/documents/tpm-library-specification).

Run `Testbenches/run_symmetric_top.do` in Questa for integration coverage.
Run `Testbenches/run_kdfa_control.do` for the existing CFB KDFa handshake suite.

Run the cryptographic integration regression from the repository root.

```powershell
python 'Symmetric Module/Testbenches/run_session_hash_integration.py' --build C:/MDE/review_work/session_hash_test
```

This regression uses Python HMAC-SHA256 on the bytes actually accepted by the
external interface, and independent Python KDFa/OpenSSL AES-CFB expectations.
It covers variable/empty inputs, multi-block CFB/XOR, the configured maximum,
input stalls, held start, captured inputs, invalid bounds and shared reset.
Its HMAC service is simulation-only. Physical FPGA acceptance requires real
HMAC RTL, synthesis/timing checks and tests of the connected command path.

Run the hardware HMAC regression and then the same session suite using the
actual HMAC/SHA RTL instead of the Python service.

```powershell
python 'Hash Module/Testbenches/run_hmac_sha256.py' --build C:/MDE/review_work/hmac_rtl_test
```

The runner copies pinned SHA sources from local Git objects into its build
directory. The HMAC tests include the seven RFC 4231 vectors, key and SHA
padding boundaries, separate end markers, source gaps, digest stalls, reset
phases, and interleaved raw SHA requests. Python and OpenSSL supply independent
expectations for the session regression. FPGA fit and physical tests remain
separate acceptance steps.

For separate module tests and waveform instructions, start with
`Testbenches/WAVEFORM_GUIDE.md`. The standalone suites cover real CFB (7 cases),
session preparation with fake HMAC/mock CFB (12 cases), and cipher-command
control with mock CFB (9 cases).

### RAM-backed session parameter

Set `parameter_base_i` and `data_bytes_i` to the in-place byte range.
The controller uses the same byte request/response handshake as PR #46.
Every accepted read or write receives one response, held until ready.
The controller writes each processed chunk back before starting the next.
The caller reserves the range and consumes it only after successful completion.
A failed job can leave partial writes. Reset must also flush pending buffer
transactions before reuse.

`symm_top` bridges its existing packed payload ports to the byte interface
with a local buffer. A direct connection to shared command RAM can replace
that bridge when the execution engine supplies buffer addresses. The session
controller keeps its current payload chunk locally. XOR still holds its
derived mask in registers.
