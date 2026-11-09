# Physical hardware testing and speed measurements — November 8, 2026

**Complete: the original Phase One physical SPI matrix passed, and all ten local RNG/keygen benchmark operations passed.** Three fresh RSA-2048 keys took **11.28–51.68 seconds, median 27.81 seconds** at 50 MHz. Active DRBG generation was approximately **5.0 MB/s**. Unmodified main was restored afterward and all eight original suites passed again at 1 MHz.

Fresh clone: `AI/tmp/hardware-speed-20261108/repo`, branch `main`, revision `81b6968645e70669cc157c7709d111206f1f56dc`. Its tracked files remain unchanged; all benchmark additions are under untracked `LocalBenchmark/`. The original feature checkout was not edited.

## Original team tester through physical SPI

- Connected board: DE25 Standard RevD target A5ED013BB32AE4SCS; JTAG device ID `4364C0DD`, index 1, cable `DE25-Standard [3-4-iface0]`. RevD/D1 is user-confirmed in project memory.
- Actual transport: NAS-attached FTDI C232HM, serial `FTA6H280`, verified even JP1 row. All ten routed main-image pins were checked against the fitted `.pin` file.
- Unmodified-main build completed with 1,335 ALMs, two RAM blocks and one PLL. Volatile JTAG configuration succeeded, zero programming errors. SOF SHA256: `112a23edf602d40a9d8090f5e77b4f3027c860d804579f92e593ac030f4a36e8`.
- **Timing limitation:** worst setup −2.690 ns on `pll_clock_100`; hold, recovery and removal summaries are nonnegative. This is empirical functional testing of this image, not worst-corner timing acceptance.

| Requested SPI | Configured SPI | Result | Enabled suites completed |
|---|---|---|---|
| 100 kHz | 100 kHz | PASS | 8/8 |
| 500 kHz | 500 kHz | PASS | 8/8 |
| 1 MHz | 1 MHz | PASS | 8/8 |
| 10 MHz | 10 MHz | PASS | 8/8 |
| 15 MHz | 15 MHz | PASS | 8/8 |
| 24 MHz, trial 1 | 30 MHz | PASS | 8/8 |
| 24 MHz, trial 2 | 30 MHz | PASS | 8/8 |
| 24 MHz, trial 3 | 30 MHz | PASS | 8/8 |

Configured frequency follows the unchanged libMPSSE 1.0.7 divider, `30 MHz / floor(30 MHz/request)`. No oscilloscope frequency measurement or true 24 MHz claim is made. These fresh results identify this exact main image and do not erase the failures recorded against different historical images.

The eight enabled calls are debug read/write, locality changing, locality permissions, status state machine, locality seize/command abort, both hierarchy-control functions, and quote. Both hierarchy functions print the same `test_hierarchyControl` label; their distinct active calls were inspected in the source. All eight labels appeared in every successful invocation, followed by `There were no errors in testing.` Exit status was also zero. No simulation output was used to satisfy these physical results.

Execution used the existing Linux compatibility/transport-safeguarded port of the team's C tester, linked to the verified unmodified libMPSSE/D2XX libraries. An explicit comparison against current-main `testbench.c` confirmed that assertion calls and transaction vectors are preserved. Differences inside test bodies are two diagnostic-only printing fixes and three fail-closed timeout branches. The port also selects the exact serial, checks short transfers/timeouts and reports failures through exit status; it does not weaken expectations. See [tester audit](tmp/hardware-speed-20261108/original-tester-audit.json) and [body diff](tmp/hardware-speed-20261108/tester-body-diff.txt).

Tester binary SHA256: `4224be036ab8fec5733bfefc2f11e66f2dd4337d638b8225b0033bb7d5fc651c`. libMPSSE SHA256: `ec28fb0976aee0cd5d36a0a5f80f7c34c067fadd8ea08a8b6d872be8aa2c6e1a`; D2XX SHA256: `bab3e589500e48c9be71eedc3fc127b883ec20a752f46077202a25d66211c04f`. Live server hashes matched these before testing.

Exact tester command, run once per table row from `/workspace/spi24-20261103` in `fpga-dev` as Lenovo:

```text
env LD_LIBRARY_PATH=. ./tester --hardware --serial FTA6H280 --hz REQUESTED_HZ --generate nov8-INDEX.v
```

Programming and all SPI tests held the shared `/workspace/.hardware.lock` via its host backing file. Programmer memory/swap limits stayed at the existing 1536 MiB values; no server resource configuration changed. Initial available RAM was above 2 GiB and the runner guarded the 768 MiB headroom floor. FTDI interface 0 was temporarily detached for D2XX, then reattached and verified. Autonomous main-branch cooling remained present; this uninstrumented main image exposes no read-only temperature/RPM monitor.

The first setup attempt failed during Docker `/tmp` copying and a second attempt used the raw programmer binary without its library wrapper. Both failed before configuration. The successful attempt used the existing `/state` mount and official `quartus/bin/quartus_pgm` wrapper. Logs retain these setup failures separately; neither is a C assertion result.

Evidence: [physical results](tmp/hardware-speed-20261108/main-hardware-results.json), [programming/driver/test logs](tmp/hardware-speed-20261108/main-physical-logs/), [pin audit](tmp/hardware-speed-20261108/main-pin-audit.json), [runner](tmp/hardware-speed-20261108/remote_run.py). Raw server evidence is under `/mnt/SSDs/fpga-dev/workspace/hardware-speed-20261108-01a1bd97/`.

## Local RNG/keygen benchmark — completed

Main's keygen placeholder and standalone RNG are not connected to TPM command handling. The authorized local-only wrapper connects current-main keygen to either its deterministic public fixture or the real ring-source/Hash_DRBG, with a synthesizable SHA byte-stream adapter filling the missing hash-service connection. Production module files are unchanged. A test-only receiver stages result words for independent checks; test keys must not be used operationally.

The SHA adapter passed 183 independently calculated hashlib vectors covering one-, two- and three-block padding boundaries. Current-main Hash_DRBG connected to that adapter matched four independent software-oracle generate outputs. The full local Altera-backed benchmark fit uses 28,509 ALMs (61%), 12 RAM blocks and four DSP blocks. At 50 MHz, reported board-clock setup/hold margins are +0.989/+0.061 ns; recovery/removal are nonnegative. The asynchronous physical ring source and SPI inputs require their documented special treatment; these margins are not an entropy-quality assessment.

Benchmark SOF SHA256: `c869aa57f3d19ff5308ba7f61486763dc10736905adb4191244e8c2dc999af02`. Source fingerprint: `3eab7d6b91c28d99d69d5303a81f6a2892f6db2b2403ad605906586870f5a1b6`. Hardware readback checked that fingerprint, the distinct HWP1 identity, nominal clock register, and a scratch-register roundtrip before testing. The fitted ten-pin mapping and all 34 source hashes were verified separately.

### Measured speeds

All times below derive from on-board counters at the nominal 50 MHz board clock. USB polling, result download and independent host verification are excluded. These are initial samples, not a twenty-seed performance characterization.

| Operation | Hardware time | Scope |
|---|---:|---|
| Real ring/DRBG initialization | 32.82 µs (1,641 cycles) | Each fresh-source operation; includes collection and DRBG setup |
| Fresh AES-128 key assembly | 39.54 µs | 32.82 µs setup + 6.72 µs core/source execution |
| Fresh AES-256 key assembly | 39.70 µs | 32.82 µs setup + 6.88 µs core/source execution |
| Fixture AES-128 / AES-256 | 1.64 / 1.80 µs | Public deterministic source, including its first SHA block; exact words matched |
| Fixture RSA seed 1 | 27.93334078 s | Normal search; 54,336 source words; all 129 output words matched oracle digest |
| Fixture RSA seed 2 | 16.13424336 s | Normal search; 31,008 source words; all 129 output words matched oracle digest |
| Fixture RSA seed 3 | 14.74280464 s | Normal search; 33,728 source words; all 129 output words matched oracle digest |
| Fresh RSA trial 1 | 51.67640762 s | 104,320 accepted source words |
| Fresh RSA trial 2 | 27.81468840 s | 53,920 accepted source words |
| Fresh RSA trial 3 | 11.28241826 s | 21,600 accepted source words |

Fresh RSA median is **27.81468840 s**, range **11.28241826–51.67640762 s**, n=3. Add 32.82 µs to each fresh RSA entry for setup. These were genuine normal prime searches, not the directed known-candidate simulation shortcut. Every RSA result passed independent width/separation, probable-primality, modulus-product, private-exponent and RSA roundtrip checks; all three fresh public moduli were distinct. The checker uses 64 independently selected bases per prime. Private result factors/exponents were not written into the downloaded report.

The DRBG generated 32-byte blocks at approximately **4.995–4.999 MB/s while generation requests were active**, including periodic reseed waits observed during the fresh RSA jobs. The counters measure generated blocks, including a possible unused prefetched block; they exclude downstream consumption stalls. This is **not** sustained FTDI bandwidth or end-to-end TPM2_GetRandom throughput. A single ordinary generate request occupied 319 cycles (6.38 µs). Measured DRBG busy time for the three fresh RSA jobs was only 0.08355, 0.04318 and 0.01729 s respectively; prime search/arithmetic dominates total key time.

The real ring source and current-main Hash_DRBG were used for fresh jobs. Entropy quality, health tests, seed entropy accounting and production TPM command integration remain unvalidated. The TPM2_GetRandom byte-stream frontend was not exercised on hardware by this wrapper. The benchmark demonstrates this local module connection and measured functional behavior, not operational key provisioning.

### Hardware conditions and recovery

The first benchmark programming attempt hit the existing 1536 MiB container ceiling: kernel evidence identified a **container OOM**, not host-wide OOM. The main image was restored and its full SPI matrix passed again. The existing Windows remote JTAG connection reported authentication failure. With pools healthy and current headroom inspected, the benchmark was successfully programmed using a temporary **2048 MiB memory/no-swap ceiling**, retaining the 768 MiB available-memory abort guard. The original **1610612736-byte memory and memory-plus-swap limits** were restored and verified before the benchmark ran; persistent Compose settings were not changed.

The initial hardware gate stopped on fan alarm **0x08**, with FPGA 34°C, board 30°C and fan 6,960 RPM. Main's vendor source explicitly configures GPIO1 as FULL ON (`GPIO_DEF=0xf5`), and the [MAX6650 datasheet](https://www.analog.com/media/en/technical-documentation/data-sheets/max6650-max6651.pdf) identifies alarm bit 3 as GPIO1 low and documents its independent full-on behavior. This matches the previously recorded board override. The override was **left enabled**. A second bounded performance run accepted only alarm 0 or that explicit full-on condition, while still rejecting other alarms, missing I2C readiness, FPGA temperatures outside 5–74°C or fan speed below 1,000 RPM. Core/assertion expectations were unchanged. Normal fan-control acceptance remains **unproven**.

Recorded before/after samples during successful operations were FPGA **33–34°C** and fan **6,960–7,020 RPM**. The first stopped gate is retained in [benchmark-initial-cooling-stop.json](tmp/hardware-speed-20261108/benchmark-initial-cooling-stop.json); it was not relabeled as a pass. No fan override/configuration was disabled or rewritten for the benchmark.

After all ten operations passed, the exact unmodified-main SOF was restored by volatile JTAG and the original eight physical suites passed again at **1 MHz**. FTDI interface 0 was reattached and verified. The loaded image is main, not the test-only key-export wrapper. Main retains its −2.690 ns timing limitation and the GPIO1 fan condition remains unresolved; the main image has no exported telemetry monitor.

Across the initial eight-rate-point matrix, its post-OOM repeat, and the final single-rate restoration check, the original C tester completed **17 invocations / 136 enabled-suite executions with zero assertion failures**. This total counts repeated verification explicitly; the main table above is the initial eight-point matrix. The final audit verified the hardware lock was free, FTDI driver bound, programmer memory/swap ceilings back at 1536 MiB, no swap active, and pools healthy. All 157 tracked clone files and the benchmark's 34 source hashes remained unchanged. See [completion audit](tmp/hardware-speed-20261108/completion-audit.json) and [final hardware state](tmp/hardware-speed-20261108/final-hardware-state.json).

Evidence: [complete hardware measurements](tmp/hardware-speed-20261108/hardware-results.json), [speed summary](tmp/hardware-speed-20261108/speed-summary.json), [benchmark/programming/restoration logs](tmp/hardware-speed-20261108/benchmark-logs/), [source manifest](tmp/hardware-speed-20261108/source-manifest.json), [preservation manifest](tmp/hardware-speed-20261108/preservation-manifest.json), [adapter tests](tmp/hardware-speed-20261108/adapter-test/manifest.json). The 157 tracked clone files remain unchanged; the implementation and reproducible preparation helper are [LocalBenchmark](tmp/hardware-speed-20261108/repo/LocalBenchmark/) and [prepare_benchmark.py](tmp/hardware-speed-20261108/prepare_benchmark.py).

Automatic approval review rejected transferring the full public reference-key fixture because it contains RSA private fields. The test now transfers only expected output digests and public seeds; it compares every output word through its complete serialized digest and independently checks generated RSA arithmetic on the NAS. No private reference fields were uploaded.
