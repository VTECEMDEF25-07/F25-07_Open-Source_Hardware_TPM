"""Build the RV32I RSA descriptor firmware using an explicit local xPack toolchain."""
import argparse,hashlib,json,subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument("--toolchain",type=Path,required=True);p.add_argument("--output",type=Path,required=True);p.add_argument("--memory-selftest",action="store_true");a=p.parse_args()
r=Path(__file__).resolve().parents[2];f=r/"firmware";a.output.mkdir(parents=True,exist_ok=True)
gcc=a.toolchain/"riscv-none-elf-gcc.exe";objcopy=a.toolchain/"riscv-none-elf-objcopy.exe";size=a.toolchain/"riscv-none-elf-size.exe"
name="memory_selftest" if a.memory_selftest else "rsa_control"
c_source=r/"testbench/softcore/memory_selftest.c" if a.memory_selftest else f/"rsa_control.c"
elf=a.output/(name+".elf");binary=a.output/(name+".bin")
subprocess.run([str(gcc),"-march=rv32i","-mabi=ilp32","-O2","-ffreestanding","-fno-builtin","-fno-stack-protector","-nostdlib","-mno-relax","-msmall-data-limit=0","-ffunction-sections","-fdata-sections","-Wall","-Wextra","-Werror","-Wl,--gc-sections","-Wl,-Map="+str(a.output/(name+".map")),"-T",str(f/"rsa_control.ld"),str(f/"rsa_start.S"),str(c_source),"-o",str(elf)],check=True)
subprocess.run([str(objcopy),"-O","binary",str(elf),str(binary)],check=True)
subprocess.run([str(size),str(elf)],check=True)
data=binary.read_bytes();assert len(data)<=32768,"Firmware exceeds ROM"
data+=bytes(32768-len(data));image="".join(f"{int.from_bytes(data[i:i+4],'little'):08x}\n" for i in range(0,len(data),4))
(a.output/(name+".hex")).write_text(image,newline="\n")
manifest={"compiler":subprocess.check_output([str(gcc),"--version"],text=True).splitlines()[0],"isa":"rv32i","abi":"ilp32","rom_capacity_bytes":32768,"ram_capacity_bytes":16384,"binary_bytes":binary.stat().st_size,"image_sha256":hashlib.sha256(image.encode()).hexdigest(),"source_sha256":{path.name:hashlib.sha256(path.read_text().encode()).hexdigest() for path in [c_source,f/"rsa_start.S",f/"rsa_control.ld"]}}
expected=f/"rsa_control_manifest.json"
if not a.memory_selftest and expected.exists() and json.loads(expected.read_text()) != manifest:
    raise RuntimeError("RSA firmware differs from reviewed source/hash manifest")
(a.output/(name+"_manifest.json")).write_text(json.dumps(manifest,indent=2)+"\n")
print(json.dumps(manifest))
