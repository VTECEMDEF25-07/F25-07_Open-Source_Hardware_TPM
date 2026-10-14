# Filename: build_boot.py
# Authors: Project contributors; see Git history.
# Date: 2026-10-13
# General Description: Deterministic minimal RV32I assembler for feasibility boot, not a C toolchain.
# AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.

"""Deterministic minimal RV32I assembler for feasibility boot, not a C toolchain."""
import argparse, hashlib, json, re
from pathlib import Path
p=argparse.ArgumentParser(); p.add_argument("--output",type=Path,required=True); a=p.parse_args()
src=Path(__file__).resolve().parents[2]/"firmware"/"softcore_boot.S"
labels={}; ins=[]
for line in src.read_text().splitlines():
    line=line.split("#")[0].strip()
    if not line: continue
    if line.endswith(":"): labels[line[:-1]]=len(ins)*4
    else: ins.append(line)
def reg(v):
    assert re.fullmatch(r"x(?:[0-9]|[12][0-9]|3[01])",v),v
    return int(v[1:])
def imm(v):
    n=int(v,0); assert -2048<=n<=2047; return n&4095
words=[]
for pc,line in enumerate(ins):
    t=re.split(r"[ ,()]+",line.strip()); op=t[0]
    if op=="lui": w=(int(t[2],0)<<12)|(reg(t[1])<<7)|0x37
    elif op in ("addi","andi"):
        w=(imm(t[3])<<20)|(reg(t[2])<<15)|((0 if op=="addi" else 7)<<12)|(reg(t[1])<<7)|0x13
    elif op=="lw": w=(imm(t[2])<<20)|(reg(t[3])<<15)|(2<<12)|(reg(t[1])<<7)|3
    elif op=="sw":
        i=imm(t[2]); w=((i>>5)<<25)|(reg(t[1])<<20)|(reg(t[3])<<15)|(2<<12)|((i&31)<<7)|0x23
    elif op in ("beq","bne"):
        off=labels[t[3]]-pc*4; assert -4096<=off<=4094 and off%2==0
        i=off&8191; w=((i>>12)<<31)|(((i>>5)&63)<<25)|(reg(t[2])<<20)|(reg(t[1])<<15)|((op=="bne")<<12)|(((i>>1)&15)<<8)|(((i>>11)&1)<<7)|0x63
    else: raise ValueError(op)
    words.append(w)
assert len(words)<=8192
image="".join(f"{w:08x}\n" for w in words+[0x13]*(8192-len(words)))
a.output.mkdir(parents=True,exist_ok=True)
(a.output/"softcore_boot.hex").write_text(image,newline="\n")
manifest={"source_sha256":hashlib.sha256(src.read_text().encode()).hexdigest(),"image_sha256":hashlib.sha256(image.encode()).hexdigest(),"instruction_count":len(words),"rom_bytes":32768,"ram_bytes":16384,"isa":"RV32I","purpose":"self-test only; not RSA firmware"}
expected=src.with_name("softcore_boot_manifest.json")
if expected.exists() and json.loads(expected.read_text()) != manifest:
    raise RuntimeError("Firmware image differs from reviewed source/hash manifest")
(a.output/"softcore_boot_manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
print(json.dumps(manifest))
