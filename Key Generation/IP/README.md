<!--
Filename: README.md
Authors: Project contributors; see Git history.
Date: 2026-10-13
General Description: Documents Portable keygen resources.
AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.
-->

# Portable keygen resources

This change adds two small reusable resources needed by the later RSA arithmetic engine. It does not implement RSA, AES key assembly, the keygen controller, or board firmware.

## Read this change

1. Read the contracts below and the selector modules `keygen_mult32.v` and `keygen_ram32.v`.
2. Compare each `_generic.v` implementation with its `_altera.v` partner. The Altera versions instantiate `lpm_mult` and `altsyncram` directly; no IP Catalog project is checked in.
3. Read `tests/tb_keygen_resources.sv`: independent expected products and memory state are checked against both implementations, rather than using either implementation as the reference.
4. Use the scripts to reproduce simulation and device mapping. Neither script programs the board.

All contributed reusable RTL and the compile-only smoke top are Verilog-2001. Tests are SystemVerilog. Vendor simulation sources remain in the installed Quartus distribution and are not copied into this repository.

## Selection and cycle contracts

Define `KEYGEN_ALTERA` to select Altera macros. Without it the public wrappers select synthesizable generic Verilog. Both underlying implementations are public modules so the test can instantiate them side by side. All ports have named connections.

### Unsigned 32 by 32 multiplier

`keygen_mult32` takes `clock_i`, active-low `reset_n_i`, `clock_en_i`, `valid_i`, and 32-bit `left_i`/`right_i`. It produces `valid_o` and the full unsigned 64-bit `product_o`.

An input accepted at an enabled rising edge appears after the next enabled rising edge: two pipeline stages, including the sampling edge. Every enabled edge advances data and validity; disabled edges hold them. Bubble cycles have `valid_i=0`. Consumers only accept outputs on enabled edges with `valid_o=1`. Asynchronous reset clears validity and product registers. No multiplication truncation or saturation occurs.

### 32-bit synchronous RAM

`keygen_ram32 #(ADDRESS_WIDTH=8)` stores `2**ADDRESS_WIDTH` words. It accepts independent write and read addresses, 32-bit write data, and `write_en_i`/`read_en_i` under common `clock_en_i`. `read_valid_o` and data appear just after the enabled edge accepting a read. Disabled clock-enable holds the transaction state. Consumers use data only when read-valid is asserted. Data when read-valid is zero is unspecified and may differ between implementations.

A simultaneous read and write to the same address returns the **new write data**. The Altera wrapper explicitly forwards that word, so the external contract does not depend on the macro's collision output. Reset clears read validity and forwarding state, blocks writes, and leaves memory contents unchanged. Initial contents are unspecified. Keygen's controller must initialize or overwrite each location before reading it and must sweep every occupied location with zero before reporting cleanup complete. This resource does not claim secure erasure by reset.

## Reproduce

From the repository root, use a writable scratch directory outside the checkout:

```powershell
& './Key Generation/IP/scripts/simulate_resources.ps1' -BuildDirectory 'ABSOLUTE_SCRATCH_DIRECTORY'
& './Key Generation/IP/scripts/fit_resources.ps1' -BuildDirectory 'ANOTHER_ABSOLUTE_SCRATCH_DIRECTORY'
# Optional inference comparison; keep its output separate.
& './Key Generation/IP/scripts/fit_resources.ps1' -Generic -BuildDirectory 'THIRD_ABSOLUTE_SCRATCH_DIRECTORY'
```

Default tools are installed Questa Intel Starter 2024.3 from `C:/intelFPGA_lite/24.1std/questa_fse/win64`, real Intel Quartus 24.1 `220model.v` and `altera_mf.v`, and Quartus Pro 26.1 for device mapping. Override runner parameters for other installations. Simulation fails unless the process succeeds and an explicit `PASS resources:` line appears.

The older vendor functional RAM model prints `RAM block type is assumed as AUTO` for the Agilex 5 family. This is disclosed rather than suppressed. Differential simulation therefore proves the vendor megafunction functional contract, not an Agilex 5 physical RAM timing model. The separate Quartus 26.1 compile checks whether the exact requested device maps these macros to its DSP and M20K resources. No generic substitute is used as the vendor model.

The smoke project targets A5ED013BB32AE4SCS at 50 MHz with virtual top-level pins. It is a resource-mapping check, not the physical board top, external I/O timing signoff, or a claim that the full core fits. The Reset Release warning is expected for this non-programmed smoke top; the board integration owns configuration reset and complete timing constraints.

## Validation record

The differential test initializes all RAM addresses by writes, then checks deterministic random vectors, maximal/zero products, bubbles, clock-enable stalls, simultaneous RAM writes/reads and collisions, repeated resets with retained memory, and explicit zeroization by an external sweep. Exact results and fitted resource counts belong in the MR description and retained build evidence.

Validated October 13, 2026: Questa differential simulation PASS with 2,637 checked products, 2,750 checked RAM reads, 596 simultaneous-address collisions and 1,300 disabled-enable cycles. RTL/test compilation and final simulation report zero errors/warnings; the disclosed RAM model informational warning still prints separately. Quartus 26.1 mapping fit succeeds on A5ED013BB32AE4SCS: 152 ALMs, 8,192 RAM bits in one M20K, and two DSP units as counted in the top fitter summary. Smoke constrained setup/hold slack is +19.625/+0.103 ns; this does not cover real board I/O or complete keygen timing.
