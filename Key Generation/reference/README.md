<!--
Filename: README.md
Authors: Project contributors; see Git history.
Date: 2026-10-13
General Description: Documents Public test reference and fixtures.
AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.
-->

# Public test reference and fixtures

Read `../docs/RSA_ALGORITHM.md` first for the procedure and standards mapping. This directory contains Python verification infrastructure; none of it is synthesizable source or production key-generation software.

- `keygen_reference.py`: exact accepted-word procedure, SHA-256 counter test provider and optional event transcript.
- `key_checker.py`: independent mathematical validation and 64 fresh Miller–Rabin witnesses for each factor.
- `seeds.json`: twenty fixed public seeds. Do not substitute faster seeds to satisfy board performance.
- `expected_keys.json`: public test keys and exact accepted-word counts for those seeds. Useful for matching generic/Altera and RTL/soft-core outputs without requiring equal cycle counts.
- `test_reference.py`: branch and full-size regression tests.
- `verify_corpus.py`: reproduce and independently validate all twenty keys.

From repository root, using Python 3.10 or newer and its standard library:

```powershell
python -m unittest discover -s 'Key Generation/reference' -v
python 'Key Generation/reference/keygen_reference.py' --seed 1
python 'Key Generation/reference/verify_corpus.py'
```

The first command must print an explicit unittest `OK`. The last command must print `PASS CORPUS count=20`. An empty successful process is not valid evidence. Unexpected errors raise exceptions and return nonzero. `--output` on the single-seed command optionally saves a JSON test-key/event transcript; it is not required for checking.

These tests establish the software oracle and fixtures. They do not validate FPGA source, resource equivalence, timing, secret clearing, TPM integration or production randomness. The generation profile uses five witnesses; the separate checker uses stronger independent sampling. Neither provides a primality proof.

Validation on October 13, 2026: 13 unit tests passed, including a full-size generation and replay. All twenty `RSA-2048-v1-trial251` corpus keys were generated and passed the independent checker. Seed 1 consumes 54,336 accepted words. Software runtime is not evidence of FPGA performance. The initial no-prefilter exploratory outputs were replaced before committing the versioned corpus.
