# Customer v2 packet leaf

`customer_demo_packet.v` implements the frozen wire-v2 packet layer only. Crypto, protected key storage, supervisor, SPI, and CRB wiring remain external services.

- `response_length_o` excludes the 10-byte TPM header; it includes the 28-byte metadata and body.
- Response reads have one clock of latency. Stage `response_addr_i` before consuming `response_byte_o`.
- Command reads expect one clock of latency; addresses include the 10-byte TPM header.
- AES status is accepted only with `aes_scrub_done_i`; the actual customer AES worker asserts this in its held STATUS state after clearing RAM and the key.
- Public component is one bit: 0 = modulus, 1 = exponent. Modulus words are read most significant first.
- Snapshot inputs must be an already coherent actual status snapshot. Opcode 5 latches all three inputs together.
- Export is disabled by default. Enable `DEMO_AES_EXPORT_ENABLE` explicitly for the authorized demo image.

Run `python Testing/Simulation/Execution\ Engine/run_customer_packet.py` using native Questa. The runner bounds each process to 60 seconds and requires a success marker as well as no simulator errors/fatals.

The enabled service-model test passed 1,884 checks, including AES lengths 0/1/17/1024, partial-result failure and retry, public 65-word reads, RSA frame lengths 0/15/240, malformed magic/length/final-tail rejection, cleanup gates, reset, and full payload/key/read-latch clearing. Separate configurations passed export-disabled and shortened-deadline lockout checks. Production Verilog-2001 and the SystemVerilog bench compiled with zero errors and zero warnings.

These are packet/control simulations with modeled crypto services. They do not establish AES/RSA arithmetic correctness, Quartus fit/timing, physical hardware behavior, Phase I acceptance on a new image, or LCD glass behavior. No FPGA or driver is opened by this runner.
