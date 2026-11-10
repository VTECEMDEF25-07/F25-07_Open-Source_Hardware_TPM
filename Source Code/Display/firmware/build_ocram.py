"""Project-local offline compile/compare gate. No hardware commands or installs."""
from pathlib import Path
import argparse,hashlib, importlib.util, json, struct, subprocess, sys
REPO=Path(__file__).resolve().parents[3]
parser=argparse.ArgumentParser()
parser.add_argument('--runtime-root',required=True,help='Project-local baremetal directory containing the pinned toolchain')
parser.add_argument('--output-dir',help='Separate build/evidence directory; never point at the preserved owner build-cold')
options=parser.parse_args()
options.cold=True
ROOT=Path(options.runtime_root).resolve()
SRC=Path(__file__).resolve().parent
OUT=Path(options.output_dir).resolve() if options.output_dir else ROOT/'build-cold'
OUT.mkdir(parents=True,exist_ok=True)
(OUT/'warnings.log').write_bytes(b'')
TOOL=ROOT/'toolchain/arm-gnu-toolchain-13.2.rel1-x86_64-aarch64-none-elf/bin'
archive=ROOT/'toolchain/arm-gnu-toolchain-13.2.rel1-x86_64-aarch64-none-elf.tar.xz'
archive_sha=hashlib.sha256(archive.read_bytes()).hexdigest()
assert archive_sha=='7fe7b8548258f079d6ce9be9144d2a10bd2bf93b551dafbf20fe7f2e44e014b8'
def linux(p):
    s=str(Path(p).resolve()).replace('\\','/')
    return '/mnt/'+s[0].lower()+s[2:]
commands=[]
def run(args,**kw):
    commands.append(args)
    r=subprocess.run(['wsl','-d','Ubuntu-24.04','--',*args],stdout=subprocess.PIPE,stderr=subprocess.PIPE,**kw)
    if r.returncode:
        sys.stderr.buffer.write(r.stderr);raise RuntimeError(args)
    if r.stderr:(OUT/'warnings.log').open('ab').write(r.stderr)
    return r.stdout
spec=importlib.util.spec_from_file_location('reference',REPO/'Testing/Host/LCD/de25_lcd.py')
ref=importlib.util.module_from_spec(spec);spec.loader.exec_module(ref)
font=[]
for code in range(32,91):
    rows=ref.PATTERNS.get(chr(code),ref.PATTERNS['?']).split()
    font.append([sum((rows[y][x]=='1')<<y for y in range(7)) for x in range(5)])
(SRC/'font.h').write_text('/* Generated from tested original de25_lcd.py PATTERNS. */\nstatic const unsigned char font[59][5]={\n'+',\n'.join('{'+','.join(map(str,row))+'}' for row in font)+'\n};\n',newline='\n')
gcc=linux(TOOL/'aarch64-none-elf-gcc')
version=run([gcc,'--version']).decode()
flags=['-std=c11','-Os','-g','-Wall','-Wextra','-Werror','-Wno-misleading-indentation','-ffreestanding','-fno-builtin','-fno-stack-protector','-fno-pie','-mgeneral-regs-only','-march=armv8-a','-nostdlib','-I'+linux(SRC)]
elf=OUT/'lcd_ocram.elf'
sources=['start.S','main.c','status.c','board.c']+(['cold_init.c','runtime.c'] if options.cold else [])
run([gcc,*flags,*[linux(SRC/n) for n in sources],'-Wl,--build-id=none','-Wl,-Map='+linux(OUT/'lcd_ocram.map'),'-T'+linux(SRC/'ocram.ld'),'-o',linux(elf)])
for fmt,name in [('ihex','lcd_ocram.hex'),('binary','lcd_ocram.bin')]:
    run([linux(TOOL/'aarch64-none-elf-objcopy'),'-O',fmt,linux(elf),linux(OUT/name)])
for program,args,name in [('readelf',['-h','-S','-l','-s'],'readelf.txt'),('size',['-A'],'size.txt'),('objdump',['-d'],'disassembly.txt')]:
    (OUT/name).write_bytes(run([linux(TOOL/('aarch64-none-elf-'+program)),*args,linux(elf)]))
exe=OUT/'host_test'
run(['gcc','-std=c11','-Wall','-Wextra','-Werror','-Wno-misleading-indentation','-fsanitize=undefined,bounds','-I'+linux(SRC),linux(SRC/'host_test.c'),linux(SRC/'status.c'),'-o',linux(exe)])
cases=[]
for mode in range(4):
    for code in range(16):
        for detail in ([0,2,4] if code==8 else [0]):
            word=0x01000080|(detail<<16)|(mode<<4)|code|(64 if code>=9 else 0)
            cases.append(dict(status_word=word,operation_id=0xffffffff,sequence=len(cases)))
cases.extend([dict(status_word=0x01000020,operation_id=0,sequence=0)])
validlines=[json.dumps(x) for x in cases]
badlines=['{}','null','{"status_word":16777344,"operation_id":1,"sequence":1,"extra":0}',
 '{"status_word":16777344,"operation_id":1,"operation_id":1}',
 '{"status_word":16777344,"operation_id":-1,"sequence":1}',
 '{"status_word":16777344,"operation_id":4294967296,"sequence":1}',
 '{"status_word":16777344,"operation_id":true,"sequence":1}',
 '{"status_word":16777344,"operation_id":01,"sequence":1}',
 '{"status_word":16777344,"operation_id":1.0,"sequence":1}',
 '{"status_word":16777344,"operation_id":1,"sequence":1}garbage']
for w in [0,0x02000080,0x01000180,0x010000c0,0x01000089]:
    badlines.append(json.dumps(dict(status_word=w,operation_id=1,sequence=1)))
checks=0
cold_log='not run: compile gate only'
if options.cold:
    cold_exe=OUT/'test_cold_init'
    run(['gcc','-std=c11','-Wall','-Wextra','-Werror','-Wno-misleading-indentation','-fsanitize=undefined,bounds','-DDE25_HOST_TEST','-I'+linux(SRC),linux(SRC/'test_cold_init.c'),linux(SRC/'cold_init.c'),'-o',linux(cold_exe)])
    cold_log=run([linux(cold_exe)]).decode()
    (OUT/'cold_init_tests.log').write_text(cold_log)
    board_exe=OUT/'test_board'
    run(['gcc','-std=c11','-Wall','-Wextra','-Werror','-Wno-misleading-indentation','-fsanitize=undefined,bounds','-DDE25_HOST_TEST','-I'+linux(SRC),linux(SRC/'test_board.c'),linux(SRC/'board.c'),'-o',linux(board_exe)])
    board_log=run([linux(board_exe)]).decode()
    (OUT/'board_tests.log').write_text(board_log)
    cold_log+=board_log
for stale in [False,True]:
    raw=run([linux(exe),*(['stale'] if stale else [])],input=('\n'.join(validlines+badlines)+'\n').encode())
    offset=0
    for record in cases:
        assert raw[offset]==1;offset+=1
        expected=ref.render(ref.status_lines(ref.decode_snapshot(record),stale=stale))
        assert raw[offset:offset+1024]==expected,record
        offset+=1024;checks+=1
    assert raw[offset:]==bytes(len(badlines));checks+=len(badlines)
# ELF header proves AArch64 executable; link assertion and symbols prove range.
readelf=(OUT/'readelf.txt').read_text()
assert 'AArch64' in readelf and 'EXEC' in readelf
assert 'Entry point address:               0x0' in readelf
blob=elf.read_bytes()
assert blob[:6]==b'\x7fELF\x02\x01'  # ELF64 little endian
assert struct.unpack_from('<H',blob,18)[0]==183  # EM_AARCH64
phoff=struct.unpack_from('<Q',blob,32)[0]
phsize,phcount=struct.unpack_from('<HH',blob,54)
segments=[]
for i in range(phcount):
    kind,flags,off,vaddr,paddr,filesz,memsz,align=struct.unpack_from('<IIQQQQQQ',blob,phoff+i*phsize)
    if kind==1:
        assert vaddr==paddr and paddr+memsz<=0x7f000 and filesz<=memsz
        segments.append(dict(address=paddr,file_bytes=filesz,memory_bytes=memsz))
assert segments
manifest=dict(compiler=version,official_toolchain_url='https://developer.arm.com/-/media/Files/downloads/gnu/13.2.rel1/binrel/arm-gnu-toolchain-13.2.rel1-x86_64-aarch64-none-elf.tar.xz',
 toolchain_sha256=archive_sha,
 altera_reference_commit='66bdcc347564c5698a8997169bce83a31647d618',
 checks=checks,load_segments=segments,commands=commands,source_sha256={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(SRC.iterdir()) if p.is_file()},
 files={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(OUT.glob('lcd_ocram.*'))},
 cold_init_tests=cold_log,
 status=('COLD_INIT_IMPLEMENTED; COMPILE_LINK_AND_HOST_TEST_PASS; TARGET_EXECUTION_UNVERIFIED' if options.cold else 'COMPILE_LINK_AND_HOST_RENDER_PASS; DEFAULT_RUNTIME_INIT_GUARD; NOT_BOARD_READY'),
 limits=(['Fitted SDM binary handoff not yet available','Runtime handoff checks precede initialization','No combined HPS-enabled FPGA fit or image','No load, UART, pins, or physical glass verified'] if options.cold else ['Cold-start clock/firewall/pinmux port not implemented','Default board_init refuses peripheral writes','No HPS-enabled FPGA image generated','No load, UART, pins, or physical glass verified']))
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2))
print(json.dumps({k:v for k,v in manifest.items() if k in ['checks','status','files']},indent=2))
print((OUT/'size.txt').read_text())
print(cold_log)
