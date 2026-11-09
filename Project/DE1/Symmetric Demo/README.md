# Standalone symmetric visual demo

`symmetric_demo_top.v` is the existing DE1-SoC switch, button, LED and seven-segment wrapper, relocated from the old symmetric source folder without changing its RTL.

Reusable logic is in `Source Code/Symmetric Module/`; simulations are in `Testing/Simulation/Symmetric Module/`. The symmetric-top simulation runner compiles this wrapper as a connection check.

This wrapper is not selected by the main DE1 TPM project's QSF. No separate demo pin assignments, timing constraints or validated bitstream are supplied by this reorganization. The demo rejects session jobs because it has no HMAC service.
