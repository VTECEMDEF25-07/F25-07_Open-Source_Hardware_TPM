"""Compile a prepared snapshot once, after verifying its recorded evidence."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess


def capture_compile(tool, build):
    # A cloud-backed inherited stdout handle can fail while a child is running.
    # Keep its output in a pipe; publish a closed log only after it exits.
    result = subprocess.run([tool, "--flow", "compile", "keygen_de25"], cwd=build,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    with (build / "compile.log").open("xb") as log:
        log.write(result.stdout)
    return result.returncode


def verify(build, manifest):
    if manifest.get("status") != "prepared" or (build / "compile.log").exists():
        raise RuntimeError("only an uncompiled prepared snapshot may be started")
    for name, expected in manifest["snapshot_sha256"].items():
        path = Path(name)
        if path.parent.resolve() != (build / "sources").resolve():
            raise RuntimeError("snapshot path outside selected build")
        if hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            raise RuntimeError(f"source snapshot changed: {path}")
    for name, expected in manifest["config_sha256"].items():
        if Path(name).name != name:
            raise RuntimeError("invalid configuration path")
        if hashlib.sha256((build / name).read_bytes()).hexdigest() != expected:
            raise RuntimeError(f"build configuration changed: {name}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("build", type=Path)
    args = parser.parse_args()
    build = args.build.resolve()
    manifest_path = build / "build_manifest.json"
    manifest = json.loads(manifest_path.read_text())
    verify(build, manifest)
    tool = manifest["quartus_executable"]
    version = subprocess.run([tool, "--version"], check=True, capture_output=True, text=True, timeout=60)
    if (version.stdout+version.stderr).strip() != manifest["quartus_version"]:
        raise RuntimeError("Quartus version differs from prepared snapshot")
    manifest["status"] = "compiling"
    manifest_path.write_text(json.dumps(manifest, indent=2)+"\n")
    returncode = capture_compile(tool, build)
    manifest["compiler_returncode"] = returncode
    manifest["status"] = "compiled" if returncode == 0 else "failed"
    manifest_path.write_text(json.dumps(manifest, indent=2)+"\n")
    print(f"{manifest['variant']}: {manifest['status']}; timing acceptance remains a separate review", flush=True)
    raise SystemExit(returncode)


if __name__ == "__main__":
    main()
