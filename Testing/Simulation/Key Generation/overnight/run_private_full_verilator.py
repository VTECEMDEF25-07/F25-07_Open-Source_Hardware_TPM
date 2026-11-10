"""WSL Verilator full private keygen run; reuse prepared independent fixtures.
No simulator license, no GNU make (class paths contain spaces), no hardware.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--build', type=Path, required=True)
    p.add_argument('--prepared', type=Path, required=True)
    p.add_argument('--reuse', action='store_true')
    p.add_argument('--entropy-source', type=Path)
    p.add_argument('--top', choices=['tb_keygen_full', 'tb_pair_private', 'tb_private_lease', 'tb_private_store',
        'tb_keygen_aes_core','tb_keygen_lifecycle','tb_demo_operation_cycles','tb_entropy_profiles','tb_rsa_admission','tb_post_generation_lease'], default='tb_keygen_full')
    a = p.parse_args()
    build, prepared = a.build.resolve(), a.prepared.resolve()
    if os.name == 'nt':
        def wsl(path):
            s = str(Path(path).resolve()).replace('\\', '/')
            return '/mnt/' + s[0].lower() + s[2:]
        command = ['wsl.exe', '-d', 'Ubuntu-24.04', '--', 'python3', wsl(__file__),
                   '--build', wsl(build), '--prepared', wsl(prepared), '--top', a.top]
        if a.reuse:
            command += ['--reuse']
        if a.entropy_source:
            command += ['--entropy-source', wsl(a.entropy_source)]
        subprocess.run(command, check=True)
        return
    repo = Path(__file__).resolve().parents[4]
    source = repo / 'Source Code/Key Generation'
    verification = repo / 'Testing/Simulation/Key Generation'
    build.mkdir(parents=True, exist_ok=True)
    if a.top=='tb_post_generation_lease':
        fixture=(verification/'integration/tb_demo_operation.sv').read_text()
        fixture=fixture.replace('module tb_demo_operation;', 'module tb_post_generation_lease;')
        fixture=fixture.replace('reg rst=0,jv=0,dr=0;', 'reg pov=0,pcv=0,pcr=0;wire por,pa,pcrdy,pcrv;reg rst=0,jv=0,dr=0;')
        fixture=fixture.replace('.DEMO_PROVIDER_MODE(MODE),', '.PRIVATE_RSA_ENABLE(1),.DEMO_PROVIDER_MODE(MODE),',1)
        fixture=fixture.replace('.clock_i(clk),.reset_n_i(rst),.job_valid_i(jv)', '''.private_open_valid_i(pov),.private_open_ready_o(por),.private_active_o(pa),
 .private_close_valid_i(pcv),.private_close_ready_o(pcrdy),.private_close_rsp_valid_o(pcrv),.private_close_rsp_ready_i(pcr),
 .private_cmd_valid_i(1'b0),.private_cmd_op_i(8'd0),.private_cmd_arg0_i(32'd0),.private_cmd_arg1_i(32'd0),
 .private_cmd_arg2_i(32'd0),.private_cmd_arg3_i(32'd0),.private_rsp_ready_i(1'b0),
 .private_mem_write_en_i(1'b0),.private_mem_read_en_i(1'b0),.private_mem_address_i(12'd0),.private_mem_write_data_i(32'd0),
 .clock_i(clk),.reset_n_i(rst),.job_valid_i(jv)''',1)
        fixture=fixture.split('reg [31:0] h;integer prior,i;')[0]+'''
reg [31:0] h;integer prior,i;
initial begin
 reset_all;
 start_job(1,MODE);wait(dv);h=handle;check_done(0,0,1);lookup(h,0,1);
 if(op.source_open_reg || op.reserved_reg || op.u_core.peers_ready_i)
   $fatal(1,"generation peers not closed");
 for(prior=0;prior<2;prior=prior+1)begin
  @(negedge clk);pov=1;i=0;
  while(!por && i<100)begin @(negedge clk);i=i+1;end
  if(!por)$fatal(1,"post-generation private OPEN blocked with source closed");
  @(posedge clk);@(negedge clk);pov=0;
  if(!pa || jr)$fatal(1,"lease admission exclusion");
  repeat(5)@(negedge clk);
  if(!pa || op.u_core.peers_ready_i || op.source_open_reg || op.reserved_reg)
   $fatal(1,"lease changed generation ownership");
  wait(pcrdy);pcv=1;@(posedge clk);@(negedge clk);pcv=0;
  wait(pcrv);repeat(5)@(negedge clk);
  if(!pcrv || !pa || jr)$fatal(1,"close response/exclusion");
  pcr=1;@(posedge clk);@(negedge clk);pcr=0;wait(jr);
  lookup(h,0,1);
 end
 flush(h);start_job(1,MODE);wait(dv);h=handle;check_done(0,0,1);lookup(h,0,1);
 $display("PASS POST_GENERATION_LEASE opens=2 subsequent_generation=1");$finish;
end
initial begin #2000000;$fatal(1,"post-generation lease timeout");end
endmodule
'''
        (build/'tb_post_generation_lease.sv').write_text(fixture)
    files = sorted((source / 'rtl').rglob('*.v')) + sorted((source / 'IP').glob('*.v'))
    test = prepared / (a.top + '.sv') if a.top in ('tb_keygen_full','tb_pair_private','tb_demo_operation_cycles') else (
        verification/'testbench'/(a.top+'.sv') if a.top in ('tb_keygen_aes_core','tb_keygen_lifecycle') else Path(__file__).with_name(a.top+'.sv'))
    if a.top=='tb_post_generation_lease':
        test=build/'tb_post_generation_lease.sv'
    private_mode=int('.PRIVATE_RSA_ENABLE(1)' in test.read_text())
    files += [verification / 'testbench/fixtures/keygen_test_source.v', test]
    if a.top=='tb_private_store':
        files += [repo/'Source Code/Demo Memory/demo_volatile_store.v']
    if a.top in ('tb_demo_operation_cycles','tb_entropy_profiles','tb_post_generation_lease'):
        files += sorted((source/'integration').glob('*.v'))
        files += sorted((repo/'Source Code/Hash Module').glob('*.v'))
        if a.entropy_source or a.top=='tb_entropy_profiles':
            assert a.entropy_source, '--entropy-source must name the frozen assessed dependency'
            assert hashlib.sha256(a.entropy_source.read_bytes()).hexdigest()=='2b0b727f93b1ab725e41e1a556c526fa48469f638a65f6f836cc650aa55a0a89'
            files += [a.entropy_source,repo/'Source Code/RNG Module/random_number_generation.v']
            if a.top!='tb_entropy_profiles':
                files += [repo/'Source Code/RNG Module/ring_osc.v']
        else:
            files += [repo/'Source Code/RNG Module'/(n+'.v') for n in ('ring_osc','entropy_source','random_number_generation')]
        files += [repo/'Source Code/Demo Memory/demo_volatile_store.v']
    build.mkdir(parents=True, exist_ok=True)
    obj = build / 'obj'
    binary = obj / ('V'+a.top)
    def digest(path):
        return hashlib.sha256(path.read_bytes()).hexdigest()
    hashes = {str(f): digest(f) for f in files}
    if a.top in ('tb_demo_operation_cycles','tb_post_generation_lease'):
        files.append(prepared/'demo_vectors.vh')
        hashes[str(prepared/'demo_vectors.vh')]=digest(prepared/'demo_vectors.vh')
    manifest = build / 'manifest.json'
    def run(label, arguments, timeout=1800):
        result = subprocess.run(list(map(str, arguments)), cwd=build, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True, timeout=timeout)
        (build / (label + '.log')).write_text(result.stdout)
        print(label + ': ' + result.stdout[-1800:], flush=True)
        if result.returncode:
            raise SystemExit(label + ' failed')
        return result.stdout
    if not a.reuse:
        run('elaborate', ['verilator', '--cc', '--exe', '--main', '--timing', '--top-module', a.top,
                         '--Mdir', obj, '-Wno-fatal', '-DSIMULATION','-I'+str(prepared),
                         # Existing shared SHA uses Verilog2005 $clog2. The
                         # separate native vlog01 compatibility gate remains.
                         ('+1364-2005ext+v' if a.top in ('tb_demo_operation_cycles','tb_entropy_profiles','tb_post_generation_lease') else '+1364-2001ext+v'),
                         '+1800-2017ext+sv', *[f for f in files if f.suffix!='.vh']])
        vr = Path('/usr/share/verilator/include')
        run('compile', ['g++', '-O2', '-std=c++20', '-pthread', '-I' + str(obj), '-I' + str(vr), '-I' + str(vr / 'vltstd'),
                        *sorted(obj.glob('*.cpp')), *[vr / x for x in ('verilated.cpp', 'verilated_timing.cpp', 'verilated_threads.cpp')], '-o', binary])
        assert hashes == {str(f): digest(f) for f in files}, 'sources changed during build'
        manifest.write_text(json.dumps(dict(status='BUILT', source_sha256=hashes, binary_sha256=digest(binary)), indent=2))
    else:
        old = json.loads(manifest.read_text())
        assert old['source_sha256'] == hashes and old['binary_sha256'] == digest(binary), 'stale simulation binary'
    if a.top=='tb_pair_private':
        (build/'pair_vectors.mem').write_bytes((prepared/'pair_vectors.mem').read_bytes())
    arguments=['+DIRECTED', '+STALLS', '+WORDS=384', '+EXPECTED=' + str(prepared / 'expected.hex'), '+STIMULUS=' + str(prepared / 'stimulus.hex')] if a.top=='tb_keygen_full' else []
    out = run('simulation', [binary,*arguments], timeout=3600)
    marker={'tb_keygen_full':'PASS FULL_RSA','tb_pair_private':'PASS pair check:','tb_private_lease':'PASS PRIVATE_LEASE',
        'tb_private_store':'PASS PRIVATE_STORE','tb_keygen_aes_core':'PASS AES_CORE',
        'tb_keygen_lifecycle':'PASS CORE_LIFECYCLE','tb_demo_operation_cycles':'DEMO_OPERATION_PASS',
        'tb_entropy_profiles':'PASS ENTROPY_PROFILES','tb_rsa_admission':'PASS RSA_ADMISSION_ALL',
        'tb_post_generation_lease':'PASS POST_GENERATION_LEASE'}[a.top]
    assert marker in out, 'no complete private keygen pass'
    assert hashes == {str(f): digest(f) for f in files}, 'sources changed during simulation'
    manifest.write_text(json.dumps(dict(status='PASS', source_sha256=hashes, binary_sha256=digest(binary),
        directed_public_fixture=True, fresh_rng_claim=False, private_mode=private_mode, simulator='Verilator'), indent=2))


if __name__ == '__main__':
    main()
