# Shared RSA pair arithmetic

`keygen_pair_check` captures two already-tested 1024-bit prime candidates on `start_valid_i && start_ready_o`, validates their RSA relationships, and holds a public 2048-bit modulus/status until accepted. Primality remains the caller's responsibility. Ports are unchanged by the RAM-based implementation.

## Interface and cleanup

Only status 0 exposes n. Other statuses are 1 for invalid bounds/parity/separation or exponent incompatibility, 2 for a canonical private exponent that is too small, and 3 for arithmetic inconsistency. Status 2 requires restarting both prime searches. There is no private-exponent output. The caller retains and ultimately scrubs its own p/q copies.

Reset immediately invalidates outputs and clears captured-input/public-output staging and scalar registers. It then sweeps all 512 private RAM words and performs a separate read of the last zeroed word to clear the RAM output latch. Ready returns after 514 rising edges. Success and failure use the same sweep before result-valid; only a successful public modulus remains in staging. The multiplier's actual pipeline reset is held throughout cleanup. RAM contents are never asynchronously reset.

## Resource allocation and layout

The pair service uses one 512x32 RAM (2 KiB; one M20K) and the shared generic/Altera wrapper contract, plus a 32x32 multiplier. This explicitly increases the accelerator's private RAM allocation from 16 KiB to **18 KiB**, using nine M20Ks total for math and pair scratch out of the board's 358. CPU-local RAM and public transport storage are separate allocations. The extra 2 KiB replaces thousands of private register bits and parallel wide arithmetic units.

| Word addresses | Contents |
| --- | --- |
| 0–31, 32–63 | Captured p, q |
| 64–95, 96–127 | Binary GCD working operands |
| 128–191 | Public product n |
| 192–255 | First phi, then lambda |
| 256–319 | Restoring-division remainder |
| 320–384 | Numerator, then canonical d with an overflow word |
| 385–511 | Reserved; still scrubbed |

Inputs are captured atomically in the 2048-bit staging register before serial RAM writes, so callers may change p/q immediately after the handshake. Staging is then cleared and reused for final n. The internal limb ALU reads private RAM synchronously and performs compare, subtraction and shifts over 32-bit words. No private operand is available through CPU control descriptors.

## Arithmetic sequence

1. Require odd p/q at least `ceil(sqrt(2)*2^1023)` and absolute separation strictly greater than `2^924`.
2. Form n and phi=(p-1)*(q-1) with schoolbook limb multiplication. Verify exactly 2048 modulus bits.
3. Find gcd(p-1,q-1) with binary GCD and restore common powers of two. All shifts and subtractions use the shared 32-bit ALU.
4. Restore-divide phi by the GCD over 2048 quotient bits, check zero remainder/nonzero lambda, and compute lambda modulo 65537 from emitted quotient bits.
5. Reject zero residue. Search k=1..65536 for k*lambda congruent to -1 modulo 65537. A scalar limb multiply forms 1+k*lambda.
6. Exactly divide this numerator by 65537 using a 17-bit remainder. Verify zero remainder, no quotient overflow, and `2^1024 < d < lambda`. Exact division establishes `65537*d = 1+k*lambda`.
7. Assemble only successful public n, then scrub before releasing the result.

The implementation is variable-time and does not claim physical side-channel resistance.

## Reproducible validation

`reference/pair_vectors.py` uses independent Python integers, `math.lcm`, and modular inverse. Its eight fixtures cover three full RSA prime pairs, genuinely small d, exponent incompatibility, and parity/separation/range rejection. The low-d fixture deliberately need not be prime: this unit checks pair arithmetic after caller-side primality. The testbench compares both private lambda and d in monitored RAM before scrub, compares public n/status, verifies every RAM read against accepted writes, checks all 512 words were overwritten with zero, and checks the actual RAM output latch and multiplier/scalar registers after cleanup. It also stalls results, changes accepted inputs, resets twelve busy phases, and resets a held result.

```powershell
& 'Key Generation/scripts/simulate_pair_check.ps1' -BuildDirectory '<absolute scratch directory>' -Corpus '<absolute expected_keys.json>'
& 'Key Generation/scripts/fit_pair_check.ps1' -BuildDirectory '<absolute fit scratch directory>'
```

`-Backend generic` or `-Backend altera` selects one simulation; the default runs both. Actual Altera simulation compiles installed `220model.v` and `altera_mf.v`, without substituting generic models. `test_pair_verilator.sh ABSOLUTE_BUILD_DIRECTORY ABSOLUTE_CORPUS_JSON` is the faster generic runner under WSL/Linux. Source is Verilog-2001; only tests use SystemVerilog. The fitter smoke test uses virtual pins and is not a board image or I/O signoff.

Initial Quartus 26.1 synthesis for A5ED013BB32AE4SCS estimates 5,339 ALMs and 2,639 registers, with one M20K and two DSP summary units. Final route/timing and completed functional regression evidence are recorded separately; synthesis alone is not a passing integration gate.

The optimized generic regression passes all eight independent n/lambda/d fixtures, repeated jobs, stable result stalls, full-RAM/output-latch cleanup and twelve busy reset phases. Successful pair latencies are 2,692,927 / 2,721,097 / 2,699,119 cycles; the genuine low-d case takes 1,908,612 cycles. Evidence: AI/tmp/keygen-pair-limb-final/result.log. Actual Altera regression and routed timing remain separate gates.

The strengthened cleanup suite also passes (AI/tmp/keygen-pair-limb-scrub/result.log), checking every private scalar/control field in addition to RAM, its output latch, and multiplier registers. No pair RTL changed between these two successful runs.
