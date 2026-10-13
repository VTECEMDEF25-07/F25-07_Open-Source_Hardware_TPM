# Build and test the portable key generator

The reusable top is `rtl/common/keygen_core.v`. It generates AES-128/AES-256
keys and RSA-2048 key pairs from an external ordered generation stream.
It contains no board pins, hierarchy seed storage, production entropy source,
TPM object wrapper or complete TPM command processor.

`RSA_SOFTCORE=0` selects dedicated control; `1` selects RV32I firmware control.
Define `KEYGEN_ALTERA` for direct Altera multiplier/RAM macros; omit it for
generic Verilog resources. All project RTL is Verilog-2001. SV is used in tests.
Xilinx-specific resources remain deferred.

## Read before building

1. `INTERFACE.md`: exact handshakes, ordering, reset, ownership and errors.
2. `RSA_ALGORITHM.md`: candidate/witness procedure, bounds and retry accounting.
3. `CORE.md`, `RSA_ENGINE.md` and `PAIR_CHECK.md`: implementation and cleanup.
4. `../rtl/rsa_softcore/RSA_CONTROL.md`: firmware descriptors and CPU cleanup.
5. `../demo/de25_revd/README.md`: board pins, SPI registers and host validation.
6. `ACCEPTANCE.md`: what actually passed and what remains outstanding.

Arithmetic scratch totals 18 KiB: 16 KiB shared math plus 2 KiB pair validation.
The soft core also has 32 KiB firmware ROM and 16 KiB data RAM. The CPU accesses
descriptors, not private big-integer storage. Both controllers use the same
arithmetic and generation-word ordering.

## Dependencies and outputs

The validated environment uses Quartus Pro 26.1 for Agilex 5 fitting, Questa
2024.3 with unchanged Quartus 24.1 functional model files, Verilator 5.020 under
WSL for fast generic simulation, and the pinned RV32I compiler described in
`../firmware/TOOLCHAIN.md`. PicoRV32 source and its license are pinned under
`../IP/third_party/picorv32/`. Keep downloaded toolchain licenses with the tools.

The older functional RAM model's AUTO-family warning is disclosed in
`../IP/README.md`; separate device fits establish actual M20K/DSP mapping.
Verilator cannot compile the unchanged vendor multiplier model used here;
generic simulation is never counted as vendor-model evidence.

Use ignored `build/` directories or the class workspace's `AI/tmp/` for outputs.
Source, constraints, fixtures, scripts and dependency manifests remain tracked.
Run `python scripts/check_repository_hygiene.py` from this directory to check
the ignore rules. Do not commit compiled firmware, simulator libraries or
Quartus databases. Retain bitstreams and reports with their build manifests
outside tracked source, and commit concise evidence summaries.

## Firmware and core simulation

These commands assume the current directory is `Key Generation`. On Windows,
build the exact firmware before running either soft-core or board tests:

```powershell
python scripts/softcore/build_rsa.py --toolchain '<xPack toolchain>/bin' --output build/full
```

The builder checks the compiler, source and resulting image against the reviewed
manifest and rejects a mismatch. The control firmware uses 1,648 bytes of text.
Generated `rsa_control.hex` contains the full padded ROM image.

From the same directory under WSL/Linux:

```sh
python3 scripts/run_integration_verilator.py
python3 scripts/run_integration_verilator.py --softcore
python3 scripts/run_full_verilator.py --directed --stalls --seeds 1 --label review-rtl
python3 scripts/run_full_verilator.py --softcore --directed --stalls --seeds 1 --label review-cpu
```

Remove `--directed` to run the complete SHA-fixture search. Directed inputs still
exercise primality and pair checks but skip candidate search, so their runtime
does not establish the 20-seed performance target. Use a fresh label for retained
evidence. Build manifests bind source, tests, firmware, fixture and simulator
inputs; reuse is refused when they no longer match.

On Windows, actual Altera-model full-key simulation uses:

```powershell
python scripts/softcore/run_full_altera_questa.py --directed --stalls --seeds 1 --label review-rtl
python scripts/softcore/run_full_altera_questa.py --softcore --directed --stalls --seeds 1 --label review-cpu
```

Run one Questa session at a time on the installed license. Use the module docs
for independent resource, arithmetic, candidate, controller and clearing tests.
A successful compile is not a test pass: runners require explicit completed
results and reject errors, timeout and missing output.

## Four physical board builds

`prepare_build.py` prepares all four controller/backend combinations. It copies
and hashes sources, firmware, constraints, pin references and tool identity.
Every variant directory is write-once; choose a new root after source changes.

```powershell
python demo/de25_revd/prepare_build.py --core-root '<absolute Key Generation directory>' --build-root '<class workspace>/AI/tmp/keygen-build-REV'
python demo/de25_revd/compile_build.py '<class workspace>/AI/tmp/keygen-build-REV/rtl_generic'
```

Repeat compilation for `rtl_altera`, `softcore_generic` and `softcore_altera`.
Run one full Quartus build at a time on this development machine: concurrent
fits exhausted available memory during validation. These commands never program
the board. Compilation must be followed
by review of final resource use, 50 MHz setup/hold, reset/clock crossings and all
unconstrained paths. `timing_accepted` remains false until that review.

## Physical acceptance, one image at a time

Only the coordinating lead programs the shared board. Record programming output
and the exact bitstream hash. The host requires the selected manifest and checks
all eight words of the loaded build fingerprint before testing. This detects
the wrong image; it is not secure boot or image authentication.

```powershell
python demo/de25_revd/host_test.py --action transport --frequency 100000 --manifest '<build_manifest.json>' --report '<report.json>'
```

Use separate report paths for every action. Repeat transport at 500 kHz and
1 MHz, then run `aes`, `corpus`, `stall-replay`, `reset-replay` and `soak` actions
with the same manifest. `corpus` checks all 20 fixed seeds and a median of at
most 30 seconds; every generation has a 180-second deadline. `soak` runs mixed
operations for at least 30 minutes and logs temperature/fan samples and errors.
Review thermal telemetry as well as the mathematical PASS results.

Independently summarize completed corpus reports with:

```powershell
python scripts/summarize_hardware.py '<corpus.json>'
python -m unittest discover -s scripts -p test_summarize_hardware.py
```

Multiple report arguments produce a comparison without changing the reports.
The auditor recomputes timing statistics, requires the complete fixed seed set,
and rejects unhealthy or absent cooling samples. It returns nonzero for an
incomplete or failed gate. A passing corpus audit covers only those sampled
operations; it does not replace simulation, timing, replay or soak acceptance.
The corpus auditor checks report content; artifact/source hash binding still
requires the build manifest review and the host's loaded-fingerprint check.

Reset through the gray SPI lead affects key generation, not cooling. The
demonstration uses predictable test streams and deliberately exports test keys
over SPI for checking; reports do not retain key words. Production integration
uses the portable core's protected interface and excludes this demo wrapper.

Repeat the entire physical sequence for all four images. Completion requires
the linked simulation, timing, correctness, performance and soak evidence for
each; a single working key or bitstream is an intermediate result.
