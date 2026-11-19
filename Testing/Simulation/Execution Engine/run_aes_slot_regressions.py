"""Sequential native regression campaign. One Questa license, no hardware access.

Captures exact HEAD, all RTL/test input bytes, subprocess deadlines, outputs and
before/after audit. Child runners require explicit pass markers and independent
Python arithmetic/CFB/Hash_DRBG fixtures. Full directed RSA may take30 minutes.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--label',default='aes-slot-review')
    parser.add_argument('--without-rsa',action='store_true')
    parser.add_argument('--rsa-only',action='store_true')
    args=parser.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9_-]+',args.label): parser.error('invalid label')
    root=Path(__file__).resolve().parents[3]
    build=root/'build'/args.label; build.mkdir(parents=True,exist_ok=True)
    inputs=sorted(p for directory in [root/'Source Code',root/'Testing/Simulation'] for p in directory.rglob('*')
                  if p.suffix in ['.v','.vh','.sv','.py','.do'])
    audit=lambda: {str(p.relative_to(root)):sha(p) for p in inputs}
    record={'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),
            'inputs':audit(),'commands':[],'result':'FAIL','directed_correctness_not_entropy_or_prime_search_performance':True}
    bench='Testing/Simulation/Execution Engine/'
    kg=bench+'run_keygen_lifecycle.py'; aes=bench+'run_aes_generated_slot.py'
    jobs=[]
    if not args.rsa_only:
        jobs += [('aes256',[aes,'--label',args.label+'-aes256'],240),
                 ('aes128',[aes,'--top','tb_aes128_generated_slot','--label',args.label+'-aes128'],240),
                 ('compile',[kg,'compile','--label',args.label],180)]
        for action in ['boundary','real','health']:
            for backend in [0,1]: jobs.append((action+str(backend),[kg,action,'--backend',str(backend),'--label',args.label],240))
        for action in ['engine','host']:
            jobs.append((action,[kg,action,'--label',args.label],240))
        for family in ['Agilex 5','Cyclone V']:
            jobs.append(('resources-'+family.replace(' ',''),[kg,'resources','--family',family,'--label',args.label],240))
        jobs += [('symmetric',['Testing/Simulation/Symmetric Module/check_symmetric_ram.py','--output',str(build/'symmetric'),
                               '--questa','C:/intelFPGA_lite/24.1std/questa_fse/win64'],1500),
                 ('commands',[kg,'regression','--label',args.label],700)]
    if not args.without_rsa:
        jobs.append(('rsa',[kg,'rsa','--label',args.label],7300))
    try:
        for name,params,deadline in jobs:
            log=build/('campaign-'+name+'.log'); started=time.monotonic()
            command=[sys.executable]+params
            print('AES_CAMPAIGN_START '+name,flush=True)
            with log.open('wb') as stream:
                process=subprocess.Popen(command,cwd=root,stdout=stream,stderr=subprocess.STDOUT,
                                         creationflags=subprocess.CREATE_NEW_PROCESS_GROUP)
                try: code=process.wait(timeout=deadline)
                except BaseException:
                    subprocess.run([str(Path(os.environ['SystemRoot'])/'System32/taskkill.exe'),'/PID',str(process.pid),'/T','/F'],
                                   capture_output=True,timeout=10)
                    raise
            text=log.read_text(errors='replace')
            command_record={'name':name,'command':command,'deadline_seconds':deadline,
                            'elapsed_seconds':time.monotonic()-started,'exit_code':code,
                            'transcript_sha256':sha(log),'pass_markers':[line.lstrip('# ') for line in text.splitlines()
                                                                       if 'PASS' in line and not 'Warning' in line]}
            record['commands'].append(command_record)
            if code:
                print(text[-5000:],flush=True)
                raise RuntimeError(name+' failed')
            print('AES_CAMPAIGN_PASS '+name,flush=True)
            record['inputs_after']=audit()
            if record['inputs_after']!=record['inputs']: raise RuntimeError('RTL/test inputs changed during campaign')
            (build/'campaign.json').write_text(json.dumps(record,indent=2)+'\n')
        record['result']='PASS'
        print('AES_SLOT_CAMPAIGN_PASS jobs='+str(len(jobs)),flush=True)
    finally:
        record['inputs_after']=audit()
        (build/'campaign.json').write_text(json.dumps(record,indent=2)+'\n')


if __name__=='__main__': main()
