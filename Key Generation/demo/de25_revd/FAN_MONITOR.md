# TMP442 monitoring and safe fan control

The first hardware image generated valid keys but continually reported invalid sensor frames and requested full fan speed. Its temperature high-byte/low-byte reads were not adjacent, and it treated a snapshot of ongoing conversion as invalid. The public telemetry did not identify the cause. The changes below correct sampling and expose diagnostic evidence; physical root-cause confirmation still requires the new image.

## Conversion contract

The TMP442 uses configuration 0x09=0x40 (shutdown between one-shots), 0x0a=0x3c (all three channels and resistance correction). Before each trigger, the monitor reads both configurations back and polls status until idle. NACK, wrong configuration or a preflight timeout rejects that frame; configuration failures cause full reconfiguration on the next cycle.

After an acknowledged write to one-shot register 0x0f, the monitor must observe BUSY high and then low. A missing, missed, or permanently high BUSY cannot produce a healthy frame. Each preflight and post-trigger wait has an independent wall-clock budget of 800,000 management clocks, 2.048 seconds at 50MHz/128. Timeout advances to a failed frame and the next fan safety command. A failed trigger/write also rejects the frame. No inferred temperature change substitutes for conversion progress: equal successive temperatures are normal.

The actual management clock is 390625Hz. The retained vendor I2C engines do not stretch the clock. The first post-trigger status read follows six short byte reads; the bus-level regression measured 1152 management clocks, approximately2.949ms, against the minimum enabled local conversion time (12ms). An unexpectedly missed BUSY fails closed instead of accepting an old sample. The test model also covers an already-running power-up conversion: preflight must finish before the one-shot.

After proven completion, reads are local high/low (0x00,0x10), remote1 high/low (0x01,0x11), remote2 high/low (0x02,0x12), with no other register read between a pair. Manufacturer/device IDs, every read/pointer/write acknowledgement, nPVLD, OPEN and conservative negative-temperature rejection remain required. Only a complete healthy three-channel frame refreshes the five-second stale guard. Startup, failed frames and stale data request MAX6650 full-on. Board/button/configuration reset initialize management; gray SPI reset cannot interrupt it. Hardware full-on GPIO protection remains independent.

## Read-only SPI diagnostics

Existing registers13..15 retain temperatures, RPM and alarm/status. Register15 bits8/9 now report held frame health masked by the live failsafe; bit10 is the failsafe request.

| Address | Contents |
|---|---|
|32|bit0 frame read/write ACK failure;1 ID mismatch;2 conversion not proven/timeout;3 nPVLD;4 OPEN;5 negative reading;6 live guard/failsafe;7 preflight/configuration failure;8 conversion wait active; all higher bits0|
|33|bits31:24 remote2 low;23:16 remote2 high;15:8 last raw status;7:0 zero|
|34|bits31:24 manufacturer ID;23:16 device ID;15:8 local low;7:0 remote1 low|

Reason bits describe the last completed frame except live bits6/8. Read repeatedly because telemetry crosses management/board domains and separate SPI registers are not one atomic frame. These fields cannot disable protection or access keys.

## Verification and source

`simulate_fan.py` exercises the real management engines with decoded-register injection, including pair ordering, bounded no-start/stuck-BUSY, preflight failures, missing ACK, wrong IDs, both OPEN flags, nPVLD, negative sentinel, staleness and recovery. `simulate_fan_bus.py` independently exercises real serial open-drain ACK/data using a TMP442/MAX6650 test slave; it never forces internal DUT data. Top-reset and real-core SPI regressions cover the additive diagnostic interface.

Primary source: [TI TMP441/TMP442 datasheet, SBOS425A](https://www.ti.com/lit/gpn/tmp442), electrical conversion times and sections Temperature Registers, Configuration1/2, One-Shot Conversion. Local original: `AI/tmp/de25-docs/DE25_RevD_extracted/Datasheet/Temp Sensor/TMP442ADCNT.pdf`. The datasheet requires adjacent high/low reads, defines BUSY as conversion activity, and states that one-shot writes during an existing conversion are ignored. No cryptographic RTL or host acceptance rule is relaxed by these changes.
