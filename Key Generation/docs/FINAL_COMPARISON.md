<!--
Filename: FINAL_COMPARISON.md
Authors: Project contributors; see Git history.
Date: 2026-10-13
General Description: Records historical dedicated-logic resource measurements.
AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.
-->

# Dedicated-logic resource comparison

These are **historical October 13 measurements**, recorded before the CPU split. They do not certify the newly changed source or a new bitstream.

| Configuration | Historical occupied ALMs | M20Ks | Current acceptance |
|---|---:|---:|---|
| Dedicated / generic | Not established | Not established | RAM inference/fit follow-up and physical acceptance pending |
| Dedicated / Altera | 26,661 / 46,800 (56.97%) | 12 / 358 | New source-matched fit and physical acceptance pending |

The historical dedicated/Altera image needed 23,116 ALMs, occupied 26,661 and used 6 physical DSP blocks out of 188. Minimum routed slack was +2.442 ns setup, +0.002 ns hold, +14.320 ns recovery and +0.012 ns removal, with zero total negative slack. Small positive margins require careful review on any rebuild. Occupied ALMs, rather than logic-needed ALMs, describe physical headroom.

Historical class-workspace evidence: `AI/tmp/kga4/rtl_altera/` and `AI/tmp/keygen-hardware-v4/rtl_altera/`. Build fingerprint: `8e8762d85f844755c3bdca8e5174e97bc3bbf602f0abee0c9e47bbb89111b310`. SOF SHA-256: `ac56d6e160784bdd0fbf88d58c161a49142162db144b7db3e14f2172b1db5375`.

The prior report recorded dedicated hardware testing as in progress; this document does not promote that to a pass. The 20-seed median/maximum, transport, recovery and cooling results must be established for selected final images. See [completion matrix](COMPLETION_MATRIX.md).
