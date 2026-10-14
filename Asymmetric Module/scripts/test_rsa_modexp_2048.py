#!/usr/bin/env python3
"""Run one 2048-bit rsa_modexp simulation against Python's pow() oracle."""

from __future__ import annotations

import random
import subprocess
import sys
import tempfile
from pathlib import Path


WIDTH = 2048
SEED = 0x5253412048


def make_vector() -> tuple[int, int, int, int]:
    rng = random.Random(SEED)
    modulus = rng.getrandbits(WIDTH) | (1 << (WIDTH - 1)) | 1
    base = rng.randrange(modulus)
    exponent = rng.getrandbits(WIDTH) | (1 << (WIDTH - 1))
    expected = pow(base, exponent, modulus)
    return base, exponent, modulus, expected


def write_vector(path: Path, vector: tuple[int, int, int, int]) -> None:
    digits = (WIDTH + 3) // 4
    with path.open("w", encoding="ascii", newline="\n") as vector_file:
        vector_file.write(" ".join(f"{value:0{digits}x}" for value in vector))
        vector_file.write("\n")


def main() -> int:
    module_dir = Path(__file__).resolve().parents[1]
    rtl_sources = [
        module_dir / "montgomery_mult.v",
        module_dir / "rsa_modexp.v",
        module_dir / "Testbenches" / "tb_rsa_modexp_vectors.v",
    ]
    vector = make_vector()

    with tempfile.TemporaryDirectory(prefix="rsa_modexp_2048_") as temp_name:
        temp_dir = Path(temp_name)
        build_dir = temp_dir / "obj_dir"
        write_vector(temp_dir / "vectors.txt", vector)

        compile_command = [
            "verilator",
            "--binary",
            "--timing",
            "--top-module",
            "tb_rsa_modexp_vectors",
            "--Mdir",
            str(build_dir),
            *(str(path) for path in rtl_sources),
        ]
        print("Compiling the 2048-bit RSA modular-exponentiation testbench...")
        subprocess.run(compile_command, check=True)

        executable = build_dir / "Vtb_rsa_modexp_vectors"
        simulation = subprocess.run(
            [str(executable)],
            cwd=temp_dir,
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        print(simulation.stdout, end="")

        expected_summary = "ALL 2048-BIT RSA MODEXP TESTS PASSED"
        if simulation.returncode != 0 or expected_summary not in simulation.stdout:
            print("2048-bit RSA modular-exponentiation simulation did not pass.", file=sys.stderr)
            return simulation.returncode or 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
