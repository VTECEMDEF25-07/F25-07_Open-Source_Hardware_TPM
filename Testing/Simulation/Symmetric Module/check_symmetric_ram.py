"""Generate independent AES-CFB vectors and run the portable Questa RAM suite.
Requires Python cryptography and Questa on PATH (or --questa directory).
All generated vectors, libraries and logs go into the required --output folder.
"""
import argparse
import json
import os
from pathlib import Path
import random
import subprocess
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes


def vectors(path, capacity, address_width):
    rng = random.Random(4104806 + capacity)
    depth = 1 << address_width
    lengths = sorted(set(range(min(capacity, 33) + 1)) | {capacity - 1, capacity})
    count = 0
    with path.open('w') as out:
        for n in lengths:
            for decrypt in (0, 1):
                # Disjoint when possible, exactly in-place otherwise; include exact
                # address-space end and adjacent regions, in both directions.
                regions = {(0, 0), (depth - n if n else depth - 1,) * 2}
                if 2 * n <= depth:
                    regions.update({(0, depth - n if n else depth - 1),
                                    (depth - n if n else depth - 1, 0), (0, n)})
                for source, destination in sorted(regions):
                    key, iv, data = rng.randbytes(32), rng.randbytes(16), rng.randbytes(n)
                    cipher = Cipher(algorithms.AES(key), modes.CFB(iv))
                    operation = cipher.decryptor() if decrypt else cipher.encryptor()
                    result = operation.update(data) + operation.finalize()
                    # TPM reference CryptSym.c explicitly zero-pads the ciphertext
                    # feedback after its final partial CFB block, in BOTH directions.
                    ciphertext = data if decrypt else result
                    final_iv = iv if n == 0 else ciphertext[(n - 1) // 16 * 16:].ljust(16, b'\0')
                    out.write(f'{n} {decrypt} {source} {destination} {key.hex()} {iv.hex()} {final_iv.hex()}\n')
                    for a, b in zip(data, result):
                        out.write(f'{a:02x} {b:02x}\n')
                    count += 1
    return count


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--questa', type=Path)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env.pop('TPM_PROJECT_ROOT', None)
    env['TPM_TEST_RUN_ROOT'] = str(output / 'runs')
    executable = str(args.questa / 'vsim.exe') if args.questa else 'vsim'
    runner = Path(__file__).resolve().with_name('run_symmetric_ram.do')
    results = []
    for capacity, address_width in ((1, 5), (17, 7), (31, 8), (1024, 12), (2049, 14), (4096, 12)):
        vector_path = output / f'vectors_{capacity}_{address_width}.txt'
        count = vectors(vector_path, capacity, address_width)
        env.update(TPM_RAM_CAPACITY=str(capacity), TPM_RAM_ADDR_WIDTH=str(address_width),
                   TPM_RAM_VECTORS=str(vector_path))
        run = subprocess.run([executable, '-c', '-do', f'do {{{runner.as_posix()}}}'],
                             cwd=output, env=env, text=True, capture_output=True, timeout=240)
        log = run.stdout + run.stderr
        (output / f'ram_{capacity}_{address_width}.log').write_text(log)
        marker = f'SYMMETRIC_RAM_SUITE_PASS capacity={capacity} address_width={address_width} vectors={count}'
        if run.returncode or marker not in log:
            raise RuntimeError(log[-6000:])
        result = next(line for line in log.splitlines() if marker in line)
        print(result, flush=True)
        results.append(result)
    (output / 'results.json').write_text(json.dumps(results, indent=2))


if __name__ == '__main__':
    main()
