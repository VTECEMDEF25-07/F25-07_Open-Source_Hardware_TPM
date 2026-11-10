# Interactive DE25 customer demo — v2

This new flow is separate from the old internal-AES/public-MODEXP demonstration.
It requires the final2048-bit private-RSA customer image and actual same-image
PhaseI acceptance. The original eight enabled suites must complete with unchanged
assertions and no failures. Hardware lead owns programming, image identity,
physical execution and the shared named D2XX hardware mutex.

## One-command customer flow

From a clean checkout with Python cryptography available:

```text
python Testing/Host/de25_customer_demo_launcher.py --phase1-runner ABSOLUTE_VERIFIED_NATIVE_RUNNER --source-commit FROZEN_PROGRAMMED_IMAGE_COMMIT --image-sha256 EXACT_CURRENT_SOF_SHA256 --record-dir NEW_CAPTURE_DIRECTORY --allow-demo-key-export
```

The launcher actually executes all eight original hardware suites first, using
the frozen native runner's argv-list ABI (`--label`, `--source`, `--sof-sha256`,
`--hz`). The runner owns the hardware mutex and releases it before crypto starts.
Fresh timestamps, all eight original raw-log completion rows, assertion totals,
unchanged-body/source audit, executable hash, same source/image and successful
exit are required. Failed or saved results cannot admit the customer transport.
The native runner is project-local at `AI/tmp/overnight-phase1-20261110/run_phase1.py`.
Its output label and the capture directory must be new; neither is reused.

Both stages default to1MHz through the named native Windows D2XX adapter; use
`--spi-hz 100000` only for an accepted slower profile. The launcher forwards the
chosen rate to the crypto child's `DE25_SPI_HZ`. Both child Python processes use
explicit UTF-8 for input/output, including redirected recordings. No driver install or FPGA program
is performed. Supply the actual frozen programmed image commit/hash, even if a
later host-only commit changes checkout HEAD. Existing transport factory resets
the crypto subsystem at session start.
Use an absolute new capture directory under the class `AI/tmp/` to preserve public
events and results; use `--auto --message "Hello Lenovo"` for a scripted genuine recording.
`--rsa-message` can select a separate RSA recording message.

The recording contains `launcher.result.json`, `phase1-runner.stdout.txt`, and
byte-preserved `phase1/result.json` plus the full original `phase1/hardware.log`
before the ordinary customer `events.json`, `stdout.txt` and `summary.json`.
`de25_customer_demo.py` remains the lower-level crypto component: it validates and
displays saved evidence but does not execute Phase I itself. Use the launcher for
the requested complete one-command customer rehearsal.

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
