# Protected RSA2048 validation

Full-width functional validation passes. **Enabled hardware qualification is
blocked:** the DE25-device harness synthesis estimates 59,220/46,800 ALMs (127%);
fit did not finish within 1,800 seconds, so no fitted timing result is available.
This is an internal RTL review candidate, not a board-ready image.

[Frozen source, fixture and transcript evidence](evidence/rsa_protected_consumer_20261118.json)
audits 119 unique inputs against the candidate. Manifest SHA256:
`b530dc9faf68f3227f93d3ea6c96ebd1ecbd7ec00f10587cfc3b42ab3fa254e6`.

## Reproduce

From the repository root, prepare the public, independently checked fixtures:

```
python "Testing/Simulation/Asymmetric Module/run_rsa_adapter.py" prepare
```

Run Generic cases with local Verilator in WSL (`python3` and `g++` installed):

```
wsl.exe --exec python3 "Testing/Simulation/Asymmetric Module/run_rsa_fast.py" boundary
wsl.exe --exec python3 "Testing/Simulation/Asymmetric Module/run_rsa_fast.py" errors
wsl.exe --exec python3 "Testing/Simulation/Asymmetric Module/run_rsa_fast.py" reset
wsl.exe --exec python3 "Testing/Simulation/Asymmetric Module/run_rsa_fast.py" adapter
wsl.exe --exec python3 "Testing/Simulation/Asymmetric Module/run_rsa_fast.py" generated
wsl.exe --exec python3 "Testing/Simulation/Asymmetric Module/run_protected_d.py"
wsl.exe --exec python3 "Testing/Simulation/Asymmetric Module/run_rsa_retry.py"
```

Native Questa is shared: obtain its window before running sequentially:

```
python "Testing/Simulation/Asymmetric Module/run_rsa_vendor.py" compile
python "Testing/Simulation/Asymmetric Module/run_rsa_vendor.py" boundary
python "Testing/Simulation/Asymmetric Module/run_rsa_vendor.py" protected-d
python "Testing/Simulation/Asymmetric Module/run_rsa_vendor.py" adapter
python "Testing/Simulation/Execution Engine/run_keygen_lifecycle.py" regression --label rsa-final-regression
```

The vendor runner compiles RTL separately as Verilog-2001 and uses unchanged
Intel/Altera `220model.v` and `altera_mf.v`. It refuses an existing native simulator.
Every timed-out runner terminates only its own launched process tree.
The full native adapter run took 28 minutes on the validation host. Obtain the
license window first; do not overlap it with another task's native simulation.

The final dependency campaign additionally reruns `run_keygen_lifecycle.py`
`compile`, then `boundary`, `real` and `health` for each backend 0/1, all with
`--label rsa-final-lifecycle`. The existing `test_pair_verilator.sh` supplies
the default pair-check regression and its independent 8-vector corpus.

Enabled synthesis and virtual-pin fit use short dedicated class AI/tmp paths
`rsac1` and `rsaa1`, avoiding Quartus Standard's generated-database MAX_PATH
limitation. Source files stay in the isolated checkout. These are test harnesses,
not board images, and retain one full keygen engine, one protected slot, AES256
packet/controller and the full RSA2048 consumer with a separate checked-math
derivation instance.

```
python "Testing/Simulation/Asymmetric Module/synthesize_rsa_slot.py"
python "Testing/Simulation/Asymmetric Module/synthesize_rsa_slot.py" --family agilex --fit
```

## Independent oracle and limits

`expected_keys.json` supplies public reproducible p/q candidates. The independent
key checker validates the key, and Python `pow` checks exact public/private
representatives separately. The private exponent oracle is independently
recomputed using `pow(e,-1,lcm(p-1,q-1))`. No test relies solely on a DUT round
trip. Known d exists only in test fixtures, never synthesized adapter logic.

Adapter-only cases use an explicitly labeled fixture slot model. The separate
`tb_rsa_generated` uses real full-width keygen through the actual engine and RNG
word-service lifecycle: 384 candidate/witness words, 129 n/e/p/q result words,
independent public/private results, preserved committed slot, destroy/overwrite
attempts while reserved, held terminal status, explicit release/full 129-word
clear and generated AES256 reuse. AES/RSA type rejections and simultaneous
acquisition exercise the engine arbiter. There is no preloaded slot, reduced
width, primality bypass or host key endpoint in that acceptance path.

These known-candidate draws are directed correctness, not fresh random prime
search performance or physical entropy qualification. Internal allow/deny and
fault injection are test fixtures, not real authorization or security proof.
The arithmetic core remains provisional and lacks a full side-channel defense.

## Final functional results

| Check | Backend | Explicit result |
| --- | --- | --- |
| Exact independent public/private RSA2048 adapter results; backpressure, held terminal, operand/key/core clearing | Generic and genuine Altera | 2 operations each; 36,300,508 cycles each |
| Real generate → protected slot → public/private consume → slot preservation → release/full clear → reuse, including AES/RSA arbitration and reserved destroy/overwrite attempts | Generic | 129 exact key words; 384 public source words; 2 operations; 172,535,525 cycles |
| Invalid/empty/wrong-type/wrong-size slot, denial, invalid operation, malformed/too-large representative, invalid modulus/exponent, input/derivation/compute timeout | Generic and genuine Altera | 15 checks each; 78,185 cycles each |
| Injected arithmetic error, mismatched n versus factors, invalid private factors, zero ID, terminal expiry and retry | Generic | 5 checks; 19,506,513 cycles |
| Reset during key load, representative input, derivation, compute, output and held status; erasure and no stale completion | Generic | 6 phases; 38,995,656 cycles |
| Exact canonical d/n, protected-d backpressure, reset during handoff/read and complete scratch/output-latch clearing | Generic and genuine Altera | 4 checks each; 10,772,489 cycles each |
| Successful exact private operation after failed derivation, without system reset; erasure, lease release, no double completion | Generic | 64 exact result words; 19,497,610 cycles |
| Default keygen pair-check behavior with handoff disabled | Generic | 8 vectors, canonical d, stalls/cleanup, 12 busy reset phases and held-result reset |
| Slot lifecycle/reservations; real RNG/SHA composition; real health failures/recovery | Generic and genuine Altera | 25 slot scenarios each; exact real-source case each; 5 health cases each |
| Combined GetRandom/Hash/PCR/AES/keygen and legacy packets after RSA integration/rebase | Native Questa | 17 command variants; 240 legacy entries, 0 errors |

RSA remains fixed at 2048 bits throughout acceptance. Neither the generated-slot
test nor the vendor consumer test replaces production arithmetic with a fixture
d. Adapter-only slot fixtures are labeled separately. Full numerical
generation-to-RSA-consumer acceptance with Altera models was not rerun; the full
generated path is Generic, while actual-model adapter/private derivation and
common lifecycle/real-source/health paths are covered.

## Synthesis, fit and material limits

* **Cyclone V/Altera enabled harness:** Quartus 24.1 Standard synthesis passes;
 84,430 registers, 164,864 block-memory bits, 9 DSP blocks. This is synthesis,
 not a Cyclone V fit/timing result. All source bytes are audited before/after.
* **Agilex 5 DE25 device A5ED013BB32AE4SCS:** Quartus 26.1 Pro synthesis completes;
 estimated 59,220/46,800 ALMs (127%), 85,089 logic registers and 6 estimated DSP
 blocks after merging. The virtual-pin harness targets a 20 ns consumer clock
 and takes random input externally; it is not the full TPM/entropy board image.
* **Fit qualification fails to complete:** the exact enabled fit reaches its
 1,800-second deadline (1,800.696 seconds including shutdown). No fitted timing
 result exists. Area repair and actual enabled-image fit/timing remain open;
 no width reduction, timing waiver or clock reduction was used to claim PASS.
 The separate checked-math instance and wide operand/core copies have an area
 cost. Device reset-release/physical integration is outside this harness.

The initial Standard synthesis attempt hit a generated-database MAX_PATH error;
the final short-directory rerun passes. Earlier pre-fix numerical runs and the
superseded fit attempt are development artifacts, not final acceptance evidence.
The manifest retains the final failed fit alongside passing functional results.

No hardware was programmed. Default-image timing, earlier physical tests and
entropy validation do not qualify this enabled composition. Real
objects/handles/Names, sessions/auth, wrapping/loading, hierarchy/primary seeds,
persistence, padding and TPM RSA command semantics remain Phase Three. No
RSA_Encrypt/Decrypt/Sign/VerifySignature command is added.
