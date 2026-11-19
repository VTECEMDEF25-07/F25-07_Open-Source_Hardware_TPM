"""Enabled keygen + AES packet + protected RSA synthesis/virtual-pin fit.

This harness is not a board image, board timing signoff or hardware acceptance.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time


def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--family',choices=['cyclone','agilex'],default='cyclone')
    parser.add_argument('--fit',action='store_true')
    args=parser.parse_args()
    root=Path(__file__).resolve().parents[3]
    build=root/('build/rsa-enabled-'+args.family+('-fit' if args.fit else '-synthesis'))
    build.mkdir(parents=True,exist_ok=True)
    board=root/'Project/DE1/de1_soc_top.qsf'
    sources=[(board.parent/p).resolve() for p in re.findall(r'-name VERILOG_FILE "([^"]+)"',board.read_text())]
    sources=list(dict.fromkeys(sources+sorted((root/'Source Code/Symmetric Module').rglob('*.v'))+
        [Path(__file__).with_name('rsa_slot_synthesis.v')]))
    agilex=args.family=='agilex'
    family='Agilex 5' if agilex else 'Cyclone V'
    device='A5ED013BB32AE4SCS' if agilex else '5CSEMA5F31C6'
    qsf=build/'consumer.qsf'
    settings=[f'set_global_assignment -name FAMILY "{family}"',f'set_global_assignment -name DEVICE {device}',
        'set_global_assignment -name TOP_LEVEL_ENTITY rsa_slot_synthesis',
        'set_global_assignment -name NUM_PARALLEL_PROCESSORS 4',
        'set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files',
        'set_global_assignment -name SEARCH_PATH "'+(root/'Source Code/IO Interface').as_posix()+'"',
        'set_parameter -name IP_TYPE 1',f'set_parameter -name DEVICE_FAMILY "{family}"']
    if args.fit:
        settings+=['set_instance_assignment -name VIRTUAL_PIN ON -to *',
            'set_global_assignment -name SDC_FILE consumer.sdc']
        (build/'consumer.sdc').write_text('create_clock -name core_clock -period 20.000 [get_ports clock_i]\n'+
            'derive_clock_uncertainty\nset_false_path -from [get_ports reset_n_i]\n')
    qsf.write_text('\n'.join(settings+['set_global_assignment -name VERILOG_FILE "'+p.as_posix()+'"' for p in sources])+'\n')
    (build/'consumer.qpf').write_text('PROJECT_REVISION = "consumer"\n')
    bindir=Path('C:/altera_pro/26.1/quartus/bin64' if agilex else 'C:/intelFPGA_lite/24.1std/quartus/bin64')
    command=[str(bindir/('quartus_sh.exe' if args.fit else 'quartus_map.exe'))]
    command+=['--flow','compile','consumer'] if args.fit else ['consumer']
    inputs=sources+list((root/'Source Code').rglob('*.vh'))+[Path(__file__)]
    record={'profile':'enabled real keygen + AES256 packet/controller + RSA2048 adapter/controller, Altera resources',
        'family':family,'device':device,'virtual_pin_harness':args.fit,'clock_period_ns':20 if args.fit else None,
        'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root).decode().strip(),
        'inputs':{str(p.relative_to(root)):sha(p) for p in inputs},'qsf_sha256':sha(qsf),
        'command':command,'deadline_seconds':1800 if args.fit else 900,'result':'FAIL','board_signoff':False}
    start=time.monotonic();log=build/'compile.log'
    with log.open('wb') as output:
        process=subprocess.Popen(command,cwd=build,stdout=output,stderr=subprocess.STDOUT,
            creationflags=subprocess.CREATE_NEW_PROCESS_GROUP|subprocess.CREATE_NO_WINDOW)
        try:process.wait(timeout=record['deadline_seconds'])
        except BaseException:
            subprocess.run([str(Path(os.environ['SystemRoot'])/'System32/taskkill.exe'),'/PID',str(process.pid),'/T','/F'],capture_output=True,timeout=10)
            process.wait();raise
        finally:
            record.update({'returncode':process.returncode,'elapsed_seconds':round(time.monotonic()-start,3),
                'transcript_sha256':sha(log),'inputs_after':{str(p.relative_to(root)):sha(p) for p in inputs}})
            text=log.read_text(errors='replace')
            if process.returncode==0 and ('Full Compilation was successful' in text if args.fit else 'Analysis & Synthesis was successful' in text) and record['inputs']==record['inputs_after']:
                record['result']='PASS'
            (build/'evidence.json').write_text(json.dumps(record,indent=2)+'\n')
    print('RSA_ENABLED_'+('FIT_' if args.fit else 'SYNTHESIS_')+record['result'],flush=True)
    if record['result']!='PASS':raise SystemExit(1)


if __name__=='__main__':main()
