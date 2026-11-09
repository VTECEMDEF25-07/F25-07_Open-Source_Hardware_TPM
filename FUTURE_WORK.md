# SPI follow-ups

- [ ] Physically test the merged image on DE25 and DE1, recording the SOF hash,
  pin selection, configured clock and original assertion results. Prior main
  or PR-image hardware results do not validate this merge.
- [ ] Verify a true 24 MHz hardware clock. The existing FTDI/libMPSSE setup
  configures 30 MHz from a 24 MHz request. Earlier PR-image tests failed at
  that setting; unmodified main later passed it. Rerun the merged image and
  investigate waveforms if results differ.
- [ ] Resolve full-TPM minimum-frame timing before reducing the current
  ≥100 ns CS setup/hold/high contract. A historical 5/5/50 ns replay failed
  13 original assertions even though the isolated serializer passed.

See the [SPI contract](Source%20Code/IO%20Interface/SPI.md) and
[DE1](Project/DE1/VALIDATION.md) / [DE25](Project/DE25/VALIDATION.md) validation.
