"""Independent arithmetic vectors for pair-check RTL; output contains public test material."""
import argparse
import json
import math
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    keys = json.loads(Path(__file__).with_name("expected_keys.json").read_text())["results"]
    lower = math.isqrt(1 << 2047) + 1
    good = [{k: int(v, 16) for k, v in entry["key"].items()} for entry in keys[:3]]
    cases = [(key["p"], key["q"], 0) for key in good]
    p, q = good[0]["p"], good[0]["q"]
    # lambda=60*g and lambda=-1 mod65537 implies k=1 and a genuinely small d.
    g = (lower + 9) // 10
    g += (-pow(60, -1, 65537) - g) % 65537
    cases.append((10 * g + 1, 12 * g + 1, 2))
    bad_p = lower + ((1 - lower) % 65537)
    if bad_p % 2 == 0:
        bad_p += 65537
    cases += [(bad_p, q, 1), (p & ~1, q, 1), (p, p, 1), (3, q, 1)]
    lines = []
    for p, q, expected_status in cases:
        n = p * q
        lam = math.lcm(p - 1, q - 1)
        d = pow(65537, -1, lam) if math.gcd(lam, 65537) == 1 else 0
        if expected_status == 0:
            if not ((1 << 1024) < d < lam and n.bit_length() == 2048):
                raise ValueError("invalid successful fixture")
        if expected_status == 2:
            if not (p >= lower and q >= lower and abs(p-q) > 1 << 924 and 0 < d <= 1 << 1024):
                raise ValueError("invalid low-d fixture")
        # Layout: p1024, q1024, expected public n2048, internal d2048, status4.
        value = p
        for width, field in ((1024, q), (2048, n if expected_status == 0 else 0), (2048, d), (4, expected_status)):
            value = (value << width) | field
        lines.append(f"{value:01537x}")
    args.output.write_text("\n".join(lines) + "\n")
    print(f"PASS pair vectors count={len(lines)}")


if __name__ == "__main__":
    main()
