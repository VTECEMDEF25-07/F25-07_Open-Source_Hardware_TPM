# Future work

Open follow-ups for the project. Check items off only after recording the
result and supporting evidence in the relevant module or board documentation.

- [ ] **Validate SPI at a true 24 MHz on hardware.** Simulation and routed
  timing pass, but physical acceptance is pending. DE25 passes the existing
  tester at 1, 10 and 15 MHz. The FTDI library turns a 24 MHz request into
  30 MHz, which fails. Obtain a suitable clock source and rerun the original
  TPM assertions, recording the actual clock, image hash and results.
  A Pico H with USB-to-SPI bridge firmware is a candidate within the team's
  approximately $50 tester budget; it has not been purchased or validated.

- [ ] **Run the board regressions on a physical DE1.** Current DE1 results
  cover simulation, compilation and routed timing. Verify the pin mapping,
  reset, interrupt and SPI transactions on hardware, including the required
  24 MHz operating point, and update `Project/DE1/VALIDATION.md`.

- [ ] **Investigate the FTDI 30 MHz failure.** Capture SCK, MOSI, MISO and CS
  waveforms to distinguish adapter sampling, wiring and FPGA timing effects.
  Late MISO capture is a hypothesis, not an established cause. Keep this
  result separate from acceptance at the required 24 MHz rate.

- [ ] **Investigate minimum SPI frame timing in the complete TPM.** The
  isolated serializer passes 5 ns CS setup, 5 ns hold and 50 ns deselected
  intervals, but a full-TPM replay at those intervals fails 13 existing
  assertions. Diagnose the failures and add a reproducible regression before
  reducing the current 100 ns CS setup/hold/high contract.

See [the common SPI guide](Source%20Code/IO%20Interface/SPI.md) and the
[DE1](Project/DE1/VALIDATION.md) / [DE25](Project/DE25/VALIDATION.md) validation
records for current evidence and limitations.
