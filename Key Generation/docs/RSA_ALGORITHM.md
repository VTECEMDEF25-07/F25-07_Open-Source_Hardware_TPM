<!--
Filename: RSA_ALGORITHM.md
Authors: Project contributors; see Git history.
Date: 2026-10-13
General Description: Documents RSA-2048 generation procedure, RSA-2048-v1-trial251.
AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.
-->

# RSA-2048 generation procedure, RSA-2048-v1-trial251

This is the executable algorithm contract for the dedicated controller. The Python oracle is test infrastructure, not synthesizable HDL or a production random generator. The controller consumes accepted 32-bit words in this order and must produce identical keys when only handshake timing differs.

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
python -m unittest discover -s 'Key Generation/reference' -v
python 'Key Generation/reference/keygen_reference.py' --seed 1
```

The tests generate a real RSA-2048 pair and independently check it, replay the same stream, test byte order, reject illegal words, exercise exact p/q retry limits, range/separation/witness rejection, composites, and mutate every key component. The low-d branch is exceptionally rare: its unit test injects that arithmetic outcome with mocks, then proves both prime searches restart. The production reference has no test-only reduced counter/prime-width/primality option.

## Standards audit, October 13, 2026

Primary sources: [FIPS 186-5 publication](https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.186-5.pdf), [NIST publication status](https://csrc.nist.gov/pubs/fips/186-5/final), [potential-updates spreadsheet](https://csrc.nist.gov/files/pubs/fips/186-5/final/docs/fips186-5-potential-updates.xlsx).

The spreadsheet was downloaded and all four populated issue rows inspected. Its SHA-256 is `306e356009813225152609c6b1361202268f2df834f7f2ec55a8898eb1ddd679`. Two rows address deterministic ECDSA octet lengths in A.3.3. Two address B.10 provable-prime references and missing square-root notation. None alters the selected A.1.3/B.3.1/Table B.1 procedure. NIST labels these potential corrections rather than official changes; the B.10 table-reference wording is internally inconsistent but is outside this selected method. Re-audit when changing the procedure or standard revision.

This establishes an algorithm mapping and executable test evidence. It does not establish production DRBG quality, TPM command compliance, FPGA timing, or FIPS validation.
