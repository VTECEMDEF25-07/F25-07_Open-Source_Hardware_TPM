# Protected generated-key AES consumption

Stacked dependency: PR57, `2f4e29a1a058fd7c30f715701f82ac7cb75b8015`.
Implementation/campaign head: `848954c60ed106547ad12518854697cfb1eed853`.
Target the dependency branch while PR57 is unmerged; eventual target is
`develop`. After dependency merge/rebase, rerun the relevant regressions before
final composed review readiness. No merge or hardware access is authorized here.

## Reproduce

From the repository root, Windows Python with `cryptography`, native Questa
Intel Starter FPGA Edition and Quartus24.1 installed:

```powershell
python 'Testing/Simulation/Execution Engine/run_aes_slot_regressions.py' --label aes-slot-review
python 'Testing/Simulation/Execution Engine/synthesize_aes_slot.py'
```

One native simulator at a time. The campaign records exact Git HEAD, all
RTL/test bytes before and after, deadlines, process status, explicit pass/count
markers and transcript SHA256. Child records include genuine Altera model
hashes, independent AES/OpenSSL, Hash_DRBG and full RSA fixture checks. Output
is under `build/aes-slot-review*` and `build/aes-slot-enabled-synthesis`.
`--without-rsa` runs the fast campaign; `--rsa-only` requires the prior compiled
inputs in the same label directory. Full RSA has a7200-second native deadline;
this is an engineering wall bound, not random prime-search performance.

## Changed behavior and coverage

* AES256: actual engine-owned generation → protected slot → exact type/size
  reservation → private key assembly → existing EncryptDecrypt2 packet decoder
  and AES-CFB worker → coherent response → owned-span sweep → relinquish.
  Independent encryption/decryption at lengths0,1,16,17,40,64,1024, exact returned
  IV (partial final feedback zero-padded), empty/denied/unknown/wrong-type and
  wrong-size slots, malformed auth/tag/size/mode/IV/decrypt, source/key/result
  stalls, held terminal, reserved overwrite/destruction attempts, RAM read/write
  errors, guard preservation, next submission during scrub, reset during partial
  key assembly/compute/output/terminal, injected late done, full destroy/reuse.
  **45 counted scenarios,23 AES launches,61,463 cycles.** The wrong-size/RSA-type
  packet error injections are labeled test faults; actual RSA generation and
  type rejection are also covered in the full shared-slot regression.
* AES128: private decoded-job path only; actual AES128 generation/reservation,
  exact key assembly, independent encrypt/decrypt and returned IV for0/1/16/40
  bytes, disjoint output guards,96 patterned RAM request stalls, key-copy erasure
  and full slot destruction. **8 cases,114 reads,114 writes,5,757 cycles.** The
  private decoded caller owns and clears its two buffer spans before relinquish.
  No AES128 packet form or host profile change is introduced.
* SPI: actual TPM_TOP/CRB/FIFO route consumes a real generated AES256 slot using
  a public simulation source fixture. Five commands cover encrypt/decrypt,
  unknown fixture handle, denied use and malformed existing auth. There are
  **zero external key-fixture requests**; response-copy completion triggers
  the40-byte scratch sweep while the committed key remains available.
* Shared slot: both Generic and genuine Altera models retain25 keygen lifecycle
  scenarios and add held acquisition, early relinquish rejection, exact metadata
  checks, wrong type/count/fixture denial, occupied-slot generation denial,
  destroy rejection and relinquish without destruction. Empty/same-edge destroy
  acquisition and reset of an unconsumed acquisition reply are checked. Actual
  RNG/SHA composition and5 real health/recovery scenarios run per backend.
* All17 combined command variants pass, including Hash, PCR Read/capability,
  Extend policy configurations, mixed real RNG/shared SHA, RCT/APT/recovery,
  both explicit known-key and generated-slot AES, engine reservation and the
  original240-entry SPI suite with zero errors. Six symmetric buffer capacities
  (1,17,31,1024,2049,4096) pass1,574 independent CFB vectors /1,717 total cases,
  including default session-path compatibility and RAM failures/guards.
* Full Generic RSA2048 generation matches all129 n/e/p/q words against the
  independent Python fixture:384 source words,136,236,096 cycles. The actual
  RSA slot rejects an AES acquisition, denies fixture/wrong-size requests,
  holds acquisition under backpressure and attempted destruction, preserves
  data through relinquish, then clears all129 words before reuse. This is
  directed numerical correctness, not prime-search performance or entropy.

All16 native campaign groups pass. The committed
[evidence manifest](evidence/aes_slot_consumer_20261118.json) records the exact
head, source/fixture/model/transcript SHA256, counts and deadlines. Manifest
SHA256: `02002fa008c332cdd23caff54fe8c1120f4fa5af0832e0e7a7ff2ce25cd1b171`.
Full transcripts remain in the indicated local build directories. No pass is
inferred from simulator exit alone.

The known handle, allow bit and deterministic source are public test fixtures,
not real TPM objects, production authorization or a physical entropy source.
There is no key in command/response scratch, debug register or private host read.
KDFa/session algorithms are unchanged. A compile-time primitive-only session
gate avoids elaborating the unused KDF datapath in the packet worker; the
general symmetric wrapper retains its enabled session default.

## Synthesis and limits

Enabled composition analysis/synthesis passes on Cyclone V with Altera resources:
protected AES128/AES256/RSA2048 generation, reservation, AES256 packet/controller,
34,371 registers,148,480 block-memory bits and6 DSP blocks. This is synthesis
only: no fitter, timing, physical SPI or entropy claim. Its446 unassigned wrapper
I/O pins are analysis inputs, not a board pin plan. The first attempt exhausted
memory elaborating the unused session/KDF path; `initial-oom.log/json` retain that
failure, followed by the successful gated run. No algorithm was replaced.
The successful synthesis ran at `0c1cc3fa4cc3ea1dad2a993830a317e92ff99d6d`;
all recorded synthesis input bytes are identical at campaign head848954c.

Full numerical RSA integration with Altera models, combined enabled DE25 fit and
all-corner timing, coordinated physical acceptance and exact-image entropy
qualification remain separate gates. Existing default DE25 +0.379ns and DE1
−9.644ns results are dependency history, not acceptance for this enabled image.
No physical board was accessed or programmed. Internal allow/known-handle values
do not implement authorization. Real objects, Names, handles, sessions,
wrapping, persistence, hierarchy/primary behavior remain Phase Three. No new
host command or RSA host operation is implemented.
