<!--
Filename: README.md
Authors: Aaron Grossman; Project contributors; see Git history.
Date: 2026-11-08
General Description: Introduces the portable key generator and its integration boundaries.
AI Disclosure: Codex assisted with consolidation; see docs/AI_DISCLOSURE.md in the keygen source folder.
-->

# Portable key generation

Generate AES-128, AES-256 and RSA-2048 keys using dedicated Verilog logic and an externally supplied generation stream. One operation runs at a time. The RSA controller is a hardware state machine; there is no CPU, firmware or instruction ROM dependency.

```text
External coordinator + generation stream
                  |
             keygen_core
          /               \
 AES key assembly     RSA controller
                      arithmetic + private RAM
          \               /
        Result words -> ownership decision -> clearing -> status
```

AES returns four or eight 32-bit words. RSA uses exponent 65537 and returns n, e, p and q; d is calculated and checked internally, then cleared. External words are most significant first; private arithmetic uses little-endian 32-bit limbs. The `IP_TYPE` parameter selects Generic or Altera resources as described below.

## Resource selection

Set the commented `FPGA_IP_TYPE` define at the top of the board source. Its value becomes the board IP_TYPE default and propagates through TPM_TOP. Standalone modules use 0 (Generic) or 1 (Altera); 2 (reserved Xilinx) is rejected. There is no shared vendor header. The define is local to the board source; reusable keygen modules receive the parameter explicitly.

```verilog
TPM_TOP #(.IP_TYPE(1)) tpm (...);
// For standalone use:
keygen_core #(.IP_TYPE(0)) keygen (...);
```

`TPM_TOP` passes the same parameter through its inactive keygen placeholder. Keygen propagates it through the RSA engine, math/pair checker and each RAM/multiplier wrapper. Generate blocks elaborate the selected implementation independently per instance. Invalid values fail elaboration in Questa/Quartus and cause a fatal error in Verilator. Xilinx implementations remain future work.

DE1 and DE25 both select Altera at their board top. Fixed `DEVICE_FAMILY` metadata propagates to keygen memories: Cyclone V/M10K for DE1 and Agilex 5/M20K for DE25. Unknown RAM families are rejected. Board PLL/reset/fan circuitry remains board-specific; implementation wrappers reject unsupported resource backends. This does not establish that an active full keygen fits either board.

## Where to start

- **Integrating the module:** [interface and lifecycle](docs/INTERFACE.md).
- **Reviewing RSA correctness:** [algorithm and implementation](docs/RSA_ALGORITHM.md).
- **Running checks:** [simulation instructions and validation summary](../../Testing/Simulation/Key%20Generation/README.md).
- **Attribution:** [Aaron Grossman's contribution, AI use and course disclosure](docs/AI_DISCLOSURE.md), [dependencies and notices](CREDITS.md), [coding standards](CODING_STANDARDS.md).

The implementation lives in `rtl/common/`, `rtl/aes/`, `rtl/rsa_rtl/`, `rtl/arithmetic/` and `IP/`. The [resource](IP/README.md) and [math](Math/README.md) READMEs are optional detailed references. Benches, the independent Python oracle, fixtures and runners live under `Testing/Simulation/Key Generation/`.

## Integration limits and remaining work

TPM command handling, authorization, production entropy/DRBG and hierarchy seeds, object wrapping, CRT preparation and protected storage remain external. The receiver must implement the whole-key ownership/discard contract; receiving the last word alone does not accept a key.

The shared [DE1/DE25 projects](../../Project/README.md) contain a temporary keygen hierarchy so `TPM_TOP.IP_TYPE` reaches the resource wrappers. The placeholder's clock/reset are connected, all request/source/ownership inputs are tied inactive, and outputs are unused. Synthesis may remove it entirely. It is not connected to TPM commands, entropy, storage or responses. Demonstration transport and packaging are local-only. Public deterministic fixtures are not production entropy.

Before claiming hardware release acceptance, resolve generic RAM inference/full-core fit, validate source-matched timing and reset/CDC, and run physical correctness, normal-stream multi-seed performance, recovery and cooling/soak tests. Directed known-candidate simulations establish functional behavior, not prime-search performance, side-channel resistance or certification.

Historical CPU work remains on `aaron/keygen-cpu` at `c90610165605cac55243522847c5e5f50f60ef08`. Earlier review ledgers are retained in Git history; they are not additional required reading.
