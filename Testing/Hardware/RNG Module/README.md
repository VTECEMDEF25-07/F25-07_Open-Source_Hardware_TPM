# RNG hardware testing (DE25)

Author: Aaron Grossman (organization notes; original source authorship preserved).

These physical-board capture assets come from PR #38. Target: Terasic DE25-Standard RevD (Agilex 5). The HDL behavior and pin assignments are unchanged; target comments and capture-tool usage text reflect the current layout. They are separate from the existing `../../../Project/DE25/de25_soc_top.qpf` TPM project.

- `entropy_test_top.v`: a standalone FPGA top connecting the noise source, capture RAM and UART.
- `DE25_entropy_test_pins.tcl`: supplied standalone capture pin assignments.
- `capture_90b.py`: PC-side serial capture program; requires Python and pyserial.

The HDL dependencies are in `../../../Source Code/RNG Module/`: `entropy_source.v`, `ring_osc.v`, `entropy_capture.v` and `uart.v`. The capture top is not instantiated by the TPM board top. No new Quartus capture project is created here.

The pin assignments are retained as supplied, not applied by either maintained TPM project. It names a different clock pin (`D8`) from the maintained RevD TPM project (`CH128`) and leaves multiword I/O-standard values unquoted. Those standalone assignments need separate board/pin review before use; the successful TPM-project builds do not validate this capture pin script.

The workflow is:

1. Build and program the standalone `entropy_test_top` design separately in Quartus.
2. Connect its UART adapter to the PC.
3. Run the collector with the adapter's **serial port**, not a design-file path:

```text
python "Testing/Hardware/RNG Module/capture_90b.py" COM5
```

Run from the repository root and replace `COM5` with the actual serial port (`/dev/ttyUSB0`, for example, on Linux). The collector does not load HDL files or program the FPGA. It writes `raw_seq.bin` and `raw_restart.bin` into the directory where you run it. The tool documentation in the file describes its sample/restart formats. The corresponding simulation bench is under `Testing/Simulation/RNG Module/`.

Vendor selection: `entropy_test_top.IP_TYPE` defaults to Altera and propagates
to every oscillator. Its commented `FPGA_IP_TYPE` define supplies the default;
no vendor header is required. Do not set legacy RO_* macros. Generic is only
available for functional RNG simulation; synthesis rejects it and unsupported
backends instead of building a generic logic-loop fallback.
