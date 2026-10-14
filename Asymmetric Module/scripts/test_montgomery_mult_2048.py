#!/usr/bin/env python3
"""Generate Python-oracle vectors and run the 2048-bit Verilator testbench."""

from __future__ import annotations

import random
import subprocess
import sys
import tempfile
from pathlib import Path


WIDTH = 2048
VECTOR_COUNT_RANDOM = 12
SEED = 0x2048_5A17


def make_vectors() -> list[tuple[int, int, int, int]]:
    rng = random.Random(SEED)
    max_value = (1 << WIDTH) - 1
    full_width_modulus = (1 << (WIDTH - 1)) | 0x1A2B3C5D
    full_width_modulus |= 1

    operands = [
        (0, full_width_modulus - 1, full_width_modulus),
        (full_width_modulus - 1, full_width_modulus - 1, full_width_modulus),
        (1, full_width_modulus - 1, full_width_modulus),
        (2, full_width_modulus - 2, full_width_modulus),
        (2, 2, 3),
        (max_value - 1, max_value - 1, max_value),
    ]

    for _ in range(VECTOR_COUNT_RANDOM):
        modulus = rng.getrandbits(WIDTH) | (1 << (WIDTH - 1)) | 1
        a_value = rng.randrange(modulus)
        b_value = rng.randrange(modulus)
        operands.append((a_value, b_value, modulus))

    radix_inverse_cache: dict[int, int] = {}
    vectors = []
    radix = 1 << WIDTH
    for a_value, b_value, modulus in operands:
        if modulus not in radix_inverse_cache:
            radix_inverse_cache[modulus] = pow(radix, -1, modulus)
        expected = (a_value * b_value * radix_inverse_cache[modulus]) % modulus
        vectors.append((a_value, b_value, modulus, expected))
    return vectors


def write_vectors(path: Path, vectors: list[tuple[int, int, int, int]]) -> None:
    digits = (WIDTH + 3) // 4
    with path.open("w", encoding="ascii", newline="\n") as vector_file:
        for row in vectors:
            vector_file.write(" ".join(f"{value:0{digits}x}" for value in row))
            vector_file.write("\n")


def main() -> int:
    module_dir = Path(__file__).resolve().parents[1]
    rtl = module_dir / "montgomery_mult.v"
    testbench = module_dir / "Testbenches" / "tb_montgomery_mult_vectors.v"
    vectors = make_vectors()

    with tempfile.TemporaryDirectory(prefix="montgomery2048_") as temp_name:
        temp_dir = Path(temp_name)
        build_dir = temp_dir / "obj_dir"
        write_vectors(temp_dir / "vectors.txt", vectors)

        compile_command = [
            "verilator",
            "--binary",
            "--timing",
            "--top-module",
            "tb_montgomery_mult_vectors",
            "--Mdir",
            str(build_dir),
            str(rtl),
            str(testbench),
        ]
        print("Compiling the 2048-bit Montgomery testbench with Verilator...")
        subprocess.run(compile_command, check=True)

        executable = build_dir / "Vtb_montgomery_mult_vectors"
        simulation = subprocess.run(
            [str(executable)],
            cwd=temp_dir,
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        print(simulation.stdout, end="")

        expected_summary = f"ALL 2048-BIT VECTORS PASSED ({len(vectors)} cases)"
        if simulation.returncode != 0 or expected_summary not in simulation.stdout:
            print("2048-bit Montgomery simulation did not pass.", file=sys.stderr)
            return simulation.returncode or 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
