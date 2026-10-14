# Filename: demo_terminal.py
# Authors: Project contributors; see Git history.
# Date: 2026-10-14
# General Description: Show live, verified test keys from the DE25 in a terminal.
# AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

"""Live DE25 key-generation demonstration. Displays TEST keys only."""
import argparse
import json
from pathlib import Path
import statistics
import sys
import time

import host_test


class DemoAdapter(host_test.SpiAdapter):
    def __init__(self, frequency):
        super().__init__(frequency)
        self.words = {}
        self.result_index = None
        self.started = None
        self.last_progress = 0

    def register(self, address, data=None):
        value = super().register(address, data)
        if address == 2 and data == 1:
            self.words = {}
            self.started = time.monotonic()
            self.last_progress = self.started
        elif address == 3 and data is None and self.started is not None:
            now = time.monotonic()
            if value & 2 and now - self.last_progress >= 5:
                print(f"  generating... {now - self.started:.0f} s elapsed", flush=True)
                self.last_progress = now
        elif address == 8 and data is not None:
            self.result_index = data
        elif address == 9 and data is None and self.result_index is not None:
            self.words[self.result_index] = value
        return value


def key_hex(words):
    return "".join(f"{word:08x}" for word in words)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--seed", type=int, choices=range(1, 21), default=1)
    parser.add_argument("--rsa-count", type=int, choices=(1, 5, 10), default=5,
                        help="number of distinct test seeds for RSA (default: 5)")
    parser.add_argument("--frequency", type=int, choices=(100000, 500000, 1000000), default=1000000)
    args = parser.parse_args()

    reference = Path(__file__).resolve().parents[2] / "reference"
    sys.path.insert(0, str(reference))
    seeds = json.loads((reference / "seeds.json").read_text())["seeds"]
    fixture = seeds[args.seed - 1]
    rsa_fixtures = [seeds[(args.seed - 1 + offset) % len(seeds)]
                    for offset in range(args.rsa_count)]
    manifest = json.loads(args.manifest.read_text())

    print("DE25 KEY GENERATION - LIVE HARDWARE DEMO", flush=True)
    print("Deterministic TEST seed and TEST keys; not production randomness.\n", flush=True)
    with DemoAdapter(args.frequency) as adapter:
        identity = host_test.identify(adapter, manifest)
        host_test.transport_test(adapter)
        print(f"Board: {identity['control']} controller / {identity['backend']} resources")
        print(f"Build fingerprint: {identity['build_fingerprint']}")
        print(f"SPI: {args.frequency:,} Hz, transport PASS; seed {fixture['id']}\n", flush=True)

        for profile, label, count in ((0, "AES-128", 4), (1, "AES-256", 8)):
            print(f"[{label}] generating on FPGA...", flush=True)
            result = host_test.run_key(adapter, profile, fixture, fixture["id"])
            words = [adapter.words[index] for index in range(count)]
            print(f"  verified test key: {key_hex(words)}")
            print(f"  PASS - {result['core_cycles']} core cycles")
            sample = result["fan_samples"][-1]
            print(f"  Cooling: {sample['fpga_c']} C FPGA, {sample['fan_rpm']} RPM, alarm {sample['alarm']}\n", flush=True)

        rsa_results = []
        for number, rsa_fixture in enumerate(rsa_fixtures, 1):
            print(f"[RSA-2048 {number}/{args.rsa_count}] test seed {rsa_fixture['id']}: generating on FPGA...", flush=True)
            result = host_test.run_key(adapter, 2, rsa_fixture, rsa_fixture["id"])
            words = [adapter.words[index] for index in range(129)]
            modulus = key_hex(words[:64])
            print(f"  verified public n: {modulus[:24]}...{modulus[-24:]} (2048 bits)")
            print(f"  public e: {words[64]}; private p/q: independently verified")
            print(f"  PASS - {result['core_seconds']:.2f} core seconds")
            sample = result["fan_samples"][-1]
            print(f"  Cooling: {sample['fpga_c']} C FPGA, {sample['fan_rpm']} RPM, alarm {sample['alarm']}\n", flush=True)
            rsa_results.append(result)

    core_times = [result["core_seconds"] for result in rsa_results]
    host_times = [result["host_operation_seconds"] for result in rsa_results]
    print(f"RSA-2048: {len(rsa_results)} distinct seeds, all keys verified")
    print(f"  Core time: average {statistics.mean(core_times):.2f} s; median {statistics.median(core_times):.2f} s")
    print(f"  Terminal time: average {statistics.mean(host_times):.2f} s; median {statistics.median(host_times):.2f} s")
    print("AES-128, AES-256, AND ALL RSA KEYS VERIFIED ON THE LIVE BOARD", flush=True)


if __name__ == "__main__":
    main()
