<!--
Filename: AI_DISCLOSURE.md
Authors: Aaron Grossman; Project contributors; see Git history.
Date: 2026-11-08
General Description: Records contributor attribution and the course AI Use Statement.
AI Disclosure: Codex assisted with consolidation; see docs/AI_DISCLOSURE.md in the keygen source folder.
-->

# AI disclosure and AI Use Statement

**Contributor:** Aaron Grossman

| Required field | Record |
|---|---|
| Tool | OpenAI Codex. Existing file headers identify Codex and GPT-6 Astra assistance; the current documentation/parameter refactor used GPT-6. Earlier exact tool versions are not independently established by this statement. |
| Purpose | HDL implementation/revision, debugging, reference/test and runner development, technical documentation, repository organization, author attribution and documentation consolidation. |
| Extent | Material AI assistance covers project-authored keygen RTL/resource wrappers under `Source Code/Key Generation/`, its docs and supporting READMEs, and reference code, fixtures, benches and runners under `Testing/Simulation/Key Generation/`. The keygen vendor work adds board-local default defines, propagates one board-top `IP_TYPE` through TPM_TOP to an inactive keygen placeholder, adds explicit family/rejection guards, and updates board source lists and `Testing/Simulation/Key Generation/Vendor/` regressions. Upstream contributor credit is retained; RNG changes are excluded from this PR. Unchanged vendor sources are excluded. |
| Method | Iterative user-directed drafting and revision, inspection of repository sources and course materials, comparison with independent arithmetic/reference checks, and execution of documented automated checks. Representative prompts are recorded below; these are examples, not a complete transcript of earlier development. |
| Verification | Historical results are distinguished from current checks. The keygen vendor suite tests both backend lifecycles, propagation to all keygen wrappers, both board RAM families, resource comparisons and invalid selections. Quartus elaborates both board projects and maps active Cyclone V RAM. Reference/AES/services checks and strict Verilog-2001 complete RSA with stalls have passed in their recorded scopes. The audit fixed a SystemVerilog-only failure task in source rejection guards. These checks do not establish fitted board timing, active full-core capacity, production entropy quality or TPM command integration. RNG source and tests match main and are outside this PR. Aaron remains responsible for reviewing and understanding the submitted work. |

## Representative planning prompt, October 13, 2026

The following is the actual implementation request used in the “Review crypto core design” conversation. It records the requested scope at that time, including both RSA controllers and hardware acceptance goals; it is not a claim that every requested gate was completed or is included in this PR.

> PLEASE IMPLEMENT THIS PLAN:
> # Complete the portable key-generation core
>
> ## Delivery target
>
> Deliver **AES-128, AES-256 and complete RSA-2048 generation**, with two separately selectable RSA implementations:
>
> - Dedicated Verilog control.
> - Soft-core firmware controlling shared hardware arithmetic.
>
> Each implementation gets **generic and Altera resource builds**. All four combinations must simulate, fit the DE25 and pass hardware validation. Xilinx-specific implementation is deferred, as agreed.
>
> The performance target is **median RSA generation within 30 seconds** over a fixed 20-seed test set. Record every runtime and use a 180-second host test deadline; a timeout is a failed test requiring investigation.
>
> Completion covers our keygen subsystem and its documented external interfaces. Production randomness, hierarchy seed management, object wrapping and complete TPM commands remain external responsibilities. The demonstration uses clearly identified test generation streams and test keys.
>
> ## Architecture and contracts
>
> **Portable core**
>
> - Verilog-2001 synthesizable source; SystemVerilog tests allowed.
> - One 50 MHz core clock. Board pins, SPI and clock-domain handling remain outside the core.
> - Build-time selection of RSA controller and resource backend.
> - One operation at a time; accepted request parameters cannot change during execution.
> - AES produces a key; RSA produces `n`, `e`, `p` and `q` through the protected interface. Calculate and validate `d` internally, then clear it. CRT preparation remains deferred.
>
> **Interfaces to freeze in the first implementation MR**
>
> - Request: ready/valid, fixed algorithm profile and 32-bit operation identifier.
> - Generation input: ordered 32-bit ready/valid words plus failure indication. The external coordinator establishes an isolated generation context before admission.
> - Result: 32-bit ready/valid words carrying component, index and final-word information. External words and bytes are most significant first.
> - Separate whole-result accept/reject handshake after transfer; individual word acceptance does not transfer ownership of the complete key.
> - Terminal status: operation identifier and success/error, held until acknowledged.
> - Reset: active-low, synchronized release; invalidate transfers immediately and block admission until local scrubbing and external peer readiness complete.
> - Fault categories: invalid request, generation failure, search exhausted, arithmetic/key-check failure, receiver rejection, CPU trap and internal watchdog expiry. Reset takes priority; otherwise preserve the first recorded fault through cleanup.
>
> Success follows **validation → complete-result acceptance → local secret clearing → held success status**. Faults discard unaccepted staged results and clear local state. Reset cannot revoke a result already accepted by the receiver.
>
> External source/receiver stalls remain legal. The host bounds demonstration waits and resets stalled operations; internal watchdogs detect failed arithmetic or firmware progress.
>
> **Shared arithmetic**
>
> Use an iterative 32-bit limb datapath and on-chip scratch memory:
>
> - Compare, add, subtract, shift, copy and clear.
> - Pipelined multiplication.
> - Montgomery multiplication and exponentiation.
> - Division, GCD, LCM and modular inverse, including the even-modulus inverse needed for the private exponent.
>
> Start with 16 KiB accelerator scratch, 32 KiB firmware ROM and 16 KiB CPU data RAM. Enforce allocation bounds. Arithmetic uses little-endian limbs internally, with conversion at the interface.
>
> Both controllers use the same candidate-generation procedure, witness draws and retry ordering. Identical accepted streams must produce identical keys despite different stalls or execution times.
>
> Use the selected FIPS 186-5 method, with the five-round Miller–Rabin profile for 1024-bit candidates and no optional Lucas test. Before implementation, produce a reviewed algorithm sheet covering every bound, counter, rejection path and applicable published correction. [NIST publication and updates](https://csrc.nist.gov/pubs/fips/186-5/final).
>
> **Soft core**
>
> Use a pinned, audited PicoRV32 RV32I configuration with its native memory interface, no caches or interrupts, and shared arithmetic acceleration. Firmware sequences operations; secret big integers remain in accelerator memory. Its upstream is archived, so preserve the exact source, license and local verification evidence. [PicoRV32 upstream](https://github.com/YosysHQ/picorv32).
>
> Explicitly verify clearing of CPU registers, internal operand state, stack/data RAM and accelerator memory. CPU reset alone is insufficient.
>
> ## IP, parallel work and review chunks
>
> **Altera IP policy**
>
> Hand-instantiate supported megafunctions from Verilog wrappers wherever possible—beginning with `lpm_mult` and the supported Agilex 5 RAM macro. Avoid IP Catalog generation unless a required resource cannot be implemented through a supported macro; document that exception.
>
> Every resource has a synthesizable generic implementation with the same defined latency, enables, valid signals and reset behavior. RAM contracts use synchronous reads and defined collision handling; clearing sweeps memory rather than asynchronously resetting the entire array.
>
> An early gate must prove:
>
> 1. Macro elaboration and actual DSP/M20K mapping.
> 2. Genuine Altera simulation-model availability.
> 3. Cycle-level equivalence against the generic implementation.
>
> The installed vendor simulation environment is **not yet proven**. Missing models must be resolved before dependent resource work is accepted. Generic substitutions cannot count as Altera simulation.
>
> Project source remains Verilog. If reusable synthesizable source requires SV, pause that section for your specific approval; SV test/model compilation does not authorize SV project RTL.
>
> **Agent execution**
>
> Use the lead plus three parallel workers, with exclusive file ownership and isolated branches. The lead owns shared contracts, integration, MR publication and all board programming. Workers may not independently change contracts or program the shared board.
>
> | Wave | Worker A | Worker B | Worker C | Lead |
> |---|---|---|---|---|
> | Foundations | Generic/Altera resources and arithmetic | Independent reference checker and tests | Soft-core/toolchain feasibility | Contracts, AES and integration |
> | RSA | Dedicated RTL controller | Independent RSA verification | Soft-core firmware/control | Shared accelerator and defect integration |
> | Completion | Fit/timing and resource optimization | Full regression and independent review | SPI runner, firmware and documentation | Board tests and release evidence |
>
> Verification starts alongside implementation. Reassign workers as dependencies clear; do not leave an agent waiting on a shared file it could avoid.
>
> **Progressive MRs**
>
> | Chunk | Reviewable deliverable |
> |---|---|
> | 1 | Exact interfaces, lifecycle, algorithm sheet and acceptance matrix |
> | 2 | Resource wrappers, genuine vendor-model simulation and generic equivalence |
> | 3 | Clean AES worker and complete handoff/reset behavior |
> | 4 | Scratch memory, clearing and basic arithmetic |
> | 5 | Multiplication and Montgomery arithmetic |
> | 6 | Exponentiation, primality testing and candidate generation |
> | 7 | Division, GCD/inverse and complete key-pair checks |
> | 8 | Complete dedicated RTL RSA |
> | Parallel A | Soft-core boot, accelerator access and cleanup feasibility |
> | Parallel B | Complete soft-core RSA firmware |
> | Parallel C | DE25 wrapper, fan integration and bounded SPI tester |
> | Final | Integrated regression, timing closure and measured comparison |
>
> Build from architecture MR #1 and selectively reuse AES logic from #3. Do not inherit the closed plumbing/store stack.
>
> Each MR includes a plain-language explanation, behavior example, dependency list, file-reading order, review checklist, reproducible tests and remaining limitations. Maintain module documentation with the code. Dependent development may continue on clearly labeled integration branches while you review; **nothing merges automatically**.
>
> ## Verification and board acceptance
>
> **Simulation**
>
> - Compile project RTL separately in Verilog mode.
> - Run identical resource vectors against generic and actual Altera models, including stalls, reset, boundaries and RAM collisions.
> - Check arithmetic against independent arbitrary-precision software: exhaustive small-width cases plus directed and randomized full-width operands.
> - Exercise AES ordering, repeated words, source gaps, result backpressure, ownership acknowledgment and status acknowledgment.
> - Test RSA constraints, composites, pseudoprimes, witness rejection, retry limits and deliberately injected faults.
> - Reset during generation, arithmetic, result transfer, cleanup and terminal status; require a clean subsequent operation.
> - Verify secret clearing and no stale result across all storage backends and both controllers.
> - Run complete RSA fixtures on all four combinations; compare key results and stream consumption, not controller cycle counts.
> - Independently check primes, modulus, exponent compatibility, separation, private-exponent relationships and RSA operation round trips.
>
> Every requirement receives a linked test and evidence entry. Runners must fail on missing output, assertion failure, timeout or incomplete execution.
>
> **Fit and timing**
>
> The actual target has 46,800 ALMs and 358 M20Ks. Run full place-and-route early after the shared datapath and soft-core feasibility builds, then for all four final configurations.
>
> - Require 50 MHz timing closure, reviewed clock/reset crossings and no unexplained unconstrained paths.
> - Target at most 70% of each principal resource class to retain integration headroom.
> - Report actual logic, memory, DSP usage, firmware size and timing.
> - If performance or fit misses, optimize the shared arithmetic first; do not reduce key size, skip checks or silently drop a backend.
>
> **Hardware**
>
> Integrate the verified SPI wiring and retain independent fan control, temperature telemetry and hardware full-speed override. SPI reset must not reset cooling control.
>
> For each final configuration:
>
> 1. Verify programming success and read build/backend identity.
> 2. Recheck SPI at 100 kHz, 500 kHz and 1 MHz.
> 3. Run both AES profiles with independently checked results.
> 4. Generate and independently validate RSA keys from 20 fixed seeds.
> 5. Repeat a seed with different source stalls and verify identical output.
> 6. Inject reset during active phases and prove successful recovery.
> 7. Run a 30-minute mixed-operation soak while logging temperature, fan status and errors.
>
> Only test builds expose test keys to the host. Production-facing builds exclude the test-key export path.
>
> ## Completion package
>
> Deliver four reproducible builds and their tested bitstreams, pinned dependencies, host tester, firmware, simulation commands, independent reports and a requirement-by-requirement completion matrix.
>
> The final comparison shows correctness, latency, resource use and remaining team-integration headroom for both RSA designs. Recommend the default from measured results; keep both implementations available.
>
> “Complete” means these gates actually pass. A working SPI link, successful compilation or a single RSA key is an intermediate milestone.
