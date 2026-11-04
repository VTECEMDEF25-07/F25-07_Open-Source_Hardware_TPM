#!/usr/bin/env python3
"""
capture_90b.py
 
Collects raw noise-source data from the FPGA (entropy_test_top.v) and writes
the two input files for NIST's SP 800-90B entropy assessment tool
(github.com/usnistgov/SP800-90B_EntropyAssessment):
 
  raw_seq.bin      1,048,576 consecutive samples   -> ea_non_iid / ea_iid
  raw_restart.bin  1000 restarts x 1000 samples    -> ea_restart
 
Both files hold one sample per byte (0x00 or 0x01), which is what the tool
expects for 1-bit samples. The restart file is row by row: the first 1000
bytes are restart 1, the next 1000 are restart 2, and so on.
 
Setup:   pip install pyserial
Usage:   python capture_90b.py COM5            (Windows)
         python capture_90b.py /dev/ttyUSB0    (Linux)
Options: --baud 115200  must match BAUD in entropy_test_top.v
         --seq-only / --restart-only
 
Written by Jungyeon Won with the help of generative AI
"""
 
import argparse
import sys
import time
 
try:
    import serial
except ImportError:
    sys.exit("pyserial is missing. Install it with:  pip install pyserial")
 
# Must match the entropy_capture.v parameters.
SEQ_BYTES = 131072          # 1,048,576 samples
RESTARTS = 1000
RESTART_SAMPLES = 1000
RESTART_BYTES_TOTAL = RESTARTS * RESTART_SAMPLES // 8
 
# Unpack table: byte -> 8 one-sample bytes, earliest sample (MSB) first.
_UNPACK = [bytes((b >> (7 - k)) & 1 for k in range(8)) for b in range(256)]
 
 
def unpack(packed: bytes) -> bytes:
    return b"".join(_UNPACK[b] for b in packed)
 
 
def read_exact(port, n, baud):
    """Read n bytes, with a timeout sized to the transfer plus capture time."""
    deadline = time.time() + n * 10 / baud * 1.5 + 30
    buf = bytearray()
    last_report = 0.0
    while len(buf) < n:
        if time.time() > deadline:
            raise TimeoutError(f"got {len(buf)} of {n} bytes before timing out")
        chunk = port.read(n - len(buf))
        buf += chunk
        if time.time() - last_report > 1.0:
            print(f"\r  received {len(buf):,} / {n:,} bytes", end="", flush=True)
            last_report = time.time()
    print(f"\r  received {len(buf):,} / {n:,} bytes")
    return bytes(buf)
 
 
def quick_stats(samples: bytes, label: str):
    """Sanity checks only. These are NOT the 800-90B estimate."""
    n = len(samples)
    ones = samples.count(1)
    longest = run = 1
    for i in range(1, n):
        run = run + 1 if samples[i] == samples[i - 1] else 1
        longest = max(longest, run)
    print(f"  {label}: {n:,} samples, {100 * ones / n:.2f}% ones, "
          f"longest run of identical samples = {longest}")
    if ones == 0 or ones == n:
        print("  WARNING: every sample is the same. The rings are probably not "
              "oscillating (check the Technology Map Viewer) or the tap is wrong.")
 
 
def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("port", help="serial port, e.g. COM5 or /dev/ttyUSB0")
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--seq-only", action="store_true")
    ap.add_argument("--restart-only", action="store_true")
    args = ap.parse_args()
 
    with serial.Serial(args.port, args.baud, timeout=0.5) as port:
        port.reset_input_buffer()
 
        print("Checking the link (ping)...")
        port.write(b"P")
        reply = port.read(1)
        if reply != b"K":
            sys.exit(f"No reply from the FPGA (got {reply!r}). Check the port, "
                     "baud rate, TX/RX wiring (TX goes to RX), and that "
                     "entropy_test_top is the programmed design.")
        print("  OK")
 
        if not args.restart_only:
            print("Sequential capture (1,048,576 consecutive samples)...")
            port.write(b"S")
            seq = unpack(read_exact(port, SEQ_BYTES, args.baud))
            with open("raw_seq.bin", "wb") as f:
                f.write(seq)
            quick_stats(seq, "raw_seq.bin")
 
        if not args.seq_only:
            print("Restart capture (1000 restarts x 1000 samples)...")
            port.write(b"R")
            rst = unpack(read_exact(port, RESTART_BYTES_TOTAL, args.baud))
            with open("raw_restart.bin", "wb") as f:
                f.write(rst)
            quick_stats(rst, "raw_restart.bin")
            # Each restart's first sample should not always be the same.
            firsts = rst[::RESTART_SAMPLES]
            print(f"  first sample after restart was 1 in "
                  f"{firsts.count(1)} of {RESTARTS} restarts (want roughly half)")
 
    print("""
Next, run NIST's tool (check each program's usage text: flags have changed
between releases):
 
  ea_non_iid -v raw_seq.bin 1
      -> note the final min-entropy estimate, H (bits per sample)
 
  ea_restart -n -v raw_restart.bin 1 H
      -> -n = non-IID data; replace H with the number from ea_non_iid.
         It must pass.
""")
 
 
if __name__ == "__main__":
    main()