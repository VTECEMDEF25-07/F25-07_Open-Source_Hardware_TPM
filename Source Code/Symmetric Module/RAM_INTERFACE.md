# RAM-backed EncryptDecrypt2 contract

## Scope and parameters

`symmetric_ram_top` owns one `encrypt_decrypt2_ram_controller` and one unchanged
16-byte `cfb_block`. It is a standalone symmetric-subsystem integration top,
not a replacement for the legacy session-oriented `symm_top`. Only resolved,
authorized AES-256/CFB128 jobs belong here; no SPI, TPM wire parsing, key lookup,
mode selection, HMAC or session lifecycle is implemented by this interface.

- `MAX_SYM_DATA_BYTES`: 1..65535, default 1024. Length/offset registers derive
  from this bound and represent both zero and the full capacity. No payload
  RAM is allocated internally, so capacity does not prescribe packet RAM depth.
- `RAM_ADDR_WIDTH`: 1..32, default 12, independent of payload capacity.
  Addresses name bytes in a flat address space of `2**RAM_ADDR_WIDTH` bytes.
  Invalid build parameters fail elaboration. The simulation model uses a small
  address space; its depth derives from its address-width parameter.
- `data_length_i`: unsigned 32-bit request length, validated before narrowing.
  The wider port permits explicit oversize rejection, including `0xffffffff`.
  `completed_length_o` is also 32 bits. No descriptor length is silently masked.

Reduced builds below 1024 bytes are application/demo configurations, not a
conformant TPM MAX_BUFFER configuration. Future capability reporting must match
implemented capacity. The 65535 upper bound follows the TPM2B size-field range;
it does not imply that a complete packet of that size is supported. Integration
must bound total command AND response storage for payload plus headers, handles,
authorization/session areas, IV and other parameters, and enforce TPM total packet
limits. No capability-reporting or packet-buffer implementation is added here.

## Descriptor and result

Present `key_i[255:0]`, `iv_i[127:0]`, `decrypt_i`, `input_base_i`,
`output_base_i` and `data_length_i` before a rising edge with `start_i=1` and
`busy_o=0`. All execution fields are latched at acceptance; later input changes
have no effect. One job is supported at a time. The caller validates command,
key type, key permissions and effective mode before submitting the descriptor.

`busy_o` stays high through the one-cycle `done_o` pulse and release state.
Lower `start_i` and wait for `busy_o=0` before submitting the next job. Holding
start high cannot replay a job. `error_o`, `tpm_rc_o`, `final_iv_o` and
`completed_length_o` remain stable after completion until the next accepted
job or reset. Status is meaningful on/after completion, not during execution.

| Result | Status | Metadata |
|---|---|---|
| Success | error=0, RC=0 | All output writes acknowledged; completed length equals request length |
| Invalid length, overflow or overlap | error=1, RC=0x095 | No RAM/AES requests; completed length zero; original IV |
| RAM error | error=1, RC=0x101 | Stop after consuming the error response; no further requests |
| Worker error | error=1, worker RC | Stop before writing that chunk |
| Empty job | success | No RAM/AES requests; original IV and length zero |

The RC values are local, unqualified TPM status conventions. An eventual
execution-engine adapter must apply correct TPM parameter/handle attribution.
On failure, completed length counts **successful write acknowledgments**, even
within a partially written chunk. Final IV describes the last fully acknowledged
chunk (or original IV if none). Neither field makes failed output resumable.
A failed write may have uncertain physical side effects; discard all failed
job output regardless of these diagnostic counts.

## Memory service

| Channel | Signals | Rule |
|---|---|---|
| Request | `ram_req_valid_o`, `ram_req_ready_i`, `ram_req_write_o`, `ram_req_addr_o`, `ram_req_data_o` | Accepted on rising edge with valid AND ready; write=0 reads, write=1 writes |
| Response | `ram_rsp_valid_i`, `ram_rsp_ready_o`, `ram_rsp_data_i`, `ram_rsp_error_i` | Consumed on rising edge with valid AND ready; data meaningful only for successful reads |

Exactly **one response per accepted request**, including writes, is mandatory.
There is at most one outstanding transaction; a request is held stable until
accepted, followed by a response wait. The adapter holds response valid, data
and error until consumed. A response can become valid as early as the request
acceptance cycle but must be retained until response ready; ready is asserted
in the following wait state. Arbitrary finite request stalls and response
latencies are supported. No timeout is implemented: a failed/nonresponding
adapter requires a coordinated reset.

The controller never completes success until the final write response arrives.
The caller exclusively reserves input/output regions throughout the job. It
must not expose intermediate output as a successful TPM response.

Exclusive base-plus-length ends are checked using widened unsigned arithmetic
before any access. An end exactly equal to the RAM address-space size is legal;
an end beyond it is rejected. Nonempty regions must be disjoint or exactly
in-place. Any other overlap is rejected in either direction. Adjacent regions
are legal. Empty regions may use any representable bases. Each chunk is fully
read before any of its output bytes are written, making exact in-place operation
safe, including decryption.

## CFB feedback and clearing

Chunks are 16 bytes except the final chunk; valid bytes occupy the worker bus
MSB first, and increasing RAM addresses follow that order. Feedback is ciphertext
(output for encryption, input for decryption). Full chunks carry all 16 bytes.
A final partial chunk returns its ciphertext bytes followed by zero bytes;
empty jobs return the input IV unchanged. This matches the explicit final-IV
padding in the TPM reference [CryptSym.c encryption and decryption routines](https://github.com/microsoft/ms-tpm-20-ref/blob/main/TPMCmd/tpm/src/crypt/CryptSym.c).
Only the last chunk within a command may be partial. Carry the returned IV to
a later command as TPM specifies; splitting an ordinary CFB stream after an
arbitrary partial chunk is not equivalent to continuing its unused keystream.

Completion clears the controller's key, chunk input/output and internal feedback
copies. The worker retains its documented result buses until its next start or
reset, while clearing its temporary AES state and expanded keys. Result metadata
and external RAM are intentionally retained. Upstream integration owns policy
for erasing input, failed/consumed output and any command/key storage. Functional
clearing does not establish side-channel or physical security.

## Reset and future execution-engine handoff

`reset_n_i` asynchronously aborts the controller and worker and clears result
metadata. It gates request valid/response ready low. **The RAM adapter must share
this reset/flush boundary and discard pending requests/responses before reset is
released.** There are no transaction tags: a late pre-reset response cannot be
distinguished from a new response. Resetting only the controller and retaining
adapter transactions is unsupported. RAM byte contents need not be erased by
reset, but remain subject to the caller's clearing policy.

Future integration must:

1. Receive/validate the bounded packet, authorize the key and resolve AES-256/CFB.
2. Reserve command/response RAM, submit the descriptor and release start.
3. Keep a real wait state until done, then inspect error/status and length.
4. On success, serialize the payload, final IV and response fields. On failure,
   discard output and apply the memory-clearing policy; then release reservations.

The current `Source Code/Execution Engine/execution_engine.v` has execution and
response-building TODOs, generic `command_start_o`/`command_done_i` signaling,
and incomplete command-specific dispatch/wait handling. It has no completed
symmetric descriptor/RAM path. This PR supplies an integration contract and a
simulated RAM demonstration, not a wired TPM EncryptDecrypt2 command. Production
RAM, arbitration, execution-engine adapters and wait/dispatch fixes remain future
work. No board project or parser is changed; HMAC remains a placeholder.
