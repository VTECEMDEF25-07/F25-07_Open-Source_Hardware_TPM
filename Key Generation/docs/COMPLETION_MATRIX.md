<!--
Filename: COMPLETION_MATRIX.md
Authors: Project contributors; see Git history.
Date: 2026-10-13
General Description: Documents Full-plan completion matrix.
AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.
-->

# Dedicated-logic review and acceptance matrix

PR #35 contains two resource configurations: dedicated RTL/generic and dedicated RTL/Altera. The CPU experiment and its evidence remain on `aaron/keygen-cpu`. This matrix distinguishes source-review readiness from final hardware acceptance.

| Requirement | Evidence / remaining gate |
|---|---|
| Dedicated-only source and build surface | Direct `keygen_rsa_controller` instantiation; no CPU source, firmware directory or controller selector. Generic and Altera resource backends. |
| Current regression results | [RTL_REVIEW_VALIDATION.md](RTL_REVIEW_VALIDATION.md); commands and limitations must be reported per run. |
| AES/RSA contracts and algorithm | [INTERFACE.md](INTERFACE.md), [RSA_ALGORITHM.md](RSA_ALGORITHM.md); faculty review requested. |
| Generic resource portability | Simulation supported; generic RAM inference and DE25 resource fit remain unresolved follow-up work. |
| Final routed image acceptance | Fresh source-matched fit, timing, reset/CDC and resource review required for both configurations. Prior images are historical evidence only. |
| Physical correctness and performance | Both AES sizes and all 20 seeds; median RSA <=30 seconds, each operation <=180 seconds; pending on newly built images. |
| Transport and recovery | 100 kHz/500 kHz/1 MHz SPI; five reset boundaries, source stalls and four fault boundaries with reuse; pending on newly built images. |
| Cooling and soak | Healthy fan/temperature telemetry required. October 13's 30-minute soak waiver was a demo waiver, not a passing test; local hardware acceptance still requires soak evidence. |
| Production TPM integration | Entropy, seed management, authorization, protected object storage and command wiring remain external. |
| Phase 1 board ports | DE1 and DE25 projects and board selection are in PR #36 against main. |
| Release package | Pending both accepted source-matched images and all required reports; no release package is claimed by this review. |

Historical board measurements and demo packaging are preserved locally. Review-ready does not mean hardware-release complete or approved to merge.
