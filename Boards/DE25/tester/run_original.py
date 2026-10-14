"""Bounded original-suite runner. Offline generation is the default."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument('--exe', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--hardware', action='store_true')
parser.add_argument('--serial', default='FTA6H280')
parser.add_argument('--hz', type=int, default=100000)
parser.add_argument('--timeout', type=float, default=180)
args = parser.parse_args()
if not 1000 <= args.hz <= 1000000 or not 0 < args.timeout <= 600:
    parser.error('Invalid frequency or timeout')
exe = Path(os.path.abspath(args.exe))
if not exe.is_file():
    parser.error('Executable file does not exist')
output = Path(os.path.abspath(args.output))
output.mkdir(parents=True, exist_ok=False)
command = [str(exe), '--generate', 'tb_original.v', '--serial', args.serial, '--hz', str(args.hz)]
if args.hardware:
    command.append('--hardware')
start = time.monotonic()
timed_out = False
launch_error = None
try:
    process = subprocess.run(command, cwd=output, stdout=subprocess.PIPE,
                             stderr=subprocess.STDOUT, timeout=args.timeout)
    log, code = process.stdout, process.returncode
except subprocess.TimeoutExpired as error:
    log, code, timed_out = error.stdout or b'', None, True
except OSError as error:
    launch_error = str(error)
    log, code = launch_error.encode(), None
(output/'tester.log').write_bytes(log)
text = log.decode(errors='replace')
passed = code == 0 and not timed_out
if args.hardware:
    passed = passed and 'There were no errors in testing.' in text
    passed = passed and all(name in text for name in (
        'test_debugRW', 'test_localityChanging', 'test_localityPermissions',
        'test_statusStateMachine', 'test_localitySeizeCommandAbort', 'test_ccQuote'))
    passed = passed and text.count('test_hierarchyControl') >= 2
else:
    passed = passed and 'OFFLINE:' in text and (output/'tb_original.v').is_file()
record = {
    'result': ('HARDWARE_PASS' if args.hardware else 'OFFLINE_GENERATED') if passed else 'FAIL',
    'hardware_requested': args.hardware, 'serial': args.serial, 'frequency_hz': args.hz,
    'returncode': code, 'timeout': timed_out, 'elapsed_seconds': time.monotonic()-start,
    'launch_error': launch_error,
    'command': command, 'executable_sha256': hashlib.sha256(exe.read_bytes()).hexdigest(),
    'working_directory': str(output),
    'runner_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
    'log_sha256': hashlib.sha256(log).hexdigest(),
    'scope': 'Original eight integration suites; not TPM conformance or key-generation validation.'
}
(output/'result.json').write_text(json.dumps(record, indent=2)+'\n')
print(json.dumps(record, indent=2))
raise SystemExit(0 if passed else 1)
