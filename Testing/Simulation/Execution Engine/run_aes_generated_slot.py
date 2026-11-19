"""Native sequential AES consumer checks, public independent cryptography oracle.

All logs, exact input SHA256, git HEAD, command/deadline/pass evidence in build.
No FPGA or physical entropy access. Requires cryptography and installed Questa.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time

from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
import cryptography


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--label', default='aes-generated-slot')
    parser.add_argument('--top', default='tb_aes_generated_slot', choices=['tb_aes_generated_slot', 'tb_aes128_generated_slot'])
    args = parser.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9_-]+', args.label):
        parser.error('invalid label')
    root = Path(__file__).resolve().parents[3]
    build = root / 'build' / args.label
    build.mkdir(parents=True, exist_ok=True)
    qbin = Path('C:/intelFPGA_lite/24.1std/questa_fse/win64')
    qsf = root / 'Project/DE1/de1_soc_top.qsf'
    sources = [(qsf.parent / p).resolve() for p in re.findall(r'-name VERILOG_FILE "([^"]+)"', qsf.read_text())]
    symmetric = root / 'Source Code/Symmetric Module'
    sources = list(dict.fromkeys(sources + sorted(symmetric.rglob('*.v'))))
    bench = Path(__file__).with_name(args.top + '.sv')
    record = {'head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(),
              'profile': 'enabled internal keygen + AES consumer, Generic, AES' + ('128 decoded' if '128' in args.top else '256 packet'),
              'inputs': {str(p.relative_to(root)): sha(p) for p in sources + [qsf, bench, Path(__file__)]},
              'commands': [], 'result': 'FAIL', 'cryptography_version': cryptography.__version__}
    key = bytes(range(16 if '128' in args.top else 32))
    encrypt = Cipher(algorithms.AES(key), modes.CFB(bytes(range(16, 32)))).encryptor()
    ciphertext = encrypt.update(bytes(j % 256 for j in range(1024))) + encrypt.finalize()
    oracle = build / 'oracle.hex'
    oracle.write_text(''.join(f'{b:02x}\n' for b in ciphertext))
    record['oracle'] = {'provider': 'Python cryptography/OpenSSL AES CFB128', 'key_bits': len(key)*8,
                        'iv': bytes(range(16, 32)).hex(), 'bytes': 1024, 'sha256': sha(oracle)}

    def run(tool, params, label, deadline=180):
        command = [str(qbin / (tool + '.exe'))] + params
        started = time.monotonic()
        process = subprocess.Popen(command, cwd=build, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                   creationflags=subprocess.CREATE_NEW_PROCESS_GROUP)
        try:
            output, _ = process.communicate(timeout=deadline)
        except BaseException:
            subprocess.run([str(Path(os.environ['SystemRoot']) / 'System32/taskkill.exe'),
                            '/PID', str(process.pid), '/T', '/F'], capture_output=True, timeout=10)
            output, _ = process.communicate()
            (build / (label + '.log')).write_bytes(output)
            raise
        path = build / (label + '.log')
        path.write_bytes(output)
        record['commands'].append({'command': command, 'deadline_seconds': deadline,
                                   'elapsed_seconds': time.monotonic()-started,
                                   'exit_code': process.returncode, 'transcript_sha256': sha(path)})
        decoded = output.decode(errors='replace')
        if process.returncode or re.search(r'\*\* (Error|Fatal):|# \*\* Fatal:', decoded):
            print(decoded[-7000:], flush=True)
            raise RuntimeError(label + ' failed')
        return decoded

    try:
        run('vlib', ['work'], 'library')
        run('vlog', ['-vlog01compat', '+incdir+' + str(root / 'Source Code/IO Interface')] + [str(p) for p in sources], 'compile')
        run('vlog', ['-sv', str(bench)], 'bench-compile')
        script = build / 'run.do'
        script.write_text('onerror {quit -force -code 1}\nonbreak {quit -force -code 0}\nrun -all\nquit -force -code 1\n')
        output = run('vsim', ['-c', '-voptargs=+acc', '-onfinish', 'stop', 'work.' + args.top,
                             '+ORACLE=' + oracle.name, '-do', 'do run.do'], 'simulation')
        marker = 'AES128_GENERATED_SLOT_PASS' if '128' in args.top else 'AES_GENERATED_SLOT_PASS'
        matches = [line.lstrip('# ') for line in output.splitlines() if marker in line]
        if not matches:
            print(output[-7000:])
            raise RuntimeError('missing explicit pass/count evidence')
        record['pass_markers'] = matches
        record['inputs_after'] = {str(p.relative_to(root)): sha(p) for p in sources + [qsf, bench, Path(__file__)]}
        if record['inputs_after'] != record['inputs']:
            raise RuntimeError('inputs changed during run')
        record['result'] = 'PASS'
        print('\n'.join(matches), flush=True)
    finally:
        (build / 'evidence.json').write_text(json.dumps(record, indent=2) + '\n')


if __name__ == '__main__':
    main()
