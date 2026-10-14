"""Compile a prepared Phase 1 snapshot after verifying its captured inputs."""
import argparse
import hashlib
import json
import os
import tempfile
from pathlib import Path
import subprocess


def save_manifest(path, manifest):
    """Replace a complete manifest atomically, including on synced folders."""
    data = (json.dumps(manifest, indent=2)+'\n').encode()
    fd, temporary = tempfile.mkstemp(prefix=path.name+'.', dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
        if path.read_bytes() != data:
            raise RuntimeError('Manifest readback mismatch')
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def compile_snapshot(build, quartus):
    build = Path(build).resolve()
    path = build / 'build_manifest.json'
    manifest = json.loads(path.read_text())
    if manifest['status'] != 'prepared':
        raise RuntimeError('Snapshot must be fresh and prepared')

    def verify(post_compile=False):
        for group in ('snapshot_sha256', 'config_sha256'):
            for name, expected in manifest[group].items():
                data = (build / name).read_bytes()
                if hashlib.sha256(data).hexdigest() == expected:
                    continue
                # Quartus appends these two tool-owned metadata/default lines.
                # Accept only that exact suffix, reconstructing the original hash.
                permitted = [
                    'set_global_assignment -name LAST_QUARTUS_VERSION "26.1.0 Pro Edition"',
                    'set_global_assignment -name RESERVE_ALL_UNUSED_PINS_NO_OUTPUT_GND "AS INPUT TRI-STATED"']
                lines = data.decode().splitlines()
                if post_compile and name == 'de25_soc_top.qsf' and lines[-2:] == permitted:
                    candidates = [('\n'.join(lines[:-2])+'\n').encode(),
                                  ('\r\n'.join(lines[:-2])+'\r\n').encode()]
                    if any(hashlib.sha256(value).hexdigest() == expected for value in candidates):
                        manifest['quartus_qsf_appends'] = permitted
                        manifest['post_compile_qsf_sha256'] = hashlib.sha256(data).hexdigest()
                        continue
                raise RuntimeError('Snapshot changed: '+name)

    verify()
    version = subprocess.run([str(quartus), '--version'], capture_output=True, text=True, check=True, timeout=60)
    if version.stdout + version.stderr != manifest['tool_version']:
        raise RuntimeError('Quartus version changed')
    manifest['status'] = 'compiling'
    save_manifest(path, manifest)
    try:
        result = subprocess.run([str(quartus), '--flow', 'compile', 'de25_soc_top'],
                                cwd=build, capture_output=True, text=True, timeout=3600)
        (build / 'compile.log').write_text(result.stdout + result.stderr)
        manifest['compiler_returncode'] = result.returncode
        verify(post_compile=True)
        manifest.update(status='compiled' if result.returncode == 0 else 'failed', compiler_returncode=result.returncode)
        save_manifest(path, manifest)
        result.check_returncode()
    except Exception as error:
        manifest.update(status='failed', failure=str(error))
        save_manifest(path, manifest)
        raise
    print('COMPILED; timing review and hardware tests still required')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build', type=Path, required=True)
    parser.add_argument('--quartus', type=Path, default=Path('C:/altera_pro/26.1/quartus/bin64/quartus_sh.exe'))
    args = parser.parse_args()
    compile_snapshot(args.build, args.quartus)
