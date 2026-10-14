# Reviewable demo release

`scripts/package_release.py` collects an explicitly selected four-image release.
It never builds, programs, publishes, merges or changes hardware reports. A package
is a test/demo artifact: its deterministic source and exported private keys are
not a production entropy source or secure TPM implementation.

## Required evidence

Supply one build directory and hardware directory for each `rtl_generic`,
`rtl_altera`, `softcore_generic` and `softcore_altera` variant. Each needs:

- Compiled build manifest, immutable source snapshots/configuration/firmware,
  accepted timing review, audit-bound SOF and timing/resource reports.
- Passing AES128/256, full twenty-seed RSA corpus, five reset boundaries plus
  three-profile replay, baseline/stalled RSA replay, four generation-failure
  boundaries with clean status/results plus three-profile reuse, and at least thirty minutes
  of alternating AES128/AES256/RSA soak.
- Separate transport scratch/partial-frame reports at100kHz,500kHz and1MHz.
- The same loaded fingerprint and exact tester/reference hashes as the packaged
  files. Every completed operation must satisfy the host deadline and have
  healthy cooling samples. A host `PASS` with fan faults is rejected.

The packager reuses the independent corpus audit. It additionally checks reset
and replay coverage, completed stall schedule, monotonic soak duration, operation
timing, tester provenance, source/firmware fingerprints, routed timing numbers,
SOF/report hashes and cooling. Missing or failed evidence prevents output creation.

## Explicit selection

Create a selection JSON outside the source tree, under the class `AI/tmp` folder.
Use absolute paths. Repeat the following variant entry for all four variants:

```json
{
  "completion_matrix": "ABSOLUTE/PATH/COMPLETION_MATRIX.md",
  "variants": {
    "rtl_generic": {
      "build_dir": "ABSOLUTE/PATH/rtl_generic",
      "hardware_dir": "ABSOLUTE/PATH/hardware/rtl_generic",
      "reports": {
        "aes": "aes.json",
        "corpus": "corpus.json",
        "reset-replay": "reset-replay.json",
        "stall-replay": "stall-replay.json",
        "fault-replay": "fault-replay.json",
        "transport_100000": "transport-100k.json",
        "transport_500000": "transport-500k.json",
        "transport_1000000": "transport-1m.json",
        "soak": "soak.json"
      }
    }
  },
  "evidence": [
    {"path": "ABSOLUTE/PATH/simulation-results.json",
     "name": "simulation-results.json", "sha256": "EXACT_SHA256"}
  ]
}
```

From the Key Generation directory:

```text
python scripts/package_release.py --selection SELECTION.json --output NEW_RELEASE_DIRECTORY
python scripts/test_package_release.py
```

Existing release directories are never overwritten. The tool captures input
bytes, checks that they remain unchanged during preparation, and verifies every
written file. A filesystem failure may leave a partial directory; it must not be
distributed. Validate `SHA256SUMS` before moving or sharing a package.

## Package contents

Each variant contains the tested SOF, firmware ROM, source/config snapshots,
build/timing manifests, reviewed reports and selected hardware evidence. Shared
content retains the canonical `rtl/`, `IP/`, `Math/`, `testbench/`, `scripts/`,
`reference/` and `demo/` layout, including resource/arithmetic benches, fixtures
and test runners. It includes firmware sources and build script, docs,
and pinned PicoRV32 license/provenance. Explicit extra evidence is text only.
Firmware source files use the exact bytes certified by their pinned manifest;
Windows checkout CRLF expansion is reversed only when that reproduces the
recorded hash. Audited build configuration bytes, including SDC line endings,
remain unchanged.
Canonical compile inputs must match the selected image snapshots byte for byte;
packaging rejects a newer untested source tree. Per-image snapshots remain the
authority for their tested SOFs. All copied inputs are hashed and checked for
changes during packaging.
Proprietary `220model.v`/`altera_mf.v`, Quartus databases and tool installations
are excluded. Each file is limited to64MiB and the package to256MiB.

Run the firmware and simulation commands in `docs/BUILD_AND_TEST.md` from the
package root. For a quick offline source check:

```text
python -m unittest discover -s reference -p test_reference.py
python demo/de25_revd/tests/test_host.py
python demo/de25_revd/tests/test_fan_monitor.py
```

Tool installations remain external dependencies. Generated simulator outputs,
build databases, caches, recovery backups and toolchains are not copied. The
Git-specific repository-hygiene command requires the original Git checkout;
Git metadata is intentionally absent from a release archive.

`release_manifest.json` hashes every payload file; `SHA256SUMS` additionally
hashes the release manifest. The checksum index does not hash itself.

Build QSF files retain their audited original paths for provenance. To rebuild
after moving the package, use its verified relocation mode from the package root:

```text
python scripts/package_release.py --rebuild rtl_generic --package-root . --quartus PATH_TO_QUARTUS_SH --output NEW_BUILD_DIRECTORY
python demo/de25_revd/compile_build.py NEW_BUILD_DIRECTORY
```

The first command verifies packaged hashes, creates a separate prepared snapshot
with relative source paths and a new fingerprint, and records the selected tool
version. It preserves the packaged original evidence. The second compiles that
fresh snapshot. The preparation/compilation helpers are included; no Quartus
installation is bundled. A rebuilt image requires new timing and hardware
acceptance; it never inherits the old image's approval.

## Separate human completion matrix

`PACKAGED_MACHINE_GATES_PASSED` is not whole-spec completion. The supplied
`COMPLETION_MATRIX.md` must separately identify each requirement, evidence path,
source revision, reviewer, result and remaining limitations. Reviewers must cover:

- Generic and genuine unchanged-Altera model equivalence/full-key simulation,
  cleanup/lifecycle/watchdogs, arithmetic and negative cases.
- Routed timing/CDC/reset exceptions, resource fit, report warnings and exact
  bitstream/source binding for all four images.
- Hardware fault injection, including explicit generation-failure behavior and
  proof that reuse occurs without resetting away an error-state defect.
- Physical fan/temperature acceptance, licensed third-party provenance and all
  remaining spec promises or exclusions.

The tool preserves that review; it does not infer review approval, approve
licensing, reinterpret timing exceptions or claim an untested requirement passed.
