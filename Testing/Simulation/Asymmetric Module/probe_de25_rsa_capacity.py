"""Place the implemented TPM services together with physical DE25 SPI and cooling.

The missing trusted object-service boundary is represented by virtual pins.
This engineering probe creates only temporary sources and never runs the assembler.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[3]
BOARD = ROOT / 'Project/DE25'
TOOLS = Path('C:/altera_pro/26.1/quartus/bin64')
# Only the internal request/result interface is virtual. Private slot and
# derivation buses stay internal. The ordinary DE25 pin assignments stay in force.
PORTS = {
    'keygen_request_i': 1, 'keygen_profile_i': 2, 'keygen_id_i': 32,
    'keygen_allow_i': 1, 'keygen_completion_ready_i': 1, 'keygen_release_i': 1,
    'keygen_ready_o': 1, 'keygen_completion_o': 1, 'keygen_code_o': 4,
    'keygen_slot_valid_o': 1, 'rsa_request_valid_i': 1, 'rsa_request_id_i': 32,
    'rsa_allow_i': 1, 'rsa_operation_i': 2, 'rsa_operand_valid_i': 1,
    'rsa_operand_data_i': 32, 'rsa_operand_last_i': 1, 'rsa_result_ready_i': 1,
    'rsa_completion_ready_i': 1, 'rsa_request_ready_o': 1, 'rsa_operand_ready_o': 1,
    'rsa_result_valid_o': 1, 'rsa_result_last_o': 1, 'rsa_result_data_o': 32,
    'rsa_completion_valid_o': 1, 'rsa_completion_code_o': 4, 'rsa_completion_id_o': 32,
}


def replace_once(source, original, replacement):
    if source.count(original) != 1:
        raise ValueError(f'Board source no longer matches anchor {original!r}')
    return source.replace(original, replacement)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def prepare(build):
    project = build / 'Project/DE25'
    project.mkdir(parents=True, exist_ok=True)
    ports = []
    for name, width in PORTS.items():
        direction = 'input' if name.endswith('_i') else 'output'
        bits = f'[{width-1}:0] ' if width > 1 else ''
        ports.append(f'{direction} wire {bits}qa_{name}')
    declarations = ',\n    '.join(ports)
    wiring = ',\n        '.join(f'.qa_{p}(qa_{p})' for p in PORTS)
    tpm = ROOT/'Source Code/TPM_TOP.v'
    top = BOARD/'de25_soc_top.v'
    tpm_text = replace_once(tpm.read_text(), 'input wire aes_slot_allow_i',
                            'input wire aes_slot_allow_i,\n    '+declarations)
    tpm_text = replace_once(tpm_text, '.ENABLE_INTERNAL_KEYGEN(ENABLE_INTERNAL_KEYGEN),',
                            '.ENABLE_INTERNAL_KEYGEN(ENABLE_INTERNAL_KEYGEN), .ENABLE_RSA_SLOT_CONSUMER(1),')
    for name in PORTS:
        if name.endswith('_i'):
            tpm_text, count = re.subn(r'\.'+name+r"\(\d+'[bd]\d+\)", f'.{name}(qa_{name})', tpm_text)
            if count != 1:
                raise ValueError('Expected exactly one tied input '+name)
    outputs = ',\n        '.join(f'.{p}(qa_{p})' for p in PORTS if p.endswith('_o'))
    tpm_text = replace_once(tpm_text, ".keygen_request_i(qa_keygen_request_i),",
                            outputs+',\n        .keygen_request_i(qa_keygen_request_i),')
    top_text = replace_once(top.read_text(), 'inout fan_i2c_sda\n',
                            'inout fan_i2c_sda, input wire qa_aes_allow_i,\n    '+declarations+'\n')
    top_text = replace_once(top_text, '.DEVICE_FAMILY("Agilex 5")', '''.DEVICE_FAMILY("Agilex 5"),
        .ENABLE_INTERNAL_KEYGEN(1), .ENABLE_AES_SLOT_CONSUMER(1), .ENABLE_ENCRYPTDECRYPT2(1),
        .ENABLE_GETRANDOM(1), .ENABLE_PCR_EXTEND(1),
        .PCR_EXTEND_EMPTY_AUTH_MASK(24'h810101), .PCR_EXTEND_LOCALITY_MASK(5'b00001)''')
    top_text = replace_once(top_text, '.CLOCK_50(clock_50),',
                            wiring+',\n        .aes_slot_allow_i(qa_aes_allow_i), .CLOCK_50(clock_50),')
    generated = {top:project/top.name, tpm:project/tpm.name}
    for original, body in [(top,top_text),(tpm,tpm_text)]:
        generated[original].write_text('// Board capacity probe. Virtual trusted requests.\n'+body)
    qsf = BOARD/'de25_soc_top.qsf'
    sources = {top,tpm,qsf,BOARD/'de25_soc_top.qpf',BOARD/'de25_spi_pins.tcl',Path(__file__)}
    def resolve(match):
        assignment = match[1]
        path = (BOARD / (match[2] or match[3])).resolve()
        if assignment != 'SEARCH_PATH':
            sources.add(path)
        return f'-name {assignment} "{generated.get(path,path).as_posix()}"'
    settings = re.sub(r'-name (VERILOG_FILE|SEARCH_PATH|SDC_FILE) (?:"([^"]+)"|([^\s]+))',
                      resolve, qsf.read_text())
    for path in sorted((ROOT/'Source Code/Symmetric Module').rglob('*.v')):
        if path not in sources:
            settings += f'\nset_global_assignment -name VERILOG_FILE "{path.as_posix()}"'
            sources.add(path)
    settings += '\nset_instance_assignment -name VIRTUAL_PIN ON -to qa_*\n'
    (project/qsf.name).write_text(settings)
    shutil.copyfile(BOARD/'de25_spi_pins.tcl',project/'de25_spi_pins.tcl')
    shutil.copyfile(BOARD/'de25_soc_top.qpf',project/'de25_soc_top.qpf')
    sources.update((ROOT/'Source Code').rglob('*.vh'))
    return project, sources, [*generated.values(),project/qsf.name]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output',type=Path)
    args = parser.parse_args()
    build = args.output.resolve()
    project,sources,generated = prepare(build)
    audit = lambda: {str(p.relative_to(ROOT)):sha(p) for p in sorted(sources)}
    record = {'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
              'inputs':audit(), 'generated':{p.name:sha(p) for p in generated},
              'production_board_signoff':False,'jobs':[]}
    try:
        for stage,timeout in [('syn',1200),('fit',5400),('sta',1800)]:
            command = [str(TOOLS/f'quartus_{stage}.exe'),'de25_soc_top']
            log = project/f'{stage}.log'
            started = time.monotonic()
            with log.open('wb') as out:
                process = subprocess.Popen(command,cwd=project,stdout=out,stderr=subprocess.STDOUT,
                                           creationflags=subprocess.CREATE_NO_WINDOW)
                try:
                    process.wait(timeout)
                except subprocess.TimeoutExpired:
                    subprocess.run(['taskkill.exe','/PID',str(process.pid),'/T','/F'],capture_output=True)
                    process.wait()
                finally:
                    record['jobs'].append({'stage':stage,'exit':process.returncode,'timeout_seconds':timeout,
                        'seconds':round(time.monotonic()-started,2),'log_sha256':sha(log)})
            print(stage,process.returncode,flush=True)
            if process.returncode:
                raise SystemExit(process.returncode)
    finally:
        record['inputs_after'] = audit()
        (build/'evidence.json').write_text(json.dumps(record,indent=2)+'\n')
        if record['inputs_after'] != record['inputs']:
            raise RuntimeError('Board probe inputs changed')


if __name__=='__main__':
    main()

