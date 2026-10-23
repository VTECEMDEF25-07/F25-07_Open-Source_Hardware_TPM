<!--
Filename: README.md
Authors: Project contributors; see Git history.
Date: 2026-09-30
General Description: Documents Portable key-generation core.
AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.
-->

# Portable key-generation core

Generate AES-128, AES-256 and RSA-2048 keys from an externally supplied generation stream using dedicated Verilog logic. The RSA controller is a hardware state machine; there is no CPU, instruction ROM or firmware dependency in this branch. Generic Verilog and hand-instantiated Altera resources remain available.

**Faculty review entry point: [REVIEW.md](REVIEW.md).** This is a source/design review, not production TPM certification or final board acceptance. [Validation](docs/RTL_REVIEW_VALIDATION.md) records the checks performed for this split and their limits.

## Architecture

```text
External coordinator + generation service
             | requests + ordered 32-bit words
        keygen_core (one operation at a time)
          /                           \
 AES key assembler             RSA state machine
                                     |
                        Arithmetic services + scratch RAM
          \                           /
       Protected result + whole-key ownership handshake
                     |
             External TPM object service
```

The portable core uses one clock (50 MHz in the demo). AES returns four or eight key words. RSA uses exponent 65537 and returns n, e, p and q; it calculates and checks d internally, then clears it. External words are most significant first; arithmetic uses little-endian 32-bit limbs.

Successful completion requires validation, whole-result acceptance and local clearing before held terminal status. Reset aborts unaccepted work and scrubs local storage before admission resumes. It cannot revoke a key already accepted by the receiver. External stalls are legal; internal watchdogs detect failed progress.

TPM commands, authorization, hierarchy seeds, production randomness, object wrapping and persistence remain external. The DE25 demonstration uses predictable test streams and exports test keys for independent checking. It is separate from the Phase 1 TPM board top.

## Read the design

| Document | Purpose |
|---|---|
| [Interface](docs/INTERFACE.md), [Core lifecycle](docs/CORE.md) | Handshakes, ordering, ownership, reset and faults |
| [RSA algorithm](docs/RSA_ALGORITHM.md), [RSA engine](docs/RSA_ENGINE.md) | Procedure, bounds, retries, descriptors and controller |
| [AES](docs/AES.md), [Pair validation](docs/PAIR_CHECK.md) | Key assembly and private arithmetic checks |
| [Resources](IP/README.md), [Arithmetic](Math/README.md) | Generic/Altera implementations and independent vectors |
| [Build and test](docs/BUILD_AND_TEST.md) | Reproducible commands |
| [DE25 demo](demo/de25_revd/README.md) | Test-only transport, wiring and cooling |
| [Completion matrix](docs/COMPLETION_MATRIX.md) | Review scope and outstanding board gates |
| [Dependencies](docs/DEPENDENCIES.md), [Coding standards](CODING_STANDARDS.md) | Provenance, notices and Verilog rules |
| [Release](docs/RELEASE.md) | Strict two-image package and rebuild gates |

## Source organization

- `rtl/common`, `rtl/aes`, `rtl/rsa_rtl`: public lifecycle and dedicated controllers.
- `rtl/arithmetic`, `Math`: arithmetic, pair checks and independent tests.
- `IP`: resource wrappers; `KEYGEN_ALTERA` selects actual Altera primitives.
- `reference`, `testbench`, `scripts`: independent oracle, tests and build helpers.
- `demo/de25_revd`, `demo/test_rng`: board adaptation and explicit deterministic test source.

The CPU-controlled implementation is preserved on [aaron/keygen-cpu](https://github.com/VTECEMDEF25-07/F25-07_Open-Source_Hardware_TPM/tree/aaron/keygen-cpu), starting at `c90610165605cac55243522847c5e5f50f60ef08`. It is outside this PR's final diff. The existing PR history is retained; no force push is required.
