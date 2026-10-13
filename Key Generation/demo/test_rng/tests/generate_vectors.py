"""Generate predictable SHA-256 fixtures with Python's independent hashlib implementation."""
import argparse
import hashlib
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    seeds = json.loads((Path(__file__).resolve().parents[3] / "reference/seeds.json").read_text())["seeds"]
    if len(seeds) != 20:
        raise ValueError("expected twenty frozen seeds")
    domain = b"KEYGEN-TEST-v1\x00"
    if len(domain) != 15:
        raise ValueError("domain length")
    words = []
    for item in seeds:
        seed = bytes.fromhex(item["seed_hex"])
        for counter in range(4):
            digest = hashlib.sha256(domain + seed + counter.to_bytes(8, "big")).digest()
            words.extend(digest[i:i+4].hex() for i in range(0, 32, 4))
    for counter in (0xFFFFFFFF, 0x100000000, 0xFFFFFFFFFFFFFFFF):
        digest = hashlib.sha256(domain + bytes.fromhex(seeds[0]["seed_hex"]) + counter.to_bytes(8, "big")).digest()
        words.extend(digest[i:i+4].hex() for i in range(0, 32, 4))
    wide_seeds = [bytes(range(32)), bytes([255]) * 32]
    for seed in wide_seeds:
        digest = hashlib.sha256(domain + seed + bytes(8)).digest()
        words.extend(digest[i:i+4].hex() for i in range(0, 32, 4))
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / "source_words.mem").write_text("\n".join(words) + "\n")
    (args.output / "source_seeds.mem").write_text("\n".join([x["seed_hex"] for x in seeds] + [s.hex() for s in wide_seeds]) + "\n")
    print(f"PASS source vectors seeds=20 words={len(words)} domain_bytes=15 message_bytes=55")


if __name__ == "__main__":
    main()
