#!/usr/bin/env python3
"""Real packet/AES/CFB/RAM seam test; generation and store are TEST fixtures."""
from pathlib import Path
import argparse,hashlib,json,subprocess
from cryptography.hazmat.primitives.ciphers import Cipher,algorithms,modes


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--crypto-repo',type=Path,required=True,
                   help='Checkout containing the actual customer_aes_worker and symmetric RTL')
    p.add_argument('--build',type=Path)
    p.add_argument('--compile-only',action='store_true',help='Prepare vectors and compile without taking the simulation lease')
    args=p.parse_args()
    td=Path(__file__).resolve().parent;repo=td.parents[2]
    build=(args.build or repo.parent/'packet-real-aes-build').resolve()
    build.mkdir(parents=True,exist_ok=True)
    crypto=args.crypto_repo.resolve();source=crypto/'Source Code'
    files=[repo/'Source Code/Execution Engine/customer_demo_packet.v',
           source/'Execution Engine/customer_aes_worker.v',source/'Demo Memory/demo_byte_ram.v']
    files+=sorted((source/'Symmetric Module').rglob('*.v'))
    files+=[td/'tb_customer_packet_real_aes.sv']
    for path in files:
        if not path.is_file():raise FileNotFoundError(path)
    rows=[]
    for n in [0,1,17,31,32,1024]:
        plain=bytes((k*29+7)%256 for k in range(n));iv=bytes(range(16))
        ctx=Cipher(algorithms.AES(bytes(range(32))),modes.CFB(iv)).encryptor()
        cipher=ctx.update(plain)+ctx.finalize()
        final=iv if n==0 else cipher[(n-1)//16*16:].ljust(16,b'\0')
        rows.append(plain.ljust(1024,b'\0')+cipher.ljust(1024,b'\0')+final)
    (build/'real-aes-oracle.hex').write_text(''.join(f'{x:02x}\n' for row in rows for x in row),encoding='ascii')
    def run(argv,name,marker=None):
        result=subprocess.run(list(map(str,argv)),cwd=build,capture_output=True,text=True,timeout=60)
        output=result.stdout+result.stderr
        (build/(name+'.log')).write_text(output,encoding='utf-8')
        if result.returncode or '** Error' in output or '** Fatal' in output or (marker and marker not in output):
            print(output[-12000:]);raise SystemExit('FAIL '+name)
        print(name+' PASS',flush=True)
    if not (build/'work').exists():run(['vlib','work'],'vlib')
    run(['vlog','-sv']+files,'compile')
    if args.compile_only:
        print('COMPILE_ONLY_PASS; no simulation performed',flush=True)
        return
    run(['vsim','-c','-voptargs=+acc','-onfinish','stop','work.tb_customer_packet_real_aes',
         '-do','run -all; quit -force -code 0'],'simulation','CUSTOMER_PACKET_REAL_AES_PASS')
    record={'status':'PASS','hardware':False,'scope':__doc__,'lengths':[0,1,17,31,32,1024],
            'oracle':'Independent Python cryptography AES256-CFB encryption; frozen partial feedback convention',
            'sources_sha256':{str(path):hashlib.sha256(path.read_bytes()).hexdigest() for path in files}}
    (build/'validation.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
    print('CUSTOMER_PACKET_REAL_AES_SUITE_PASS (simulation only)',flush=True)


if __name__=='__main__':main()
