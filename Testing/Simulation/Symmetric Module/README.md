# Symmetric module simulations

RTL is under `Source Code/Symmetric Module/`; the standalone DE1 visual wrapper is under `Project/DE1/Symmetric Demo/`.

From the repository root, run any suite with Questa on PATH:

```powershell
vsim -c -do 'do {Testing/Simulation/Symmetric Module/run_cfb_block.do}'
vsim -c -do 'do {Testing/Simulation/Symmetric Module/run_encrypt_decrypt2_controller.do}'
vsim -c -do 'do {Testing/Simulation/Symmetric Module/run_session_parameter_controller.do}'
vsim -c -do 'do {Testing/Simulation/Symmetric Module/run_kdfa_control.do}'
vsim -c -do 'do {Testing/Simulation/Symmetric Module/run_symmetric_top.do}'
```

The scripts locate the repository from their macro filenames, including paths with spaces. In an existing Questa GUI, use `do {<absolute path to a run script>}`. Synthesizable sources compile in Verilog-2001 mode; testbenches compile separately in SystemVerilog mode.

| Suite | Cases | Scope |
|---|---:|---|
| CFB worker | 7 | Real AES/CFB |
| EncryptDecrypt2 controller | 9 | Mock CFB worker |
| Session parameter controller | 12 | Fake HMAC and mock CFB |
| KDFa controller | 6 | Fake HMAC |
| Symmetric top | 14 | Real AES and fake HMAC |

Each run checks its completion flag and expected case count. Generated libraries, transcripts and waveforms default to `build/symmetric-module/`, which is ignored by Git. Set `TPM_TEST_RUN_ROOT` to choose a scratch directory; `TPM_PROJECT_ROOT` optionally overrides the source checkout.

See [waveform guidance](WAVEFORM_GUIDE.md) and the [software-HMAC demonstration](professor_demo/README.md). The demonstration has 16 independent-reference comparisons and replaces the hardware HMAC placeholder only in its isolated simulation library. These simulations do not establish hardware HMAC correctness or full TPM integration.

## RAM-backed multi-block suite

Requires Python `cryptography` and Questa on PATH. Choose a scratch output
folder; all generated vectors, simulation libraries and logs go there:

```powershell
python 'Testing/Simulation/Symmetric Module/check_symmetric_ram.py' --output '<scratch-directory>'
# If needed, add: --questa 'C:/intelFPGA_lite/24.1std/questa_fse/win64'
```

This drives the real AES worker through `symmetric_ram_top` and a byte-addressed
simulation-only RAM. It compares independent encryption/decryption results and
TPM final IVs for capacities 1, 17, 31, 1024, 2049 and 4096, using address widths
5, 7, 8, 12, 14 and 12 respectively. Coverage includes every final partial-block
length, empty/exact/oversized requests, full address-space capacity, exact-end
addresses, disjoint/adjacent/in-place operation, both invalid overlap directions,
overflow, descriptor capture, held-start suppression, result retention,
request stalls, variable response latency, RAM/worker errors, acknowledged-byte
counts, reset in five execution phases and reuse after failures/resets. The
bench checks all RAM bytes, so unrelated bytes and unread input are preserved.
The RAM model retains storage while jointly flushing pending traffic on reset.

`run_symmetric_ram.do` is the underlying portable runner. Its capacity, address
width and vector file come from `TPM_RAM_CAPACITY`, `TPM_RAM_ADDR_WIDTH` and
`TPM_RAM_VECTORS`; the Python driver sets these and `TPM_TEST_RUN_ROOT`.
Questa sources compile as Verilog separately from the SystemVerilog testbench.
Run suites sequentially if the local license permits only one simulator session.

For standalone Quartus analysis/synthesis with virtual top-level pins:

```powershell
quartus_sh -t 'Testing/Simulation/Symmetric Module/synthesize_symmetric_ram.tcl' '<scratch-directory>' 1024 12
```

The optional last arguments select capacity and address width. This is a resource
and synthesizability check for Cyclone V 5CSEMA5F31C6; it does not fit a board,
constrain clocks, establish timing closure or produce a validated bitstream.
See [validation results](RAM_VALIDATION.md) and the
[RAM contract](../../../Source%20Code/Symmetric%20Module/RAM_INTERFACE.md).
