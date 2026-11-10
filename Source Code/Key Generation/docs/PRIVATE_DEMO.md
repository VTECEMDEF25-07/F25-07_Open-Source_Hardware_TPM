# Optional protected RSA private context

2026-11-10. Codex-assisted implementation for the explicitly authorized DE25 educational demo. Defaults preserve the original result/profile/lifecycle behavior. This adds internal ports; legacy wildcard test instantiations explicitly tie the new interface inactive without changing their assertions.

Set `PRIVATE_RSA_ENABLE=1` consistently on `demo_keygen_operation` and `demo_volatile_store`. The operation propagates it through core, RSA engine/services and pair checker. It selects one shared `keygen_math #(.MAX_LIMBS(64),.COMPACT_STORAGE(1))`; disabled mode uses the legacy32-limb engine and original n/e/p/q result. Do not instantiate a second wide private core.

Enabled RSA profile2 emits n64/component2, e1/component3, d64/component6: exactly129 MSW-first32-bit words. Index restarts for each component, e=65537, whole-result last on d index63. Store physical layout is n0..63,e64,d65..128. p/q do not leave the generation engine in this mode. AES profiles and AES-only lookup are unchanged.

The pair checker derives and validates d in private RAM320..383, then streams64 little-endian limbs on `private_valid/ready`, data32/index6 before its original full scrub/n-result publication. RSA services stages them into math RAM384..447. Core reads that region in reverse order to produce MSW-first component6. Source failure/reset invalidates partial staging; ordinary whole-result ownership and local/source scrub are still required before generation completion. Committed key storage is independent of engine-local reset.

## Private math lease

Core and operation expose the same worker-relative channels:

| Channel | Ports |
|---|---|
| Open | `private_open_valid_i/ready_o`; `private_active_o` |
| Commands | `private_cmd_valid_i/ready_o`, op8,arg0..3 each32; `private_rsp_valid_o/ready_i`, status8 |
| Private scratch | `private_mem_write_en_i/read_en_i`, address12,write_data32; `private_mem_ready_o/read_valid_o/read_data_o[31:0]` |
| Close | `private_close_valid_i/ready_o`; held `private_close_rsp_valid_o/ready_i` |

Open is one handshake, only in cleaned IDLE with no new generation request; no separate open response. Active remains asserted through close response acknowledgment and blocks generation. Generation wins simultaneous admission. Commands use the existing arithmetic ABI; memory reads are native one-cycle pulses which worker captures. No host can access these ports.

Worker restores typed store n/d reads to math N1024..1087,D1088..1151; ciphertext C1152..1215; result R1216..1279. MOD_SETUP(1024,1536,64,0), workspace1536..1793; MODEXP(1216,1152,1088,64). Math limbs little-endian, host blocks256-byte big-endian.

Close requires engine idle and all command/read traffic drained, registers local engine reset, then waits complete math4096-word/pair512-word sweeps and caches/read-latch clearing. Response is held and no fake keygen status is emitted. The observed legacy-bank lease close is4100 cycles including reset sequencing; do not replace ready/valid with a fixed delay. Unfinished-command deadline uses sticky global recovery/reset, not an early successful close. Store ownership survives engine-local close; full demo reset clears owned keys.

## Store read isolation

Separate registered held channels use `public_*` and `private_*`, each request/ready, handle32,component1,index6, reply_valid/ready,data32,reply_code32. Public component0=n,1=e (only e index0). Private component0=n,1=d. All indexes MSW-first; worker writes math at base+63-index. Public selection cannot name d or p/q. Private port is wired only to worker.

Both require owned RSA profile2, matching handle, demo permission and `rsa_use_allowed_i`. Private additionally requires `rsa_client_active_i`, held through math close/cleanup. This lease/reply state blocks release/replacement. Replies remain stable under stalls; denied/nonvalid outputs zero; reply latches erase on consumption/reset. Codes0 success,18b invalid handle,12f permission/type denied,095 bad public index. AES lookup still rejects RSA/type mismatch. Explicit disposable AES export, separately authorized by user, belongs to a build+request-gated common protocol endpoint, not these RSA private ports.

## Completion metric

`done_cycles_o[63:0]` is stable with held operation done: elapsed crypto-clock edges from accepted outer job through cleanup, excluding held-DONE backpressure. It is zero outside done; common diagnostic controller must capture it on done handshake. It includes source preparation, generation, receiver backpressure and cleanup and is not just arithmetic active time. Transport wall-clock timing is a separate measurement.

Tests and exact evidence are under `Testing/Simulation/Key Generation/overnight/`. Public known-prime fixtures exercise real candidate/Miller–Rabin/pair/d arithmetic but are not fresh prime-search performance. No entropy health qualification, OAEP/production security or constant-time claim: the shared exponent schedule is data dependent. Real fresh FPGA generation/private-decrypt acceptance, final fit/timing and physical module measurements are separate hardware-lead gates.
