# Filename: softcore_boot.S
# Authors: Project contributors; see Git history.
# Date: 2026-10-13
# General Description: Provides the deterministic RV32I feasibility and memory-interface boot self-test.
# AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

# RV32I feasibility program. Opcode 0 is a TEST-ONLY accelerator self-test.
# No stack, interrupts, secret loads, runtime library, or RSA procedure yet.
lui x1, 0x40000
addi x2, x0, 32
sw x2, 8(x1)
addi x2, x0, 64
sw x2, 12(x1)
addi x2, x0, 96
sw x2, 16(x1)
addi x2, x0, 32
sw x2, 20(x1)
sw x0, 0(x1)
poll:
lw x3, 4(x1)
andi x4, x3, 2
beq x4, x0, poll
andi x4, x3, -256
bne x4, x0, failed
addi x4, x0, 1
sw x4, 24(x1)
lui x4, 0x600d0
addi x4, x4, 1
sw x4, 28(x1)
halt:
beq x0, x0, halt
failed:
addi x4, x0, -1
sw x4, 28(x1)
beq x0, x0, halt
