"""Simulation-only HMAC service. No hardware HMAC implementation.
Author: Codex, for Makeda Solomon | Date: October 14, 2026
Input file contains the actual Verilog key and message as two hex lines.
"""
import hashlib
import hmac
import sys
from pathlib import Path

request = Path(sys.argv[1]).read_text().splitlines()
key, message = (bytes.fromhex(line.strip()) for line in request[:2])
digest = hmac.new(key, message, hashlib.sha256).hexdigest()
Path(sys.argv[2]).write_text(digest + '\n')
