# Protected keygen integration validation

Base: `develop` at `267a75cc2d3d1c2d11623a4e096f5145de46cd67`.
The implementation contract and Phase Three handoff are in
[KEYGEN_LIFECYCLE.md](../../../Source%20Code/Execution%20Engine/KEYGEN_LIFECYCLE.md).

## Reproduce

Run from the repository root on the native Windows toolchain. Use one native
simulator at a time so another task can coordinate the shared license.

```powershell
$runner = 'Testing/Simulation/Execution Engine/run_keygen_lifecycle.py'
python $runner compile --label review
foreach ($backend in 0, 1) {
    python $runner boundary --backend $backend --label review
    python $runner real --backend $backend --label review
    python $runner health --backend $backend --label review
}
python $runner rsa --label review
python $runner engine --label review
python $runner host --label review
python $runner resources --family 'Agilex 5' --label review
python $runner resources --family 'Cyclone V' --label review
python $runner regression --label review
```

The runner accepts `--questa-bin` and `--altera-models` overrides. Default tools
are Questa Intel Starter FPGA Edition 2024.3 and the genuine installed Quartus
24.1 simulation models; vendor models are compiled unchanged. RTL is compiled
as Verilog-2001; only benches use SystemVerilog. No hardware is accessed.

Each invocation records exact source/model/fixture SHA256 values, command line,
wall deadline, elapsed time, exit code, explicit pass markers and transcript
SHA256 in `build/review/`. It rejects changed inputs without recompilation,
missing fixtures, simulator errors, missing pass markers and exceeded deadlines.
Native process trees are terminated on timeout so a failed run cannot strand
the shared license. RSA uses the existing project harness's 7200-second native
simulation bound; other cases use 180 seconds and the combined regression 600.
These wall limits are not FPGA latency measurements.

## Coverage

| Test | What it checks |
|---|---|
| `boundary`, Generic and Altera | 25 scenarios each: exact AES128/256 words, type/size/validity, captured ID/profile, denial/invalid and busy admission, source/result/ownership/terminal stalls, faults through the publication edge, source and lifecycle watchdogs, reset in eight phases, full 129-word sweep, held completion and live-slot lifetime, and release/readiness. |
| `rsa`, Generic | Complete dedicated RSA2048 generation through the block/word service into the 129-word slot, exact n/e/p/q ordering and flags, independent numerical values, result backpressure and delayed ownership/terminal, private publication, release and full scrub. |
| `real`, both backends | Actual entropy collection/health, Hash_DRBG, shared SHA, word service, AES256 and protected slot. Python independently computes Hash_df and the first Hashgen output from the public collected seed fixture. |
| `health`, both backends | Real RCT detection during staging, ownership and terminal cleanup; a failing raw sample exactly on the publication edge; shared reset, reseeding and successful AES128 recovery. |
| `engine` | Actual engine-owned wiring; GetRandom waits beyond its normal collection bound while keygen reserves the source, then obtains a different whole block. Healthy AES128-to-AES256 slot reuse without reset consumes the third block, never earlier residuals; a withdrawn busy request queues no work. Fault after the eligibility edge does not rewrite committed host data or a valid slot. |
| `resources`, both device families | Existing independent Generic/Altera multiplier and RAM scoreboards, randomized enable stalls, collisions, reset persistence and explicit clearing, using real vendor models. |
| `regression` | Existing Hash, PCR Read/capability/Extend policies, mixed real RNG/shared-SHA GetRandom, real RCT/APT and recovery, optional AES packet route, disabled gates, legacy240-entry SPI command suite, and the new internal engine reservation case. |

RSA input is the existing public known-candidate fixture: p and q, each followed
by five witness draws,384 source words. An independent checker validates the
fixture's primality, n=p*q, canonical d, exponent constraints and RSA round trips;
the 129 expected result words are derived independently from that key. This is
directed numerical correctness, **not random prime-search performance**. There
is no deterministic provider or fallback in production RTL.

Generic RSA passed with 384 source words,129 result words and 136,236,052 cycles
in the complete test window. Each `real` case passed one complete AES256 job;
each `health` case passed five fault/recovery scenarios. Each device-family
resource scoreboard checked 2637 products, 2750 reads, 596 collisions and 1300
stalls. The combined command regression passed 16 variants, including 240 legacy
SPI entries with zero errors.

Final result counts, pass markers and hashes are recorded in
`evidence/keygen_lifecycle_20261118.json`. Full RSA numerical integration is
covered on Generic. Altera coverage includes the common lifecycle/real-source
cases, real resource-model scoreboards and enabled-worker synthesis; a full
numerical RSA run with Altera models remains a coverage limit. The current
source contract has one dedicated controller; a historical softcore is not
introduced or claimed here.

## Board and security limits

Both default board projects are compiled/fitted with keygen, GetRandom, Extend
and optional AES feature gates disabled. The enabled internal worker is also
synthesized separately on Cyclone V/Altera resources; that is not a combined
enabled-image fit or a timing acceptance result. The slot is register-backed.
Detailed area, all-corner timing minima, reports and input/transcript hashes are
in the evidence record. A successful Quartus process exit is not timing closure.

DE1 retains negative setup slack. Default-profile DE25 timing does not establish
enabled-keygen timing, high-speed physical SPI acceptance, or entropy quality.
Quartus's retained timestamp-based out-of-date warnings are accompanied by
before/after SHA256 audits of all recorded input bytes; no changed RTL input
bytes are silently accepted as matching evidence.

No new FPGA image was programmed or physically assessed. Prior 318/0 hardware
results and earlier entropy data do not qualify this source/image. Physical
entropy qualification must use the exact final FPGA image and source profile.
The live DRBG retains private V/C/counter state across reservations and follows
its existing reseed interval; no fresh-seed-per-key or SP800-90B entropy-credit
claim is added. Side-channel resistance and complete TPM object security are
not established by these simulations. Authorization remains a labeled internal
fixture; real objects, authorization, handles/Names, seeds, protected parents,
wrapping/loading and persistence belong to Phase Three.
