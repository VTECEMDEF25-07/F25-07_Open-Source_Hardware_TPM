# Professor demonstration: independent cryptographic comparisons

Author: Codex, for Makeda Solomon  
Date: October 14, 2026

This demonstration does **not** implement a hardware HMAC. It compiles the
existing production RTL into an isolated Questa library, replacing only the
fake HMAC implementation with a simulation-only Python HMAC service.
The original source files and Quartus source list are not changed.

## What happens

```text
Session inputs -> existing KDFa message builder
                       |
                       v
Actual HMAC key/message written by simulation
                       |
                       v
Python standard-library HMAC-SHA256 (software reference, not FPGA hardware)
                       |
                       v
Existing KDFa collects digest -> key + IV -> existing AES-CFB
                       |
                       v
Questa output compared with independently prepared Python/OpenSSL result
```

The HMAC service hashes the actual bytes emitted by the RTL, rather than
returning a preselected fake digest. The testbench separately checks the key,
counter, label, nonce order and requested bit length. The software reference
is checked against RFC 4231 test case 1 before any simulation.

## Tests

- Eight EncryptDecrypt2-path checks: four published NIST CFB128/AES-256
  segments, encrypt and decrypt. Caller explicitly supplies chaining IVs;
  this does not demonstrate an internal multi-block controller.
- Four session CFB checks: two nonce-order fixtures, encrypt and decrypt.
  Each fixture is chosen test data, not an official TCG known-answer vector.
- Four session XOR checks: protect/recover 16-byte and five-byte inputs.
- Each case checks final data/feedback/status, HMAC/AES call counts,
  KDFa request contents, the AES key/IV, and a completion deadline.

## Run from PowerShell at the repository root

Requires the installed Questa license, Python stdlib, and OpenSSL on PATH.
No Python packages need to be installed.

```powershell
python "Testing/Simulation/Symmetric Module/professor_demo/run_demo.py"
```

Use `--output-dir "<scratch directory>"` to choose another output location.

The command creates a fresh run directory under
`build/symmetric-module/professor-demo`, executes Questa, and generates
`report.html`, `results.json`, `vectors.json`, source hashes, a transcript,
and `vsim.wlf`. A failed or incomplete simulation must not be presented as
a passing result.

## Run inside your existing Questa window

If another simulation occupies the single-session license, do not launch a
second simulator. Use the current window:

1. Prepare the test in PowerShell:

   ```powershell
   python "Testing/Simulation/Symmetric Module/professor_demo/run_demo.py" --prepare
   ```

2. The command prints a new run directory. In Questa Transcript enter
   `quit -sim`, then `do {<printed run directory>/run.do}` using forward slashes.
3. All 16 cases run, grouped waveforms open, and the report is generated.
4. Open `report.html` from that run directory in a browser. It can also be
   printed to PDF from the browser. Keep the directory together when sharing
   so raw-evidence links continue to work.

To regenerate a report after a run:

```powershell
python "Testing/Simulation/Symmetric Module/professor_demo/run_demo.py" --report "<run directory>"
```

## Sources

- NIST SP 800-38A F.3.17/F.3.18, printed pages 51-52:
  https://nvlpubs.nist.gov/nistpubs/legacy/sp/nistspecialpublication800-38a.pdf#page=58
- TCG Part 1 r1.83, session CFB clause 21 and XOR clause 11.4.7.3:
  https://trustedcomputinggroup.org/wp-content/uploads/TPM-2.0-1.83-Part-1-Architecture.pdf#page=179
- RFC 4231, HMAC-SHA256 test case 1:
  https://www.rfc-editor.org/rfc/rfc4231.html#section-4.2
- Python HMAC: https://docs.python.org/3/library/hmac.html
- OpenSSL AES reference: https://docs.openssl.org/3.0/man1/openssl-enc/

## What can be claimed

After a passing run: the tested RTL AES-CFB path matches NIST examples, and
the tested session KDFa/CFB/XOR paths work with a real software HMAC substitute.
Do not claim hardware HMAC completion, full TPM command authorization,
host integration, general variable-length support, FPGA timing validation,
or TPM conformance certification.
