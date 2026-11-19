# Protected consumer reservation (Phase Two)

Dependency: PR57, `2f4e29a1a058fd7c30f715701f82ac7cb75b8015`.
AES owns changes to shared slot/engine/scratch files. RSA should reuse this
contract after AES lands; do not edit shared files concurrently.

`execution_engine_keygen.ENABLE_CONSUMER` defaults to zero for existing callers.
The containing engine must arbitrate ONE consumer; these ports are private,
never a host lookup, export endpoint or production authorization service.

* `acquire_valid_i && acquire_ready_o` captures one request. Ready requires
  enabled/reset released, no reservation and no outstanding acquisition reply.
  Type/word count/allow are sampled on that edge, not throughout the job.
* `acquire_reply_valid_o/ready_i` holds exactly one code: 0 acquired; 9 fixture
  denial; 1 absent/unpublished/destroyed; 4 wrong type or word count. Success
  atomically sets `reserved_o` on the acquisition edge. No key may be used
  before successful reply acceptance. Denial must never launch arithmetic.
* Reservation preserves the committed slot, type, size and data. Generation
  cannot replace the occupied one-slot result. `release_i` means DESTROY;
  while reserved it is rejected and not queued. Simultaneous unreserved
  destroy/acquire gives destruction priority and an absent-slot reply.
* `consumer_release_i` relinquishes an existing reservation after its reply has
  been accepted; it does not destroy the slot. The consumer must first finish
  computation, erase its key copies and owned scratch, and surrender terminal
  result ownership. A pulse before reply acceptance is ignored. New acquisition
  cannot happen on the relinquish edge; readiness follows the unlocked state.
* Shared reset immediately masks valid/data/reply/reservation, invalidates every
  consumer state, and starts the full129-word sweep. No retained lease, late
  completion or automatic recovery exists. Every connected consumer must use
  the SAME reset. Slot destruction is not generation cancellation.

The slot address/data port is combinational, 32-bit words MSB first, with
out-of-range reads zero. The containing engine routes it exclusively to the
reserved consumer. AES assembles only4/8 words in private registers; RSA can
reuse the reservation for its129-word n/e/p/q adapter. Neither may put keys in
host command/response scratch. Postpublication RNG fault does not revoke a
committed slot. Fixtures are not Phase Three handles, Names or authorization.
