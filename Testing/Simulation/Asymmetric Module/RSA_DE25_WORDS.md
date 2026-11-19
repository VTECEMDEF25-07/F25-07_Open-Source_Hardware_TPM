# RSA2048 area on the DE25

The protected consumer uses the keygen Generic/Altera RAM and multiplier
wrappers. Its five arithmetic banks hold the modulus, representative, private
or public exponent, accumulator and scratch. A sixth stores the result through
scrubbing and backpressure. The Altera RAM summary identifies each of these
64-word, 32-bit memories as an M20K instance. The DSP handles unsigned 32-by-32-bit
products. The core uses one registered multiplier and one word carry.

## Protected consumer before and after word-based arithmetic

Quartus Pro 26.1.0 Build 110, `A5ED013BB32AE4SCS`, `rsa_slot_synthesis`,
Altera backend. The subsystem contains enabled protected keygen, the AES
packet path, reservation arbitration and the RSA consumer. Testbench pins
drive the request and operand inputs and supply random words.

| Measurement | PR59 baseline | Result RAM only | Word engine |
| --- | ---: | ---: | ---: |
| Estimated ALMs out of 46,800 | 59,220 | 59,067 | 37,149 |
| Dedicated logic registers | 85,089 | 83,075 | 42,735 |
| Estimated DSP blocks after merging | 6 | 6 | 8 |
| Synthesis block memory bits | 164,096 | 166,144 | 176,384 |

The result-only pilot removed 2,014 registers and saved 153 estimated ALMs.
Quartus mapped its newly instantiated result store to block RAM. The remaining
wide arithmetic justified moving the operands and Montgomery operations to
32-bit limbs. The baseline fit reached its 1,800-second deadline. Baseline
input hashes matched all 64 build inputs in the PR59 checkout. The pilot
input bytes correspond to `a0057ad`. The first word-based RTL checkpoint is `65ad205`.

| Hierarchy, including descendants | Baseline ALUTs | Word-engine ALUTs | Baseline registers | Word-engine registers |
| --- | ---: | ---: | ---: | ---: |
| Protected RSA | 41,424 | 7,493 | 50,056 | 7,702 |
| RSA arithmetic, inside protected RSA | 30,583 | 1,654 | 34,914 | 713 |
| Protected keygen | 29,744 | 29,879 | 21,184 | 21,184 |
| AES packet | 9,853 | 10,122 | 13,271 | 13,271 |

The hierarchy reports count combinational ALUTs. Quartus reports ALMs at the
device level. Protected RSA previously retained adapter copies, the original
exponentiator's precomputation and square buffers, and a radix-2 multiplier's
2,048-bit A/B/N and two full-width sum registers. The result-only change
preserved that arithmetic. The protected arithmetic path instantiates the word
engine alone. Key generation and protected private derivation each retain
their own existing checked arithmetic and private scratch. AES retains its
packet scratch. Resource reporting at the top contains one of each enabled
worker. The keygen slot retains its original combinational private read and
commit/destroy semantics.

## First routed subsystem (word engine, original keygen operand storage)

The enabled subsystem fitted at **41,378 / 46,800 ALMs (88%)**, 42,727
dedicated logic registers, 176,384 block-memory bits, 17 RAM blocks, and
8 DSP blocks. The fitted ALM margin is **5,422**. Additional board services
and their routing must fit within the available device resources. The
fitter's physical RAM report identifies six distinct M20K sites for
accumulator, exponent, modulus, representative, scratch and result.

All four timing models on this checkpoint pass the 20 ns internal clock. Values are
worst slacks in nanoseconds.

| Operating condition | Setup | Hold | Recovery | Removal | Pulse width |
| --- | ---: | ---: | ---: | ---: | ---: |
| Slow fix4 100 °C | 3.256 | 0.131 | 14.112 | 0.506 | 9.430 |
| Slow fix4 0 °C | 1.609 | 0.172 | 13.533 | 0.621 | 9.404 |
| Slow fix4a 0 °C | 1.431 | 0.167 | 13.529 | 0.609 | 9.401 |
| Fast fix4 0 °C | 9.846 | 0.074 | 16.302 | 0.306 | 9.551 |

TimeQuest reports zero unconstrained clocks. The virtual interface has 440
unconstrained input ports and 129 unconstrained output ports with no board
I/O delays. Quartus also reports the device reset-release warning on this
standalone harness. The board wrapper supplies its own reset-release and
cooling circuitry.

## Numerical scope and latency

Both normal and private exponents traverse 2,048 fixed square/multiply pairs.
The separate arithmetic test covers a zero base, a zero exponent, an all-ones
exponent, an alternating exponent, and a deterministic random 2,048-bit
case. Each result matches independent Python `pow` in **39,069,025 cycles**
(0.78138 s at 50 MHz). The comparison below includes adapter lifecycle and
the testbench's stalls.

| Full-width directed test | PR59 cycles | Word-engine cycles |
| --- | ---: | ---: |
| Exact public and private adapter results together | 36,300,508 | 80,835,322 |
| Generate RSA, consume twice, destroy, generate AES | 172,535,525 | 217,070,339 |

The generation fixture supplies 384 public candidate/witness words to the real
key generator. Checks cover all 129 committed words, separate public/private
oracles, exclusive use, masked private reads, held results and status, calls
to destroy or overwrite while reserved, destruction after release and fresh
reuse. These directed inputs measure functional correctness. Physical entropy,
prime-search throughput, side-channel resistance and ASIC signoff require
separate evidence.

## Integrated keygen and protected derivation

Keygen retains its 32-limb prime arithmetic and 64-limb RSA result. Its
production engine uses the project's compact Montgomery implementation from
the earlier DE25 study (43ce09e). Each operand reader uses `keygen_ram32`
on both backends. The controller waits for the compact engine's ready edge
before accepting the job. Candidate separation uses a 32-bit subtract with
borrow while the 32 peer words arrive. The signed distance threshold is
checked in both directions at, immediately below and immediately above
2^924. The original general-purpose math module remains available.

The RSA adapter reads each factor directly from its reserved slot into
the pair checker's private RAM. After the arithmetic range and exact
division checks pass, the pair checker streams the canonical exponent into
the exponent bank and the derived modulus into the word comparator. Each
64-word transfer can stall. A mismatch, lost lease or early timeout
suppresses exponentiation and starts erasure. The consumer waits for
the pair checker's 512-word scrub and its successful terminal result
before starting RSA. Normal keygen callers retain their parallel public
modulus interface. The original held-wide protected handoff remains
covered by its own regression.

## Board capacity and production hookup

The physical SPI pins, PLL, reset release, and fan controller come from
`de25_soc_top`. Production `TPM_TOP` ties keygen and RSA requests,
authorization, operands and completion-ready inactive. No trusted object
or authorization producer is present. The separate capacity probe activates
the real SPI, RNG, SHA, PCR, AES, keygen and RSA paths by driving their
missing trusted boundary with virtual ports. It does not add a host port
for private slot memory.

| Board capacity checkpoint | Estimated ALMs / 46,800 | Synthesis registers |
| --- | ---: | ---: |
| Word engine with original keygen storage | 56,510 | 66,369 |
| Compact operand RAM in keygen | 42,321 | 58,733 |
| Word-serial prime separation and candidate reuse | 41,977 | 56,688 |

The first board placement failed with Intel error 22191 after 22 minutes.
It required 5,701 LABs on a device containing 4,680. The fit-stage summary
reported 54,501 ALMs (116%). The final capacity probe gives the virtual
issuer an ideal 50 MHz launch and capture boundary with zero external I/O
delay. The repository's physical SPI, mailbox, reset and fan constraints
remain in force. Its independent board audit checks every timing corner,
each SPI synchronizer, both mailboxes and the unconstrained endpoint report.
Production TPM integration still requires the missing trusted issuer.

## Reproduce

From the checkout root on Windows, prepare the independent fixtures. Use WSL
Verilator for the Generic tests.

```powershell
$bench = 'Testing/Simulation/Asymmetric Module'
python "$bench/run_rsa_adapter.py" prepare
wsl.exe --exec python3 "$bench/run_protected_d.py"
foreach ($case in 'boundary','adapter','generated','errors','reset','word-resets') {
    wsl.exe --exec python3 "$bench/run_rsa_fast.py" $case
    if ($LASTEXITCODE) { throw "Generic $case failed" }
}
wsl.exe --exec python3 "$bench/run_rsa_retry.py"
wsl.exe --exec python3 "$bench/run_rsa_words.py"
wsl.exe --exec bash "Testing/Simulation/Key Generation/scripts/test_pair_verilator.sh" build/rsa-default-pair "Testing/Simulation/Key Generation/reference/expected_keys.json"
```

Reserve the shared native Questa installation. Run these commands sequentially.
The installed `220model.v` and `altera_mf.v` implement the multiplier and RAM
in the Altera simulations. The older simulation library reports AUTO for the
RAM type. Physical RAM selection is checked in the Quartus reports.

```powershell
foreach ($case in 'compile','boundary','protected-d','adapter','generated','errors','word-resets','resets') {
    python "$bench/run_rsa_vendor.py" $case
    if ($LASTEXITCODE) { throw "Altera $case failed" }
}
python 'Testing/Simulation/Execution Engine/run_aes_slot_regressions.py' --without-rsa --label rsa-word-final
```

Use a new short directory under the class scratch root for each build. Preserve
the previous baseline and failed runs. Each runner records input hashes and
tool transcripts.

```powershell
python "$bench/synthesize_rsa_slot.py" --family agilex --fit --output ../wordfit --deadline 5400
& 'C:/altera_pro/26.1/quartus/bin64/quartus_sta.exe' -t "$bench/verify_rsa_slot_timing.tcl" ../wordfit
```

The board-capacity experiment uses a fresh output directory and runs the original DE25 SPI timing audit after routing.

```powershell
python "$bench/probe_de25_rsa_capacity.py" ../wordboard
```
