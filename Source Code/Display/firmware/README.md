# DE25 LCD first-stage OCRAM candidate

**Cold initialization is implemented and host-tested. ARM/SDM execution and physical LCD output are unverified.** This replaces the earlier always-guarded compile-gate source with a real handoff-driven initialization path. The old guarded artifact remains separate in class-root `AI/tmp/overnight-lcd/baremetal/build/`; it must not be mistaken for this candidate in `build-cold/`.

From repository root:

```powershell
python 'Source Code/Display/firmware/build_ocram.py' --runtime-root '<absolute class-root>/AI/tmp/overnight-lcd/baremetal'
```

For lead rebuilds, add `--output-dir '<separate lead-owned evidence directory>'`.
The option was verified with a separate build producing the identical reviewed
HEX/binary; it preserves the original owner's `build-cold/` ELF and manifest.

The runtime root contains the officially downloaded/checksum-verified Arm GNU13.2.Rel1 x86_64 Linux `aarch64-none-elf` toolchain. It runs through WSL Ubuntu24.04; native WSL gcc runs host tests. No global install, target load or FPGA build. The builder records complete commands, compiler/source/output hashes, ELF load segments, sizes and test logs under `build-cold/`. It compares all176 parser/render cases against the prior tested Python renderer. The146 valid fresh/stale frames cover73 snapshots, plus30 malformed-record rejections.

Initialization follows this order:

1. Before stack/BSS/literal-memory/MMIO access, require first-stage EL3, SCTLR_EL3.EE=0 and M/C/I clear. Unsupported entry parks at named `entry_rejected_el/endian/control` symbols with x19=90/91/92; BSS/`lcd_diag` is not initialized on that path and must not be trusted. This is a read-and-reject guard, not an endian/MMU/cache repair or proof of the real SDM entry state. Park other core affinities; mask interrupts, install current-EL vectors, clear BSS and set16KiB OCRAM stack. Fatal exceptions capture ESR/ELR/FAR in `lcd_exception` and an error in `lcd_diag`. No DDR references. ELF load-segment assertions keep everything below reserved handoff0x7f000..0x7ffff.
2. Copy the actual big-endian SDM handoff to bounded local memory. Validate BOOT/PMUX/IOCT/FPGA/DLAY/CLKS/PERI/SDRM magics, DDRoff, peripheral power255 and all required generated clock fields. Validate every pinmux offset against exact sparse SVD whitelists, reject duplicates and require the generated selectors/delays/dedicated routes. No writes occur on invalid handoff. Fixed structure bounds, rather than untrusted length fields, control reads. IO electrical words are fitted SDM data; do not invent them from pre-fit XML or mask away their high bits.
3. Enable only MPU access bits for needed L4 endpoints, preserving unrelated access controls. Replay validated pinmux and disable peripheral FPGA-routing enables. Program HPS PLLs/dividers from the actual validated handoff, using source-sync analog setup and bounded FSM/membus/stable-lock waits. Any failure stops with a diagnostic; no fabricated success. SDM software boot-clock control bits8/9 are preserved. CPU/DSU counters are initialized; unused Ethernet/USB/user/debounce counters remain untouched. No FPGA PLL is programmed.
4. Explicitly enable core0/L4_MAIN/L4_SP and UART1/SPIM0 clock gates. Release only SPIM0, UART1 and GPIO1 resets; no bridge/DDR/fan reset. Start the official Agilex5 global counter at the generated400MHz NOC rate and confirm ticks advance. Resolve the live clock chain and require400MHz L3/100MHz UART before peripheral output.
5. Configure UART1 for115200 requested,8N1/FIFOs/polling: integer divisor54 yields about115741baud (+0.47%). Configure SPIM0 CS0, mode0, both DFS fields for8 bits, TX-only, divisor800 from400MHz for500kHz requested. GPIO1 bits10/11/18 bind LCD reset/D_C/backlight. ST7567 reset62.5ms low/high, displayoff, C8/2F/40,20ms power wait, clear all8Ã—132 DDRAM before displayon. Output frames use8Ã—128 bytes. SPI bursts are at most16bytes with UART pumping between them; waits also have iteration caps if the counter stops.

Input remains newline-delimited JSON containing exactly unsigned32-bit `status_word`, `operation_id`, `sequence`. No heap, commands, keys, crypto implementation, network or filesystem. Oversized/NUL/UART-error records are discarded through newline; invalid schema never updates freshness. Complete records update a coherent frame snapshot. Repeated actual snapshots renew the2s freshness timeout, then STATUS STALE overrides retained DONE. DONE detail2/4 means actual AES/RSA completion; no progress is inferred from host timing. Acknowledgement is `FRAME_SENT <source sequence>`, which is a write-side event, never glass acceptance.

Host evidence:225 cold-init checks validate all register offsets/duplicate/magic/clock failures cause zero peripheral writes; injected PLL/FSM/membus/unstable-lock failures stop before peripheral release; successful trace preserves unrelated reset and boot-clock bits and grants only MPU access.1071 transport checks use an independent8Ã—132 DDRAM model to verify full clear before AF,8Ã—128 frame bytes, UART divisor/errors, GPIO preservation, RX pumping and bounded SPI/timer failure. These tests model software behavior; they do not prove MMIO timing, SDM execution or LCD electrical behavior.

The fixed SDM binary layout is pinned to official Trusted Firmware-A commit `cf1b7fe657a3215423ab397363cc4fa1a0e6399f` Agilex5 handoff structure. Register/clock metadata is from the actually generated Pro26.1 DE25 island. PLL helper subset is adapted from Altera baremetal-drivers commit `66bdcc347564c5698a8997169bce83a31647d618`, MIT-0 (license included). Baked kit PLL settings, global firewall opening and broad reset writes were excluded. Membus error/timeout propagation was strengthened. The new island's generated handoff must be reviewed again after the lead's combined fit; IO-control words and actual SDM launch contract cannot be proven by this offline build.

Lead-only next gates: combine the accepted island with the passing crypto source; full fit/timing/RO/SPI/cooling review; inspect actual SDM handoff/boot contract; package a volatile SOF with this candidate HEX; observe UART1 diagnostic/banner; fixed glass frame; actual status relay/sticky completion and stale behavior. No board load, debug attach, SD/QSPI write or boot-switch change was performed here.

## One-time post-banner UART diagnostic

The separate diagnostic build adds `LCD_DIAG` checkpoints until the first
`FRAME_SENT`, then quiets them. UART diagnostic output polls only UART LSR with
an iteration cap; it does not depend on a functioning generic-counter deadline.
It reports actual main stage/error, raw64-bit CNTPCT samples and a detail word.
`COUNTER_PROBE` brackets a fixed UART marker; detail is CNTFRQ (software metadata,
not a measured counter rate), followed by read-only CNTCR at0x10d01000. Error22
means no counter change across that UART-only probe;23 is diagnostic TX budget.
Board initialization already required at least one counter increment before the
banner, so silence after the banner does not prove a counter disabled throughout
startup. Continuous operation/rate is still a target observation.

Reset low/high have before/after checkpoints. Each delay prints begin/end and
raw ticks/poll count; no change over4096 polling iterations produces
`DELAY_NO_TICKS` and returns failure instead of waiting the full10million-poll
budget. Each SPI call prints begin/end; FIFO/busy waits/failures include raw SR.
For `SPI_BEGIN`, detail is bytecount|(D_C<<16). `MAIN_INIT_FAIL`/`MAIN_FRAME_FAIL`
print the latched error20/21 before parking. An OK checkpoint only describes
software execution; it is never SPI readback, target timing or optical proof.

No PLL, clock-gate, counter-enable/frequency or reset-init recipe changed in this
diagnostic. GPIO reset sequence and SPI contents remain the same; UART logging
adds delay and therefore this image is for root-cause capture, not performance
measurement. Build it into a fresh `--output-dir`, preserving earlier artifacts.
# Post-page diagnostic candidates (2026-11-10)

`build_ocram.py --strict-align` applies `-mstrict-align` to every target C unit,
in addition to the existing `-mgeneral-regs-only`. The separate exception-only
build deliberately retains the prior compiler alignment behavior for diagnosis.
The original UART diagnostic contained `sturh w21,[sp,#49]` at 0x2310 after
the completed 20ms delay and before the first page SPI call. This is consistent
with an alignment fault with MMU off; it is not confirmed until target evidence.
The exception-only candidate moves that instruction to 0x2498; the strict build
uses byte stores at 0x24a0/0x24a4/0x24a8 for the three page-command bytes.

Both new candidates add PRE_PAGE and raw SCTLR readback, plus a one-attempt
stage>=2 exception UART report of ESR/ELR/FAR/SCTLR/SP. Fatal TX has bounded
UART polls and no timer, RX pump, or parser dependency. A nested reporting fault
parks; a stalled MMIO transaction itself cannot be bounded in software. Reporter
assumes the current SP remains valid, as expected for the suspected odd data
store; it is not a general recovery mechanism. No SCTLR/MMU/clock writes added.

