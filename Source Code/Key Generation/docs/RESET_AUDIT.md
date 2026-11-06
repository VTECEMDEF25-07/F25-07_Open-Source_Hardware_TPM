<!--
Filename: RESET_AUDIT.md
Authors: Project contributors; see Git history.
Date: 2026-10-13
General Description: Documents Reset/clear/clock-enable audit.
AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.
-->

# Reset and clear topology for dedicated logic

The portable core's engine cleanup reset is driven by registered `engine_reset_reg`, not a combinational FSM decode. The pair multiplier uses registered `multiplier_clear_reg`. The demo SHA source uses a registered reset request. These preserve cleanup sequencing while avoiding asynchronous pulses caused by state-decode transitions.

External reset assertion is asynchronous; core/demo release is synchronized. Engine reset reaches the RSA controller, services, math and resource wrappers. Pair cleanup sweeps private storage before reuse. Vendor multiplier `aclr` is the inverse of its supplied reset; `sclr` remains constant zero. Arithmetic/RAM clock enables are constant one at integration; wrappers retain their clock-enable contracts.

Lifecycle and pair tests check reset/clearing behavior; [current validation](RTL_REVIEW_VALIDATION.md) records reruns. Imported fan/configuration sources are outside the portable-core reset audit and need separate board timing/CDC review. Historical routed diagnostics do not certify the new source snapshot. Preserve timed synchronizer interstage paths and review exceptions on every final fit.
