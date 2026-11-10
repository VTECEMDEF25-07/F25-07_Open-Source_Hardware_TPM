"""Independent known-prime full-keygen checks, optional private handoff and lease.
Public fixture keys only. This is simulation, not RNG/search performance evidence.
Aaron Grossman; Codex-assisted. Reuses existing full-keygen assertions unchanged
except explicitly selecting/checking the frozen private n/e/d result format.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import subprocess


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--build', type=Path, required=True)
    p.add_argument('--compile-only', action='store_true')
    p.add_argument('--suite', choices=['all', 'full', 'lease', 'pair', 'store'], default='all')
    p.add_argument('--private', type=int, choices=[0, 1], default=1)
    a = p.parse_args()
    here = Path(__file__).resolve().parent
    verification = here.parent
    repo = here.parents[3]
    build = a.build.resolve()
    build.mkdir(parents=True, exist_ok=True)
    q = Path('C:/intelFPGA_lite/24.1std/questa_fse/win64')
    def run(label, tool, *args):
        r = subprocess.run([str(q / (tool + '.exe')), *map(str, args)], cwd=build,
                           capture_output=True, text=True, timeout=1800)
        out = r.stdout + r.stderr
        (build / (label + '.log')).write_text(out)
        print(label + ': ' + out[-2500:], flush=True)
        if r.returncode or '** Error:' in out or '** Fatal:' in out:
            raise SystemExit(label + ' failed')
        return out
    key = json.loads((verification / 'reference/expected_keys.json').read_text())['results'][0]['key']
    pv, qv = int(key['p'], 16), int(key['q'], 16)
    nv = pv * qv
    dv = pow(65537, -1, math.lcm(pv - 1, qv - 1))
    components = [(nv, 64), (65537, 1)] + ([(dv, 64)] if a.private else [(pv, 32), (qv, 32)])
    words = [f'{value >> (32 * i) & 0xffffffff:08x}' for value, count in components for i in reversed(range(count))]
    (build / 'expected.hex').write_text('\n'.join(words) + '\n')
    stimulus = [f'{value >> (32 * i) & 0xffffffff:08x}' for prime in (pv, qv)
                for value in [prime] + [2] * 5 for i in reversed(range(32))]
    (build / 'stimulus.hex').write_text('\n'.join(stimulus) + '\n')
    baseline = (verification / 'testbench/tb_keygen_full.sv').read_text()
    ties = '''
    wire private_open_ready_o,private_active_o,private_cmd_ready_o,private_rsp_valid_o;
    wire [7:0] private_rsp_status_o;wire private_mem_ready_o,private_mem_read_valid_o;
    wire [31:0] private_mem_read_data_o;wire private_close_ready_o,private_close_rsp_valid_o;
    wire private_open_valid_i=0,private_cmd_valid_i=0,private_rsp_ready_i=0;
    wire private_mem_write_en_i=0,private_mem_read_en_i=0,private_close_valid_i=0,private_close_rsp_ready_i=0;
    wire [7:0] private_cmd_op_i=0;wire [31:0] private_cmd_arg0_i=0,private_cmd_arg1_i=0,private_cmd_arg2_i=0,private_cmd_arg3_i=0;
    wire [11:0] private_mem_address_i=0;wire [31:0] private_mem_write_data_i=0;
'''
    bench = baseline.replace('keygen_core #(.IP_TYPE(IP_TYPE))',
                             f'keygen_core #(.IP_TYPE(IP_TYPE),.PRIVATE_RSA_ENABLE({a.private}))')
    bench = bench.replace('    keygen_core #', ties + '    keygen_core #')
    if a.private:
        bench = bench.replace('((received<64)?2:((received==64)?3:((received<97)?4:5)))',
                              '((received<64)?2:((received==64)?3:6))')
        bench = bench.replace('((received<64)?received:((received==64)?0:((received<97)?received-65:received-97)))',
                              '((received<64)?received:((received==64)?0:received-65))')
        bench = bench.replace('((received==63)||(received==64)||(received==96)||(received==128))',
                              '((received==63)||(received==64)||(received==128))')
    (build / 'tb_keygen_full.sv').write_text(bench)
    pair = (verification / 'testbench/tb_keygen_pair_check.sv').read_text()
    pair = pair.replace('module tb_keygen_pair_check #', 'module tb_pair_private #')
    pair = pair.replace('keygen_pair_check #(.IP_TYPE(IP_TYPE))',
                        'keygen_pair_check #(.IP_TYPE(IP_TYPE),.PRIVATE_RSA_ENABLE(1))')
    pair = pair.replace('    keygen_pair_check #', '''
    wire private_valid;wire[31:0]private_data;wire[5:0]private_index;
    reg private_ready=0;integer private_received=0;reg[31:0]private_held;reg private_stalled=0;
    always @(negedge clock_i)private_ready=(cycles%7<4);
    always @(posedge clock_i)begin
      if(!reset_n_i || (start_valid_i && start_ready_o))private_received<=0;
      if(reset_n_i && private_valid && private_ready)begin
        if(private_index!==private_received || private_data!==expected_d[private_received*32+:32])
          $fatal(1,"protected d stream mismatch");
        private_received<=private_received+1;
      end
      if(private_stalled && reset_n_i && (!private_valid || private_data!==private_held))
        $fatal(1,"private d changed while stalled");
      private_stalled<=reset_n_i && private_valid && !private_ready;private_held<=private_data;
      if(reset_n_i && result_valid_o && status_o==0 && private_received!=64)
        $fatal(1,"n result published before full private handoff");
    end
    keygen_pair_check #''')
    pair = pair.replace('.n_o(n_o), .status_o(status_o)',
                        '.n_o(n_o), .status_o(status_o),.private_valid_o(private_valid),.private_ready_i(private_ready),.private_data_o(private_data),.private_index_o(private_index)')
    # cycles is a bounded loop counter in the inherited bench; use a free-running
    # divider so d-stream stalls cannot deadlock during reset-phase subtests.
    pair = pair.replace('always @(negedge clock_i)private_ready=(cycles%7<4);',
                        'integer stall_cycle=0;always @(negedge clock_i)begin stall_cycle=stall_cycle+1;private_ready=(stall_cycle%7<4);end')
    (build / 'tb_pair_private.sv').write_text(pair)
    subprocess.run(['python', str(verification / 'reference/pair_vectors.py'), str(build / 'pair_vectors.mem')], check=True)
    source = repo / 'Source Code'
    files = sorted((source / 'Key Generation/rtl').rglob('*.v')) + sorted((source / 'Key Generation/IP').glob('*.v'))
    files += [source / 'Demo Memory/demo_volatile_store.v', verification / 'testbench/fixtures/keygen_test_source.v']
    if not (build / 'work').exists():
        run('vlib', 'vlib', 'work')
    run('rtl', 'vlog', '-vlog01compat', *files)
    tests = [build / 'tb_keygen_full.sv', build / 'tb_pair_private.sv']
    tests += list(here.glob('tb_*.sv'))
    run('bench', 'vlog', '-sv', *tests)
    inputs = files + tests + [Path(__file__)]
    hashes = {str(f): hashlib.sha256(f.read_bytes()).hexdigest() for f in inputs}
    if a.compile_only:
        return
    suites = []
    if a.suite in ('all', 'full'):
        suites.append(('tb_keygen_full', 'FULL_RSA', ['+DIRECTED', '+STALLS', '+EXPECTED=expected.hex', '+WORDS=384', '+STIMULUS=stimulus.hex']))
    if a.suite in ('all', 'pair'):
        suites.append(('tb_pair_private', 'pair check:', []))
    if a.suite in ('all', 'lease'):
        suites.append(('tb_private_lease', 'PRIVATE_LEASE', []))
    if a.suite in ('all', 'store'):
        suites.append(('tb_private_store', 'PRIVATE_STORE', []))
    for top, marker, arguments in suites:
        out = run(top, 'vsim', '-c', top, *arguments, '-do',
                  'onerror {quit -code 1}; onbreak {quit -code 1}; run -all; quit -code 0')
        if 'PASS ' + marker not in out:
            raise SystemExit('missing complete PASS: ' + top)
    assert hashes == {str(f): hashlib.sha256(f.read_bytes()).hexdigest() for f in inputs}, 'source changed during test'
    (build / 'manifest.json').write_text(json.dumps(dict(status='PASS', private_mode=a.private,
        suite=a.suite, source_sha256=hashes), indent=2))
    print('PASS OVERNIGHT KEYGEN suite=' + a.suite, flush=True)


if __name__ == '__main__':
    main()
