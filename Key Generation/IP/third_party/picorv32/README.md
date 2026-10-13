# Pinned PicoRV32 source

Upstream: https://github.com/YosysHQ/picorv32

Pinned commit: `ef203c2b0a3fb793280f5114941416c425c5b461`.
License: ISC; upstream copyright and COPYING are preserved.

This is a locally modified upstream Verilog source. Project wrappers follow project naming; upstream identifiers remain intact to make patch review possible. The selected RV32I configuration disables compressed instructions, counters, multiply/divide, PCPI, interrupts and trace. Compile without FORMAL/RISCV_FORMAL/testbug defines. Upstream's optional formal interfaces are not part of this source configuration.

## Runtime cleanup patch

Upstream REGS_INIT_ZERO is an initial block, not runtime clearing. The local patch adds synchronous reset clearing to the built-in 32-entry register array, reg_op1/reg_op2/reg_out/reg_sh, ALU result registers, debug operand captures, trace data, native bus address/write data/strobes, and the read-data latch. Each signal is cleared in its existing owning clocked process, avoiding extra drivers. STACKADDR is disabled; firmware must explicitly establish a stack when required.

This is a configuration-specific data-state audit, not a claim that every CPU bookkeeping/debug register reads zero. Disabled extensions and formal/debug configurations require re-audit before enabling. Instruction/PC/decode state contains public firmware/address metadata. Accelerator operands and generation words have no CPU-readable address window; the CPU sees only descriptor addresses, counters and public completion codes. The wrapper's RAM scrub and descriptor reset complete the feasibility reset boundary. Final RSA integration must inventory new firmware state and prove cleanup on every terminal path, not only reset.

Regression checks architectural registers, main operand/result registers and all 4096 RAM words after reset, including reboot and abort of a pending descriptor. It does not constitute an upstream CPU ISA regression or formal proof.
