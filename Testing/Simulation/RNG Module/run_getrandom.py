"""Run GetRandom with a test-only SHA service, independently checked by hashlib.

Author: Aaron Grossman, with Codex assistance. Python standard library + Questa.
Production Verilog is compiled separately from SystemVerilog test sources.
"""
import argparse
import hashlib
import os
from pathlib import Path
import shutil
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True, help='Scratch directory outside tracked source')
    args = parser.parse_args()
    here = Path(__file__).resolve().parent
    repo = here.parents[2]
    build = args.output.resolve()
    build.mkdir(parents=True, exist_ok=True)
    configured = os.environ.get('QUESTA_BIN')

    def executable(name):
        path = shutil.which(name)
        if path:
            return path
        if configured:
            path = Path(configured) / (name + ('.exe' if os.name == 'nt' else ''))
            if path.is_file():
                return str(path)
        raise SystemExit(f'{name} not found: add Questa to PATH or set QUESTA_BIN')

    def run(label, name, *arguments):
        result = subprocess.run([executable(name), *map(str, arguments)], cwd=build,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        (build / (label + '.log')).write_text(result.stdout)
        print(result.stdout, flush=True)
        if result.returncode:
            raise SystemExit(result.returncode)
        return result.stdout

    # Different padding boundaries and binary data, independent of DRBG outputs.
    messages = [b'', b'abc'] + [bytes((37*i + 11*n) & 255 for i in range(n))
                              for n in list(range(1, 131)) + [191, 192, 193, 255, 256, 257, 511, 512, 513, 1024]]
    cases = '\n'.join(f"check_hash({len(m)}, 8192'h{m.hex() or '0'}, 256'h{hashlib.sha256(m).hexdigest()});" for m in messages)
    bench = '''`timescale 1ns/1ps
module tb_sha_model;
reg clk=0;always #5 clk=~clk;
reg reset_n=0;
sha256_test_model dut(.clk_i(clk),.reset_n_i(reset_n),.data_i(8'd0),
 .valid_i(1'b0),.last_i(1'b0),.ready_o(),.digest_reg_o(),.digest_valid_reg_o());
task check_hash(input integer length,input reg[8191:0] data,input reg[255:0] expected);
 reg[255:0] actual;integer i;
 begin
  for(i=0;i<length;i=i+1)dut.message_reg[i]=data[(length-1-i)*8+:8];
  dut.hash_message(length,actual);
  if(actual!==expected)$fatal(1,"SHA model mismatch length=%0d",length);
 end
endtask
initial begin
''' + cases + f'\n$display("PASS SHA model: {len(messages)} hashlib cases");$finish;\nend\nendmodule\n'
    (build / 'tb_sha_model.sv').write_text(bench)
    if not (build / 'work').exists():
        run('library', 'vlib', 'work')
    rtl = repo / 'Source Code/RNG Module'
    run('rtl-compile', 'vlog', '-vlog01compat', '+define+SIMULATION',
        *[rtl / (n + '.v') for n in ['RNG', 'tpm2_get_random', 'random_number_generation', 'entropy_source', 'ring_osc']])
    run('test-compile', 'vlog', '-sv', here / 'sha256_test_model.sv',
        here / 'tb_tpm2_get_random.v', build / 'tb_sha_model.sv')
    for top, marker in [('tb_sha_model', 'PASS SHA model:'), ('tb_tpm2_get_random', 'ALL TESTS PASSED')]:
        output = run(top, 'vsim', '-c', '-onfinish', 'exit', top, '-do',
                     'onerror {quit -code 1}; onbreak {quit -code 1}; run -all; quit -code 0')
        if marker not in output or '  FAIL' in output or 'GLOBAL TIMEOUT' in output:
            raise SystemExit(f'{top} failed: missing success marker or failure text')


if __name__ == '__main__':
    main()
