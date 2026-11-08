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
