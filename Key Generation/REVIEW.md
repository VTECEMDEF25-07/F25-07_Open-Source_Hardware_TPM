# Outline validation record

Date: 2026-09-30. Scope: documentation-only proposal in `Key Generation/README.md` on `aaron/key-generation`, based on main `91759b2c98ccf0f0a1bf29012d9f5ec64d669b57`.

Codex authored the outline at Aaron's request. A separate AI tester reviewed it read-only; the development agent remained sole repository writer. AI review is not human approval. Aaron must review the draft PR before merge.

## Independent review findings resolved

| Finding | Correction |
| --- | --- |
| Stray Markdown fence hid later design sections | Removed fence; diagram fence is balanced. |
| Cancellation could coincide with storage begin/worker launch, making rollback ownership ambiguous | Cancel/fault suppresses request/begin/work/RNG/data/commit normal transfers on that edge. Start worker only after staging opens; wait for cleanup only from actually started peers. |
| Late fault could rewrite a stalled terminal success response | First `rsp_valid` publishes immutable status/object/token through acknowledgment, except reset. Faults through publication decision edge dominate success; later faults are separately supervised through sticky health state and storage recovery. |

## Static validation

- Port directions and widths reviewed for external wrapper/controller, both workers, request/cancel/status, RNG, protected component stream, storage finalization and health/recovery.
- Reviewed latching and held-start rearming, accepted-word counting, stalls, error priority, cancel/zeroization intent, rollback versus accepted commit, immutable terminal status and reset reconciliation.
- Component arithmetic checked: AES-256 eight words; RSA basic n/e/d profile 129 words; reserved full CRT profile 289 words; 7-bit component index accommodates maximum used index 63; 12-bit sizes accommodate 2048 bits.
- Repo-relative Markdown links and fence balance checked; final staged whitespace and changed-file scope checks performed before commit. Only two new Markdown files in `Key Generation` are intended changes.
- Every generation/storage operation remains proposed. No inherited HDL or board configuration changed. No success stub, source algorithm, functional key generation or compliance claim added.

The independent tester found no remaining substantive documentation issue after corrections. This is a proposal review, not verification that hardware satisfies the contracts.

## Inherited implementation evidence reused

The read-only chat **Review inherited TPM execution and management modules** analyzed the same base; its saved report is class `AI/INHERITED_MODULE_REVIEW.md`, and its separate logs live outside the repository under class `AI/tmp/inherited-module-review/`. The development agent read the report and relevant log output and reconciled the integration plan. Selected observations:

- Execution's default next state can leave EXECUTE when `command_done` is low; command_start is not a safe one-shot launch protocol.
- Session-free command progression, authorization/preprocessing waits and initialization-on-error behavior need correction before generation launch.
- Dispatcher error response can revert to success; execution response input is only one bit. Neither is a valid full-width error return path.
- Management hierarchy changes depend on enable-gated, prior-latched values; a one-cycle command enable cannot be assumed to apply the new request.
- Management reset coverage and response priority also need correction before autonomous lifecycle/object side effects.
- Top validation/completion constants and CRB's ten-byte header-only response remain integration blockers.

These are inherited-module findings, **not tests of this outline or a new key-generation implementation**. This PR documents required changes and does not fix those modules.

## Limits and future verification

No new HDL exists to compile, elaborate or simulate. No cryptographic functional tests ran for this change. Native PATH searches did not find HDL tools; the separate inherited review found an off-PATH Questa installation. Its availability does not make documentation an executable design.

Future implementation must test accepted-word counts and ordering; stalls and equal-valued consecutive words; reset/RNG error/cancel at every transfer boundary; held request/rearming; late failure and status stability; rollback/commit and stale IDs; variable RSA candidate retries and independent arithmetic/key checks. RNG assurance/CDC, actual secret clearing, protected-storage behavior and TPM creation/session response semantics need separate verification.

RNG full contract, formal AES sizes, primary derivation, byte order/encoding, target board/clocks, storage profile, failure/recovery classification and RSA generation/compliance procedure remain review gates.
