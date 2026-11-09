# DE25 initial integration testing

This branch preserves the reviewed SPI integration plus the standalone
RSA/RNG hardware benchmark and its read-only reset diagnostics. Hardware
testing was stopped at the user's request on November 9, 2026.
It is not a completed 1,000-key qualification or a production clock upgrade.

## Recorded results

| Configuration | Result |
| --- | --- |
| Reviewed TPM SPI integration, 50 MHz core | Eight original C suites passed at 1 and 15 MHz SPI; configured 30 MHz SPI still fails command polling. |
| Small TPM command path, 160 MHz core | Timing passed; eight suites passed three times each at 1 and 15 MHz SPI. RSA generation was inactive. |
| Active RSA datapath, 80 MHz | Timing failed: worst setup slack -4.786 ns. Never programmed. |
| Active RSA datapath, 53.333 MHz, original PLL | Timing passed; three deterministic fixtures and 31 fresh RSA-2048 keys independently verified. Key 32 returned to idle with cleared counters. Run incomplete. |
| Active RSA datapath, 53.333 MHz, reset trace | Compilation and four-corner timing passed. Never programmed: JTAG chain failed during preflight. |

The **31-key partial arithmetic mean is 35.870669297 seconds** per key,
computed from FPGA core plus setup cycles. It excludes result transfer and
host checking. These 31 keys are an interrupted dataset, not the requested
1,000-key result or a stability qualification. The 160 MHz small-command
result does not establish a 160 MHz RSA clock.

The original 53.333 MHz PLL used M=64, C0=60 (3.2 GHz VCO). The diagnostic
project here uses M=32, C0=30 (1.6 GHz VCO) at the same output frequency.
The change is not a proven fix for the interruption. Its minimum audited
slacks are setup +0.590 ns, hold +0.012 ns, recovery +13.279 ns,
removal +0.002 ns, and pulse width +6.716 ns. All ten physical pins and
36 HDL source hashes were checked. See `evidence/rsa53-trace-image.json`
for the original SOF hash and fingerprint.

After the interrupted run, restoration of the reviewed 50 MHz image and all
eight original C suites succeeded. Later, both JTAG and that image's SPI
interface became unresponsive before diagnostic programming. A 6 MHz JTAG
probe also failed; JTAG was restored to 15 MHz, the FTDI kernel driver was
reattached, the hardware lock released, and programmer memory limits returned
to their original values. The user reported no manual reset or reprogramming.
The cause remains unknown. No further board tests are running.

## Source and evidence

The project is a standalone test wrapper around the repository's existing
RSA, RNG, and vendor cooling sources. It uses a 100 kHz diagnostic SPI protocol,
separate from the production TPM protocol. Production algorithm and fan
sources are unchanged. The arithmetic/control path from `peer_reg[4]` to
`odd_part_reg[287]` limited the original RSA clock build.

`batch_test.py` first checks three fixed fixtures, then requests fresh physical
ring/Hash_DRBG RSA-2048 keys. It uses the maintained independent checker with
64 fresh Miller-Rabin bases per prime, key consistency and RSA round trips,
and checks duplicate moduli/shared factors. FPGA n/e/p/q are checked with a
host-derived d; d generation is not part of the measured FPGA operation.
Persisted results contain timings and public modulus digests, not private
factors. Any failure stops the batch without discarding or retrying samples.

The reset monitor retains PLL-lock loss, SPI-reset, board-reset and aggregate
core-reset event counts across functional resets; FPGA configuration clears
them. It exposes registers 48-51, uptime milliseconds at 52, and identity
`RST1` at 54. It never drives functional resets or cooling. Its saved simulation
checks short-pulse capture, held-low counting, reset retention and clear.

`evidence/` preserves timing summaries, the interrupted 31-key JSON dataset,
the last counters before the interruption, reset-monitor simulation output,
JTAG failure evidence, and prior clock/50 MHz benchmark reports. Prior reports
contain historical local artifact paths; those paths are not build dependencies.
Large compiler databases, FPGA binaries and machine-specific NAS deployment
scripts are deliberately excluded.

## Build only

Using Quartus Pro 26.1 from this directory:

```sh
quartus_sh --flow compile benchmark
quartus_sta -t audit.tcl
```

`source-manifest.json` uses relative paths while preserving the original HDL
hashes and image identity. Rebuilding may produce a different SOF hash; the
recorded SOF hash identifies the original audited artifact. Build commands
do not program the board. `batch_test.py` accesses physical hardware when
explicitly invoked, asserts SPI reset on exit, and does not restore an FPGA
image by itself; board programming/restoration belongs to a hardware-lock
coordinator. No automatic deployment is included in this branch.
