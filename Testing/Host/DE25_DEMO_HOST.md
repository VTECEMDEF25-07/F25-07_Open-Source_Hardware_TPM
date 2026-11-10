# Historical DE25 bounded crypto demo

**Current customer flow:** see [DE25_CUSTOMER_DEMO.md](DE25_CUSTOMER_DEMO.md).
The current board project supports actual FPGA RSA2048 generation/private
decryption and disposable AES256 DEMO export. The instructions below describe
the earlier internal-AES/public1024 fallback images and require their matching
historical configuration; they do not describe the current board build.

The DE25 project explicitly enables the demo with a **50 MHz core**, **1024-bit
public modular exponentiation**, and the experimental **FRESH_UNQUALIFIED**
provider (`DEMO_PROVIDER_MODE=0`). RTL defaults keep the demo disabled. AES key
generation remains **256 bits**; 1024 describes only the public MODEXP operands.

The FPGA generates an AES key into protected volatile storage and returns only
a handle. The host encrypts/decrypts a public message, checks IV handling and
SHA-256 independently, flushes the handle and checks its rejection, then compares
all 128 bytes of the public MODEXP result with Python `pow`. Reset destroys the
volatile objects. There is no key-read or host-seed command in this demo.

## Run the currently configured fresh image

After building, checking timing and loading the matching DE25 image, run from
`Testing/Host` on Windows:

```powershell
python de25_crypto_demo.py --transport de25_d2xx_transport:factory --expected-modexp-width 1024 --expected-provider fresh-unqualified --repeat 2 --evidence result.json
```

Requires Python with `cryptography`, the installed native D2XX driver/library,
and the named FTDI adapter `FTA6H280`. The transport uses SPI mode 0 at 100 kHz
by default; `DE25_SPI_HZ=1000000` explicitly selects the other validated speed.
It acquires the shared `Local\CodexDE25Hardware` mutex, resets the TPM before
Startup and closes/releases its outputs afterward. It does not install drivers
or program the FPGA. Do not contend with another hardware owner.

Expected output identifies `FRESH_UNQUALIFIED`, the exact 1024-bit capability,
two AES/IV/plaintext/SHA/flush-denial PASS rounds and a MODEXP/Python PASS.
The provider must match explicitly before generation. There is no silent TEST
substitution, width fallback or truncation.

Fresh cipher verification is a **roundtrip**, with independent SHA checks; the
secret key is never exported for a known-key cipher oracle. The deterministic
TEST provider uses a public fixture and additionally checks ciphertext against
an independent AES implementation. Select `--expected-provider test` only for
a matching TEST image. Host defaults require TEST and 2048-bit MODEXP, so the
explicit arguments above are required for the current DE25 configuration.

## Recorded hardware validation and limits

Both TEST and experimental fresh configurations passed on DE25 at **100 kHz and
1 MHz**: two AES-256 generation/encrypt/decrypt/IV/plaintext/SHA/flush-denial
rounds and public 1024-bit MODEXP/Python comparison per speed. Each speed began
with reset and Startup. Two separate fresh Generate contexts used the same
public message and IV; ciphertexts differed at both speeds. This observation
does **not** establish entropy quality, independence or min-entropy.

Health-qualified remains false. No `capture_90b.py` hardware dataset collection
or SP 800-90B entropy assessment was completed for this demo. Successful RSA
key-pair generation and 2048-bit hardware operation are not demonstrated.
The 2048-bit design fits but fails 50 MHz setup timing: a modulus-precompute
path took 28.278 ns against a 20 ns period. That image was not programmed.

| Tested profile | Source commit | Core setup margin | Physical SPI |
|---|---|---|---|
| Public deterministic TEST | `194354378815ad122b966a37249aa15ab7e858cf` | +0.102 ns | 100 kHz, 1 MHz PASS |
| Experimental FRESH_UNQUALIFIED | `5d39a28dc7a048be2aaf1100a1eefa875cd85e12` | +0.223 ns | 100 kHz, 1 MHz PASS |

Fresh tested tree: `b0d899fc4d8bc9ccec6efbbf8b82715ce01a9b93`.
The publication documentation commit changes only this Markdown file; tested
RTL, board configuration, host implementation and test sources are unchanged.
Original author comments and Git history are retained; demo integration and
verification were Codex-assisted.

Quartus Pro 26.1 builds and four-corner setup/hold/recovery/removal/pulse, SPI
mailbox/synchronizer/unconstrained, clock and structure audits passed. Physical
post-fit connectivity confirmed four closed inverting Intel logic loops at
fitted locations, their XOR feeding sampler 0, and sampler 0 Q solely feeding
sampler 1 D. The checked asynchronous exception targets only sampler 0 D;
interstage and reset recovery/removal remain timed. These checks prove retained
topology, not entropy quality. Original autonomous cooling RTL was unchanged;
no temperature/RPM telemetry is claimed. Programming was volatile only.

Generated SOFs and local build/capture artifacts are intentionally not included.
Recorded SOF SHA-256 fingerprints:

- TEST: `906ee00c087b593e6149bc9f11a375923b0e38391fea689dc409ee4890dfedf1`.
- Fresh: `a8460feb596d5469fc7f9a216e49bc83cd0ddddbda161456cc9404983b215bac`.

## Explicit public MODEXP width

The host defaults to expecting the full2048-bit portable target. The approved
bounded DE25 configuration must be requested explicitly:

```text
python de25_crypto_demo.py --transport module:factory --expected-modexp-width 1024 --evidence result.json
```

The factory supplies the hardware owner's locked FIFO/SPI transport. CAPS and
MODEXP results must advertise the exact expected width. There is no automatic
fallback or truncation. Choices256/1024/2048 are accepted only when the caller
expects them;256 is a possible future explicit configuration, not a board claim.
Packet operands and result lengths derive from the matched actual capability.

For1024 bits: B=128, public byte-RAM layout0/128/256/384 (base/exponent/modulus/
result), request410 bytes and response166 bytes. AES256,1024-byte payload
capacity, TEST_DETERMINISTIC and FRESH_UNQUALIFIED labels remain unchanged.
Output identifies1024-bit public MODEXP and makes no2048-bit hardware claim.

Run `python test_de25_crypto_demo_width.py` for focused software-only capability,
layout/length, mismatched-width rejection and visible-claim checks. The scripted
empty-message flow is a host protocol test, not RTL or physical acceptance.
`python de25_crypto_demo.py --self-test` retains independent NIST AES and public
test-key fixtures. Hardware owner performs configured RTL/build/physical gates.
