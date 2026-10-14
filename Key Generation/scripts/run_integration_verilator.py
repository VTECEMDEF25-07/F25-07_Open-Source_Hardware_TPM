# Filename: run_integration_verilator.py
# Authors: Project contributors; see Git history.
# Date: 2026-10-13
# General Description: Bounded Linux/WSL integration tests, with all products in ignored build/.
# AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

"""Bounded Linux/WSL integration tests, with all products in ignored build/."""
import argparse
from pathlib import Path
import shutil
import subprocess

p = argparse.ArgumentParser()
p.add_argument('--suite', choices=['services', 'lifecycle'], default='lifecycle')
p.add_argument('--softcore', action='store_true')
a = p.parse_args()
root = Path(__file__).resolve().parents[1]
top = 'tb_keygen_rsa_services' if a.suite == 'services' else 'tb_keygen_lifecycle'
build = root / 'build' / (a.suite + ('_softcore' if a.softcore else '_rtl'))
obj = build / 'obj'
build.mkdir(parents=True, exist_ok=True)
sources = ['rtl/rsa_rtl/keygen_rsa_services.v', 'testbench/' + top + '.sv']
if a.suite == 'lifecycle':
    sources += ['IP/keygen_mult32.v', 'IP/keygen_mult32_generic.v', 'IP/keygen_mult32_altera.v',
                'IP/keygen_ram32.v', 'IP/keygen_ram32_generic.v', 'IP/keygen_ram32_altera.v',
                'rtl/aes/keygen_aes_core.v', 'rtl/arithmetic/keygen_math.v',
                'rtl/arithmetic/keygen_pair_check.v', 'rtl/rsa_rtl/keygen_rsa_controller.v',
                'rtl/rsa_rtl/keygen_rsa_engine.v', 'rtl/common/keygen_core.v']
    if a.softcore:
        sources += ['IP/third_party/picorv32/picorv32.v',
                    'rtl/rsa_softcore/keygen_softcore_control.v', 'rtl/rsa_softcore/keygen_rsa_softcore.v']
        shutil.copyfile(root / 'build/full/rsa_control.hex', build / 'rsa_control.hex')
command = ['verilator', '--cc', '--exe', '--main', '--timing', '--top-module', top,
           '--Mdir', str(obj), '-Wno-fatal', '+1364-2001ext+v', '+1800-2017ext+sv']
if a.softcore:
    command += ['+define+KEYGEN_SOFTCORE']
command += [str(root / s) for s in sources]
with (build / 'elaborate.log').open('w') as log:
    subprocess.run(command, cwd=build, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=120)
vr = Path('/usr/share/verilator/include')
command = ['g++', '-O2', '-std=c++20', '-pthread', '-I' + str(obj), '-I' + str(vr), '-I' + str(vr / 'vltstd')]
command += [str(s) for s in sorted(obj.glob('*.cpp'))]
command += [str(vr / s) for s in ['verilated.cpp', 'verilated_timing.cpp', 'verilated_threads.cpp']]
binary = obj / ('V' + top)
command += ['-o', str(binary)]
with (build / 'compile.log').open('w') as log:
    subprocess.run(command, cwd=build, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=300)
with (build / 'result.log').open('w') as log:
    subprocess.run([str(binary)], cwd=build, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=120)
report = (build / 'result.log').read_text()
marker = 'PASS RSA_SERVICES' if a.suite == 'services' else 'PASS CORE_LIFECYCLE'
if marker not in report or '%Error' in report:
    raise RuntimeError('Incomplete or failed simulation: ' + report)
print(report)
