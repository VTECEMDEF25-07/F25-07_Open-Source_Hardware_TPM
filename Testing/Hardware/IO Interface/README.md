# Legacy FTDI tester and testbench generator

`testbench.c` and `TpmTypes.h` are preserved from the original IO testing tools. The C program needs the Windows/FTDI SDK headers, libraries, DLL and driver described in its source; these external dependencies are not bundled here.

The program can transact with connected hardware and can generate a Verilog testbench. Its supplied hardware clock is 24 MHz. It prints errors but does not reliably report them through the process exit status. Generated Verilog retains the old top-module assumptions, so it needs adaptation for the current board tops.

The existing generated HDL bench is in `Testing/Simulation/IO Interface/tb_test.v`. This relocation does not repair or certify the legacy tester.
