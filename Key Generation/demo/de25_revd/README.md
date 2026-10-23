<!--
Filename: README.md
Authors: Project contributors; see Git history.
Date: 2026-10-13
General Description: Documents DE25 RevD key-generation demonstration.
AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.
-->

# DE25 RevD key-generation demonstration

This is an explicit **test image**: a deterministic SHA-256 fixture stream feeds the portable core, and a stand-in protected receiver allows the host to inspect test keys. It must not be used with production seeds or keys. The core itself has no public private-key export port. Two images cover dedicated RTL control with generic/Altera arithmetic; each image contains both AES profiles and RSA-2048.

## Layout and reset

`keygen_de25_top.v` connects the board configuration-reset primitive, independent fan control, and the SPI demonstration. `keygen_demo_system.v` captures a request, starts the SHA source, then presents the request to the core. It collects up to 129 result words before acknowledging ownership. `keygen_demo_spi.v` handles the transport.

KEY0 and configuration reset initialize both domains. The gray adapter lead resets only the demonstration and key-generation core: fan control continues running. The fan uses the existing vendor automatic temperature control; no SPI register can disable it or override its safety behavior. The `vendor/` files preserve the board-management implementation from the earlier verified board demonstration, including its configuration-reset wrapper and CLOCKMEM reset connection. These imported files retain their original names and style; the safety corrections below are explicitly tracked. `pin_reference.qsf` is the original board pin reference, not another top-level design.

At reset, status acknowledgement, or result discard, the receiver clears one word per clock over all 129 positions. Results are unreadable until a complete key arrives; they immediately become unreadable when clearing begins. A new request is accepted only after clearing and core readiness. Gray reset also clears the fixture seed and generator state. Status acknowledgement resets the generator and captured context, but preserves host-written shadow configuration for convenient replay.

## Verified wiring

| Adapter wire | Signal | JP1 contact | FPGA pin |
|---|---|---:|---|
| Purple | Interrupt, active low | 2 | BE43 |
| Green | MISO | 4 | BF40 |
| Yellow | MOSI | 6 | BM31 |
| Brown | Chip select, active low | 8 | BP31 |
| Orange | Clock | 10 | BU28 |
| Gray | Core reset, active low | 14 | BW28 |
| Black | Ground | 12 | Ground |

Blue on contact 16 remains unused; red and white remain disconnected. These are the corrected, physically verified assignments, not the earlier photo-based odd-number hypothesis. The 50 MHz clock is CH128. KEY0 is BW59. Board-management SCL/SDA are BF120/BH118.

## SPI protocol

Use mode 0, MSB first, at 100 kHz, 500 kHz, or 1 MHz. Keep chip select low for exactly eight bytes:

`operation, address, 0, 0, data[31:24], data[23:16], data[15:8], data[7:0]`

Operation 1 reads; operation 2 writes. MISO returns `A5, 0, 0, 0` followed by a 32-bit read snapshot. A write commits only after all eight bytes arrive with both reserved bytes zero. Raising chip select early aborts without mutation. Extra clocks after eight bytes are ignored until chip select rises. Unknown addresses read zero and ignore writes. START while busy or awaiting acknowledgement is ignored; it does not replace an operation. Profile, operation ID, and seed are captured together at an accepted START. Later writes affect only the next operation.

| Address | Register | Meaning |
|---:|---|---|
| 0 | ID | `0x4B473031` |
| 1 | Configuration | bit 0 reserved (zero); bit 1 Altera backend; bit 2 test image |
| 2 | Control, write | bit 0 START; bit 1 acknowledge held status |
| 3 | Status | bit 0 ready; bit 1 busy; bit 2 complete receiver; bit 3 held status; bits 11:8 core status code |
| 4 | Profile | 0 AES-128; 1 AES-256; 2 RSA-2048; other writes select invalid profile 3 |
| 5 | Operation ID | Shadow 32-bit request identifier |
| 6, 7 | Elapsed cycles | Low/high halves; 50 MHz cycles from accepted core request until held status |
| 8 | Result address | 0 through 128; out-of-range writes ignored |
| 9 | Result data | Selected 32-bit word; zero until complete or outside actual result length |
| 10 | Result metadata | bit 31 valid; bit 11 whole-key last; bit 10 component last; bits 9:3 component word index; bits 2:0 component |
| 11 | Test controls | bit 0 hold generation; bit 1 hold result; bit 2 hold ownership; bit 3 force source failure |
| 12 | Public progress | bits 2:0 wrapper state (0 clear, 1 idle, 2 source start, 3 core start, 4 running); bit 3 result valid; bit 4 ownership ready; bit 5 owned; bit 6 receiver clearing |
| 13 | Temperatures | Signed 16-bit FPGA degrees C in high half; board degrees C in low half |
| 14 | Fan speed | Vendor-reported RPM in low 16 bits |
| 15 | Fan status | bits 7:0 vendor ALARM; bit 8 I2C_READY; bit 9 TEMP_VALID; bit 10 sensor failsafe/full-on request |
| 16–23 | Seed | Eight MSW-first words, 256 bits total |
| 63 | Scratch | Read/write transport check |

Generation hold applies between words: an already offered word remains valid and stable until accepted, even if the host sets hold meanwhile. The same offer gate controls core valid and source ready; no hidden word is consumed. Reset/acknowledgement ends the stream and clears its offer state.

Fan telemetry is read-only, synchronized diagnostic information. I2C_READY describes the last completed frame; TEMP_VALID holds complete-sample health. Both ready/valid are masked while the live failsafe is asserted. The failsafe bit is the persistent indication of invalid or stale data and takes precedence over a previously healthy frame. Multi-field reads are not an atomic sensor snapshot; use repeated samples and validity flags. The vendor fan controller retains responsibility for protection. Register 12 intentionally exposes wrapper progress, not private arithmetic data or exact RSA subphases.

AES exports component 1, four/eight words. RSA exports modulus component 2 (64 words), exponent component 3 (one word), p component 4 (32 words), and q component 5 (32 words). Each component is MSW first. Success is held until acknowledgement. Component metadata is checked by the host before mathematical verification. For simultaneous START and acknowledgement, acknowledgement wins; issue START separately after ready.

## Build and review

Run `prepare_build.py --build-root <project>/AI/tmp/keygen-board-build --core-root <canonical Key Generation directory>`. The canonical source tree must exist; no firmware image is required. Add `--variant rtl_altera --compile` for one complete Quartus flow; use `rtl_generic` for the other resource backend. Without `--compile`, this only prepares projects. Nothing programs the board.

The default `--processors 2` bounds per-build worker pressure. Run one full fit at a time on the 32 GB development machine; concurrent full fits exhausted available memory during development. Check free memory before adding simulation work. Each variant records original source paths and SHA-256 values, copies an immutable source snapshot into its build directory, and targets A5ED013BB32AE4SCS at 50 MHz. Altera arithmetic is selected with `KEYGEN_ALTERA`; the design instantiates primitives directly rather than depending on generated arithmetic IP-catalog projects. The board configuration reset uses its vendor primitive. Synthesis-generated debug/configuration fabric is tool infrastructure, not a separately authored key-generation IP dependency.

A successful tool exit is not timing acceptance. Review fitted resources, 50 MHz setup/hold, generated fan clock, asynchronous input synchronizers, and every timing exception. `timing_accepted` remains false until that review. Build products stay under `AI/tmp/`.

### Boot from configuration flash

The `.sof` loaded over JTAG is volatile. For automatic boot after a power cycle, set DE25 SW10 to Active Serial: switch 1 OFF, switches 2 and 3 ON; switch 4 is unused. Use only a reviewed, timing-accepted build. From an empty output directory, convert its `keygen_de25.sof` with the same Quartus installation used for the build:

```text
quartus_pfg -c <build>/output_files/keygen_de25.sof keygen_de25.jic -o device=MT25QU128 -o flash_loader=A5ED013BB32AE4SCS -o mode=ASX4
```

Copy `flash_keygen.cdf` beside the generated `.jic`, then run `quartus_pgm -m JTAG -c "DE25-Standard [USB-1]" flash_keygen.cdf` from that directory. This replaces the board's existing configuration-flash image, including any factory image. After the programmer reports success, power-cycle the board and run `host_test.py --action transport --manifest <build_manifest.json> --report <report.json>` over SPI. The build fingerprint check proves the intended image actually booted. Check fan telemetry and run AES/RSA again before the demonstration.

## Tests and host use

`simulate_demo.ps1 -BuildDirectory <project>/AI/tmp/keygen-demo-sim` runs the transport/receiver bench. Its clearly marked **model core** checks framing, request capture, full 129-word reception, stalls, ownership, discard, clearing, reset, and fan-register wiring. It does not prove RSA mathematics. Production builds never include the model. Real AES/RSA integration has separate core tests.

`python tests/test_host.py` performs offline host checks with a fake adapter, independent hashlib AES values and the frozen RSA corpus plus strong key checker. It never opens USB.

The host client opens only C232HM serial `FTA6H280`. Use `python host_test.py --action transport --manifest <build_manifest.json> --report <report.json>` first; then `--action aes`, `--action rsa --seed 1`, or `--action corpus`. `--reset` pulses gray core reset only. Reads and operations are bounded; each operation has a 180-second deadline. A failure records FAIL and exits nonzero. Timeout may leave a busy operation: explicitly reset the core before retrying.

For a live presentation, run `python demo_terminal.py --manifest <build_manifest.json> --seed 1 --rsa-count 5`; use `--rsa-count 10` for a longer run or `1` for a quick smoke test. It identifies the test image, generates AES-128 and AES-256, then independently verifies each RSA-2048 key from a distinct seed. RSA progress appears every five seconds. The final summary reports average and median core and terminal times for the selected sample; only the full 20-seed corpus establishes the acceptance target. Only this explicit terminal demo prints test key material; the normal acceptance reports do not.

RSA results must match the frozen deterministic corpus and pass the independent key checker. AES must match the SHA fixture stream. The host records 50 MHz cycle counts, separate wall-clock completion latency, and roughly one-second fan telemetry samples. No private result values are saved to reports. The corpus acceptance checks the median of all twenty RSA core times against 30 seconds; a transport-only or single-key success does not establish that target.

## Initial evidence

- Questa SPI/receiver/telemetry model suite: PASS, 29.414 ms simulated; source compiled as Verilog-2001 with zero compiler warnings/errors. The simulator's `+acc` optimization warning is expected.
- Offline Python host suite: twelve tests PASS, including RSA mathematical validation, corrupt AES/metadata rejection, error acknowledgement, timeout and image identity.
- No board programming or electrical testing is performed by these preparation steps. Fitted-resource, timing and physical evidence must be attached after the corresponding runs finish.

### Soak and reset/replay

`--action soak` runs mixed AES-128, AES-256 and RSA jobs for at least 30 minutes, cycling the twenty fixture seeds. Each job retains the 180-second bound; a job already in flight may finish after the 30-minute mark. Every completed job checkpoints the report, and failures preserve earlier results and collected fan samples. A PASS means all completed jobs verified; inspect sensor readiness, alarms and trends separately before accepting thermal behavior.

`--action reset-replay` tests reset during a generation stall, during an actively running RSA request (observable busy state after 50 ms), while AES result delivery is stalled, while ownership is stalled, and while success is held. It checks that result/status/configuration are cleared, then regenerates and verifies all three profiles. This is a board boundary/reset test; exact RSA candidate, witness and pair-check phase reset coverage remains in the RTL integration tests. The offline suite checks soak sequencing/checkpointing/failure and reset-suite orchestration without opening hardware.

### Fan safety corrections

`--action fault-replay` injects a generation-source failure during a source stall, active RSA, stalled AES result transfer and stalled whole-result acceptance. Each operation must hold error status 2 until acknowledged, discard receiver ownership and expose zero result data and metadata. The tester then generates and independently verifies AES-128, AES-256 and RSA-2048 without another reset. Each phase has a 180-second deadline; unexpected errors trigger checked recovery and remain failures. This complements reset testing by checking the normal fault-cleanup path.

### Fan safety corrections

The inherited vendor code left `invalid_temp` undriven. The demonstration now reads TMP442 low bytes 0x10/0x11/0x12 and rejects nPVLD, remote OPEN, incorrect manufacturer/device IDs (expected 0x55/0x42), missing read/pointer acknowledgements, and an unproven conversion. Each frame uses bounded shutdown/readback, one-shot, BUSY-to-idle, and adjacent high/low sampling; see FAN_MONITOR.md. It conservatively rejects negative temperatures for this room-temperature demo, including the shorted-diode -64 C sentinel. Configuration register 0x0B uses 0x06 (4 conversions/second) without setting reserved bits.

`keygen_fan_guard.v` starts in failsafe, immediately rejects a failed frame, and expires after 1,953,125 management clocks (five seconds at 50 MHz / 128). A complete healthy frame restores normal operation. Preflight and conversion waits each expire after 800,000 management clocks (2.048 seconds at the actual divided clock), so a stuck ADC cannot prevent the next safety command. The pointer writer now stops and reports a NACK instead of retrying a missing sensor forever; this keeps sensor loss from blocking later fan commands. Each update writes the MAX6650 mode as well as speed: invalid data selects full-on via configuration bits 5:4 = 00; healthy data selects the existing closed-loop configuration. The hardware full-on GPIO assignment and alarm configuration remain unchanged. The AutoFan reset target is also its maximum speed.

Sources: [TI TMP441/TMP442 datasheet, table 3 and diode-fault section](https://www.ti.com/lit/gpn/tmp442); [Analog Devices MAX6650/MAX6651 datasheet, full-on and closed-loop modes](https://www.analog.com/media/en/technical-documentation/data-sheets/max6650-max6651.pdf). A failed I2C bus can prevent delivery of a software command; the independent hardware full-on override remains the fallback. Simulation validates requested commands and fault logic, not physical airflow or sensor calibration.

Run `simulate_fan.py --build <project>/AI/tmp/keygen-fan-sim` under Linux/WSL with Verilator. The bench accelerates management timing and uses real vendor bus engines with a pulled-up unresponsive bus, then acknowledges bus transfers and injects decoded sensor samples at the controller boundary for identity, invalid-data, OPEN, stale-data and recovery tests. Production timing defaults are unchanged by the bench. Source uses Verilog-2001; the bench uses SystemVerilog. The inherited extra semicolon is removed rather than enabling SystemVerilog for vendor source.

### Real-core SPI integration

`simulate_real.py --core-root <canonical Key Generation directory> --build <project>/AI/tmp/keygen-real-spi-rtl` runs the actual `keygen_core`, SHA fixture source, SPI transport and receiver. RTL/IP are copied and hashed before elaboration. Python's standard `hashlib` independently supplies the first AES fixture digest; the expected words do not come from the RTL or project reference generator.

This suite verifies AES-128/AES-256 data and metadata through SPI, source/result/ownership stalls, captured configuration despite busy writes, source failure, reset/clearing and replay. RSA requests exercise the real controller's held-generation and abort/recovery paths; this short suite does not run a complete RSA search. The separate model-core bench remains useful for full 129-word transport/framing coverage, and its synthetic RSA payload must not be described as mathematical RSA validation. Complete RSA arithmetic/corpus tests are separate acceptance evidence.

The real-core suite also checks fan failsafe bit10 at the public register-bank input. The physical top-level connects guard output into telemetry bit58, which becomes bit10 of register15 after the two-stage diagnostic synchronization; the host decodes the same bit. Fan sample/validity updates occur in the management-clock domain after all 13 reads, and the freshness guard samples that completed frame before the controller advances. The independent gray reset only reaches the key-generation subsystem.
Build evidence is write-once: `prepare_build.py` rejects any existing variant directory, including incomplete builds without a manifest. Use a new build root for every source revision. It captures source bytes once, verifies the originals remained unchanged during capture/copy, verifies copied bytes, and records source, pin-reference, QSF/QPF/SDC hashes and the queried Quartus version before compilation. A failed snapshot must not be used for acceptance. Offline checks: `python tests/test_prepare_build.py`.
Registers 24–31 expose the 256-bit build fingerprint, most-significant word first. The top passes a build parameter to this read-only register bank. The builder hashes the ordered source snapshots, pin reference, tool version, SDC and normalized settings **before adding the fingerprint parameter**; this avoids circular hashing and ignores the output directory location. The manifest retains the full input recipe and final configuration hashes. This is reproducible image identification, not secure boot or image authentication. Every host action requires `--manifest` and rejects mismatched fingerprints or controller/backend configuration before tests.

`--action stall-replay` completes and independently checks one baseline RSA key, then regenerates the same seed with generation hold/release transitions requested at 20/120/200/300 ms. Actual transition times are logged; all transitions must occur while busy and before completion. Both keys must match the frozen corpus and independent mathematical checker. Failure/timeout releases the generation hold and records the error; each generation keeps the 180-second bound. Reports contain timings and transition metadata, never key words. This complements reset-replay, which aborts requests instead of completing them.
To compile a previously prepared snapshot, use `python compile_build.py <variant-directory>`. It verifies snapshot/configuration hashes and the exact tool version, then permits only one compiler launch. Compilation does not mark timing accepted.
The top resets fan/telemetry and core through separate two-stage release chains. Both chains use the raw configuration/button reset for asynchronous assertion; gray additionally asserts only the core chain. Telemetry uses the synchronized board release. This avoids feeding the clocked output of one reset chain into the asynchronous clear of another; the earlier mixed-source form was positively timed but classified as insufficiently constrained by the tool. `simulate_top.py --build <new-directory>` tests this boundary with explicitly labeled fan/core models; real fan and real-core SPI regressions remain separate.

Output timing uses a 20 ns maximum and 0 ns minimum from internal launch to MISO/IRQ pins. SPI mode 0 falling/rising edges are at least 500 ns apart at1 MHz; the 50 MHz input synchronizer latency and output delay fit within that interval. IRQ is an asynchronous status level. These are explicit asynchronous-interface constraints, not a fictitious SPI clock synchronous to the board oscillator. The vendor open-drain fan bus retains explicit path exceptions. Both board/fan clocks and their crossings remain timed; no clock-to-clock false path is applied. Specific reset/SPI-input synchronizers are identified in QSF, while their interstage data paths remain timed.
A routed top/SPI/vendor-fan diagnostic (`AI/tmp/keygen-top-constraints-v1`, telemetry-only system stub, never program) confirmed zero unconstrained setup/hold ports, zero RES-50001/2/3/4 violations, zero ignored constraints, and no synchronizer chains excluded from MTBF analysis after these changes. Two rule categories remain intentionally visible: TMC-20012 requests synchronous output-delay declarations on MISO/IRQ and both I2C pins despite their explicit asynchronous min/max or false-path constraints; RDC-50003 reports the intentionally independent board and gray reset chains. These are documented interface/reset architecture choices, not hidden blanket waivers. The complete final core must still pass its own routed timing/DRC review.

The demo SHA source reset is driven by a registered request-lifetime bit, never a binary FSM decode. Both real-core SPI suites assert that source reset is released exactly while an accepted request is active and held through result/status handling until acknowledgment.
Compiler console output is captured through a pipe and written once after the process exits; the manifest records the numeric exit code. This avoids inheriting a long-lived cloud-backed log handle. Use closed Quartus reports for live progress. A failed attempt remains preserved and requires a new, preferably locally pinned, snapshot directory.

### Host failure recovery and reset boundaries

Reset replay requires the public wrapper state to be RUN before recording either a generation-stall or active-RSA reset boundary. The busy bit alone is insufficient because it also covers source setup and request admission. A wrapper stuck before admission times out and fails the test.

If generation polling fails or times out, the host pulses the gray core reset and verifies idle state plus cleared status, result and configuration; it does not try to acknowledge an operation that never completed. A completed but invalid key is acknowledged and cleared normally. If acknowledgment or readiness recovery fails, the host attempts the same checked reset. The original failure remains the report's primary error, with cleanup errors and recovery outcome recorded separately. A correct key followed by failed cleanup still fails the operation. Adapter-close failures cannot replace an earlier error. Fan control is outside the gray reset domain.

The offline host suite now passes 22 tests, including stuck pre-admission rejection, timeout reset recovery, primary-error preservation when ACK/reset/adapter close fail, and rejection of successful key generation followed by failed cleanup. These tests do not open hardware.

Admission writes, including START, use the same recovery guard: a USB failure may mean the board accepted the write even though the host did not receive confirmation, so the host performs checked reset before propagating the original error. Reset-replay setup and boundary polling are also guarded; a failed RUN/result/ownership boundary resets the held operation while the adapter remains open. The expanded offline suite passes 25 tests, including ambiguous START acceptance and boundary timeout with both successful and failed recovery.

### Frozen host acceptance bounds and provenance

The 180-second job deadline starts immediately before the START write attempt and covers completion, result retrieval, independent key checking, and final acknowledgment/readiness. Late status or cleanup cannot produce PASS. USB calls have their own bounded transport timeout; a call crossing the job deadline is rejected when it returns. Reports retain both completion latency and total successful host-operation time.

After failure, recovery has a separate 10-second deadline, checked between bounded USB calls, and reports its actual elapsed time and outcome. Recovery never converts failure into success. Transport CS release, initialization cleanup, adapter close and driver-close failures preserve the initiating error and accumulate secondary diagnostics.

When the selected manifest declares `fan_diagnostics_version: 1`, key-test
samples also include decoded registers 32–34. Older images retain their original
telemetry format; unknown diagnostic versions are rejected. The decoder's source
hash is included in the test provenance. `fan_monitor.py` separately supports
the explicitly identified FAN1 diagnostic image; key-generation tests continue
to require KG01 and never accept FAN1 as a key generator.

Every hardware report records UTC start, Python version, and SHA-256 hashes of this host script, the fan-diagnostics helper, the independent key checker, generation reference, seed list and expected-key corpus. Those files must remain unchanged through completion before PASS can be recorded. These hashes supplement the loaded image's build fingerprint.

The current offline host suite passes 38 tests; host, fan, build and source-hold runner suites total 51 tests. Added cases reject late ready status, late verification/ACK, exhausted recovery budget, changed reference inputs, and transport/driver cleanup failures without masking the primary cause.
