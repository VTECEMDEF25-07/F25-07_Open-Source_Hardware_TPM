# Portable key-generation core

Generate AES-128, AES-256 and RSA-2048 keys from an externally supplied generation stream. Dedicated Verilog control and PicoRV32 firmware control share the RSA arithmetic. Each can use generic resources or hand-instantiated Altera resources.

**Status: implementation is in draft review; final four-image acceptance is in progress.** The [completion matrix](docs/COMPLETION_MATRIX.md) identifies actual passes and remaining gates. Nothing merges automatically.

## System layout

```text
External coordinator + isolated generation service
                  | requests + 32-bit words
             Portable keygen core
              /                \
       AES assembler      RSA controller (RTL or firmware)
                               |
                      Shared arithmetic + scratch RAM
              \                /
        Protected 32-bit result + whole-key acceptance
                  |
       External receiver / TPM object service
```

The portable core uses one 50 MHz clock and accepts one operation at a time. Accepted parameters cannot change mid-operation. AES returns four or eight key words. RSA uses exponent 65537 and returns n, e, p and q; it calculates and checks d internally, then clears it. External words and bytes are most significant first; arithmetic uses little-endian 32-bit limbs internally.

Success requires validation, complete-result acceptance and local clearing before held terminal status. Individual word transfers do not transfer whole-key ownership. Reset aborts unaccepted work, invalidates transfers and scrubs local storage before admission resumes. It cannot revoke a key the receiver already accepted. External stalls are legal; internal watchdogs detect failed progress.

TPM commands, authorization, hierarchy seeds, production randomness, object wrapping and persistence remain external. CRT preparation and Xilinx-specific resources are deferred. The DE25 demonstration uses predictable test streams and exports test keys for independent checking; production integration excludes that board test wrapper.

## Read the design

| Document | What it explains |
|---|---|
| [Interface](docs/INTERFACE.md) | Exact signals, ordering, ownership, reset and fault codes |
| [Core lifecycle](docs/CORE.md) | Admission, workers, clearing and terminal status |
| [RSA algorithm](docs/RSA_ALGORITHM.md) | FIPS procedure, bounds, witnesses, retries and correction audit |
| [AES worker](docs/AES.md) | Key assembly, transfer and clearing |
| [RSA engine](docs/RSA_ENGINE.md) | Shared services and dedicated controller |
| [Pair validation](docs/PAIR_CHECK.md) | Modulus, GCD/LCM, private inverse and checks |
| [Soft-core control](rtl/rsa_softcore/RSA_CONTROL.md) | Firmware, acceleration and CPU cleanup |
| [Resources](IP/README.md) | Generic/Altera latency, RAM collisions and actual-model equivalence |
| [Arithmetic](Math/README.md) | Limb operations and independent vectors |
| [Coding standards](CODING_STANDARDS.md) | Verilog-2001 source, approved SV tests and naming rules |
| [Build and test](docs/BUILD_AND_TEST.md) | Reproducible simulation and board commands |
| [DE25 demo](demo/de25_revd/README.md) | Wiring, SPI registers and bounded host tests |
| [Release](docs/RELEASE.md) | Four-image evidence and package/rebuild procedure |
| [Dependencies](docs/DEPENDENCIES.md) | Pinned versions, source provenance and supplied license notices |
| [Measured comparison](docs/FINAL_COMPARISON.md) | Per-build latency, physical resource use, timing and remaining acceptance |

## Source organization

- `rtl/common`, `rtl/aes`, `rtl/rsa_rtl`, `rtl/rsa_softcore`: portable control.
- `rtl/arithmetic`: limb arithmetic and private pair validation; `Math/` contains associated documentation, tests and runners.
- `IP/keygen_*`: resource wrappers and generic/Altera implementations; `IP/third_party`: pinned PicoRV32 source and license.
- `firmware`, `reference`, `testbench`: firmware, independent checks and fixtures.
- `demo/de25_revd`, `demo/test_rng`: board adaptation and explicit test stream.
- `scripts`: build, simulation, evidence and release helpers.

`RSA_SOFTCORE=0/1` selects the controller; `KEYGEN_ALTERA` selects Altera resources. Both controllers consume the same ordered words and produce identical keys under different stalls. Vendor simulation must use genuine installed Altera models. Generated Quartus databases, waveforms, logs and firmware products are ignored; source, constraints, scripts, licenses and checked fixtures remain tracked.

## Acceptance and review

All four configurations must simulate, route at 50 MHz, fit the DE25 with the 70% resource-headroom target, and pass physical validation. Each needs the fixed 20-seed RSA corpus with median generation at most 30 seconds, a 180-second host deadline per operation, three SPI rates, AES checks, replay/reset/fault recovery, and a 30-minute mixed-operation soak with healthy cooling.

See the [evidence ledger](docs/ACCEPTANCE.md) for historical measurements and the [completion matrix](docs/COMPLETION_MATRIX.md) for remaining work. The initial soft-core/Altera image met the RSA median target but failed cooling acceptance; corrected images must repeat testing.

Review architecture first, then interfaces/resources/AES, arithmetic, each RSA controller and board integration. Each draft MR includes behavior, dependencies, reading order, reproducible tests and limitations. The closed legacy plumbing and staged-store drafts are not dependencies of this implementation.
