<!--
Filename: ACCEPTANCE.md
Authors: Project contributors; see Git history.
Date: 2026-10-13
General Description: Documents Implementation and evidence ledger.
AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.
-->

# Acceptance evidence scope

Use [RTL_REVIEW_VALIDATION.md](RTL_REVIEW_VALIDATION.md) for checks of the dedicated-only source split and [COMPLETION_MATRIX.md](COMPLETION_MATRIX.md) for outstanding hardware gates.

Earlier combined-controller development logs are preserved at commit `c90610165605cac55243522847c5e5f50f60ef08` on `aaron/keygen-cpu`. They are historical evidence, not current-source acceptance. Earlier dedicated-controller results included 28 lifecycle checks, 49 RSA-service checks, full directed RSA, resource/math/pair tests with generic and genuine Altera models, and normal-stream seed 1 with 54,336 input words. Each result applies only to its recorded source snapshot and test scope.

Current source changes require fresh simulation. New bitstreams require fresh timing/resource review and physical testing bound to their fingerprints. A directed known-candidate RSA test does not establish prime-search performance, 20-seed coverage or production entropy quality. No FIPS or production security certification is claimed.
