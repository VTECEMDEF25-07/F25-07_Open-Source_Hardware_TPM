<!--
Filename: REVIEW.md
Authors: Project contributors; see Git history.
Date: 2026-09-30
General Description: Provides the faculty advisor reading order and review scope.
AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.
-->

# Faculty advisor review guide

## Decision requested

Review the dedicated-logic AES/RSA key-generation design and its interface for future TPM integration. DE1/DE25 board projects and board selection belong to PR #36 targeting main; the keygen demonstration is local-only and is not wired into the TPM command path.

The CPU implementation has been preserved separately on `aaron/keygen-cpu` at `c90610165605cac55243522847c5e5f50f60ef08`. Review this PR's **Files changed** view for the final dedicated-logic scope; earlier commits still contain the superseded combined implementation.

## Suggested reading order

1. [README](README.md), [interface](docs/INTERFACE.md) and [lifecycle](docs/CORE.md): external responsibilities, ownership and fault behavior.
2. [Algorithm](docs/RSA_ALGORITHM.md), `rtl/rsa_rtl/keygen_rsa_controller.v` and [engine](docs/RSA_ENGINE.md): prime-generation sequencing and bounded failures.
3. [AES](docs/AES.md), [pair validation](docs/PAIR_CHECK.md), [arithmetic](Math/README.md) and [resources](IP/README.md): implementation and reference checks.
4. [Validation](docs/RTL_REVIEW_VALIDATION.md) and [build commands](docs/BUILD_AND_TEST.md): what was rerun for this branch.

## Review questions

- Are result ownership, discard, reset and clearing contracts suitable for the team's protected object store?
- Do the RSA state-machine ordering, retry bounds and arithmetic checks implement the intended algorithm? No FIPS certification is claimed.
- Are the external entropy and seed-service responsibilities sufficiently explicit?
- Are resource use and remaining timing/physical gates acceptable before integration?

## Known limits

Production entropy, hierarchy seed management, authorization, object wrapping, CRT preparation and full TPM command integration are outside this subsystem. Test fixtures contain public test keys only. Generic RAM inference/DE25 fit remains a separate follow-up. Prior bitstream evidence does not certify the changed source snapshot; final fit, timing and physical acceptance must use matching manifests. Existing Phase 1 SPI CDC/generated-clock limitations remain documented in the board README.

[Completion matrix](docs/COMPLETION_MATRIX.md) separates review readiness from hardware release acceptance. AI assistance is disclosed in [AI_DISCLOSURE.md](docs/AI_DISCLOSURE.md); human review remains required before merge.

DE25 board support: [PR #36](https://github.com/VTECEMDEF25-07/F25-07_Open-Source_Hardware_TPM/pull/36), targeting main and intended to merge first.
