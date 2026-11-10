# RevD HPS LCD actual-status display

The DE25 RevD blue128x64 LCD is an ST7567 on **dedicated HPS SPI/GPIO**.
It cannot be driven by assigning ordinary FPGA logic to the HPS package pins.
This service reuses the vendor `hps_lcd` Linux device/command route without
reconfiguring HPS, its pinmux, SD/QSPI media or the FPGA. Codex assisted with the
new status capture/renderer/service/tests. No vendor code is copied into the
service; initialization and signal mapping were checked against the complete
RevD resource package.

## Prerequisites owned by the hardware lead

A running compatible HPS Linux with `/dev/spidev0.0` and vendor HPS GPIO mappings:
`/dev/gpiochip0` line10 reset, line11 D/C, line18 backlight. Verify actual GPIO
labels/ownership before launch if the Linux image differs from the vendor BSP.
GPIO v1 character-device API must be enabled and the calling user must have
permission to open the devices. If missing, fail rather than guessing another
pin mapping. Only the hardware lead launches the service or accesses board ports.

RevD pins, all1.8V SoC-side: resetT124, D/C P124, backlightH127, SPI SS AB124,
clockF127, MOSIY124. These are **reference HPS pin constraints**, not a new FPGA
QSF file. Do not drive them from a fabric-only top. Backlight JP4/module power
must also be physically available; software cannot prove that from a write.

The manual's HPS UART is the FT2232H channel sharing the onboard USB-Blaster III
USB-C connector, baud115200. A Linux microSD/factory boot environment must already
exist; no persistent media/boot setting changes are made by this deliverable.
An existing plain-FPGA JTAG image does not prove HPS/Linux is alive.

## Actual snapshot contract

`Source Code/Display/demo_lcd_status.v` captures actual50MHz hardware FSM inputs,
never host-step strings. Inputs are valid, code4, detail8, operationID32 and
provider2. Outputs are `status_word_o`, `operation_id_o`, `sequence_o` (all32bits).
Sequence increments only on first valid/changed tuple. Reset invalidates any old
done/error record and synchronizes release; repeated valid tuples do not animate.

The frozen live SPI register at locality0 address`0xD40F80` supplies four **little
endian** words: sequence, status_word, operation_id, sequence again. Relay accepts
only matching sequence bookends and forwards the three values exactly as JSON:

```json
{"status_word": 16777347, "operation_id": 42, "sequence": 1}
```

The example is a test snapshot, not a hardware observation. Only forward records
read from the actual FPGA register in a physical demonstration. Word bits31:24
are version1;23:16 actualdetail;15:8 reserved0;7 captured-valid;6 error;5:4 provider;
3:0 state. State0READY,1STARTUP/PHASEI,2RNG_PREPARE,3AES_KEYGEN,4RSA_KEYGEN,
5WAITING_INPUT,6AES_DECRYPT,7RSA_DECRYPT,8DONE,9ERROR. Unsupported10..15 remain
diagnostic UNKNOWN HW STATE with error flag. Provider0FRESH UNQUALIFIED,1TEST ONLY,
2UNAVAILABLE; unsupported3 is labeled invalid. No key/plaintext appears on screen.
Detail is an actual subphase/error code in hex, not a guessed percentage.
For sticky DONE state8 only, hardware lead approved detail2=completed AES decrypt
and detail4=completed RSA private decrypt. These render AES DECRYPT DONE / RSA
DECRYPT DONE, so a completed operation is visible even if its busy phase finished
between250ms polls. This is a retained hardware completion, not a replayed busy
animation or a claim that the busy phase was observed. Stale still overrides it.

## Run on an already verified HPS Linux

This command is for the hardware lead after HPS access/device mapping is verified:

```sh
python3 de25_lcd.py < actual_fpga_status_stream.jsonl
```

Normally feed a live FIFO/stdin stream containing repeated fresh readbacks every
100–500ms. The same tuple may repeat as a heartbeat; stale after2s shows STATUS
STALE/LAST HW SNAPSHOT. No captured-valid record shows WAIT HW STATUS, never READY.
Arbitrary host text, extra fields and malformed records are rejected. Repeated
snapshots are not treated as progress; rendering only changes when pixels change.
Input EOF marks the last observed status stale and exits. Do not feed generated
UI steps as input or call a software framebuffer capture a glass observation.

Driver defaults500kHz mode0/MSB-first,8-bit words. Rate is requested, not a measured
SCLK claim. Vendor reset timing62.5ms low/high and vendor COM-reverse/power/start
commands are used. All8x132 DDRAM columns are cleared before display-on; visible
pages are128columns,8pages. GPIO D/C is set before synchronous SPI writes and is
not changed until the write completes. Partial writes raise an error. SPI-4 has
**no readback/MISO**: no busy/DDRAM verification can be fabricated.

## Offline verification

```text
python Testing/Host/LCD/test_de25_lcd.py
```

Tests cover64 state/provider combinations, known glyph orientation, actual-source
schema/invalid input, stale/reset text, bounds, captured initialization+10 full
frames in an independent132-column/page model, and Linux GPIO/SPI transport calls
with mocked devices including failure cleanup. `verify_lcd_linux_abi.c` independently
checks seven Linux header sizes/ioctl values without opening a device.

The status HDL bench/runner under `Testing/Simulation/Display` uses Verilator and
g++ C++20 directly, so class paths with spaces work without GNU Make and without
consuming the single native Questa license. RTL test captures299 checks across16
state codes at a simulated50MHz. It is not a hardware/LCD result. The hardware
lead must still integrate actual FSM signals/live-register serialization, prove
HPS access, and obtain a physical screen observation or explicitly report that
gate as blocked. No standalone tests here prove LCD power, glass, wiring, actual
SCLK, screen orientation/contrast or new-demo physical acceptance.
# Bare-metal UART relay

`de25_lcd_uart_relay.py` replaces the Linux/SSH transport only when the lead has
validated the HPS-only OCRAM image. It uses the existing unchanged customer
`DE25_LCD_COMMAND_JSON` child-stdin seam. Example argv, with absolute paths:

```json
["python","<checkout>/Testing/Host/LCD/de25_lcd_uart_relay.py","--port","COM7","--expected-serial","TRWZCK53B"]
```

No helper invocation here proves a live HPS or LCD. Lead alone opens COM7;
COM5/other ports and automatic selection are rejected. It checks discovered
serial/hardware serial and descriptor for conflicts; an optional
`--expected-description` pins a known descriptor substring. If the device has
only a descriptor and no serial metadata, it logs that reduced identity level.
An absent device, no identity information, mismatched serial or an SPI descriptor
fails before opening. PySerial3.5 is installed; import/help/tests never open it.

UART is115200/8N1, no flow control,50ms read timeout and250ms write timeout.
Desired DTR/RTS are low before opening and never changed while open; driver
opening transients are not physically verified. No buffer reset or flush discards
boot output. Each bounded valid3-field actual snapshot is sent as canonical ASCII
JSON; duplicate heartbeats are preserved. Malformed/oversized input, short write
or disconnect produces a nonzero exit. UART raw bytes and parsed FRAME_SENT
acknowledgments go to separate JSON log events on stdout, never back to stdin.
Every ack explicitly records `glass_verified:false`.

For a lead-owned5second boot capture with **zero snapshot writes**:

```powershell
python '<checkout>/Testing/Host/LCD/de25_lcd_uart_relay.py' --port COM7 --capture-only --capture-seconds 5
```

Capture is capped at30seconds. Relay EOF allows0.5seconds to drain acknowledgments;
stdin joins and close are bounded. Tests use fake serial only:

```powershell
python -m unittest discover -s 'Testing/Host/LCD' -p 'test_de25_lcd_uart_relay.py' -v
```
