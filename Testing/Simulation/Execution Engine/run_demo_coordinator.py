#!/usr/bin/env python3
"""Questa demo unit/reference checks; optionally replay inherited SPI/Hash/AES suites.

Requires vlib/vlog/vsim in PATH and Python cryptography. Build/log outputs default
to ../unit-build outside the repository; override --build for other checkouts.
No FPGA programming or live transport access.
"""
from pathlib import Path
import argparse
import re
import subprocess


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build',type=Path)
    parser.add_argument('--legacy',action='store_true')
    args=parser.parse_args()
    td=Path(__file__).resolve().parent; repo=td.parents[2]; src=repo/'Source Code'
    build=(args.build or repo.parent/'unit-build').resolve(); build.mkdir(parents=True,exist_ok=True)
    def run(command,name,marker=None):
        r=subprocess.run(list(map(str,command)),cwd=build,capture_output=True,text=True,timeout=180)
        output=r.stdout+r.stderr; (build/(name+'.log')).write_text(output,encoding='utf-8')
        if r.returncode or (marker and marker not in output) or '** Error' in output or '** Fatal' in output:
            print(output[-12000:]); raise SystemExit('FAIL '+name)
        print(name+' PASS')
    from cryptography.hazmat.primitives.ciphers import Cipher,algorithms,modes
    key=bytes.fromhex('603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4')
    fixture=[]
    for n in [0,1,15,16,17,31,32,1023,1024]:
        p=bytes(i%256 for i in range(n)); e=Cipher(algorithms.AES(key),modes.CFB(bytes(range(16)))).encryptor()
        fixture+=list(e.update(p)+e.finalize())+[0]*(1024-n)
    (build/'aes_ciphertext.hex').write_text('\n'.join(f'{b:02x}' for b in fixture)+'\n',encoding='ascii')
    if not (build/'work').exists(): run(['vlib','work'],'vlib')
    rtl=[src/'Execution Engine/execution_engine.v',src/'Execution Engine/demo_aes_coordinator.v',
         src/'Execution Engine/execution_engine_demo_packet.v',src/'Symmetric Module/symmetric_top.v']
    rtl+=list((src/'Symmetric Module/AES').glob('*.v'))+list((src/'Symmetric Module/Controllers').glob('*.v'))
    if args.legacy:
        board=repo/'Project/DE1'
        qsf=(board/'de1_soc_top.qsf').read_text(encoding='utf-8')
        rtl += [(board/p).resolve() for p in re.findall(r'-name VERILOG_FILE "([^"]+)"',qsf)]
    rtl=list(dict.fromkeys(rtl))
    run(['vlog','-vlog01compat','+incdir+'+str(src/'IO Interface')]+rtl,'compile-production')
    for top in ['tb_demo_packet','tb_demo_aes_lifecycle','tb_demo_timeout']:
        run(['vlog','-sv',td/(top+'.sv')],top+'-compile')
        run(['vsim','-c','-voptargs=+acc','-onfinish','stop','work.'+top,
             '-do','run -all; quit -force -code 0'],top+'-sim',top.removeprefix('tb_').upper()+'_PASS')
    if args.legacy:
        run(['vlog','-sv',repo/'Testing/Simulation/Symmetric Module/symmetric_test_ram.sv',
             td/'tb_tpm2_hash_command.sv',td/'tb_tpm2_hash_spi.sv',td/'tb_keygen_encryptdecrypt2.sv',
             repo/'Testing/Simulation/IO Interface/tb_test.v'],'compile-legacy-benches')
        for top,extra in [('tb_tpm2_hash_command',[]),('tb_keygen_encryptdecrypt2',[]),
                          ('tb_tpm2_hash_spi',[]),('tb_tpm2_hash_spi',['-gENABLE_AES_TEST=1'])]:
            script='run -all; if {[examine -radix unsigned sim:/'+top+'/passed] != 1} {quit -force -code 2}; echo LEGACY_SCOPED_PASS; quit -force -code 0'
            run(['vsim','-c','-voptargs=+acc','-onfinish','stop']+extra+['work.'+top,'-do',script],
                top+('-aes' if extra else '')+'-legacy','LEGACY_SCOPED_PASS')
        run(['vsim','-c','-L','altera_mf_ver','-L','lpm_ver','-voptargs=+acc','-onfinish','stop',
             'work.tb_test','-do','onbreak {resume}; run 2 ms; if {[examine -radix unsigned sim:/tb_test/errors] != 0 || [examine -radix unsigned sim:/tb_test/genEntry] != 240} {quit -force -code 2}; echo LEGACY_SPI_240_PASS; quit -force -code 0'],
            'tb_test-legacy','LEGACY_SPI_240_PASS')
    print('DEMO_COORDINATOR_SUITE_PASS')

if __name__=='__main__': main()
