# Customer v2 packet leaf

`customer_demo_packet.v` implements the frozen wire-v2 packet layer only. Crypto, protected key storage, supervisor, SPI, and CRB wiring remain external services.

- `response_length_o` excludes the 10-byte TPM header; it includes the 28-byte metadata and body.
- Response reads have one clock of latency. Stage `response_addr_i` before consuming `response_byte_o`.
- Command reads expect one clock of latency; addresses include the 10-byte TPM header.
- AES status is accepted only with `aes_scrub_done_i`; the actual customer AES worker asserts this in its held STATUS state after clearing RAM and the key.
- Public component is one bit: 0 = modulus, 1 = exponent. Modulus words are read most significant first.
- Snapshot inputs must be an already coherent actual status snapshot. Opcode 5 latches all three inputs together.
- Export is disabled by default. Enable `DEMO_AES_EXPORT_ENABLE` explicitly for the authorized demo image.

Run `python "Testing/Simulation/Execution Engine/run_customer_packet.py"` using native Questa. The runner bounds each process to 60 seconds and requires a success marker as well as no simulator errors/fatals.

The enabled service-model test passes 1,918 checks, including AES lengths 0/1/17/1024, partial-result failure and retry, public 65-word reads, RSA frame lengths 0/15/240, malformed magic/length/final-tail rejection, cleanup gates, reset, and full payload/key/read-latch clearing. AES and RSA early rejection before the first input-ready must return their real nonzero status after cleanup without waiting for the packet deadline; a subsequent valid operation must work. Separate configurations cover export-disabled, shortened-deadline lockout, unexpected early success, and early terminal wrong operation ID. Production Verilog-2001 and the SystemVerilog bench compile with zero errors and zero warnings.

These are packet/control simulations with modeled crypto services. They do not establish AES/RSA arithmetic correctness, Quartus fit/timing, physical hardware behavior, Phase I acceptance on a new image, or LCD glass behavior. No FPGA or driver is opened by this runner.

## Real AES stream integration

`tb_customer_packet_real_aes.sv` connects the packet to the actual customer AES worker, AES/CFB RTL, and byte RAM. Only generation/store are TEST fixtures (provider mode 1). `run_customer_packet_real_aes.py --crypto-repo PATH` prepares six independent Python cryptography AES256-CFB vectors and runs native Questa; `--compile-only` avoids simulation. The crypto checkout must contain the customer worker and symmetric RTL.

The same bench passed existing WSL Verilator simulation: 1,270 checks, six actual worker jobs, lengths 0/1/17/31/32/1024. It verifies exact plaintext and updated IV through the packet response, framing/provider/operation ID, terminal success after worker cleanup, sticky DONE, and local key/payload/read-latch clearing. All input sources were hashed before/after the run. This additional test establishes that the real AES/CFB/RAM stream connects correctly to the packet; it does not validate physical hardware or actual fresh generation/storage. Native Questa compilation passed; this seam simulation result was obtained with Verilator.

## Real RSA2048 private stream integration

`tb_customer_packet_real_rsa.sv` connects the packet to the actual private worker and compact 64-limb math engine. It reuses the existing worker bench's TEST-only protected-store/lease harness, including stalled replies, reset-driven math scrub, and close acknowledgment. Generation is modeled in TEST mode. `run_customer_packet_real_rsa.py --service-repo PATH` runs under existing WSL/Linux Verilator and g++; it installs nothing and opens no FPGA/driver.

One known RSA2048 fixture passes 311 packet checks, checks all 256 actual raw private-result bytes, validates the public n/e response and exact UTF-8 message extraction, waits for one completed private close/scrub, and clears the packet payload. The independent reference uses public modular exponentiation of the known frame. This does not establish fresh generation, actual protected-store implementation, physical hardware, or timing closure. Source/fixture hashes remained unchanged during the simulation. The log's final `cycles=1027` is the packet consume/scrub wait counter, **not private arithmetic latency**; use the separately validated module counters for metrics.
