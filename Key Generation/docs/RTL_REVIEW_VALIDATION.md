<!-- Codex assisted with this review guide and verification. -->

# Dedicated-logic split validation

Date: October 23, 2026. Scope: removal of the CPU-controlled path from PR #35, retaining dedicated RTL with generic and Altera resources. The prior combined implementation is preserved on `aaron/keygen-cpu` at `c90610165605cac55243522847c5e5f50f60ef08`.

## Results on the dedicated-only source

Commands below run from `Key Generation`; Linux commands use Ubuntu 24.04/WSL and Verilator 5.020. Python offline tests use Python 3.14 on Windows.

| Check | Command | Result |
|---|---|---|
| Packaging and hardware-report gates | `python -m unittest discover -s scripts -p 'test_*.py'` | PASS: 36 tests |
| Independent reference | `python -m unittest discover -s reference -p 'test_*.py'` | PASS: 13 tests |
| Host, fan and board-build helpers | `python -m unittest discover -s demo/de25_revd/tests -p 'test_*.py'` | PASS: 52 tests, including rejection of CPU images |
| Core lifecycle | `python3 scripts/run_integration_verilator.py --suite lifecycle` | PASS: 28 checks |
| RSA services | `python3 scripts/run_integration_verilator.py --suite services` | PASS: 49 checks |
| Complete generic RSA | `python3 scripts/run_full_verilator.py --directed --stalls --seeds 1 --label advisor-rtl` | PASS: all 129 result words match the independent fixture; 384 input words; 136,232,057 cycles |
| Real core over SPI | `python3 demo/de25_revd/simulate_real.py --core-root . --build build/advisor-real-spi` | PASS: AES128/256, capture, source/result/ownership stalls, errors, reset and RSA abort/recovery |
| Board reset boundary | `python3 demo/de25_revd/simulate_top.py --build build/advisor-top-reset` | PASS; isolated reset test with core/fan models |
| SHA/SPI source hold | `python3 demo/de25_revd/simulate_source_hold.py --build build/advisor-source-hold` | PASS: outstanding offer, single transfer, pause/resume and reset; controllable core model |
| Board preparation | `python demo/de25_revd/prepare_build.py --build-root build/advisor-board --variant all` | PASS: exactly `rtl_generic` and `rtl_altera`; no firmware required; snapshot/config hashes checked |
| Repository hygiene | `python scripts/check_repository_hygiene.py` and `git diff --check` | PASS |
| Genuine Altera full RSA | `python scripts/run_full_altera_questa.py --directed --stalls --seeds 1 --label advisor-altera` | PASS: all 129 result words match; 384 input words; 136,232,057 cycles, identical to generic resources |

Source audit found no CPU RTL, PicoRV32 source, firmware files, controller selectors or CPU build options in the retained implementation. Changed Markdown links resolve. Python syntax checks pass. Complete generic RSA input hashes still match the tested source; its manifest SHA-256 is `d0b41dee270dde4e9a5b1776b910ae772e6e75b819af04985a22ed65f80a1bb7`.

The genuine-model run completed successfully in 2,844.45 simulator seconds. Its source, runner, installed vendor-model, fixture and log hashes were rechecked after completion. Run-manifest SHA-256: `0f32ce60516155bac7601317cc59245e098874c3edfddd3c7396db3dd6f56c6b`; build-manifest SHA-256: `cf6a97dc495634f7ef70bf7f43193fd59e5933b2392031f41318488fce60e909`. The installed model's AUTO RAM-block warning remains a simulation-model limitation; this run does not establish device-specific RAM mapping or fit.

## Interpretation and limits

The directed RSA case exercises actual primality/pair arithmetic and cleanup under stalls, but skips prime search using known candidates. Its 2.72464114 seconds at 50 MHz is a cycle-derived functional-test duration, not a hardware measurement or 20-seed search benchmark. Source/model manifests and logs are retained in the named ignored build directories in the class workspace.

No fresh FPGA place-and-route, timing signoff, physical tester run, 20-seed hardware benchmark or soak was performed for this split. Historical measurements apply only to their original snapshots. Generic RAM inference/fit and production TPM integration remain open as described in [COMPLETION_MATRIX.md](COMPLETION_MATRIX.md). Source-review readiness does not imply hardware release acceptance.
