"""Generate independent references, run Questa, and build a shareable HTML report.
Author: Codex, for Makeda Solomon | Date: October 14, 2026
Python stdlib HMAC + OpenSSL AES reference; original RTL stays unchanged.
"""
from pathlib import Path
import argparse
import datetime as dt
import hashlib
import hmac
import html
import json
import re
import shutil
import subprocess
import sys
from zoneinfo import ZoneInfo

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]
SYM = REPO / 'Source Code' / 'Symmetric Module'
OUT = REPO / 'build' / 'symmetric-module' / 'professor-demo'
NIST = 'https://nvlpubs.nist.gov/nistpubs/legacy/sp/nistspecialpublication800-38a.pdf#page=58'
TCG = 'https://trustedcomputinggroup.org/wp-content/uploads/TPM-2.0-1.83-Part-1-Architecture.pdf#page=179'
RFC = 'https://www.rfc-editor.org/rfc/rfc4231.html#section-4.2'
KEY = bytes.fromhex('603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4')
IV = bytes(range(16))
PLAINS = [bytes.fromhex(x) for x in ['6bc1bee22e409f96e93d7e117393172a', 'ae2d8a571e03ac9c9eb76fac45af8e51', '30c81c46a35ce411e5fbc1191a0a52ef', 'f69f2445df4f9b17ad2b417be66c3710']]
CIPHERS = [bytes.fromhex(x) for x in ['dc7e84bfda79164b7ecd8486985d3860', '39ffed143b28b1c832113c6331e5407b', 'df10132415e54b92a13ed0a8267ae2f9', '75a385741ab9cef82031623d55b1e471']]
SECRET, NEWER, OLDER = bytes(range(32)), bytes(range(32,64)), bytes(range(64,96))

def aes(key, iv, data, decrypt=False):
    cmd = [shutil.which('openssl') or 'openssl', 'enc', '-aes-256-cfb', '-K', key.hex(), '-iv', iv.hex(), '-nopad']
    if decrypt: cmd.append('-d')
    return subprocess.run(cmd, input=data, capture_output=True, check=True).stdout

def derive(secret, newer, older, label, bits):
    result = b''
    counter = 1
    while len(result)*8 < bits:
        msg = counter.to_bytes(4,'big')+label+b'\0'+newer+older+bits.to_bytes(4,'big')
        result += hmac.digest(secret, msg, 'sha256')
        counter += 1
    return result[:(bits+7)//8]

def prepare():
    # Published RFC 4231 test 1 validates the software HMAC reference first.
    got = hmac.new(b'\x0b'*20,b'Hi There',hashlib.sha256).hexdigest()
    expected = 'b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7'
    assert got == expected, 'RFC HMAC check failed'
    assert aes(KEY,IV,b''.join(PLAINS)) == b''.join(CIPHERS), 'OpenSSL/NIST mismatch'
    run = OUT / ('run_'+dt.datetime.now().strftime('%Y%m%d_%H%M%S_%f'))
    run.mkdir(parents=True)
    if ' ' in sys.executable:
        raise RuntimeError('Use the installed Python executable with a space-free path for this Windows simulation bridge.')
    shutil.copyfile(HERE/'hmac_reference_service.py',run/'hmac_reference_service.py')
    cases = []
    def add(name, group, data, expected, key=KEY, iv=IV, secret=SECRET, newer=NEWER, older=OLDER, decrypt=False, xor=False):
        session = group != 'NIST'
        material = derive(secret,newer,older,b'XOR' if xor else b'CFB',len(data)*8 if xor else 384) if session else b''
        result_iv = iv if xor else (data if decrypt else expected).ljust(16,b'\0')
        cases.append(dict(id=len(cases)+1,name=name,group=group,session=session,xor=xor,decrypt=decrypt,bytes=len(data),
          data=data.hex(),expected=expected.ljust(16,b'\0').hex(),key=key.hex(),iv=iv.hex(),secret=secret.hex(),newer=newer.hex(),older=older.hex(),
          expected_iv=result_iv.hex(),derived_key=(material[:32] if session and not xor else key).hex(),
          derived_iv=(material[32:48] if session and not xor else iv).hex(),mask=material.hex() if xor else ''))
    # Each published segment is a separate current-interface job. The caller
    # explicitly supplies prior ciphertext as IV; no multi-block FSM is claimed.
    for i,(plain,cipher) in enumerate(zip(PLAINS,CIPHERS)):
        feedback = IV if i==0 else CIPHERS[i-1]
        add(f'NIST segment {i+1}: encrypt','NIST',plain,cipher,iv=feedback)
        add(f'NIST segment {i+1}: decrypt','NIST',cipher,plain,iv=feedback,decrypt=True)
    for suffix,newer,older in [('A',NEWER,OLDER),('B',OLDER,NEWER)]:
        material=derive(SECRET,newer,older,b'CFB',384)
        cipher=aes(material[:32],material[32:],PLAINS[0])
        add(f'Session CFB {suffix}: encrypt','Session CFB',PLAINS[0],cipher,newer=newer,older=older)
        add(f'Session CFB {suffix}: decrypt','Session CFB',cipher,PLAINS[0],newer=newer,older=older,decrypt=True)
    for n in [16,5]:
        data=PLAINS[0][:n]; mask=derive(SECRET,NEWER,OLDER,b'XOR',n*8)
        encrypted=bytes(a^b for a,b in zip(data,mask))
        add(f'Session XOR {n} bytes: protect','Session XOR',data,encrypted,xor=True)
        add(f'Session XOR {n} bytes: recover','Session XOR',encrypted,data,xor=True,decrypt=True)
    (run/'vectors.json').write_text(json.dumps(dict(cases=cases,rfc_hmac=dict(expected=expected,actual=got)),indent=2))
    (run/'tb_professor_demo.sv').write_text(make_bench(cases),encoding='utf-8')
    sources=['AES/aes_sbox.v','AES/aes_inv_sbox.v','AES/aes_key_mem.v','AES/aes_encipher_block.v','AES/aes_decipher_block.v','AES/aes_core.v','AES/aes.v','Controllers/kdfa_control.v','Controllers/cfb_block.v','Controllers/session_parameter_controller.v','Controllers/primitive_controller.v','symmetric_top.v']
    compile_lines='\n'.join(f'vlog -vlog01compat -work work_demo {{{(SYM/n).as_posix()}}}' for n in sources)
    script=f'''# Simulation-only Python HMAC replacement; original placeholder is NOT compiled.
if {{[batch_mode]}} {{onerror {{quit -force -code 1}}}} else {{onerror {{abort}}}}
onbreak {{resume}}
cd {{{run.as_posix()}}}
transcript file {{{(run/'transcript.log').as_posix()}}}
vlib work_demo
{compile_lines}
vlog -sv -work work_demo {{{(HERE.parent/'hmac_stream_test_service.sv').as_posix()}}} {{{(run/'tb_professor_demo.sv').as_posix()}}}
vsim -voptargs=+acc -onfinish stop -wlf {{{(run/'vsim.wlf').as_posix()}}} -lib work_demo tb_professor_demo +PYTHON={Path(sys.executable).as_posix()} +HMAC_SERVICE=hmac_reference_service.py
log -r sim:/tb_professor_demo/*
if {{![batch_mode]}} {{
 view wave
 add wave -group {{Test case}} -radix unsigned sim:/tb_professor_demo/test_case
 add wave -group {{Clock}} sim:/tb_professor_demo/clock_i sim:/tb_professor_demo/reset_n_i
 add wave -group {{Job}} sim:/tb_professor_demo/start_i sim:/tb_professor_demo/wait_o sim:/tb_professor_demo/done_o sim:/tb_professor_demo/session_protect_i sim:/tb_professor_demo/session_use_xor_i
 add wave -group {{Input}} -radix hexadecimal sim:/tb_professor_demo/data_in_i sim:/tb_professor_demo/key_i sim:/tb_professor_demo/iv_i
 add wave -group {{KDFa message}} -radix hexadecimal sim:/tb_professor_demo/dut/SESSION_CONTROLLER/KDFA_CONTROLLER/hmac_key_r sim:/tb_professor_demo/dut/SESSION_CONTROLLER/KDFA_CONTROLLER/hmac_message_r
 add wave -group {{Python HMAC digest}} -radix hexadecimal sim:/tb_professor_demo/hmac_digest_i
 add wave -group {{Derived key and IV}} -radix hexadecimal sim:/tb_professor_demo/dut/SESSION_CONTROLLER/kdfa_key_w sim:/tb_professor_demo/dut/SESSION_CONTROLLER/kdfa_iv_w
 add wave -group {{AES input}} -radix hexadecimal sim:/tb_professor_demo/dut/WORKER/aes_key_r sim:/tb_professor_demo/dut/WORKER/aes_feedback_r
 add wave -group {{Actual vs expected}} -radix hexadecimal sim:/tb_professor_demo/data_out_o sim:/tb_professor_demo/expected_data sim:/tb_professor_demo/iv_out_o sim:/tb_professor_demo/expected_feedback
 configure wave -namecolwidth 260 -valuecolwidth 260 -timelineunits ns
}}
run -all
if {{[examine -radix unsigned sim:/tb_professor_demo/successfully_completed] != 1}} {{error {{Demo did not complete}}}}
puts {{PROFESSOR_DEMO_PASS: {len(cases)} cryptographic comparisons}}
puts [exec {{{Path(sys.executable).as_posix()}}} {{{Path(__file__).as_posix()}}} --report {{{run.as_posix()}}}]
if {{[batch_mode]}} {{quit -force -code 0}} else {{wave zoom full}}
'''
    (run/'run.do').write_text(script,encoding='utf-8')
    # Source hashes identify exactly which RTL version produced the recording.
    files=[SYM/n for n in sources]+[HERE.parent/'hmac_stream_test_service.sv',HERE/'hmac_reference_service.py',Path(__file__)]
    (run/'source_hashes.json').write_text(json.dumps({str(f):hashlib.sha256(f.read_bytes()).hexdigest() for f in files},indent=2))
    (OUT/'latest_run.txt').write_text(str(run))
    return run

def make_bench(cases):
    head='''// Generated presentation testbench; see vectors.json for reference provenance.
// Author: Codex, for Makeda Solomon | Date: October 14, 2026
`timescale 1ns/1ps
module tb_professor_demo;
 reg clock_i=0; always #5 clock_i=~clock_i;
 reg reset_n_i=0,start_i=0;
 reg [15:0] command_code_i=16'h0193;
 reg session_protect_i=0,session_decrypt_i=0,session_encrypt_i=1,session_use_xor_i=0;
 reg key_valid_i=1,session_valid_i=1,decrypt_i=0;
 reg [2:0] mode_i=1;
 reg [31:0] data_bytes_i=16;
 reg [255:0] key_i=0,session_value_i=0,nonce_newer_i=0,nonce_older_i=0;
 reg [127:0] iv_i=0,data_in_i=0;
 wire wait_o,done_o;
 wire [11:0] tpm_rc_o;
 wire [127:0] iv_out_o;
 reg [127:0] data_out_o=0;
 reg [7:0] ram_rsp_data_i=0;
 reg ram_rsp_valid_i=0;
 wire ram_req_valid_o, ram_req_write_o, ram_rsp_ready_o;
 wire [3:0] ram_req_addr_o;
 wire [7:0] ram_req_data_o;
 wire [15:0] session_value_bytes_i=32, nonce_newer_bytes_i=32, nonce_older_bytes_i=32;
 wire hmac_start_o, hmac_key_valid_o, hmac_key_end_o, hmac_key_ready_i;
 wire hmac_message_valid_o, hmac_message_end_o, hmac_message_ready_i, hmac_busy_i;
 wire hmac_digest_valid_i, hmac_digest_ready_o;
 wire [7:0] hmac_key_data_o, hmac_message_data_o;
 wire [255:0] hmac_digest_i;
 hmac_stream_test_service #(.USE_PYTHON(1)) hmac_service(.*);
 symm_top #(.MAX_SYM_DATA_BYTES(16), .RAM_ADDR_WIDTH(4),
   .MAX_SECRET_BYTES(32), .MAX_NONCE_BYTES(32)) dut(
   .data_length_i(data_bytes_i), .input_base_i(4'd0), .output_base_i(4'd0),
   .busy_o(wait_o), .final_iv_o(iv_out_o), .error_o(), .completed_length_o(),
   .ram_req_ready_i(!ram_rsp_valid_i), .ram_rsp_error_i(1'b0), .*
 );
 always @(posedge clock_i or negedge reset_n_i) begin
   if (!reset_n_i) begin
     data_out_o <= 0; ram_rsp_valid_i <= 0; ram_rsp_data_i <= 0;
   end else if (start_i && !wait_o) data_out_o <= data_in_i;
   else begin
     if (ram_rsp_ready_o) ram_rsp_valid_i <= 0;
     if (ram_req_valid_o && !ram_rsp_valid_i) begin
       ram_rsp_valid_i <= 1;
       if (ram_req_write_o) data_out_o[127-ram_req_addr_o*8 -: 8] <= ram_req_data_o;
       else ram_rsp_data_i <= data_out_o[127-ram_req_addr_o*8 -: 8];
     end
   end
 end
 integer test_case=0,cycles,hmac_calls=0,aes_calls=0;
 reg successfully_completed=0;
 reg [127:0] expected_data,expected_feedback,expected_aes_iv;
 reg [255:0] expected_aes_key;
 reg [607:0] expected_message;
 string test_name;
 always @(posedge clock_i) if(reset_n_i) begin
  if(hmac_start_o) begin
   expected_message={32'd1+hmac_calls,(session_use_xor_i ? 32'h584f5200 : 32'h43464200),
     nonce_newer_i,nonce_older_i,(session_use_xor_i ? data_bytes_i*32'd8 : 32'd384)};
   if(!session_protect_i || dut.SESSION_CONTROLLER.KDFA_CONTROLLER.hmac_key_r!==session_value_i ||
      dut.SESSION_CONTROLLER.KDFA_CONTROLLER.hmac_message_r!==expected_message)
       $fatal(1,"Incorrect KDFa message or secret");
   hmac_calls<=hmac_calls+1;
  end
  if(dut.WORKER.aes_init_r) begin
   if(session_use_xor_i || dut.WORKER.aes_key_r!==expected_aes_key ||
      dut.WORKER.aes_feedback_r!==expected_aes_iv) $fatal(1,"AES key/IV mismatch");
   aes_calls<=aes_calls+1;
  end
 end
 task run_case;
  begin
   hmac_calls=0; aes_calls=0;
   $display("CASE|%0d|%s",test_case,test_name);
   start_i=1; @(negedge clock_i); start_i=0;
   cycles=0;
   while(!done_o && cycles<1000) begin @(negedge clock_i); cycles++; end
   $display("RESULT|%0d|%032h|%032h|%032h|%032h|%03h|%0d|%0d|%0d",test_case,
       expected_data,data_out_o,expected_feedback,iv_out_o,tpm_rc_o,cycles,hmac_calls,aes_calls);
   if(!done_o || tpm_rc_o!==0 || data_out_o!==expected_data || iv_out_o!==expected_feedback ||
      hmac_calls!=(session_protect_i ? (session_use_xor_i ? 1 : 2) : 0) ||
      aes_calls!=(session_use_xor_i ? 0 : 1)) $fatal(1,"Reference comparison failed");
   repeat(5) @(negedge clock_i);
   if(wait_o) $fatal(1,"Top did not release job");
  end
 endtask
 initial begin
  repeat(3) @(negedge clock_i); reset_n_i=1;
'''
    for c in cases:
        head+=f'''  @(negedge clock_i);
  test_case={c['id']}; test_name="{c['name']}";
  session_protect_i={int(c['session'])}; session_use_xor_i={int(c['xor'])};
  decrypt_i={int(c['decrypt'])}; session_decrypt_i={int(c['decrypt'])}; session_encrypt_i={int(not c['decrypt'])};
  data_bytes_i={c['bytes']}; key_i=256'h{c['key']}; iv_i=128'h{c['iv']};
  data_in_i=128'h{c['data'].ljust(32,'0')}; session_value_i=256'h{c['secret']};
  nonce_newer_i=256'h{c['newer']}; nonce_older_i=256'h{c['older']};
  expected_data=128'h{c['expected']}; expected_feedback=128'h{c['expected_iv']};
  expected_aes_key=256'h{c['derived_key']}; expected_aes_iv=128'h{c['derived_iv']};
  run_case();
'''
    return head+'''  successfully_completed=1; $display("ALL_REFERENCE_CASES_PASSED"); $finish;
 end
 initial begin #1000000; $fatal(1,"Demo timeout"); end
endmodule
'''

def report(run):
    manifest=json.loads((run/'vectors.json').read_text())
    transcript=(run/'transcript.log').read_text(errors='replace')
    pattern=r'RESULT\|(\d+)\|([0-9a-f]+)\|([0-9a-f]+)\|([0-9a-f]+)\|([0-9a-f]+)\|([0-9a-f]+)\|(\d+)\|(\d+)\|(\d+)'
    results={int(m[0]):dict(expected=m[1],actual=m[2],expected_iv=m[3],actual_iv=m[4],rc=m[5],cycles=int(m[6]),hmac=int(m[7]),aes=int(m[8])) for m in re.findall(pattern,transcript,re.I)}
    hm=re.findall(r'HMAC\|([0-9a-f]+)\|([0-9a-f]+)\|([0-9a-f]+)',transcript,re.I)
    digest_ok=all(hmac.digest(bytes.fromhex(k),bytes.fromhex(m),'sha256').hex()==d.lower() for k,m,d in hm)
    overall=len(results)==len(manifest['cases']) and 'ALL_REFERENCE_CASES_PASSED' in transcript and digest_ok and len(hm)==12
    for c in manifest['cases']:
        r=results.get(c['id'],{})
        c['observed']=r
        c['pass']=bool(r) and r['actual']==c['expected'] and r['actual_iv']==c['expected_iv'] and int(r['rc'],16)==0 and r['hmac']==(1 if c['xor'] else 2 if c['session'] else 0) and r['aes']==(0 if c['xor'] else 1)
        overall=overall and c['pass']
    manifest.update(overall_pass=overall,hmac_service_calls=len(hm),hmac_digests_rechecked=digest_ok,run_directory=str(run))
    (run/'results.json').write_text(json.dumps(manifest,indent=2))
    build_html(run,manifest,hm)
    print('REPORT:',run/'report.html')
    print('PASS' if overall else 'FAIL',len(results),'/',len(manifest['cases']))
    return overall

def build_html(run,m,hm):
    esc=lambda x:html.escape(str(x))
    ran=any(c['observed'] for c in m['cases'])
    status_label='PASS' if m['overall_pass'] else 'FAIL / INCOMPLETE' if ran else 'NOT RUN'
    notice='' if ran else '<p class="scope"><b>No RTL results recorded.</b> The demo compiled but Questa could not obtain its single-session license. Expected values below are software/published references only. Actual values and pass evidence require a successful simulation.</p>'
    rows=''
    for c in m['cases']:
        r=c['observed']
        rows+=f'''<tr><td><b>{esc(c['name'])}</b><small>{esc(c['group'])}</small></td><td class="hex">{c['expected']}</td><td class="hex">{r.get('actual','NOT RECORDED')}</td><td class="{'pass' if c['pass'] else 'fail'}">{'MATCH' if c['pass'] else 'FAIL'}</td></tr>'''
    details=''
    for c in m['cases']:
        fields=['data','bytes','key','iv','secret','newer','older','derived_key','derived_iv','mask','expected','expected_iv']
        details+=f'<details><summary>{esc(c["name"])} — exact inputs and expected values</summary><dl>'+''.join(f'<dt>{f}</dt><dd class="hex">{esc(c[f])}</dd>' for f in fields if c[f]!='')+'</dl></details>'
    digest_rows=''.join(f'<details><summary>HMAC service call {i+1}: actual Verilog request and returned digest</summary><dl><dt>Key</dt><dd class="hex">{k}</dd><dt>76-byte message</dt><dd class="hex">{msg}</dd><dt>HMAC-SHA256 digest</dt><dd class="hex">{d}</dd></dl></details>' for i,(k,msg,d) in enumerate(hm))
    page=f'''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>TPM symmetric module — verification evidence</title>
<style>body{{font:16px/1.55 system-ui,sans-serif;color:#17243a;background:#f2f5f9;margin:0}}main{{max-width:1100px;margin:auto;padding:40px 24px}}h1{{font-size:36px;line-height:1.15;max-width:800px}}h2{{margin-top:36px}}.eyebrow{{text-transform:uppercase;letter-spacing:.12em;font-size:12px;color:#46617d}}.banner{{padding:18px;background:#e0f1e9;border-left:5px solid #237653}}.pass{{color:#176343;font-weight:bold}}.fail{{color:#a32424;font-weight:bold}}.flow{{display:flex;gap:10px;align-items:stretch;flex-wrap:wrap;margin:18px 0}}.node{{flex:1;min-width:160px;background:white;border-top:4px solid #346eaa;padding:14px}}.software{{border-color:#ac7021;background:#fff8e9}}.arrow{{align-self:center}}small{{display:block;color:#607086}}table{{border-collapse:collapse;width:100%;background:white;font-size:14px}}td,th{{padding:12px;text-align:left;border-bottom:1px solid #dce3eb;vertical-align:top}}th{{background:#e7edf5}}.hex{{font-family:ui-monospace,Consolas,monospace;overflow-wrap:anywhere;word-break:break-word}}details{{background:white;border:1px solid #dce3eb;margin:9px 0;padding:12px}}summary{{cursor:pointer;font-weight:600}}dl{{display:grid;grid-template-columns:150px 1fr;gap:8px}}dd{{margin:0}}a{{color:#205e9b}}.scope{{background:#fff8e9;padding:16px}}@media(max-width:650px){{main{{padding:20px 12px}}h1{{font-size:28px}}table{{font-size:12px}}td,th{{padding:6px}}dl{{grid-template-columns:1fr}}}}@media print{{body{{background:white}}main{{padding:0}}details{{break-inside:avoid}}a{{color:inherit}}}}</style></head><body><main>
<div class="eyebrow">Makeda Solomon · FPGA TPM project · October 14, 2026</div><h1>Symmetric cryptography: measured progress</h1>
<p>Questa RTL simulation compared against published AES vectors and an independent software reference.</p>
<div class="banner"><b>{status_label} · {sum(c['pass'] for c in m['cases'])}/{len(m['cases'])} output comparisons matched.</b> Every test also checks feedback, status, expected HMAC/AES call counts and a completion deadline. The testbench checks KDFa messages and the key/IV reaching AES.</div>{notice}
<h2>1 · EncryptDecrypt2: published NIST answers</h2><p>The normal <code>symm_top</code> command path runs real AES-256/CFB hardware against all four segments of <a href="{NIST}">NIST SP 800-38A F.3.17–F.3.18</a>, in both directions. Each segment is a separate 16-byte job; the testbench supplies the published prior ciphertext as the next IV.</p>
<div class="flow"><div class="node">Published key + IV + data<small>NIST reference inputs</small></div><span class="arrow">→</span><div class="node">EncryptDecrypt2 controller → CFB → AES<small>Your existing RTL</small></div><span class="arrow">→</span><div class="node">Actual output = published expected output?<small>Automated comparison in Questa</small></div></div>
<h2>2 · Session path: real HMAC calculations in software</h2><p>No hardware HMAC was written. For this simulation only, the placeholder is replaced in an isolated library by a Python bridge. It hashes the <b>actual key/message emitted by KDFa</b>, then returns the real digest through the existing handshake.</p>
<div class="flow"><div class="node">Session inputs → KDFa<small>Your RTL builds counter, label, nonces and length</small></div><span class="arrow">→</span><div class="node software">Python HMAC-SHA256<small>Software substitute for missing hardware</small></div><span class="arrow">→</span><div class="node">KDFa → key/IV → real AES-CFB<small>Your RTL resumes; XOR uses its derived mask</small></div><span class="arrow">→</span><div class="node">Compare final output<small>Independent Python KDFa + OpenSSL AES reference</small></div></div>
<p>Session fixture inputs are chosen test data, <b>not published TCG test vectors</b>. Message construction follows <a href="{TCG}">TCG Part 1, clause 21</a>. Nonce order A and B are separate fixtures; encryption/decryption within each fixture intentionally reuse the same inputs to check reversal.</p>
<h2>Actual versus expected</h2><p>All values below are hexadecimal; short outputs are zero-filled at the unused end of the 128-bit bus.</p><table><thead><tr><th>Test</th><th>Expected</th><th>Questa actual</th><th>Result</th></tr></thead><tbody>{rows}</tbody></table>
<h2>What this demonstrates</h2><ul><li>Real command-path AES-CFB agrees with published NIST examples.</li><li>KDFa constructs the checked messages and assembles correct key/IV bytes when supplied real software HMAC digests.</li><li>Session CFB and XOR output agrees with the software reference for these fixed-size fixtures.</li></ul>
<div class="scope"><b>Remaining work:</b> hardware HMAC integration, host/execution-engine wiring, nonce lifecycle, variable session lengths, longer-buffer control, and complete TPM authorization/error handling. These tests are not full TPM conformance, hardware timing, resource, side-channel or security certification evidence.</div>
<h2>Exact inputs and derived material</h2>{details}<h2>Actual HMAC service exchanges</h2><p>{m['hmac_service_calls']} real HMAC calculations; returned digests were rechecked from the recorded key/message. Software reference also passed RFC 4231 test case 1 before simulation.</p>{digest_rows}
<h2>Sources and reproducibility</h2><ul><li><a href="{NIST}">NIST SP 800-38A: AES-256 CFB128 vectors, F.3.17/F.3.18, printed pages 51–52</a></li><li><a href="{TCG}">TCG TPM 2.0 Part 1 r1.83: session CFB, clause 21.3</a>; XOR: clause 11.4.7.3</li><li><a href="{RFC}">RFC 4231: HMAC-SHA256 known answer, test case 1</a></li><li><a href="https://docs.python.org/3/library/hmac.html">Python hmac reference library</a></li><li><a href="https://docs.openssl.org/3.0/man1/openssl-enc/">OpenSSL enc AES reference</a></li><li><a href="transcript.log">Raw Questa transcript</a> · <a href="results.json">Machine-readable results</a> · <a href="vectors.json">Reference inputs</a> · <a href="source_hashes.json">Source hashes</a> · <a href="tb_professor_demo.sv">Generated testbench</a></li></ul>
<p><b>Waveforms:</b> <code>vsim.wlf</code> in this report's directory. Run <code>do {{{(run/'run.do').as_posix()}}}</code> in the Questa GUI for grouped signals.</p>
<p><b>Suggested presentation statement, only after a passing run:</b> “My AES-256/CFB command path matches the published NIST examples. My session path builds checked KDFa messages and produces the expected encryption/XOR results using a real software HMAC substitute. The hardware HMAC and full TPM integration remain unfinished.”</p>
</main></body></html>'''
    (run/'report.html').write_text(page,encoding='utf-8')
    (OUT/'latest_report.html').write_text('<!doctype html><meta http-equiv="refresh" content="0;url='+run.name+'/report.html"><a href="'+run.name+'/report.html">Open latest report</a>',encoding='utf-8')

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--output-dir',type=Path,help='Directory for generated runs and reports')
    parser.add_argument('--prepare',action='store_true')
    parser.add_argument('--report',type=Path)
    args=parser.parse_args()
    if args.output_dir: OUT=args.output_dir.resolve()
    elif args.report: OUT=args.report.resolve().parent
    if args.report: sys.exit(0 if report(args.report) else 1)
    run=prepare()
    print('RUN:',run,flush=True)
    if args.prepare: sys.exit(0)
    process=subprocess.run([shutil.which('vsim') or 'vsim','-c','-do',f'do {{{(run/"run.do").as_posix()}}}'],cwd=run,capture_output=True,text=True)
    (run/'launcher.log').write_text(process.stdout+process.stderr,encoding='utf-8')
    if process.returncode:
        print(process.stdout[-5000:]); print(process.stderr); sys.exit(process.returncode)
    sys.exit(0 if report(run) else 1)
