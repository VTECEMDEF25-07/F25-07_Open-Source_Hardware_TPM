<!--
Filename: FAN_MONITOR.md
Authors: Project contributors; see Git history.
Date: 2026-10-13
General Description: Documents TMP442 monitoring and safe fan control.
AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.
-->

# TMP442 monitoring and safe fan control

The first hardware image generated valid keys but continually reported invalid sensor frames and requested full fan speed. Its temperature high-byte/low-byte reads were not adjacent, and it treated a snapshot of ongoing conversion as invalid. The public telemetry did not identify the cause. The changes below correct sampling and expose diagnostic evidence; physical root-cause confirmation still requires the new image.

## Conversion contract

The TMP442 uses configuration 0x09=0x40 (shutdown between one-shots), 0x0a=0x3c (all three channels and resistance correction). Before each trigger, the monitor reads both configurations back and polls status until idle. NACK, wrong configuration or a preflight timeout rejects that frame; configuration failures cause full reconfiguration on the next cycle.

After an acknowledged write to one-shot register 0x0f, the monitor must observe BUSY high and then low. A missing, missed, or permanently high BUSY cannot produce a healthy frame. Each preflight and post-trigger wait has an independent wall-clock budget of 800,000 management clocks, 2.048 seconds at 50MHz/128. Timeout advances to a failed frame and the next fan safety command. A failed trigger/write also rejects the frame. No inferred temperature change substitutes for conversion progress: equal successive temperatures are normal.

The actual management clock is 390625Hz. The retained vendor I2C engines do not stretch the clock. The first post-trigger status read follows six short byte reads; the bus-level regression measured 1152 management clocks, approximately2.949ms, against the minimum enabled local conversion time (12ms). An unexpectedly missed BUSY fails closed instead of accepting an old sample. The test model also covers an already-running power-up conversion: preflight must finish before the one-shot.

After proven completion, reads are local high/low (0x00,0x10), remote1 high/low (0x01,0x11), remote2 high/low (0x02,0x12), with no other register read between a pair. Manufacturer/device IDs, every read/pointer/write acknowledgement, nPVLD, OPEN and conservative negative-temperature rejection remain required. Only a complete healthy three-channel frame refreshes the five-second stale guard. Startup, failed frames and stale data request MAX6650 full-on. Board/button/configuration reset initialize management; gray SPI reset cannot interrupt it. Hardware full-on GPIO protection remains independent.

## Verification

Run `simulate_fan.py` and `simulate_fan_bus.py` under Linux/WSL with Verilator, passing an absolute `--build` directory. The first injects decoded sensor values; the second uses a serial I2C slave model without forcing DUT internals. Tests cover conversion progression, ACK/ID/configuration errors, invalid readings, staleness and recovery.

The management block retains diagnostic outputs for optional observation, but this board project does not include the keygen demo or its SPI diagnostic register protocol. Cooling runs independently of TPM SPI reset.

## Provenance

Board-resource input: DE25-Standard_revD_v1.2.0_ResourcePackage.zip, SHA256 5e46ac11779b617f40d672acf1f2fed20db90b777ba7ad74d90dc8167043b0ad. Imported modules retain supplied notices. Local changes add sensor validation, bounded conversion waits, freshness protection and reset handling. No new license is assigned to imported code.
