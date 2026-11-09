# Symmetric module organization

Author: Makeda Solomon 
Date: October 13, 2026

## Project layout

This directory contains reusable symmetric RTL. Testbenches, Questa runners and the software-HMAC demonstration are in [Testing/Simulation/Symmetric Module](../../Testing/Simulation/Symmetric%20Module/README.md). The standalone DE1 board wrapper is in [Project/DE1/Symmetric Demo](../../Project/DE1/Symmetric%20Demo/README.md).

The existing DE1 and DE25 TPM projects do not yet instantiate this symmetric module. This relocation preserves the current RTL behavior and does not add TPM command integration.

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
  +-- primitive_controller
        |
        +-- supplied object key and command IV -> shared cfb_block
```

## Source layout and job inputs

- `AES/` holds the [Secworks AES RTL](https://github.com/secworks/aes).
- `Controllers/primitive_controller.v` validates a decoded EncryptDecrypt2
  request and processes the buffer in chunks using a supplied key and IV.
- `Controllers/session_parameter_controller.v` uses `kdfa_control.v` to derive
  the CFB key and IV or the XOR mask from session inputs.
- `symmetric_top.v` selects the job, routes its buffer transactions, and shares
  one `Controllers/cfb_block.v` worker between both CFB paths.

Present the descriptor while `busy_o` is low and assert `start_i`. Supply the
buffer addresses and `data_length_i` for either path. For a primitive job,
supply the decoded command code, resolved AES key, starting IV and direction.
For a session job, set `session_protect_i`, supply the validated session value
and ordered nonces with their byte lengths, and use the same input and output
address. See [RAM_INTERFACE.md](RAM_INTERFACE.md) for the byte handshakes.

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
from the reviewed hash branch. The previous placeholder remains as a historical reference. The board-only demo rejects session requests because it has
no connected HMAC service.

## Command scheduling

Upstream logic may schedule session decryption, a direct cipher job, and
session encryption in sequence. Wait for each `done_o`, check `tpm_rc_o`,
and wait for `busy_o` to fall before starting the next job. The caller owns
command parsing, key and session lookup, authorization, and host responses.

## Specification references and verification

TPM 2.0 revision 1.59 Part 1, clauses 11.4.7.3 and 21, define XOR masks and
session protection. Part 3, clause 15.3, defines EncryptDecrypt2 inputs.

Use the Revision 1.59 Parts 1, 3 and 4 documents in the previous versions
section of the [TCG TPM library](https://www.trustedcomputinggroup.org/resources/documents/tpm-library-specification).

See the [simulation guide](../../Testing/Simulation/Symmetric%20Module/README.md)
for the standalone worker, KDFa, session-controller and unified top tests.
