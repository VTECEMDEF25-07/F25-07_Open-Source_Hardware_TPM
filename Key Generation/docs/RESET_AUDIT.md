<!--
Filename: RESET_AUDIT.md
Authors: Project contributors; see Git history.
Date: 2026-10-13
General Description: Documents Reset/clear/clock-enable audit.
AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.
-->

# Reset/clear/clock-enable audit

Scope: every contributed Verilog module under Key Generation/rtl, IP and demo, excluding imported vendor fan/configuration source and third_party PicoRV32. Exact source inventory/hashes are in class-workspace AI/tmp/keygen-reset-constraint-audit/contributed_rtl_inventory.json. PicoRV32 reset sensitivity was additionally inspected: its CPU reset is synchronous, sampled on posedge clk.

## Asynchronous reset decode findings

1. Public core engine_reset_n decoded binary RESET_ENGINE. Replaced by a registered engine_reset_reg in b499300. The completed diagnostic softcore fit had actually recoded this FSM one-hot: routed recovery paths originate state_reg.RESET_ENGINE Q, worst observed +15.673ns. This is a generic/ASIC portability correction, not evidence that that particular fitted FPGA image glitched.
2. Softcore child_reset_n decoded binary CLEAR. Replaced by registered child_clear_reg in 17994b3. The old fit recoded this FSM one-hot; observed routed recovery paths originate state_reg.CLEAR Q, worst +18.222ns.
3. Pair multiplier_reset_n decoded CLEAR/CLEAR_READ/CLEAR_WAIT. The old fit does not list this task-driven FSM among recoded state machines, so it retains binary state registers. The patch replaces the decode with multiplier_clear_reg: set on external reset and finishâ†’CLEAR, held through sweep/read/wait, released exactly on CLEAR_WAITâ†’IDLE/RESULT. Complete generic pair regression passes with identical cycle counts for all 8 fixtures and an every-cycle equivalence assertion. The source/test change is integrated as 825fa08. The patch and log are retained under AI/tmp/keygen-reset-constraint-audit and AI/tmp/keygen-pair-registered-reset-generic; genuine-model pair verification is recorded separately when complete.
4. Demo SHA source_reset_n decodes SCRUB/IDLE; CORE_START 3â†’RUN 4 can transiently decode a reset state. Corrected by the registered-source-reset change in demo commit 2803f5a, with actual SPI transport tests for both controller selections and a lifetime reset assertion. That board change also passed the isolated routed reset/constraint diagnostic with zero RES50001/50002/50003/50004 violations.

No other contributed state decode drives an asynchronous reset or generated clock. CPU execute_en derives from RUN and contributes to cpu_reset_n, but both the control implementation and imported PicoRV32 sample it synchronously; it is not an asynchronous-reset glitch path. Conditional clears of storage/control registers occur inside clocked blocks and remain timed synchronous data/control paths.

## Remaining reset and enable topology

- Core/AES running combines external reset with the second release flip-flop. External assertion is asynchronous; release is synchronized.
- Engine resets flow unchanged to math RAM/multiplier and RSA services/controller. Pair multiplier has its own registered cleanup reset. Wrapper lpm_mult aclr is the inverse of the supplied reset, with constant sclr=0.
- All instantiated arithmetic/RAM clock enables are constant 1. Portable wrappers use if(clock_en_i) in clocked blocks; vendor clocken/clken ports are proper clock enables. No contributed expression is used as an event clock or inserted as a fabric clock gate.
- Board reset/configuration sources feed explicit release chains. Original SPI chain combined board_release_reg[1] with raw SPI reset. Its port false-path exception is applied completely, but Quartus calls the mixed-source chain unconstrained. An additional scoped portâ†’chain false path did not change classification. The board-releaseâ†’SPI-reset recovery path remains timed and has +16.423ns slack. The board correction simplifies the two chains to share the raw board/config reset assertion while retaining independent SPI-only reset.

## Saved-fit diagnostics

`core_fsm_reset_paths.rpt`, `cpu_fsm_reset_paths.rpt`, `baseline_cdc.rpt`, `scoped_cdc.rpt`, `baseline_spi_exceptions.rpt`, and `board_to_spi_recovery.rpt` were generated from the completed diagnostic softcore fit using temporary in-memory STA constraints. No source or saved SDC was edited. Scripts preserve revision order and never export assignments or rebuild the database.

Intel's documented RES-50003 recommendation permits the existing source-port false path; therefore adding broader false paths or waiving the mixed-source finding without inspection is not justified. Source: https://www.intel.com/programmable/technical-pdfs/683539.pdf . Explicit synchronizer identification uses the value "FORCED IF ASYNCHRONOUS" with spaces; it supports MTBF analysis and does not justify cutting interstage timing. Source: https://www.intel.com/programmable/technical-pdfs/683296.pdf .
