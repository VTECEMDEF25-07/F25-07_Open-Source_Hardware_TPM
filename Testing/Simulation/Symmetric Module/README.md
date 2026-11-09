# Symmetric module simulations

RTL is under `Source Code/Symmetric Module/`; the standalone DE1 visual wrapper is under `Project/DE1/Symmetric Demo/`.

From the repository root, run any suite with Questa on PATH:

```powershell
vsim -c -do 'do {Testing/Simulation/Symmetric Module/run_cfb_block.do}'
vsim -c -do 'do {Testing/Simulation/Symmetric Module/run_session_parameter_controller.do}'
vsim -c -do 'do {Testing/Simulation/Symmetric Module/run_kdfa_control.do}'
```

The scripts locate the repository from their macro filenames, including paths with spaces. In an existing Questa GUI, use `do {<absolute path to a run script>}`. Synthesizable sources compile in Verilog-2001 mode; testbenches compile separately in SystemVerilog mode.

| Suite | Cases | Scope |
|---|---:|---|
| CFB worker | 7 | Real AES/CFB |
| Session parameter controller | 15 | Fake HMAC and mock CFB |
| KDFa controller | 6 | Fake HMAC |

Each run checks its completion flag and expected case count. Generated libraries, transcripts and waveforms default to `build/symmetric-module/`, which is ignored by Git. Set `TPM_TEST_RUN_ROOT` to choose a scratch directory; `TPM_PROJECT_ROOT` optionally overrides the source checkout.

See [waveform guidance](WAVEFORM_GUIDE.md) and the [software-HMAC demonstration](professor_demo/README.md). The demonstration has 16 independent-reference comparisons and uses a software HMAC service in its isolated simulation library. These simulations do not establish hardware HMAC correctness or full TPM integration.

## RAM-backed multi-block suite

Requires Python `cryptography` and Questa on PATH; `--questa <directory>` can
select its installation. All generated files go to the scratch directory.

```powershell
python 'Testing/Simulation/Symmetric Module/check_symmetric_ram.py' --output '<scratch-directory>'
quartus_sh -t 'Testing/Simulation/Symmetric Module/synthesize_symmetric_ram.tcl' '<scratch-directory>' 1024 12
```

The suite checks independent AES-CFB results across six capacities, bounds/overlap,
partial IVs, stalls, errors, reset, reuse, and switching between primitive and session jobs. Quartus runs analysis/synthesis with
virtual pins, not board fitting or timing checks. See the [RAM contract](../../../Source%20Code/Symmetric%20Module/RAM_INTERFACE.md).
