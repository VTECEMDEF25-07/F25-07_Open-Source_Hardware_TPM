# Protected internal RSA2048 consumer

Stacked on AES PR58 `8dc74f9f9b673eee45e9f7d96aa37322490ce8ff`, following
merged keygen PR57. The shared reservation implementation is reused unchanged.
The execution engine arbitrates AES and RSA on that single lease, latching the
consumer on acquisition acceptance, routing the held reply only to that owner,
and retaining ownership until denied-reply acceptance or terminal relinquish.
AES wins simultaneous acquisition requests; RSA's waiting deadline prevents
unbounded starvation. Private read addresses/data are routed only to the owner.
The existing internal unreserved inspection fixture is masked during either
reservation. Normal board TPM_TOP explicitly ties RSA request/operands inactive
and leaves its enable at zero. No board pins or host commands expose this route.

## Format and arithmetic

The published slot remains 129 MSB-first 32-bit words: n[0..63], e[64],
p[65..96], q[97..128]. Public operations read only n/e. Private operations
stream n into private word RAM, retain e/p/q locally, and reuse
`keygen_pair_check` to recompute n and canonical d modulo lcm(p-1,q-1).
This repeats the checked keygen math on a separate service instance; it does
not race keygen RAM or share its multiplier. The generated slot remains intact.

`PROTECTED_D_HANDOFF=1` adds an internal handoff AFTER the pair service's
existing bounds, distance, product, GCD/LCM, exact-division and d-bound checks.
The normal keygen instance keeps its default zero and has no d publication.
The protected service holds its d bus until accepted, clears that copy, reads
n, and performs the existing full 512-word RAM/multiplier/register scrub before
its ordinary result. The adapter waits for that scrubbed successful result,
requires recomputed n to match the reserved n, and only then launches RSA.
No known fixture d is present in synthesizable logic.

The team radix-2 implementation from `3afc1f6` remains available in the
asymmetric module. The protected adapter uses `rsa_montgomery_words` for the
DE25. The core stores 64 little-endian 32-bit limbs per operand in five
`keygen_ram32` banks for n, base, exponent, accumulator and scratch. A sixth
bank holds the result in transfer order during cleanup. `IP_TYPE=0` selects
portable synchronous RTL. `IP_TYPE=1` selects the same `altsyncram` and
pipelined `lpm_mult` wrappers used by key generation. `DEVICE_FAMILY` selects
the RAM block. The wrappers forward new data on a same-address read/write.

The adapter compares the incoming representative with n in MSB-first order.
For a private operation it streams the held d into the exponent bank and
checks every limb of the recomputed n before launch. For a public operation
the exponent bank holds 65537 and the slot exponent must equal that value.

The arithmetic uses coarsely integrated operand scanning (CIOS) Montgomery
multiplication with radix 2^32. Each row multiplies one accumulator limb by
the second operand, computes the low-word cancellation factor, and adds a
multiple of n using the same DSP pipeline. A canceled low word must be zero.
The upper carry survives the word shift. A fixed two-pass reduction produces
the canonical residue. The full-width modulus has its top bit set, so R−n
initializes the accumulator to R modulo n for R=2^2048. Repeated modular
doubling converts the representative. Each of the 2048 exponent bits executes
both a square and a multiply, with the same sequence of accumulator writes.
A final Montgomery multiply by one converts the result. Timing measurements
and limits are recorded in the validation notes.

## Ownership and transfer

An enabled, idle adapter accepts one internal request ID, allow fixture and
operation (0 public, 1 private). Other operation values and denied fixtures fail
before acquisition or arithmetic. It requests type 2/129 words through the
AES-owned acquire/reply handshake and begins key reads only after code 0.
The containing engine must arbitrate the single consumer and its private read
port. Shared reset is mandatory. No private buses may reach host scratch.

The 64-word representative stream requires last exactly on word 63. The modulus
must be full width and odd, e must be 65537, and representative must be below n.
The adapter holds the request until completion. Arithmetic holds its terminal
state while the adapter copies 64 result words into separate RAM. A registered
local reset clears the multiplier, control state and carry. The five arithmetic
banks subsequently write zero to every address and refresh their read latches.
The checked derivation sweeps its 512-word memory. The adapter waits for both
workers before publishing the result. The registered result read port prefetches
the next word on acceptance and keeps the current word stable through stalls.
Each accepted result word is overwritten with zero. Reset and failure mask
access and sweep the entire result bank before accepting another request.

The reservation extends through computation, cleanup, result transfer and held
terminal ownership. Completion acknowledgment relinquishes it one cycle later;
this never destroys the key slot. Destroy while reserved is rejected by the
shared slot, not queued. Explicit destruction after relinquish sweeps all 129
words before reuse. Reset masks every transfer immediately and starts full
child/slot erasure, with no stale completion or recovery.

`WAIT_LIMIT` bounds work/input/output waiting, including arithmetic and cleanup.
Acquisition cannot be abandoned after acceptance: the slot's one-cycle, held
reply is mandatory. On timeout the adapter resets/scrubs its children before
an error completion. `TERMINAL_LIMIT` bounds unacknowledged terminal ownership:
expiry withdraws the completion and relinquishes the lease, with no second
completion. The internal owner must treat this as abandonment, not success.
Defaults are 100,000,000 work cycles and 1,000,000 terminal cycles. Successful
result data must not be committed by an internal caller without its matching
successful terminal acceptance. These are internal fixtures, not production
authorization or host-visible result/key endpoints.

`ENABLE=0` uses a generate gate that omits adapter arithmetic hardware.
The module has no memory writes into command/response scratch.

## Phase Three and acceptance limits

Real objects/handles/Names, authorization/sessions/policy, padding and TPM RSA
commands, wrapping/loading, hierarchy/primary seeds and persistence remain
outside this work. No RSA_Encrypt/Decrypt/Sign/VerifySignature host commands are
added. Exact enabled-image fit/timing and physical entropy acceptance remain
separate. Default-image and historical demo measurements do not qualify this
enabled RSA consumer. The existing portable Generic/vendor math wrappers remain.
