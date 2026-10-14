/*
 * Filename: rsa_start.S
 * Authors: Project contributors; see Git history.
 * Date: 2026-10-13
 * General Description: Establishes the RV32I firmware entry point and startup state.
 * AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.
 */

.section .text.start,"ax",@progbits
.global _start
_start:
    lui sp, 0x10004
    la a0, __data_load
    la a1, __data_start
    la a2, __data_end
1:  bgeu a1, a2, 2f
    lw t0, 0(a0)
    sw t0, 0(a1)
    addi a0, a0, 4
    addi a1, a1, 4
    j 1b
2:  la a1, __bss_start
    la a2, __bss_end
3:  bgeu a1, a2, 4f
    sw zero, 0(a1)
    addi a1, a1, 4
    j 3b
4:  call main
5:  j 5b
