# DE25 high-speed SPI validation

Validated November 3, 2026, against parent organization revision `a0f9bb4`.
**PR #37 remains a draft: exact 24 MHz physical acceptance is pending.**

- Quartus Pro 26.1 full build: PASS; Agilex 5 A5ED013BB32AE4SCS, 1,561 ALMs,
  2 RAM blocks, one board PLL. All 10 physical pins verified.
- Original TPM protocol assertions: PASS at 100 kHz, 1, 10, 15, 24 and 30 MHz
  using ideal test-only clock/reset models. The 21 inherited bench warnings remain.
- Shared serializer unit regression: PASS across 100/500 kHz and 1/10/15/24/30 MHz,
  including phase offsets, short framing and reset/replay; zero simulator errors/warnings.
- Final routed audit: PASS at all four available corners. Five SPI synchronizer
  chains remain timed. UCP reports zero unconstrained clocks, ports and paths.

| Worst slack, ns | Result |
|---|---:|
| Setup | +0.401 |
| Hold | +0.012 |
| Recovery | +1.944 |
| Removal | +0.045 |
| Pulse width | +4.538 |

SCK is constrained at 30 MHz, MOSI at 2/3 ns setup/hold, MISO at <=0.7 of its
half-period, and frame-start CS at 5 ns setup. The complete legacy TPM retains
>=100 ns CS setup/hold/high. A diagnostic full-TPM replay at 5/5/50 ns framing
fails 13 existing assertions despite the isolated serializer passing that framing;
minimum framing compliance is not accepted by this PR.

The pin interface uses local SCK routing and ordinary fabric registers.
Forcing an Agilex input I/O register produced an unsuitable hold path; forcing
an output I/O register required a slower global clock route. Both assignments
are explicitly OFF for DE25. These settings are board-local; SPI RTL is shared.
Worst physical mailbox bus delay is 1.158 ns (audit bound:20 ns).
Only SCK-domain startup reset clear pins are excepted from the core's registered
reset release. Keep CS high and SCK low through reset and >=1 us after release.
Core reset release, CS framing, mailbox data and synchronizer interstage timing
remain checked. Existing fan/JTAG timing assumptions and vendor warnings remain.

## Physical test using the previous team's assertions

The original eight C suites were run through a checked transport port, using
unmodified vendor libMPSSE 1.0.7/D2XX libraries and adapter serial `FTA6H280`.
The Linux port adds serial selection, checked/bounded USB operations and timing
compatibility; test transactions/assertions are retained.

| Requested rate | Vendor-divider rate | Final image result |
|---|---:|---|
| 1 MHz | 1 MHz | PASS |
| 10 MHz | 10 MHz | PASS |
| 15 MHz | 15 MHz | PASS |
| 24 MHz | 30 MHz | FAIL, 3/3 runs; command poll limit |

The vendor source computes an integer divider as `(30 MHz/request)-1`;
requesting 24 MHz selects divider zero. These rates are derived from source,
not oscilloscope measurements. The [FT232H datasheet, section4.8](https://www.ftdichip.cn/Support/Documents/DataSheets/ICs/DS_FT232H.pdf)
documents its divided 30 MHz clock and incoming-data setup window. The current
adapter cannot generate a true 24 MHz clock. Failure resembles late MISO capture,
but signal/adapter/board causality has not been isolated with measured waveforms.
**Neither the failing 30 MHz run nor passing simulation proves 24 MHz hardware acceptance.**

The published 50 MHz oversampling baseline (`400ecc6`) passed 1 MHz and failed
its requested-24/configured-30 MHz run. An intermediate high-speed/global-SCK
image also passed 1/10/15 MHz and failed 10/10 configured-30 MHz runs. Those
failed experiments are preserved separately and are not accepted high-speed evidence.

Programming was volatile JTAG under the shared hardware lock at 15 MHz TCK.
After testing, cooling remained healthy (FPGA34 C, fan >=3960 RPM), the target
FTDI kernel driver was reattached, and the programmer's persisted 1536 MiB
memory/no-swap limits were verified. The final image remains loaded; the tester
closes with TPM reset asserted while autonomous cooling continues.

Serializer SHA-256:
`dc6dfbc3f27fc5543616491bac09628cd5cbd25534b08c8e20938780e5f692f3`

Programmed SOF SHA-256:
`975bc8900d692f72b45e2a63cb76fea8e23c712111b75fadbf97126bd4093dfd`

Local class evidence: `AI/tmp/spi24-local-hardware.json`,
`spi24-local-transfer/manifest.json`, `spi24-accepted-v2-de25-*`,
`spi24-unit-accepted`, `spi24-layout-de25-compile-v10-local-fabric.log` and
`spi24-de25-accepted-timing.log`. Remote logs:
`/tmp/codex-spi24-local-20261103/`. Generated evidence/images are not tracked.

See [SPI reproduction and portability](../../Source%20Code/IO%20Interface/SPI.md).
This is transport/board validation, not full TPM certification or ASIC signoff.
