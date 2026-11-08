"""Linux/WSL check: invalid RNG backends must fail before any traffic.

Author: Aaron Grossman; Codex assisted with verification.
Compile generated C++ directly because GNU make cannot use this workspace's spaces.
"""
import argparse
from pathlib import Path
import subprocess

p=argparse.ArgumentParser()
p.add_argument('--build',type=Path,required=True)
p.add_argument('--verilator-root',type=Path,default=Path('/usr/share/verilator/include'))
a=p.parse_args()
repo=Path(__file__).resolve().parents[3]
source=repo/'Source Code'
build=a.build.resolve()
build.mkdir(parents=True,exist_ok=True)
bench=build/'tb_rng_vendor.sv'
bench.write_text('''`timescale 1ns/1ps
module tb_rng_vendor #(parameter IP_TYPE=0);
    RNG #(.IP_TYPE(IP_TYPE)) dut (
        .clk(1'b0), .rst_n(1'b0), .enable(1'b0),
        .cmd_data(8'd0), .cmd_valid(1'b0), .cmd_last(1'b0), .cmd_ready(),
        .rsp_data(), .rsp_valid(), .rsp_last(), .rsp_ready(1'b0)
    );
    initial begin #1; $display("PASS accepted supported RNG selection"); $finish; end
endmodule
''')
files=[source/'RNG Module'/name for name in ['RNG.v','entropy_source.v','ring_osc.v','random_number_generation.v','tpm2_get_random.v']]
for ip_type in [0,1,2,99,-1]:
    obj=build/('ip-'+str(ip_type))
    with (build/('compile-'+str(ip_type)+'.log')).open('w') as log:
        subprocess.run(['verilator','-I'+str(source),'--cc','--exe','--main','--timing','-Wno-fatal',
            '+1364-2001ext+v','+1800-2017ext+sv',
            '--top-module','tb_rng_vendor','-GIP_TYPE='+str(ip_type),'--Mdir',str(obj)]+list(map(str,files+[bench])),
            stdout=log,stderr=subprocess.STDOUT,check=True)
        vr=a.verilator_root
        subprocess.run(['g++','-O1','-std=c++20','-pthread','-I'+str(obj),'-I'+str(vr),'-I'+str(vr/'vltstd')]+
            list(map(str,obj.glob('*.cpp')))+[str(vr/name) for name in ['verilated.cpp','verilated_timing.cpp','verilated_threads.cpp']]+
            ['-o',str(obj/'run')],stdout=log,stderr=subprocess.STDOUT,check=True)
    result=subprocess.run([str(obj/'run')],capture_output=True,timeout=20)
    output=(result.stdout+result.stderr).decode(errors='replace')
    (build/('run-'+str(ip_type)+'.log')).write_text(output)
    if ip_type in [0,1]:
        assert result.returncode==0 and 'PASS accepted' in output,output
    else:
        assert result.returncode!=0 and 'RNG_UNSUPPORTED_IP_TYPE' in output and 'PASS accepted' not in output,output
    print('PASS Verilator RNG IP_TYPE='+str(ip_type),flush=True)
