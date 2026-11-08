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
  +-- encrypt_decrypt2_controller
        |
        +-- supplied object key and command IV -> shared cfb_block
```

## Read these files in order

1. `symmetric_top.v`: selects and remembers which controller owns the job.
2. `session_parameter_controller.v`: prepares session CFB or XOR inputs.
3. `encrypt_decrypt2_controller.v`: validates the decoded cipher job.
4. `cfb_block.v`: performs one AES-256/CFB chunk using supplied key/IV.
5. `kdfa_control.v`: builds HMAC messages and collects derived material.
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

## Current scope

- AES-256 and CFB128 only for the cipher operation.
- Each job contains 0 through 16 bytes, first valid byte at the bus MSB.
- Secret and nonces remain fixed at 32 bytes. No variable-length interface
  or multi-block buffer controller has been added in this refactor.
- CFB derives 384 bits using the `CFB` label. XOR requests `data_bytes*8`
  bits using the `XOR` label and consumes the leading digest bytes.
- `aes_key_o` in the KDFa interface carries either the CFB key or the XOR
  digest. The session controller selects the relevant leading mask bytes.
- The HMAC instance is still a **fake placeholder**. Tests check integration
  and real AES, not cryptographically correct KDFa/HMAC.
- Partial CFB feedback preserves the existing zero-filled convention;
  it is not a complete TPM continuation implementation for partial chunks.
- Session decrypt/encrypt flags describe this one internal job's direction;
  they are not the full command's session-attribute field.

## Command scheduling

A command can require several jobs: session-decrypt its input parameter,
execute the command using the object key, then session-encrypt its output.
Upstream command logic schedules these jobs sequentially. The wrapper does
not perform that entire sequence automatically.

Key generation is separate: it supplies material for creating a new key
record. Later object lookup can provide that record's key to `key_i`.

## Specification references and verification

TPM 2.0 revision 1.83 Part 1, clauses 11.4.7.3 and 21, define XOR masks and
session protection. Part 3, clause 15.3, defines EncryptDecrypt2 inputs.

- https://trustedcomputinggroup.org/wp-content/uploads/TPM-2.0-1.83-Part-1-Architecture.pdf
- https://trustedcomputinggroup.org/wp-content/uploads/TPM-2.0-1.83-Part-3-Commands.pdf

Run `../../Testing/Simulation/Symmetric Module/run_symmetric_top.do` in Questa for integration coverage.
Run `../../Testing/Simulation/Symmetric Module/run_kdfa_control.do` for the existing CFB KDFa handshake suite.

For separate module tests and waveform instructions, start with
`../../Testing/Simulation/Symmetric Module/WAVEFORM_GUIDE.md`. The standalone suites cover real CFB (7 cases),
session preparation with fake HMAC/mock CFB (12 cases), and cipher-command
control with mock CFB (9 cases).
