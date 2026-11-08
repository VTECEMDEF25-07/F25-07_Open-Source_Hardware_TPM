# RAM-backed EncryptDecrypt2

`symmetric_ram_top` connects `encrypt_decrypt2_ram_controller` to the unchanged
16-byte AES-256/CFB worker. The legacy `symm_top` session path is unchanged.

## Parameters and jobs

- `MAX_SYM_DATA_BYTES`: 1..65535, default 1024; internal counters derive from it.
- `RAM_ADDR_WIDTH`: 1..32, default 12; byte addresses, independent of payload capacity.
- Length and completed-length ports are unsigned 32-bit values. Oversize requests
  are rejected before narrowing. Invalid build parameters fail elaboration.
- Builds below 1024 bytes are reduced configurations. Integration must report the
  actual capacity, size command/response storage for payload plus overhead, and
  enforce TPM total packet limits.

With `busy_o=0`, assert `start_i` with key, IV, direction, input/output bases and
length. The descriptor is latched at acceptance. The caller supplies an authorized,
resolved AES-256/CFB job. Lower start and wait for busy to fall before the next job;
a held start cannot replay it. Busy stays high through the one-cycle done pulse.
Status, final IV and completed length remain until the next accepted job or reset.

| Outcome | Error / RC | Result |
|---|---|---|
| Success | 0 / 0 | All writes acknowledged; completed length equals request length |
| Invalid length, overflow or overlap | 1 / 0x095 | No RAM/AES access; zero completed length, original IV |
| RAM failure | 1 / 0x101 | Stop after the error response |
| Worker failure | 1 / worker RC | Stop before writing that chunk |
| Empty job | 0 / 0 | No RAM/AES access; zero length, unchanged IV |

RCs are local, unqualified TPM status values; upstream adds parameter/handle
attribution. On failure, completed length counts successful write acknowledgments,
even within a partial chunk; final IV covers fully acknowledged chunks, or the
original IV if none completed.
Discard failed output: a failed write may still have physical side effects.

## Byte RAM contract

Requests carry valid/ready, write flag, address and 8-bit write data; responses
carry valid/ready, 8-bit read data and error. Transfers occur on rising edges with
valid AND ready. Hold each channel stable while stalled. Exactly one response is
required per accepted request, **including writes**, with one transaction outstanding.
An immediate response must remain valid until consumed in the following wait state.
There is no timeout; a nonresponding adapter requires coordinated reset.

The caller reserves both regions throughout the job and publishes output only on
success. Regions must be disjoint or exactly in-place; other overlap is rejected.
Widened base-plus-length checks allow an exclusive end equal to the address-space
size, but reject overflow. Every chunk is fully read before any of it is written.

Only the final chunk may be partial. Bytes are MSB-first on worker buses and follow
increasing RAM addresses. Final IV is the last ciphertext chunk, zero-padded if
partial; empty jobs preserve the input IV, matching [TPM CryptSym.c](https://github.com/microsoft/ms-tpm-20-ref/blob/main/TPMCmd/tpm/src/crypt/CryptSym.c).
A partial-command boundary does not preserve unused ordinary CFB keystream bytes.

Reset aborts the job and clears metadata. **The adapter must jointly flush pending
requests/responses before reset release**: untagged stale responses cannot be
identified. Completion clears controller temporary secrets/data; worker result
buses and external RAM remain. The caller owns RAM clearing and failed-output disposal.

Production RAM/arbitration and execution-engine descriptor/wait/response integration
remain future work; the current engine has no completed symmetric RAM path.
