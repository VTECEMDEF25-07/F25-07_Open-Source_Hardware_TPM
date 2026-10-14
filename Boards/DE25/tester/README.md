# Original TPM tester on DE25

`testbench_safe.c` preserves the original eight test suites from
`IO Interface/Testbenches/testbench.c`. The original remains untouched.
`provenance.json` records its hash; `original_to_safe.diff` makes the changes reviewable.

Current status: **All eight original suites pass on DE25 at 100 kHz,
500 kHz and 1 MHz using the final 2 ms latency build**. The preceding 255 ms build passed all eight suites
at 100 kHz in 138.688 seconds; retained evidence is
`CLASS/AI/tmp/phase1-original-hardware-100k/result.json`. Here CLASS means
the SeaDrive class workspace root.
Runner regression: five mocked-process/argument tests pass (never open USB).
The original 1.0.8 download returned HTTP 403. The vendor's regional site supplied
the genuine 1.0.7 Windows SDK; this version difference is explicit. No substitute
SPI implementation is being counted as the original tester.

Validated executable: `CLASS/AI/tmp/original-tester-build-v2/tester.exe`, SHA-256
`76b7b69895814a7835794d1663e3fbbe63b1aefc7cddcf199b4a6f1465f67e59`.
`build.json` there records the exact command and input hashes. The unchanged
GCC 13 compiler and SDK package hashes remain in the preceding
`CLASS/AI/tmp/original-tester-build/build.json`. `compile.log` retains warnings inherited from the original
source (unused variables, signedness, format types and an implicit zero initializer).
Offline evidence: `CLASS/AI/tmp/original-tester-offline-v5/result.json` and generated
`tb_original.v`. This verifies executable/DLL loading and generation, not hardware.

## Dependencies and build

Use a Windows-targeting C compiler and matching-architecture FTDI libMPSSE DLL,
import library and headers (`FTDI/ftd2xx.h`, `FTDI/libMPSSE_spi.h`). The original
source specifies libMPSSE1.0.8 from
https://ftdichip.com/wp-content/uploads/2025/08/libmpsse-windows-1.0.8.zip .
The local `C:/Windows/System32/ftd2xx.dll` exists. That D2XX driver DLL alone does
not supply the libMPSSE API. SDK1.0.7 was downloaded from the link published on
https://www.ftdichip.cn/Support/SoftwareExamples/MPSSE/LibMPSSE-SPI.htm :
https://www.ftdichip.cn/Support/SoftwareExamples/MPSSE/LibMPSSE_1.0.7.zip .
Exact download hash/URL and retained vendor notices are under
`CLASS/AI/tmp/original-tester-deps/`. MinGW GCC13 packages were unpacked locally
there under `mingw/`, without system compiler or driver installation.

Keep downloaded vendor/tool files and generated binaries under class `AI/tmp/`.
Retain vendor notices; do not commit DLLs or toolchains. Example MinGW build,
once dependencies exist (FTDI include directory must have an `FTDI/` child):

```text
gcc -std=c11 -Wall -Wextra -D_WIN32_WINNT=0x0600 -I<include-root> testbench_safe.c -L<FTDI-win64-library-folder> -llibMPSSE -lftd2xx -o <build>/tester.exe
```

The reviewed `build_tester.py` automates the verified GCC/DLL path:

```text
python build_tester.py --compiler <Windows-targeting-gcc> --sdk <SDK-release> --driver <x64-ftd2xx.dll> --output <fresh-build>
```

For the isolated WSL compiler, also pass `--system-include` with its unpacked
`usr/x86_64-w64-mingw32/include` directory and use `/mnt/c/` input paths.
The script successfully compiled the tester in `CLASS/AI/tmp/original-tester-builder-check/`.
It records source/header/DLL hashes and command, and never launches the executable.
Supply architecture-matched import libraries, or use the vendor DLL as a
MinGW link input where supported. Preserve the exact compiler/build output and
hash executable, headers and DLLs. Put the libMPSSE runtime DLL beside the
executable. Do not infer build success from this example command.

## Safe defaults and launch

The executable defaults to offline Verilog generation and never enumerates or
opens USB unless `--hardware` is supplied. It generates a short basename in its
working directory. Use a fresh output directory with the bounded Python runner:

```text
python run_original.py --exe <build>/tester.exe --output <scratch>/offline
python run_original.py --exe <build>/tester.exe --output <scratch>/hardware-100k --hardware --serial FTA6H280 --hz 100000
```

The DE25 runner caps SPI at1MHz to match the new oversampled serializer; the
legacy tester's24MHz setting is outside that migration's supported contract.
Only the lead should run the hardware command after approving/programming the
DE25 migrated original TPM image and releasing other adapter users. The default
serial is FTA6H280; selection requires exactly one matching FT232H serial and PID.
Start at 100 kHz. Do not run concurrently with another SPI application.

The runner imposes a 180-second whole-process timeout (configurable up to 600),
captures output in memory and closes the evidence files after completion. D2XX
transfer timeouts are 1500 ms; each TPM SPI wait-state loop is bounded to one
second. Transport errors, short transfers, execution timeouts and assertion
failures produce a nonzero exit. Hardware success also requires all eight suite
markers and the original no-errors summary. Offline generation is explicitly
labeled OFFLINE_GENERATED and never counts as a hardware pass.

## Coverage and limits

The unchanged suite logic covers debug register read/write, locality changing,
locality permissions, status state transitions, locality seize/command abort,
two hierarchy-control cases, and the original quote-command test. These are
integration checks, not complete TCG conformance, cryptographic quote-signature
validation or key-generation acceptance. The separately defined
test_sendReceiveCMD function is not called by the original main routine.

The generated Verilog names the legacy test0_top wrapper and its original
100 MHz behavioral PLL; adapt the simulation wrapper separately when validating
the DE25 top. Existing AI/tmp/de25-spi-demo transport/XOR assets can help diagnose
wiring but do not validate this original TPM design. Older fan bitstreams are
not evidence for the current migrated image.

Review original_to_safe.diff: changes are explicit serial/frequency selection,
offline mode, bounded/checked transport, failing exits, and diagnostic-only
out-of-bounds print corrections. No TPM suite has been replaced by a mock.
test_runner.py mocks only the launcher process for its five safety tests:

```text
python test_runner.py
```

The final 2 ms binary hardware results are recorded below. The earlier
100 kHz pass remains separately bound to the previous executable.

## USB latency and idle reset

The inherited 255 ms USB receive latency is now 2 ms, without changing SPI
frequency or suite logic. FTDI AN_178 section 3.4.1 permits 1-255 ms for FT232H;
2 ms also fits the D2XX documented range. See the
[official libMPSSE guide](https://ftdichip.com/wp-content/uploads/2023/08/AN_178_User-Guide-for-LibMPSSE-SPI.pdf).
The duplicate connection-time FT_SetTimeouts call was removed; the single
1500 ms setting after every initialization, including reset/reopen, remains.

The original Pin setting 0x00101010 is preserved. SDK header lines 127-130
and AN_178 define its four bytes: initial direction/value 0x10/0x10, final
direction/value 0x10/0x00. Thus DBUS4 (gray TPM reset) is high after channel
initialization and low after channel close. Closing the tester intentionally
holds the TPM in reset; the next initialization releases it. Board management
and cooling remain active. In this Phase1 monitor, status 5 after close is
expected idle reset; requiring status 7 there would mislabel healthy cooling.
The original post-test monitor report is retained rather than rewritten.


## Final DE25 hardware validation

The final 2 ms latency binary passed all eight original suites at 100 kHz
(4.095 s), 500 kHz (2.869 s) and 1 MHz (2.891 s). Evidence directories are
`AI/tmp/phase1-original-hardware-v2-100k`, `-500k`, and `-1m` under the class
root. Each run completed with zero process exit, every suite marker and the
original no-errors summary. The board validation JSON in `../validation/`
binds exact binary/log hashes and records the inherited Phase 1 limitations.
