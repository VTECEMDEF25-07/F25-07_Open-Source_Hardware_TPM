# Private scratch arithmetic engine

`../rtl/arithmetic/keygen_math.v` supplies the arithmetic service shared by the RTL and firmware RSA controllers. It uses the portable IP wrappers, so defining `KEYGEN_ALTERA` selects real multiplier and RAM macros; the default selects generic Verilog. It is not a complete RSA key generator or an entropy source.

## Review order

Read this command table, then the RAM/command boundary in `keygen_math.v`, the `MULT_WAIT` accumulator and Montgomery states, and finally the independent Python-vector test. Every operation first captures metadata and operands; source and destination overlap is safe because all source limbs are captured before destination writes. Nothing on the CPU command interface exposes a key limb.

## Interface

All words are unsigned little-endian limbs: address zero of an operand contains its least-significant 32 bits. Scratch has 4,096 words (16 KiB); a numeric operand has 1–MAX_LIMBS words. MAX_LIMBS defaults to 64; the RSA board integration selects 32 to reduce operand-cache muxes while retaining 1024-bit prime arithmetic and 2048-bit full products. Multiplication produces 2N words. Inputs use `cmd_valid_i/cmd_ready_o`, an 8-bit opcode and four 32-bit arguments. One command may be outstanding. `rsp_valid_o/rsp_ready_i` holds an 8-bit terminal status until accepted. No new command is accepted while responding.

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

Status 00 means success; 01 bad opcode; 02 out of bounds/invalid length; 03 reserved workspace overlap; 04 missing/invalid modulus or Montgomery/base operand outside modulus; 05 internal state error. Successful comparisons use 10 (less), 11 (equal), 12 (greater). Bounds and lengths are checked before destination writes. DIV20, GCD21, LCM22 and INVERSE_E65537=23 are reserved and currently return bad opcode; they are later implementation chunks.

## Algorithm and verification

The engine reuses a pipelined 32x32 multiplier. Schoolbook multiplication accumulates one product at a time. Montgomery multiplication uses the coarsely integrated operand scanning algorithm with an extra carry word and a final conditional subtraction. Modulus setup uses five low-word Newton iterations and repeated modular doubling for R-squared. Exponentiation converts to Montgomery representation, performs a left-to-right square/multiply sequence, and converts back. These operations have data-dependent duration and are not a side-channel hardening claim.

`Math/scripts/generate_vectors.py` computes expected results using Python integer multiplication, modular inverse and `pow(base, exponent, modulus)`, independently of the RTL algorithm. The test includes 32–2048-bit Montgomery and full products, 1024-bit modular exponentiation, exponent zero/one, maximal/carry values, response backpressure, invalid commands/contexts, overlapping COPY, and reset during operation followed by reading every scrubbed RAM word.

```powershell
& './Key Generation/Math/scripts/simulate_math.ps1' -BuildDirectory 'ABSOLUTE_SCRATCH_PATH' -Full -Small
& './Key Generation/Math/scripts/simulate_math.ps1' -BuildDirectory 'OTHER_ABSOLUTE_SCRATCH_PATH' -Full -Small -Altera
& './Key Generation/Math/scripts/fit_math.ps1' -BuildDirectory 'FIT_SCRATCH_PATH'
```

Simulation uses the real installed vendor models when `-Altera` is set. See the IP README for the older model's disclosed AUTO RAM warning. The fit is a virtual-pin resource/timing smoke build, not board I/O timing signoff or a flash operation. Only one Questa session may run on the installed license, so coordinate simulation runs between workers.
