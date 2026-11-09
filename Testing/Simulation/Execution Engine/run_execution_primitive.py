"""Run execution-engine launch/capture tests with a mock and real symmetric RTL."""
import argparse
from pathlib import Path
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", type=Path, required=True)
    parser.add_argument("--questa-bin", type=Path, default=Path("C:/intelFPGA_lite/24.1std/questa_fse/win64"))
    args = parser.parse_args()
    bench = Path(__file__).resolve().parent
    repo = bench.parents[2]
    build = args.build.resolve()
    build.mkdir(parents=True, exist_ok=True)
    sym = repo/"Source Code/Symmetric Module"
    names = ("aes_sbox.v", "aes_inv_sbox.v", "aes_key_mem.v", "aes_encipher_block.v", "aes_decipher_block.v",
             "aes_core.v", "aes.v", "cfb_block.v", "kdfa_control.v", "session_parameter_controller.v", "encrypt_decrypt2_controller.v", "symmetric_top.v")
    sources = [repo/"Source Code/Execution Engine/execution_engine.v", *(sym/name for name in names)]
    script = build/"run.do"
    commands = ["onerror {quit -force -code 1}", "onbreak {resume}", "vlib work"]
    commands += [f"vlog -work work {{{path.as_posix()}}}" for path in sources]
    commands += [f"vlog -sv {{{(bench/'tb_execution_engine_primitive.sv').as_posix()}}}",
                 "vsim -voptargs=+acc -onfinish stop work.tb_execution_engine_primitive",
                 "run -all", "quit -sim"]
    for name in ("header", "handle", "session"):
        legacy = f"tb_execution_engine_{name}_valid"
        commands += [f"vlog {{{(bench/(legacy+'.v')).as_posix()}}}",
                     f"vsim -onfinish stop work.{legacy}", "run 800 ns", "quit -sim",
                     f"puts {{LEGACY_INTERFACE_SMOKE_PASS ({name})}}"]
    commands.append("quit -force -code 0")
    script.write_text("\n".join(commands), encoding="utf-8")
    result = subprocess.run([str(args.questa_bin/"vsim.exe"), "-c", "-do", f"do {{{script.as_posix()}}}"],
                            cwd=build, text=True, capture_output=True)
    (build/"run.log").write_text(result.stdout+result.stderr, encoding="utf-8")
    for line in (result.stdout+result.stderr).splitlines():
        if any(word in line for word in ("PASS", "Fatal", "** Error", "** Warning")):
            print(line)
    if result.returncode or "EXECUTION_SYMMETRIC_PASS" not in result.stdout:
        raise SystemExit(f"Execution integration failed. Read {build/'run.log'}")


if __name__ == "__main__":
    main()
