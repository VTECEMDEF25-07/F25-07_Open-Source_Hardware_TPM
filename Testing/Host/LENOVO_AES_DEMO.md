# Lenovo deterministic AES demo

This branch starts from GitHub main `cb965dc31d6b1af1153a79798502fbbbcb622099`.
It includes the command routing preservation from PR #51 and engine-owned Hash
from PR #52, then routes EncryptDecrypt2 through the same Phase One engine.
The previous Lenovo branch is preserved as
`archive/lenovo-demo-before-aes-20261118` at `37daefd`.

## Hardware flow

After reset, `demo_test_source` hashes the 15-byte domain `KEYGEN-TEST-v1\0`,
32 zero seed bytes and an eight-byte big-endian counter starting at zero.
`lenovo_aes_key_service` sends the first eight words through the existing
Phase Two `keygen_aes_core` AES-256 assembly interface. It receives the full
key, accepts ownership, and waits for successful terminal status before making
handle `0x80000000` available. The same key is regenerated after every reset.
This is a public, predictable test key.

The laptop derives that same test key, encrypts the entered UTF-8 message using
AES-256 CFB128 with a random IV, and sends standard `TPM2_EncryptDecrypt2`
(`0x193`) over SPI with the handle, ciphertext and IV. The Phase One engine
captures the command header, dispatches its existing AES packet handler, waits
for the actual symmetric worker, and publishes completion through the existing
command/response buffer. The client compares the returned plaintext and final IV.

The demo key slot permits an empty password session for its public test handle.
Unknown handles return an error. Messages may contain up to 1024 UTF-8 bytes.
This deterministic seed produces a different key from the published NIST vectors.

## Run

Build `Project/DE25/de25_soc_top.qpf` with Quartus Pro and program the DE25 with
the resulting image after checking its timing report. The DE25 wrapper enables
AES and connects the deterministic key service. Use the existing USB-adapter
SPI wiring and the named FT232H adapter `FTA6H280`.

Install the host dependency using the Python interpreter used for the demo.

```powershell
py -3 -m pip install cryptography
py -3 Testing/Host/lenovo_aes_demo.py
py -3 Testing/Host/lenovo_aes_demo.py --message "Hello Lenovo"
```

Opening the native transport resets the TPM. The client then sends Startup
before accepting messages. The default SPI rate is 100 kHz. Set `DE25_SPI_HZ`
to `1000000` to use 1 MHz after verifying that rate on the programmed image.
The adapter and pin configuration follow `de25_d2xx_transport.py`.

## Verification

```powershell
vsim -c -do 'do {Testing/Simulation/Execution Engine/run_tpm2_hash_command.do}'
py -3 -B -m unittest discover -s Testing/Host -p test_lenovo_aes_demo.py -v
```

The Questa runner checks the original Phase One SPI bench to entry 240 with
zero errors, Hash command parsing and reset recovery, AES enabled and disabled
SPI paths, and the actual deterministic source/keygen/key-slot path. It checks
40-byte ciphertext against an independent SHA-256/AES reference and exercises
empty, 1/15/16/17/1024-byte encrypt/decrypt requests over SPI.
The offline Python tests check packet encoding, UTF-8 bounds, reply validation
and detection of incorrect returned plaintext. Physical board acceptance must
be performed with the newly compiled image.

Local validation on November 18, 2026 passed the complete Questa runner,
including key-service reset/backpressure, all six SPI boundary lengths and
the legacy entry-240 check, plus all five Python tests. Quartus Pro 26.1.1
synthesis passed with zero errors and 16 warnings. Full fitting stopped at
license error 119013 for A5ED013BB32AE4SCS, so routed timing and physical
board operation remain pending.

## PR #53 RNG integration

Phase One GetRandom, raw-source health monitoring and the shared-SHA DRBG
service are integrated. GetRandom uses engine states 14/15 alongside AES at
12/13. ENABLE_GETRANDOM defaults to zero, matching the upstream board policy.
The AES key remains derived from the public deterministic seed. Feeding fresh
RNG output into AES requires an internal request arbiter and a held 256-bit
block converted to eight generation words, with RNG faults propagated through
generation_failed. The laptop encryption flow must then receive a disposable
demo key or use FPGA encryption before requesting FPGA decryption.
