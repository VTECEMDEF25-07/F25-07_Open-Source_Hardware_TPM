"""Synthesize enabled protected-keygen + AES256 packet composition; no fit claim."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


root = Path(__file__).resolve().parents[3]
build = root / 'build/aes-slot-enabled-synthesis'
build.mkdir(parents=True, exist_ok=True)
board_qsf = root / 'Project/DE1/de1_soc_top.qsf'
sources = [(board_qsf.parent / p).resolve() for p in re.findall(r'-name VERILOG_FILE "([^"]+)"', board_qsf.read_text())]
sources = list(dict.fromkeys(sources + sorted((root / 'Source Code/Symmetric Module').rglob('*.v')) + [Path(__file__).with_name('aes_slot_synthesis.v')]))
qsf = build / 'consumer.qsf'
qsf.write_text('\n'.join([
    'set_global_assignment -name FAMILY "Cyclone V"',
    'set_global_assignment -name DEVICE 5CSEMA5F31C6',
    'set_global_assignment -name TOP_LEVEL_ENTITY aes_slot_synthesis',
    'set_global_assignment -name NUM_PARALLEL_PROCESSORS 4',
    'set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files',
    'set_global_assignment -name SEARCH_PATH "' + (root / 'Source Code/IO Interface').as_posix() + '"',
    'set_parameter -name IP_TYPE 1',
    'set_parameter -name DEVICE_FAMILY "Cyclone V"'] +
    ['set_global_assignment -name VERILOG_FILE "' + p.as_posix() + '"' for p in sources]) + '\n')
(build / 'consumer.qpf').write_text('PROJECT_REVISION = "consumer"\n')
inputs = sources + list((root / 'Source Code').rglob('*.vh')) + [Path(__file__)]
record = {'profile': 'enabled protected AES128/AES256/RSA2048 keygen + one-slot reservation + AES256 packet/controller, IP_TYPE=1 Cyclone V',
          'head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(),
          'inputs': {str(p.relative_to(root)): sha(p) for p in inputs},
          'qsf_sha256': sha(qsf), 'deadline_seconds': 900,
          'command': ['C:/intelFPGA_lite/24.1std/quartus/bin64/quartus_map.exe', 'consumer'],
          'result': 'FAIL', 'fit_or_timing_claim': False}
start = time.monotonic()
process = subprocess.Popen(record['command'], cwd=build, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                           creationflags=subprocess.CREATE_NEW_PROCESS_GROUP)
try:
    output, _ = process.communicate(timeout=900)
except BaseException:
    subprocess.run([str(Path(os.environ['SystemRoot']) / 'System32/taskkill.exe'), '/PID', str(process.pid), '/T', '/F'],
                   capture_output=True, timeout=10)
    output, _ = process.communicate()
    (build / 'compile.log').write_bytes(output)
    raise
log = build / 'compile.log'
log.write_bytes(output)
record.update({'exit_code': process.returncode, 'elapsed_seconds': time.monotonic()-start,
               'transcript_sha256': sha(log),
               'inputs_after': {str(p.relative_to(root)): sha(p) for p in inputs}})
if process.returncode==0 and 'Analysis & Synthesis was successful' in output.decode(errors='replace') and record['inputs']==record['inputs_after']:
    record['result']='PASS'
(build / 'evidence.json').write_text(json.dumps(record, indent=2) + '\n')
print('AES_SLOT_ENABLED_SYNTHESIS_' + record['result'], flush=True)
if record['result']!='PASS':
    print(output.decode(errors='replace')[-7000:])
    raise SystemExit(1)
