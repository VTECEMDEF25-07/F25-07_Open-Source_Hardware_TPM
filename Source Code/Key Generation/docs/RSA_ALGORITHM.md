<!--
Filename: RSA_ALGORITHM.md
Authors: Aaron Grossman; Project contributors; see Git history.
Date: 2026-11-08
General Description: Preserves the exact RSA procedure and private implementation contracts.
AI Disclosure: Codex assisted with consolidation; see docs/AI_DISCLOSURE.md in the keygen source folder.
-->

# RSA-2048 generation procedure, RSA-2048-v1-trial251

This is the executable algorithm contract for the dedicated controller. The Python oracle is test infrastructure, not synthesizable HDL or a production random generator. The controller consumes accepted 32-bit words in this order and must produce identical keys when only handshake timing differs. References to `reference/` and simulation commands below refer to `Testing/Simulation/Key Generation/` in the repository.

## Selected profile

RSA modulus length is 2048, prime length 1024, mathematical exponent 65537. The method is FIPS 186-5 A.1.3 with A.1.1 constraints and B.3.1 Miller–Rabin. Use five accepted witnesses per surviving candidate, following Table B.1's 1024-bit prime / 2^-112 generation-error profile. Do not interpret this generation profile as a universal error bound for adversarial composites. No optional mod-8 restriction, forced high bits or Lucas test is selected. An exact composite prefilter tries every odd prime from 3 through 251, in ascending order, after exponent compatibility and before drawing witnesses. A divisor proves compositeness without a probabilistic test; it counts as one primality rejection. Altering filters changes stream consumption and requires a procedure version change and regenerated replay expectations.

All draws are 1024 bits: exactly 32 accepted input words. The first word is most significant; bytes within each word are big-endian. Rejecting a draw consumes all its words. Candidates and witnesses share one isolated operation stream. Pauses do not consume words. A fresh operation restarts only when its external context manager establishes the requested context.

## Candidate search and exact counter rules

Let `L = ceil(sqrt(2) * 2^1023)`, evaluated exactly as `isqrt(2^2047) + 1`; no floating-point constant is allowed. Candidate upper bound is `2^1024 - 1`. For p initialize failed-candidate count to zero, with limit 10,240; for q initialize its separate count to zero, with limit 20,480.

1. Draw 32 words. If the value is even, add one; this is equivalent to setting only bit zero. Do not force either high bit. Each odd value has two equally likely preimages under a uniform input stream.
2. If the odd value is below L, draw again. This rejection does not increment the failed-candidate count.
3. For q only, if `abs(p-q) <= 2^924`, draw again without incrementing that count.
4. If `gcd(candidate-1,65537) != 1`, skip witnesses and proceed to the failure-count step.
5. Otherwise trial-divide by all odd primes 3 through 251. A zero remainder proceeds directly to the failure-count step without consuming witnesses. If every remainder is nonzero, perform the five-round primality procedure below. On probable-prime acceptance retain the candidate and move to q search, or complete the pair.
6. Only exponent incompatibility or a composite outcome increments the failed-candidate count. Increment first; if the result reaches the phase limit, fail the operation and invalidate both primes. Otherwise draw a completely new candidate. Do not walk candidates by adding two.

These correspond to A.1.3 steps 4.2–4.7 and 5.2–5.8. Unlimited repeated range/separation/witness rejections are not bounded by these standard counters; source availability watchdogs belong to the external interface contract and must not silently turn these draws into counter increments.

## Primality procedure

For odd candidate w, factor `w-1 = 2^a * m`, with m odd. For each of five rounds:

1. Draw a 1024-bit witness b; reject and redraw unless `2 <= b <= w-2`. A rejected witness does not advance the round or the candidate-failure count. Do not reduce modulo w to construct a witness.
2. Compute `z = b^m mod w`. Values 1 and w-1 pass this round.
3. Otherwise square z modulo w, at most a-1 times. Reaching w-1 passes the round. Reaching 1 first, or exhausting the squarings without w-1, declares the candidate composite immediately.
4. Accept probable prime only after all five rounds pass. Composite detection stops witness consumption immediately.

## Pair validation and result

Compute `n=p*q`, `lambda=lcm(p-1,q-1)`, and canonical `d=65537^-1 mod lambda`. Check exactly 2048 modulus bits, `2^1024 < d < lambda`, and `65537*d mod lambda = 1`. If d is too small, discard **both** primes and start p search again using the continuing operation stream. The two prime-search counters restart for that new pair. Other arithmetic inconsistencies are internal faults, not successful keys.

The reference returns n/e/p/q/d for test checking. This does not require exporting d from the hardware protected interface: hardware must calculate/check it internally and preserve p/q through ownership handoff. The reference does not implement secret-memory scrubbing; Python integers are test-only. RTL cleanup and result-ownership verification require their own tests.

## Predictable test stream and frozen corpus

`reference/seeds.json` fixes twenty explicit 32-byte seeds before optimization. They are integers 1 through 20 encoded in 32 big-endian bytes. For each seed, counter starts at zero. Each block is:

```text
SHA256(ASCII("KEYGEN-TEST-v1") || 0x00 || seed[32] || counter[8, big-endian])
```

Read each digest left to right as eight big-endian 32-bit words; increment the 64-bit counter once per digest, never once per stalled cycle. Counter wrap is a source failure. This custom test provider is **not an approved DRBG**, even though SHA-256 is used. Production source assurance is an external requirement. Seeds and any exported keys are public test material.

## Independent checking and regression

`keygen_reference.py` is the procedure oracle and records rejection/acceptance events. `key_checker.py` does not import the procedure: it checks integer widths, squared lower bounds, pair/product relationships, canonical d, primality with 64 fresh uniformly sampled witnesses per prime, and RSA round trips including messages divisible by a prime. The checker's witnesses use the host cryptographic random source and are separate from generation. This is strong probable-prime checking, not a primality proof or certification.

```powershell
python -m unittest discover -s 'Testing/Simulation/Key Generation/reference' -v
python 'Testing/Simulation/Key Generation/reference/keygen_reference.py' --seed 1
```

The tests generate a real RSA-2048 pair and independently check it, replay the same stream, test byte order, reject illegal words, exercise exact p/q retry limits, range/separation/witness rejection, composites, and mutate every key component. The low-d branch is exceptionally rare: its unit test injects that arithmetic outcome with mocks, then proves both prime searches restart. The production reference has no test-only reduced counter/prime-width/primality option.

## Standards references

The retained procedure mapping is FIPS 186-5 A.1.3/A.1.1, B.3.1 and Table B.1. Primary sources: [FIPS 186-5](https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.186-5.pdf), [NIST publication page](https://csrc.nist.gov/pubs/fips/186-5/final), and [potential updates](https://csrc.nist.gov/files/pubs/fips/186-5/final/docs/fips186-5-potential-updates.xlsx). The October 13 standards audit is historical, not a fresh audit of later NIST updates; see Git history before changing the procedure or standard revision. An algorithm mapping and test results do not establish production DRBG quality, TPM compliance or FIPS validation.

## Implementation reference

`rtl/rsa_rtl/keygen_rsa_controller.v` issues held descriptors to `keygen_rsa_engine.v`; `keygen_rsa_services.v` implements candidate/witness/pair services and borrows the arithmetic memory port only while arithmetic is idle. Result reads require both command owners to be idle. This implementation has no CPU/MMIO/ROM allocation. Arithmetic and pair operations are variable-time; no physical side-channel resistance is claimed.

## Private memory layout

All addresses below identify 32-bit words. Integers use little-endian limbs.

| Start | Length | Contents |
|---:|---:|---|
| 0 | 32 | Current candidate W |
| 32 | 32 | W minus one |
| 64 | 32 | Odd part of W minus one |
| 96 | 32 | Witness |
| 128 | 32 | Modular exponentiation result |
| 160 | 32 | Retained p |
| 192 | 32 | Retained q |
| 224 | 64 | Validated n |
| 288 | 32 | Constant one |
| 320 | 32 | Constant two |
| 352 | 32 | Temporary square result |
| 512 | bounded by arithmetic command | Montgomery workspace |

The accelerator owns all 4096 words. It clears the full allocation, its operand
caches and its synchronous RAM output before declaring reset cleanup complete.
Private operands are not exported through the keygen interface.
The area-optimized pair checker has an additional 512-word private RAM, also
scrubbed with its read latch. Total private arithmetic storage is therefore
18 KiB (16 KiB shared scratch plus 2 KiB pair scratch). This small memory increase replaces thousands of registers
and wide arithmetic paths; it does not remove any key-pair validation.

## Service descriptors

The engine serializes a command and its held response. Commands 0x30–0x34 use
the services below; other commands go to the arithmetic block. Services borrow
the accelerator's private memory port while arithmetic is idle. Result reads
are possible only with neither command owner active.

| Opcode | Arguments | Behavior |
|---|---|---|
| 30 | destination, 32, force-odd, 0 | Draw exactly 32 MSW-first words; reverse limb order; optionally set only bit zero. |
| 31 | 0, 32, 64, q-mode | Apply range, optional p/q separation, exponent compatibility and trial-prime checks; prepare W−1 and its odd part. |
| 32 | 96, 0, 0, 0 | Accept witness only in [2,W−2]. |
| 33 | first-check, 0, 0, 0 | Check the exponentiation/square result and bound the remaining squarings. |
| 34 | 0, 0, 0, 0 | Validate the p/q pair, compute and check d, clear d, then retain n. |

Malformed descriptors return an error before memory mutation. Service status
0x10 is context-specific (redraw, square again or restart pair); controllers
interpret it only in the phase that requested it. See source for the complete
status mapping. Unexpected responses become arithmetic errors.

The dedicated controller counts only candidate failures specified by the
algorithm. It permits 10,240 failures for p and 20,480 for q. Accepted DRAW
commands may wait indefinitely for external data. Internal command admission
and non-DRAW execution have a 50-million-cycle watchdog; expiry reports code 7.
Outer cleanup runs before terminal failure becomes visible to the caller.


### Pair-check implementation

`keygen_pair_check` captures two already-tested 1024-bit prime candidates on `start_valid_i && start_ready_o`, validates their RSA relationships, and holds a public 2048-bit modulus/status until accepted. Primality remains the caller's responsibility. Ports are unchanged by the RAM-based implementation.

#### Pair status and cleanup

Only status 0 exposes n. Other statuses are 1 for invalid bounds/parity/separation or exponent incompatibility, 2 for a canonical private exponent that is too small, and 3 for arithmetic inconsistency. Status 2 requires restarting both prime searches. There is no private-exponent output. The caller retains and ultimately scrubs its own p/q copies.

Reset immediately invalidates outputs and clears captured-input/public-output staging and scalar registers. It then sweeps all 512 private RAM words and performs a separate read of the last zeroed word to clear the RAM output latch. Ready returns after 514 rising edges. Success and failure use the same sweep before result-valid; only a successful public modulus remains in staging. The multiplier's actual pipeline reset is held throughout cleanup. RAM contents are never asynchronously reset.

#### Pair memory layout

The pair service uses one 512x32 RAM (2 KiB; one M20K) and the shared generic/Altera wrapper contract, plus a 32x32 multiplier. This explicitly increases the accelerator's private RAM allocation from 16 KiB to **18 KiB**, using nine M20Ks total for math and pair scratch out of the board's 358. Public transport storage is a separate allocation. The extra 2 KiB replaces thousands of private register bits and parallel wide arithmetic units.

| Word addresses | Contents |
| --- | --- |
| 0–31, 32–63 | Captured p, q |
| 64–95, 96–127 | Binary GCD working operands |
| 128–191 | Public product n |
| 192–255 | First phi, then lambda |
| 256–319 | Restoring-division remainder |
| 320–384 | Numerator, then canonical d with an overflow word |
| 385–511 | Reserved; still scrubbed |

Inputs are captured atomically in the 2048-bit staging register before serial RAM writes, so callers may change p/q immediately after the handshake. Staging is then cleared and reused for final n. The internal limb ALU reads private RAM synchronously and performs compare, subtraction and shifts over 32-bit words. There is no CPU control/read interface in this implementation.

#### Pair arithmetic sequence

1. Require odd p/q at least `ceil(sqrt(2)*2^1023)` and absolute separation strictly greater than `2^924`.
2. Form n and phi=(p-1)*(q-1) with schoolbook limb multiplication. Verify exactly 2048 modulus bits.
3. Find gcd(p-1,q-1) with binary GCD and restore common powers of two. All shifts and subtractions use the shared 32-bit ALU.
4. Restore-divide phi by the GCD over 2048 quotient bits, check zero remainder/nonzero lambda, and compute lambda modulo 65537 from emitted quotient bits.
5. Reject zero residue. Search k=1..65536 for k*lambda congruent to -1 modulo 65537. A scalar limb multiply forms 1+k*lambda.
6. Exactly divide this numerator by 65537 using a 17-bit remainder. Verify zero remainder, no quotient overflow, and `2^1024 < d < lambda`. Exact division establishes `65537*d = 1+k*lambda`.
7. Assemble only successful public n, then scrub before releasing the result.

The implementation is variable-time and does not claim physical side-channel resistance.


### Implementation checks

The pair oracle independently computes n, lambda and d with Python integer arithmetic. Its eight fixtures include valid pairs, a small-d outcome, exponent incompatibility and range/parity/separation failures. Tests inspect private arithmetic before scrub, verify all 512 zero writes and RAM output-latch cleanup, check multiplier/scalar state, stall results, change captured inputs, reset twelve busy phases and reset a held result. Primality remains the caller's responsibility; an intentionally nonprime low-d fixture isolates pair arithmetic.

The controller regression checks descriptor arguments, exact candidate retry limits, witness rejection without round consumption, low-d restart of both primes, held command/response behavior, source/arithmetic faults, reset and real watchdog boundaries. The service regression checks filtering, draw order, malformed descriptors, witness/square/separation boundaries and final-word failure. Full-core tests compare all 129 output words, source consumption, ownership and cleanup against the independent corpus. These are complementary scopes; no single unit regression establishes full TPM or physical acceptance.

See [simulation commands](../../../Testing/Simulation/Key%20Generation/README.md), [math commands and memory contract](../Math/README.md), and [multiplier/RAM contracts](../IP/README.md) for deeper implementation details.
