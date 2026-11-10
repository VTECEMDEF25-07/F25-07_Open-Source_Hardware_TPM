# Interactive DE25 customer demo — v2

This new flow is separate from the old internal-AES/public-MODEXP demonstration.
It requires the final2048-bit private-RSA customer image and actual same-image
PhaseI acceptance. The original eight enabled suites must complete with unchanged
assertions and no failures. Hardware lead owns programming, image identity,
physical execution and the shared named D2XX hardware mutex.

## One-command customer flow

From a clean checkout with Python cryptography available:

```text
python Testing/Host/de25_customer_demo.py --allow-demo-key-export --phase1-evidence PATH_TO_PHASE1_JSON --image-sha256 EXACT_CURRENT_SOF_SHA256
```

Default transport is the named native Windows D2XX adapter at100kHz. Hardware lead
may set DE25_SPI_HZ=1000000 after acceptance. No driver install or FPGA program is
performed. Existing transport factory resets the crypto subsystem at session start.
Use `--record-dir AI/tmp/customer-rehearsal` to preserve actual public events and
results; use `--auto --message "Hello Lenovo"` for a scripted genuine recording.
`--rsa-message` can select a separate RSA recording message.

The program displays actual8/8 PhaseI results first, explicitly acknowledges
disposable AES256 DEMO key export, asks for an AES UTF8 message (up to1024 bytes),
encrypts on the LAPTOP with cryptography AES256-CFB128, sends ciphertext/IV to the
FPGA and verifies actual returned plaintext/IV. It then requests real FPGA RSA2048
generation, receives n/e only, asks for a <=240-byte RSA UTF8 message, encrypts with
the FPGA public key on the LAPTOP, and verifies actual FPGA PRIVATE-decrypt output.
There is no customer public-MODEXP or key-deletion showcase. RSAGEN internally
clears/replaces the previous AES context under the hardware contract.

AES export is intentionally disposable DEMO ONLY, gated by both explicit command
flag and immutable hardware capability. AES bytes are not printed or included in
the public recording. Python host-copy wiping is best effort, not a secure-erasure
guarantee. RSA d/p/q are never imported/exported by the customer client. Private
fixture arithmetic exists only in test modules and is not hardware evidence.

RSA encoding is exactly256 bytes BE:00 + ASCII DE25 + u16BE message length +
UTF8 bytes(max240) + zero tail. FPGA validates the complete decrypted block before
returning any actual message bytes. This is an educational deterministic raw-RSA
format, not OAEP/PKCS or a generally secure message protocol. Default provider is
FRESH_UNQUALIFIED; TEST requires explicit selection and is visibly labeled.

## Actual hardware status and LCD relay

New transport polls the read-only locality0 status region D40F80 while commands
are busy and while a customer types. It accepts only matching LE sequence
bookends. No host-derived progress state is synthesized. Changed real snapshots
are recorded; identical real snapshots may be relayed as liveness heartbeats.

LCD owner/lead must validate the actual HPS connection and ST7567 display. Once
they supply a working command to run that service, set DE25_LCD_COMMAND_JSON to
an explicit argv JSON list (for example the lead's verified SSH invocation), then
add `--status-relay de25_customer_lcd_relay:factory`. Optional
DE25_LCD_RELAY_LOG records that child command's output. No shell is used. A bounded
relay prevents a stalled pipe from blocking SPI indefinitely. Pipe/telemetry
success is not proof of physical LCD glass; summary records that gate separately.

## Software checks and evidence limits

```text
python -B -m unittest discover -s Testing/Host -p "test_de25_customer_*.py" -v
```

Checks cover NIST AES known-answer ciphertext, byte/UTF8 bounds, exact raw frame,
existing TEST RSA fixture/public encryption, strict capabilities/mode/export/ID/
length/error checks, actual snapshot coherence and wrong-plaintext rejection.
The software board model never opens hardware and is not a board pass. Final
hardware/source/image metrics and genuine backup video remain separate gates.
