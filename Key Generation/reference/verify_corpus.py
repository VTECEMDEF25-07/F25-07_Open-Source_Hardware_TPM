"""Regenerate and independently check the frozen twenty-key public test corpus."""
import json
from pathlib import Path

from keygen_reference import Sha256Words, generate_key, PROCEDURE
from key_checker import check_key


def main():
    folder = Path(__file__).parent
    seeds = json.loads((folder / "seeds.json").read_text())["seeds"]
    corpus = json.loads((folder / "expected_keys.json").read_text())
    if corpus["procedure"] != PROCEDURE:
        raise ValueError("corpus procedure version mismatch")
    expected = corpus["results"]
    if len(seeds) != 20 or len(expected) != 20:
        raise ValueError("corpus must contain exactly twenty records")
    for seed, result in zip(seeds, expected):
        if seed["id"] != result["seed_id"]:
            raise ValueError("seed ID mismatch")
        source = Sha256Words(bytes.fromhex(seed["seed_hex"]))
        actual = generate_key(source.word)
        if actual != {name: int(value, 16) for name, value in result["key"].items()}:
            raise ValueError(f"seed {seed['id']}: key mismatch")
        if source.words != result["words_consumed"]:
            raise ValueError(f"seed {seed['id']}: stream consumption mismatch")
        check_key(actual)
        print(f"PASS RSA-2048 seed={seed['id']} words={source.words} checker_rounds=64", flush=True)
    print("PASS CORPUS count=20")


if __name__ == "__main__":
    main()
