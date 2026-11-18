# Execution engine integration

This branch connects the SPI command/response path to the shared SHA-256
engine and adds a simulation path from a TPM2_EncryptDecrypt2 packet to the
existing AES controller. The two commands share the same packet buffer and
header parsing.

## Command flow

```text
Host → SPI → tpm_io → tpm_crb → TPM_TOP
                                  ├─ Legacy → management + Phase One engine
                                  ├─ Hash → Phase One engine → Hash worker → shared SHA-256
                                  └─ Optional EncryptDecrypt2 → key service → AES

Phase One engine (or optional AES handler) → tpm_crb → SPI → host
```

| File or module | Role |
| --- | --- |
| [`tpm_io.v`](../IO%20Interface/tpm_io.v) | Connects the SPI transport to the command/response buffer and passes down the AES command enable flag. |
| [`tpm_crb.v`](../IO%20Interface/tpm_crb.v) | Reads the common 10-byte header, buffers the remaining bytes for supported commands, and lets the selected handler read them by address. It writes the response header and streams the handler's reply bytes back into the SPI FIFO. |
| [`TPM_TOP.v`](../TPM_TOP.v) | Preserves inherited management/engine routes, passes Hash to the Phase One execution engine, and selects the optional AES handler only when enabled. It connects the engine to the raw SHA requester and exposes the optional AES key-service handshake. |
| [`execution_engine`](execution_engine.v) | Accepts Hash only while idle, captures its tag/code/size/operational state, dispatches the focused worker once, waits for actual completion, and publishes status/length through shared post-processing. Its command-buffer ports carry request addresses and reply bytes. `TPM_TOP` enables `ENABLE_HASH_COMMAND`; the default is zero for existing standalone engine users. |
| [`execution_engine_hash`](execution_engine.v) | Runs as a child of the Phase One engine. Validates the Hash request, streams the message bytes to shared SHA-256, waits for the digest, and formats the digest and null validation ticket. |
| [`execution_engine_aes_packet`](execution_engine.v) | Reads the key handle, password record, input length and data, direction, mode, and IV. It buffers the data, starts the decoded job, and formats the output data, updated IV, and password acknowledgment on success. |
| [`execution_engine_encryptdecrypt2`](execution_engine.v) | Requests the key by handle and waits for the key service. A rejected request returns an error before AES starts. An approved request supplies the resolved key, IV, direction, and buffer descriptor to the symmetric worker. |
| [`symm_top`](../Symmetric%20Module/symmetric_top.v) | Runs the decoded AES job through the existing primitive controller. The worker reads and writes bytes through its RAM interface. The packet handler supplies in-place scratch storage for the current command. |

## Routing compatibility

`TPM_TOP` enables `PRESERVE_LEGACY_COMMANDS` on the IO/CRB wrappers.
Only Hash and EncryptDecrypt2 use scoped packet parsing and dynamic
responses. Other commands retain inherited handle/session parsing,
management/engine dispatch, completion and ten-byte response behavior.
The standalone scoped CRB mode keeps its prior default behavior.

A disabled EncryptDecrypt2 request still reaches the scoped rejection
path and cannot use the legacy authorization placeholders. Legacy
authorization placeholders are preserved for compatibility; this fix
does not establish real authorization or complete TPM semantics for
those inherited commands.

## Supported paths

- **TPM2_Hash** accepts the no-session form with SHA-256 and
  `TPM_RH_NULL`. After Startup, a host can send the message over SPI and
  read the digest and null validation ticket back. The shared hash subsystem
  also has HMAC, PCR, and RNG requesters. This host integration connects the
  raw SHA lane.
- **TPM2_EncryptDecrypt2** supports the tested AES-256 CFB path with a
  16-byte IV, a payload of up to 1024 bytes, and one `TPM_RS_PW` record
  with an empty password. Its enable flag defaults to zero in the normal
  FPGA build. The SPI simulation enables it and supplies a testbench key
  service with a known handle and key.
- **Key generation** is exercised in a separate simulation. That test passes
  the generated key to the decoded AES job. The SPI round trip uses a known
  key so its ciphertext and IV can be checked against fixed expected values.

The scratch buffer holds message bytes for the current job. Key object lookup,
authorization, TPM object and session storage, power detection, and
nonvolatile storage are outside this integration. Enabling the AES host path
for hardware requires a real key service that resolves the handle and
authorizes its use. Session parameter protection is a separate symmetric path.

## Run the simulations

From the repository root, run this in a shell with Questa on your PATH.

```powershell
vsim -c -do 'do {Testing/Simulation/Execution Engine/run_tpm2_hash_command.do}'
```

The runner also requires the installed Questa `altera_mf_ver` and
`lpm_ver` libraries for the unchanged original DE1 SPI bench.

The [runner](../../Testing/Simulation/Execution%20Engine/run_tpm2_hash_command.do)
builds the RTL and runs these checks.

| Pass marker | Coverage |
| --- | --- |
| `TPM2_HASH_COMMAND_PASS` | Hash command handling through the command/response buffer. |
| `TPM2_HASH_SPI_PASS` | Startup and SHA-256 of `abc` over simulated SPI, including digest and ticket checks. The default build also checks that AES requests are rejected. |
| `KEYGEN_ENCRYPTDECRYPT2_PASS` | Generated key handed to the decoded AES job. |
| `TPM2_ENCRYPTDECRYPT2_SPI_PASS` | A 40-byte encrypt/decrypt round trip over simulated SPI, including the returned IV and acknowledgment. Also checks an unknown handle, denied key use, and malformed authorization. |

| `TPM_LEGACY_SPI_PASS` | Unchanged original SPI bench: final entry 240 and zero assertion errors. |

The SPI Hash bench repeats Startup → Hash four times without reset and checks
engine dispatch/ownership/completion directly in both AES configurations.
The command-buffer bench also instantiates the real Phase One engine, checks
empty, 3/55/56/63/64/65/1024-byte digests, rejects 1025-byte and malformed
requests, and verifies busy commands cannot replace the captured header.
It resets the CRB, engine and SHA during streaming and digest wait, checks
for stale completion, and verifies a subsequent `abc` request succeeds.

The Hash route uses its focused no-session validation rather than the legacy
handle/session/authorization placeholders. Phase Three authorization, other hash
algorithms/hierarchies, Lenovo demo changes, and physical hardware verification
are outside this change. Simulation does not establish board timing, synthesis
results, or a hardware SPI round trip.
