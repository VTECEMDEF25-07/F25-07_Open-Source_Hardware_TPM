#!/usr/bin/env python3
"""Run under existing WSL/Linux: real RSA2048 packet seam, TEST generation/store/lease."""
from pathlib import Path
import argparse,hashlib,json,shutil,subprocess


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--service-repo',type=Path,required=True,
                   help='Integrated checkout containing private worker, compact math and TEST corpus')
    p.add_argument('--build',type=Path)
    args=p.parse_args()
    td=Path(__file__).resolve().parent;repo=td.parents[2]
    service=args.service_repo.resolve();source=service/'Source Code'
    out=(args.build or repo.parent/'packet-real-rsa-build').resolve();obj=out/'obj'
    obj.mkdir(parents=True,exist_ok=True)
    fixture=service/'Testing/Simulation/Key Generation/reference/expected_keys.json'
    data=json.loads(fixture.read_text());assert data['test_only'] is True
    key=data['results'][0]['key'];n,e,d=(int(key[k],0) for k in ['n','e','d'])
    assert n.bit_length()==2048 and e==65537 and d>0
    assert int(key['p'],0)*int(key['q'],0)==n
    message='Packet → real RSA2048 private math ✓'.encode()
    frame=b'\0DE25'+len(message).to_bytes(2,'big')+message+bytes(249-len(message))
    assert len(frame)==256
    value=int.from_bytes(frame,'big');cipher=pow(value,e,n)
    (out/'real-rsa-vector.txt').write_text(' '.join(f'{x:0512x}' for x in [n,d,cipher,value])+'\n')
    files=[repo/'Source Code/Execution Engine/customer_demo_packet.v',
           source/'Asymmetric Module/demo_rsa_private_worker.v',
           source/'Key Generation/rtl/arithmetic/keygen_math.v']
    files+=sorted((source/'Key Generation/IP').glob('*.v'))
    files+=[td/'tb_customer_packet_real_rsa.sv']
    inputs=files+[fixture,Path(__file__).resolve()]
    before={str(f):hashlib.sha256(f.read_bytes()).hexdigest() for f in inputs}
    (out/'inputs.json').write_text(json.dumps(before,indent=2))
    if not shutil.which('verilator') or not shutil.which('g++'):
        raise RuntimeError('Existing Verilator and g++ required; no installation is performed')
    top='tb_customer_packet_real_rsa'
    with (out/'build.log').open('w') as log:
        subprocess.run(['verilator','--cc','--exe','--main','--timing','--top-module',top,
                        '--Mdir',str(obj),'-Wno-fatal']+list(map(str,files)),
                       stdout=log,stderr=subprocess.STDOUT,check=True,timeout=90)
        print('Verilator generation PASS',flush=True)
        version=subprocess.check_output(['verilator','-V'],text=True)
        vr=Path(next(line.split('=',1)[1].strip() for line in version.splitlines()
                     if line.strip().startswith('VERILATOR_ROOT') and line.split('=',1)[1].strip()))/'include'
        subprocess.run(['g++','-O1','-std=c++20','-pthread','-I'+str(obj),'-I'+str(vr),'-I'+str(vr/'vltstd')]+
                       list(map(str,obj.glob('*.cpp')))+[str(vr/s) for s in
                       ['verilated.cpp','verilated_timing.cpp','verilated_threads.cpp']]+['-o',str(obj/'run')],
                       stdout=log,stderr=subprocess.STDOUT,check=True,timeout=180)
        print('C++ build PASS',flush=True)
    with (out/'simulation.log').open('w') as log:
        subprocess.run([str(obj/'run')],cwd=out,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=120)
    log=(out/'simulation.log').read_text()
    if 'CUSTOMER_PACKET_REAL_RSA_PASS' not in log:raise AssertionError('Missing packet RSA PASS marker')
    if before!={str(f):hashlib.sha256(f.read_bytes()).hexdigest() for f in inputs}:
        raise AssertionError('A source changed during the run')
    record={'status':'PASS','hardware':False,'scope':__doc__,'rsa_bits':2048,
            'tool':'Verilator','generation_store_lease_test_fixtures':True,
            'message':message.decode(),'sources_sha256':before,
            'log_sha256':hashlib.sha256(log.encode()).hexdigest()}
    (out/'validation.json').write_text(json.dumps(record,indent=2))
    print(log,flush=True)


if __name__=='__main__':main()
