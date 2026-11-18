# SPI follow-ups

- [ ] Complete physical high-speed acceptance on DE25 and physical testing on
  DE1. Reviewed DE25 image `80597de` passes all eight C suites at 1/15 MHz SPI,
  but configured 30 MHz times out during command execution. Its SOF hash and
  timing results are in the DE25 validation document.
- [ ] Verify a true 24 MHz hardware clock. The existing FTDI/libMPSSE setup
  configures 30 MHz from a 24 MHz request. Earlier PR-image tests failed at
  that setting; unmodified main later passed it, while the reviewed merge
  fails again. Investigate waveforms and the execution timeout.
- [ ] Resolve full-TPM minimum-frame timing before reducing the current
  ≥100 ns CS setup/hold/high contract. A historical 5/5/50 ns replay failed
  13 original assertions even though the isolated serializer passed.

See the [SPI contract](Source%20Code/IO%20Interface/SPI.md) and
[DE1](Project/DE1/VALIDATION.md) / [DE25](Project/DE25/VALIDATION.md) validation.
