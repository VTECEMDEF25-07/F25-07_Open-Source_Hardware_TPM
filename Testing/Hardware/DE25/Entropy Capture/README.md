# DE25 hardware entropy capture

Author: Aaron Grossman (organization notes; original source authorship preserved).

These are physical-board capture assets from PR #38, preserved unchanged. They are separate from the existing `../../../../Project/DE25/de25_soc_top.qpf` TPM project.

- `entropy_test_top.v`: a standalone FPGA top connecting the noise source, capture RAM and UART.
- `DE25_entropy_test_pins.tcl`: supplied standalone capture pin assignments.
- `capture_90b.py`: PC-side serial capture program; requires Python and pyserial.

The HDL dependencies are in `../../../../Source Code/RNG Module/`: `entropy_source.v`, `ring_osc.v`, `entropy_capture.v` and `uart.v`. The capture top is not instantiated by the TPM board top. No new Quartus capture project is created here.

The pin script is retained exactly as supplied, not applied by either maintained TPM project. It names a different clock pin (`D8`) from the maintained RevD TPM project (`CH128`) and leaves multiword I/O-standard values unquoted. Those standalone assignments need separate board/pin review before use; the successful TPM-project builds do not validate this capture pin script.

To run the PC tool after configuring and programming a separately reviewed capture design:

```text
python "Testing/Hardware/DE25/Entropy Capture/capture_90b.py" COM5
```

Run from the repository root and choose the actual serial port. The tool documentation in the file describes its sample/restart formats. The corresponding simulation bench is under `Testing/Simulation/RNG Module/`.
