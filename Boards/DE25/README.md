<!--
Filename: README.md
Authors: Project contributors; see Git history.
Date: 2026-10-14
General Description: Documents Minimal DE25 port of Phase 1.
AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.
-->

# Minimal DE25 port of Phase 1

Open `de25_soc_top.qpf` in Quartus Pro 26.1. The top is the repository-root
`de25_soc_top.v`. This project selects DE25 Standard RevD / A5ED013BB32AE4SCS.

The original TPM top, SPI serializer, register logic and command logic are
unchanged. The board wrapper supplies related 50 MHz and 100 MHz clocks from one vendor PLL, waits for configuration/PLL readiness, and keeps cooling
independent of the gray SPI reset. Our RTL remains Verilog (.v); Verilog-2005 features such as `$clog2` are allowed; only the
vendor PLL's internal SystemVerilog uses the specifically approved exception.

## Review these changes

1. `../../de25_soc_top.v`: connections, reset and existing fan support.
2. `de25_phase1_clock.v`: vendor PLL macro providing both TPM clocks.
3. `de25_soc_top.qsf`: device, pins and explicit source list.
4. `de25_soc_top.sdc`: clock constraints and inherited timing limitations.

No SPI redesign, keygen integration, copied tester or new test framework is
included. Fan support is reused from the existing reviewed board-support files.
The optional read-only JTAG probe observes PLL/reset/temperature/fan state; it
cannot control TPM or cooling and does not change the SPI register map.

| Signal | Connection | FPGA pin |
|---|---|---|
| 50 MHz | CLOCK0_50 | CH128 |
| Board reset | KEY0 | BW59 |
| SPI clock | Orange, JP1 pin 10 | BU28 |
| MOSI | Yellow, JP1 pin 6 | BM31 |
| MISO | Green, JP1 pin 4 | BF40 |
| Chip select | Brown, JP1 pin 8 | BP31 |
| TPM reset | Gray, JP1 pin 14 | BW28 |
| Interrupt | Purple, JP1 pin 2 | BE43 |
| Ground | Black, JP1 pin 12 | Ground |
| Fan I2C | SCL / SDA | BF120 / BH118 |

Blue is unused; red and white remain disconnected. The existing tester's
channel-close behavior holds gray reset low; opening the channel releases it.

## Validation

The original FIFO is restored unchanged, including `$clog2`; the forced
Verilog-2001 project setting is removed. Prior fit/timing figures below describe
the earlier equivalent-width helper revision; place-and-route has not been
repeated for this language-setting cleanup.

| Check | Result |
|---|---|
| Original Phase 1 simulation vectors, 1 MHz SPI | PASS; ideal PLL model, not vendor PLL simulation |
| Quartus Pro 26.1 full fit | PASS: 1,570 ALMs (3%), 2 M20Ks, 0 DSPs, 1 PLL |
| New board clock/reset/cooling paths | Reviewed; positive downstream timing margins |
| Existing tester on hardware, 100 kHz / 500 kHz / 1 MHz | PENDING: programmer reports no connected devices |

The original SPI has inherited asynchronous crossings and a logic-generated
transmit clock. Full SPI timing/CDC signoff is **not established**; the SDC
documents these gaps rather than hiding them. The PLL-lock exception covers
only the two reset synchronizer clear inputs; downstream reset paths stay timed.

To rebuild, open this QPF and run a full compile, or run
`quartus_sh --flow compile de25_soc_top` from this directory. Program the
resulting SOF with Quartus Programmer. Read-only JTAG diagnostics assume 15 MHz
JTAG. Run the existing Phase 1 tester at each listed SPI rate, retaining all
eight suites; no new tester is included here. These suites check register,
locality, status, abort, hierarchy-control and quote-response flows, not full
TPM conformance or key generation.

Local validation records are in the class workspace under `AI/tmp/`:
`phase1-minimal-build-v3`, `phase1-minimal-v3-final-audit`,
`phase1-minimal-sim-v2005`, and `phase1-minimal-program` (failed device discovery).
The fitted SOF SHA-256 is
`4bea0b39856d152e06a57e849e9673eedc1a31834fd6fe10cce831cc69053404`.
