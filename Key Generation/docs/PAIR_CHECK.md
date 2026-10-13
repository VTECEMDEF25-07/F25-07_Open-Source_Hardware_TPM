# Shared RSA pair arithmetic

`keygen_pair_check` accepts two already-tested prime candidates and checks the RSA pair relationships needed by both controllers. It captures p/q at `start_valid_i && start_ready_o`. It does **not** repeat primality testing; that remains the caller's responsibility.

Read the RTL in this order: port/result qualification, product datapath, state transitions, then `SCRUB`. The testbench first compares Python-generated mathematical fixtures, then interrupts every major arithmetic phase.

## Interface and ownership

Inputs p/q are 1024 bits. The public modulus result is 2048 bits. A single result/status remains stable until `result_valid_o && result_ready_i`. No further request is accepted while busy or holding a result. Reset asynchronously clears working registers and invalidates results; callers must provide the system's synchronized reset release.

| Status | Meaning | Controller response |
| --- | --- | --- |
| 0 | Pair relationships valid | Retain original p/q externally for protected handoff; use returned n. |
| 1 | Bounds/parity/separation or exponent incompatibility | Reject the pair; do not claim success. |
| 2 | Canonical d is too small | Discard both primes and restart the pair search. |
| 3 | Arithmetic consistency fault | Fail the operation and perform subsystem cleanup. |

Only valid status 0 exposes n; n is zero during computation, after reset/acceptance and for failures. There is no d output port. `d_reg` is observed hierarchically by the testbench before scrub, then cleared. The caller's p/q copies remain the caller's cleanup responsibility.

## Datapath and states

- Bounds check requires odd p/q at least `ceil(sqrt(2)*2^1023)` and separation greater than `2^924`.
- Schoolbook multiplication visits 32-by-32 limbs through `keygen_mult32`, accumulating each 64-bit product plus a 32-bit destination word and carry. No 1024-bit multiplier is inferred.
- Compute phi from `n-p-q+1`; binary shift/subtract GCD computes `gcd(p-1,q-1)` and restores shared powers of two one shift per clock.
- A 2048-step restoring divider calculates lambda=phi/gcd and verifies zero remainder. Its emitted quotient bits simultaneously compute lambda modulo 65537.
- A zero residue indicates exponent incompatibility. Otherwise a bounded modular-add search finds k in 1..65536 with `k*lambda = -1 mod65537`. This takes at most 65,536 clocks (about 1.31 ms at a hypothetical 50 MHz; achieved FPGA timing is unverified).
- Seventeen shift/add steps form the 2065-bit numerator `1+k*lambda`. A restoring divide by 65537 yields canonical d with remainder zero. The quotient must fit 2048 bits and satisfy `2^1024 < d < lambda`. Exact division establishes `65537*d = 1+k*lambda` without a redundant wide multiply.
- Scrub clears captured factors, lambda, d, GCD/division operands, carries and counters. Three scrub clocks also drain the multiplier's two registered stages with zero operands before result-valid appears. Only a successful public modulus survives until acceptance.

Wide add/subtract/compare operations remain in this first implementation; place-and-route must establish achievable frequency. This module has not yet been synthesized or fitted. It depends on the resource-wrapper MR (`keygen_mult32`, generic or actual Altera implementation), not an IP Catalog-generated block.

## Validation

`reference/pair_vectors.py` independently uses Python integers, `math.lcm` and modular inverse to generate eight fixtures: three real RSA-2048 prime pairs, a mathematically constructed low-d case, an exponent-incompatible pair, and parity/separation/range rejections. The low-d fixture uses lambda=60*g congruent to -1 modulo 65537, so d=(lambda+1)/65537 is genuinely small; no production state/threshold is weakened. These special arithmetic fixtures need not be prime because primality is explicitly a caller prerequisite.

```powershell
& 'Key Generation/scripts/simulate_pair_check.ps1' -BuildDirectory '<absolute class AI/tmp scratch directory>'
```

When wrappers are in another reviewed worktree, pass `-IpDirectory` pointing to its `Key Generation/IP`. Source compiles in Verilog-2001 mode; only the testbench uses SystemVerilog. The runner compiles and simulates generic and Altera variants separately, using the installed real `220model.v`/`lpm_mult` for Altera, and rejects missing explicit PASS output.

October 13 results: both variants passed all eight fixtures, canonical d comparisons, stable output stalls, private cleanup, reset in twelve busy phases and reset of a held result. Both completed at simulation time 5,205,500 ns. Source and test compilation had zero errors/warnings; simulation reported only the expected `+acc` optimization warning needed for private-register observation. This proves arithmetic simulation behavior, not FPGA fit, timing, whole-key ownership or production physical security.
