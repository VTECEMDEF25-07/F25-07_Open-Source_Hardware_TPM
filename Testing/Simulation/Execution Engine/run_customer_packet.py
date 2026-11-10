#!/usr/bin/env python3
"""Bounded packet-leaf service-model checks. No real crypto/FPGA claim."""
from pathlib import Path
import argparse,json,subprocess


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--build',type=Path);args=p.parse_args()
    td=Path(__file__).resolve().parent;repo=td.parents[2]
    build=(args.build or repo.parent/'packet-build').resolve();build.mkdir(parents=True,exist_ok=True)
    def run(argv,name,marker=None):
        r=subprocess.run(list(map(str,argv)),cwd=build,capture_output=True,text=True,timeout=60)
        out=r.stdout+r.stderr;(build/(name+'.log')).write_text(out,encoding='utf-8')
        if r.returncode or '** Error' in out or '** Fatal' in out or (marker and marker not in out):
            print(out[-12000:]);raise SystemExit('FAIL '+name)
        print(name+' PASS')
    if not (build/'work').exists():run(['vlib','work'],'vlib')
    run(['vlog','-vlog01compat',repo/'Source Code/Execution Engine/customer_demo_packet.v'],'compile-production')
    run(['vlog','-sv',td/'tb_customer_demo_packet.sv'],'compile-bench')
    for name,params,marker in [('enabled',[],'CUSTOMER_PACKET_PASS'),
                               ('export-disabled',['-gEXPORT_ENABLED=0'],'CUSTOMER_PACKET_DISABLED_PASS'),
                               ('deadline',['-gWATCHDOG_TEST=1'],'CUSTOMER_PACKET_TIMEOUT_PASS')]:
        run(['vsim','-c','-voptargs=+acc','-onfinish','stop']+params+
            ['work.tb_customer_demo_packet','-do','run -all; quit -force -code 0'],name+'-simulation',marker)
    print('CUSTOMER_PACKET_SUITE_PASS (service-model simulation only)')


if __name__=='__main__':main()
