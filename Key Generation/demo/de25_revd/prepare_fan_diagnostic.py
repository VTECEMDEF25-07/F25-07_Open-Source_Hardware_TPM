# Filename: prepare_fan_diagnostic.py
# Authors: Project contributors; see Git history.
# Date: 2026-10-13
# General Description: Prepare a fan/SPI-only diagnostic, never a key-generation acceptance image.
# AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

"""Prepare a fan/SPI-only diagnostic, never a key-generation acceptance image."""
import argparse, hashlib, json
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--build',type=Path,required=True);p.add_argument('--template-manifest',type=Path,required=True);a=p.parse_args()
build=a.build.resolve();here=Path(__file__).resolve().parent;template=json.loads(a.template_manifest.read_text())
if build.exists():raise RuntimeError('use a fresh diagnostic directory')
originals=[here/'keygen_de25_top.v',here/'keygen_demo_spi.v',here/'keygen_fan_guard.v',here/'diagnostic/keygen_fan_diagnostic_system.v']+sorted((here/'vendor').glob('*.v'))
inputs={p:p.read_bytes() for p in originals};(build/'sources').mkdir(parents=True)
h=lambda b:hashlib.sha256(b).hexdigest();snapshots={}
settings=[s for s in template['fingerprint_inputs']['settings_before_fingerprint'] if not any(x in s for x in ('VERILOG_FILE','VERILOG_MACRO','ROM_FILE','RSA_SOFTCORE'))]
settings=[s.replace('./',build.as_posix()+'/') for s in settings]
for index,(original,data) in enumerate(inputs.items()):
    dest=build/'sources'/f'{index:03}_{original.name}';dest.write_bytes(data);snapshots[str(dest)]=h(data)
    settings.append(f'set_global_assignment -name VERILOG_FILE "{dest.as_posix()}"')
sdc=template['fingerprint_inputs']['sdc'];fingerprint_inputs={'format':'KEYGEN-FAN-DIAGNOSTIC-v1','sources':{Path(k).name:v for k,v in snapshots.items()},'sdc':sdc,'settings':[s.replace(build.as_posix(),'.') for s in settings],'quartus_version':template['quartus_version']}
fingerprint=h(json.dumps(fingerprint_inputs,sort_keys=True,separators=(',',':')).encode());settings.append(f'set_parameter -name BUILD_FINGERPRINT "256\'h{fingerprint}"')
(build/'keygen_de25.qsf').write_text('\n'.join(settings)+'\n');(build/'keygen_de25.qpf').write_text('PROJECT_REVISION = "keygen_de25"\n');(build/'keygen_de25.sdc').write_text(sdc)
assert all(p.read_bytes()==data for p,data in inputs.items()),'source changed during snapshot'
manifest={'variant':'fan_diagnostic','diagnostic_only':True,'diagnostic_mode':True,'fan_diagnostics_version':1,'protocol_id':'46414e31','status':'prepared','timing_accepted':False,'build_fingerprint':fingerprint,'fingerprint_inputs':fingerprint_inputs,'snapshot_sha256':snapshots,'config_sha256':{p.name:h(p.read_bytes()) for p in build.glob('keygen_de25.*')},'quartus_executable':template['quartus_executable'],'quartus_version':template['quartus_version']}
(build/'build_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');print(build)
