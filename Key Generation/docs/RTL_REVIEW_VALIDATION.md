<!-- Codex assisted with this review guide and verification. -->

# Dedicated-logic split validation

Date: October 23, 2026. Scope: removal of the CPU-controlled path from PR #35, retaining dedicated RTL with generic and Altera resources. The prior combined implementation is preserved on `aaron/keygen-cpu` at `c90610165605cac55243522847c5e5f50f60ef08`.

The SPI/reset simulation utilities and fan-only diagnostic builder were subsequently moved to ignored `local_scripts/spi_verification/`. Their results below record the earlier runs; these utilities are not included in the PR. Production HDL was unchanged by that cleanup. The 52-test host/helper count includes five runner checks now kept locally.

The entire DE25 demo, board preparation and release packager have since been removed from this PR. Their results below are historical local evidence, not commands provided by this checkout. The deterministic full-core fixture moved unchanged to `testbench/fixtures/keygen_test_source.v`; production core RTL is unchanged.

## Checks after demo extraction (October 23)

- Complete generic RSA rerun with `--directed --stalls --seeds 1 --label demo-extracted`: PASS; all 129 result words match, 384 input words, 136,232,057 cycles. Source-manifest SHA256: `e4f8ce0367261c81ab27d25c35deb9630d1f4183359871d65d62c7cd80555f31`.
- 13 reference tests and repository hygiene: PASS.
- 47 relocated local host/build tests and preparation of both local demo variants: PASS; these are not distributed PR tests.
- Production RTL/IP unchanged; deterministic fixture preserved byte-for-byte. Markdown links, Python syntax and Git whitespace checked.
- DE25 board support is validated independently against main in its own PR. No new physical-board test is claimed here.

## Results before demo extraction

Commands below run from `Key Generation`; Linux commands use Ubuntu 24.04/WSL and Verilator 5.020. Python offline tests use Python 3.14 on Windows.

| Check | Command | Result |
|---|---|---|
| Packaging and hardware-report gates | Local archived packaging tests | PASS: 36 tests |
| Independent reference | `python -m unittest discover -s reference -p 'test_*.py'` | PASS: 13 tests |
| Host, fan and board-build helpers | Local demo tests | PASS: 52 tests, including rejection of CPU images |
| Core lifecycle | `python3 scripts/run_integration_verilator.py --suite lifecycle` | PASS: 28 checks |
| RSA services | `python3 scripts/run_integration_verilator.py --suite services` | PASS: 49 checks |
| Complete generic RSA | `python3 scripts/run_full_verilator.py --directed --stalls --seeds 1 --label advisor-rtl` | PASS: all 129 result words match the independent fixture; 384 input words; 136,232,057 cycles |
| Real core over SPI | `python3 ../local_scripts/spi_verification/simulate_real.py --core-root . --build build/advisor-real-spi` | PASS: AES128/256, capture, source/result/ownership stalls, errors, reset and RSA abort/recovery |
| Board reset boundary | `python3 ../local_scripts/spi_verification/simulate_top.py --build build/advisor-top-reset` | PASS; isolated reset test with core/fan models |
| SHA/SPI source hold | `python3 ../local_scripts/spi_verification/simulate_source_hold.py --build build/advisor-source-hold` | PASS: outstanding offer, single transfer, pause/resume and reset; controllable core model |
| Board preparation | Local demo build preparation | PASS: exactly `rtl_generic` and `rtl_altera`; no firmware required; snapshot/config hashes checked |
| Repository hygiene | `python scripts/check_repository_hygiene.py` and `git diff --check` | PASS |
| Genuine Altera full RSA | `python scripts/run_full_altera_questa.py --directed --stalls --seeds 1 --label advisor-altera` | PASS: all 129 result words match; 384 input words; 136,232,057 cycles, identical to generic resources |

Source audit found no CPU RTL, PicoRV32 source, firmware files, controller selectors or CPU build options in the retained implementation. Changed Markdown links resolve. Python syntax checks pass. Complete generic RSA input hashes still match the tested source; its manifest SHA-256 is `d0b41dee270dde4e9a5b1776b910ae772e6e75b819af04985a22ed65f80a1bb7`.

The genuine-model run completed successfully in 2,844.45 simulator seconds. Its source, runner, installed vendor-model, fixture and log hashes were rechecked after completion. Run-manifest SHA-256: `0f32ce60516155bac7601317cc59245e098874c3edfddd3c7396db3dd6f56c6b`; build-manifest SHA-256: `cf6a97dc495634f7ef70bf7f43193fd59e5933b2392031f41318488fce60e909`. The installed model's AUTO RAM-block warning remains a simulation-model limitation; this run does not establish device-specific RAM mapping or fit.

## Interpretation and limits

The directed RSA case exercises actual primality/pair arithmetic and cleanup under stalls, but skips prime search using known candidates. Its 2.72464114 seconds at 50 MHz is a cycle-derived functional-test duration, not a hardware measurement or 20-seed search benchmark. Source/model manifests and logs are retained in the named ignored build directories in the class workspace.

No fresh FPGA place-and-route, timing signoff, physical tester run, 20-seed hardware benchmark or soak was performed for this split. Historical measurements apply only to their original snapshots. Generic RAM inference/fit and production TPM integration remain open as described in [COMPLETION_MATRIX.md](COMPLETION_MATRIX.md). Source-review readiness does not imply hardware release acceptance.

DE25 board support: [PR #36](https://github.com/VTECEMDEF25-07/F25-07_Open-Source_Hardware_TPM/pull/36), targeting main and intended to merge first.
