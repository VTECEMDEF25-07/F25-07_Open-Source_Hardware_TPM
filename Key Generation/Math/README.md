# Private scratch arithmetic engine

`../rtl/arithmetic/keygen_math.v` supplies the arithmetic service shared by the RTL and firmware RSA controllers. It uses the portable IP wrappers, so defining `KEYGEN_ALTERA` selects real multiplier and RAM macros; the default selects generic Verilog. It is not a complete RSA key generator or an entropy source.

## Review order

Read this command table, then the RAM/command boundary in `keygen_math.v`, the `MULT_WAIT` accumulator and Montgomery states, and finally the independent Python-vector test. Every operation first captures metadata and operands; source and destination overlap is safe because all source limbs are captured before destination writes. Nothing on the CPU command interface exposes a key limb.

## Interface

All words are unsigned little-endian limbs: address zero of an operand contains its least-significant 32 bits. Scratch has 4,096 words (16 KiB); a numeric operand has 1Ã¢â‚¬â€œMAX_LIMBS words. MAX_LIMBS defaults to 64; the RSA board integration selects 32 to reduce operand-cache muxes while retaining 1024-bit prime arithmetic and 2048-bit full products. Multiplication produces 2N words. Inputs use `cmd_valid_i/cmd_ready_o`, an 8-bit opcode and four 32-bit arguments. One command may be outstanding. `rsp_valid_o/rsp_ready_i` holds an 8-bit terminal status until accepted. No new command is accepted while responding.

The private `mem_*` port is available only when `mem_ready_o=1`, which requires IDLE and no presented command. A read or write is accepted on that rising edge; read-valid/data appear just after it. `mem_read_valid_o` is one cycle long. The command interface takes priority over the private port. This private port must never be connected to CPU data reads or external transport in production.

Reset immediately aborts the command and invalidates the cached modulus. It then writes zero to all 4,096 scratch locations and every internal operand array then performs a separate zero-word read to refresh the RAM output latch before raising command-ready (4,098 rising edges). Reset must remain connected to the subsystem's cleanup/abort policy. `ZERO` only clears the selected scratch range; it does not erase all cached arithmetic operands, and therefore cannot alone establish complete secret cleanup.

| Opcode | Operation | Arguments 0, 1, 2, 3 |

|---|---|---|

| 01 | COPY | destination, source, ignored, N |

| 02 | ZERO | destination, ignored, ignored, N |

| 03 | COMPARE | ignored valid destination address, source A, source B, N |

| 04 | ADD | destination, source A, source B, N |

| 05 | SUB | destination, source A, source B, N |

| 06 | SHIFT_RIGHT | destination, source, ignored, N; shift exactly one bit |

| 10 | MUL | destination (2N words), source A, source B, N |

| 11 | MOD_SETUP | modulus address, reserved workspace address, N, zero |

| 12 | MONT_MUL | destination, source A, source B, zero; N from context |

| 13 | MODEXP | destination, normal base, normal exponent, exponent word count |

ADD and SUB wrap modulo `2**(32*N)`; they do not return carry or borrow. COMPARE returns unsigned relation. MONT_MUL returns `A*B*R^-1 mod modulus` for `R=2**(32*N)`. Both inputs must be below the modulus. MODEXP accepts a normal base below the modulus and a normal exponent (including zero), and returns a normal modular result. Exponent length is independent of modulus length.

MOD_SETUP requires an odd modulus greater than one, with a nonzero top limb, and computes the Montgomery low-word inverse and R-squared internally. Its reserved workspace is `4*N+2` words and must fit scratch without overlapping the modulus. Current implementation caches work operands in private registers; the workspace argument reserves room for later RAM placement. Rewriting scratch does not update the cached modulus: issue MOD_SETUP again when it changes. Context persists until another setup or reset.

Status 00 means success; 01 bad opcode; 02 out of bounds/invalid length; 03 reserved workspace overlap; 04 missing/invalid modulus or Montgomery/base operand outside modulus; 05 internal state error. Successful comparisons use 10 (less), 11 (equal), 12 (greater). Bounds and lengths are checked before destination writes. DIV20, GCD21, LCM22 and INVERSE_E65537=23 remain reserved on this shared command interface and return bad opcode. The integrated `../rtl/arithmetic/keygen_pair_check.v` already performs division, GCD, LCM and the fixed-e=65537 inverse privately for RSA key validation. Those operations are reached through the RSA pair-check service, not these reserved math opcodes. Its separate 2 KiB scrubbed scratch brings the private arithmetic allocation to 18 KiB (16 KiB math plus 2 KiB pair).

## Algorithm and verification

The engine reuses a pipelined 32x32 multiplier. Schoolbook multiplication accumulates one product at a time. Montgomery multiplication uses the coarsely integrated operand scanning algorithm with an extra carry word and a final conditional subtraction. Modulus setup uses five low-word Newton iterations and repeated modular doubling for R-squared. Exponentiation converts to Montgomery representation, performs a left-to-right square/multiply sequence, and converts back. These operations have data-dependent duration and are not a side-channel hardening claim.

`Math/scripts/generate_vectors.py` computes expected results using Python integer multiplication, modular inverse and `pow(base, exponent, modulus)`, independently of the RTL algorithm. The test includes 32Ã¢â‚¬â€œ2048-bit Montgomery and full products, 1024-bit modular exponentiation, exponent zero/one, maximal/carry values, response backpressure, invalid commands/contexts, overlapping COPY, and reset during operation followed by reading every scrubbed RAM word.

```powershell

& './Key Generation/Math/scripts/simulate_math.ps1' -BuildDirectory 'ABSOLUTE_SCRATCH_PATH' -Full -Small

& './Key Generation/Math/scripts/simulate_math.ps1' -BuildDirectory 'OTHER_ABSOLUTE_SCRATCH_PATH' -Full -Small -Altera

& './Key Generation/Math/scripts/fit_math.ps1' -BuildDirectory 'FIT_SCRATCH_PATH'

```

Simulation uses the real installed vendor models when `-Altera` is set. See the IP README for the older model's disclosed AUTO RAM warning. The fit is a virtual-pin resource/timing smoke build, not board I/O timing signoff or a flash operation. Only one Questa session may run on the installed license, so coordinate simulation runs between workers.

## Validated baseline

The generic 64-limb baseline passed 54 independent bigint cases in Questa, including 2048-bit Montgomery/products and two fully random 1024-bit exponents. The board-sized MAX_LIMBS=32 configuration passed 48 cases in compiled Verilator, including two different random 1024-bit exponents (13,177,407 and 12,891,195 cycles), the final collision-free RAM output-latch refresh, invalid-base rejection before writes, and all 4,096 reset-scrub reads. These cycle counts are arithmetic measurements, not complete RSA key-generation timing guarantees.

`simulate_math_verilator.sh ABSOLUTE_SCRATCH_DIRECTORY` provides the faster generic full-width run under WSL/Linux. It invokes g++ directly on Verilator's generated C++ because GNU Make rejects the spaces in this class-directory path. Generated files and logs stay in the supplied scratch directory. The runner prints Verilator width diagnostics into `build.log`; it does not present a warning-free lint signoff. Real vendor simulation and actual-device fitter results are separate gates.

The same 48-case MAX_LIMBS=32 suite also passes in Questa with the real Altera `lpm_mult` and `altsyncram` models. Full-width exponentiation cycle counts exactly match the generic run. This includes the final output-latch scrub and invalid-base/no-destination-write check. The vendor run reports zero errors and one clock-port pull-type coercion warning, plus the separately printed AUTO RAM-model warning disclosed in the IP README. No vendor model was replaced by generic RTL.

The MAX_LIMBS=32 Altera macro smoke build completed placement and routing in Quartus Pro 26.1 for A5ED013BB32AE4SCS: 12,266 / 46,800 ALMs (26%), 10,682 registers, eight M20Ks (131,072 bits), and two DSP summary units. At 50 MHz, final setup slack was +12.503 ns and hold slack +0.095 ns. This virtual-pin arithmetic-only result does not establish full-core utilization or board I/O timing. Evidence is retained under AI/tmp/keygen-math-fit-altera32/output_files/ in the class workspace.

A subsequent source-only cleanup makes unsigned carry/borrow extensions explicit. The complete 48-case generic suite passes again with identical full-width exponentiation cycle counts (AI/tmp/keygen-math-width-regression/math.log). The routed fit and vendor-model results above identify the preceding arithmetic baseline; array-index width diagnostics remain and are not suppressed.

## Exhaustive small-input domain

The separate `tb_keygen_math_small.sv` drives the same MAX_LIMBS=32 engine and 32-bit resource wrappers; it does not reduce the RTL datapath width. `generate_small_vectors.py` supplies 10,771 independent Python-oracle cases:

- All 256 pairs of four-bit inputs for ADD, SUB, COMPARE and full multiplication, plus six 32-bit boundary values in every pair.
- Every four-bit input and six 32-bit boundaries for COPY, SHIFT_RIGHT and ZERO.
- All 5,455 legal operand pairs across odd moduli 3 through 31 for Montgomery multiplication, using Python's inverse of 2^32 modulo the modulus.
- All bases below those moduli and exponents 0 through 15 for normal modular exponentiation, plus composite 2047=23*89: base 2 passes its strong probable-prime arithmetic round, while base 3 fails. This is an arithmetic example, not a valid RSA candidate; the service trial division rejects its small factors.
- Three additional two-limb carry, borrow and cross-limb shift checks, held responses, and all 4,096 scratch words plus actual RAM output latch after reset.

The generic suite passed against frozen integrated RTL: `AI/tmp/keygen-math-small-generic/result.log` and its input hashes. The genuine-Altera suite also passed all 10,771 cases with the same oracle in `AI/tmp/keygen-math-small-altera-preload/result.log` (57,840,800 ns simulated, zero errors, one disclosed clock-port warning). Vectors are preloaded with `$readmemh`; the earlier streaming-file attempt stopped at vector 4096 with an input-parse failure and is retained as failed evidence in `AI/tmp/keygen-math-small-altera`. No arithmetic mismatch was reported in that attempt. The same preloaded testbench passed all cases on the generic backend too (`AI/tmp/keygen-math-small-generic-preload/result.log`).

Run the generic script under Linux/WSL, passing absolute paths. The vendor script runs under Windows with the installed Questa license:

```text
python3 Math/scripts/simulate_small_verilator.py ABSOLUTE_BUILD --source-root ABSOLUTE_KEYGEN_ROOT
python Math/scripts/simulate_small_altera.py ABSOLUTE_BUILD --source-root ABSOLUTE_KEYGEN_ROOT
```

Both runners retain hashes of the actual RTL, test, oracle and vectors and reject changes during execution. The vendor runner additionally hashes the unchanged installed `220model.v` and `altera_mf.v` files. Keep each evidence build directory distinct; coordinate the single Questa license before running the vendor script.
