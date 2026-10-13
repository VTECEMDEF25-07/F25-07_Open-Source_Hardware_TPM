"""Prepare or compile four DE25 images. This script never programs a board."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess


def digest(data):
    return hashlib.sha256(data).hexdigest()


def verify_inputs(inputs):
    """Reject a moving source tree; compilation uses only the captured bytes."""
    for path, data in inputs.items():
        if path.read_bytes() != data:
            raise RuntimeError(f"source changed during snapshot: {path}")

PINS = {
    "clock_i": ("CLOCK0_50", "CH128", "3.3-V LVCMOS"),
    "board_reset_n_i": ("KEY[0]", "BW59", "1.2-V"),
    "spi_clock_i": ("GPIO_D[9]", "BU28", "3.3-V LVCMOS"),
    "spi_cs_n_i": ("GPIO_D[7]", "BP31", "3.3-V LVCMOS"),
    "spi_mosi_i": ("GPIO_D[5]", "BM31", "3.3-V LVCMOS"),
    "spi_reset_n_i": ("GPIO_D[11]", "BW28", "3.3-V LVCMOS"),
    "spi_miso_o": ("GPIO_D[3]", "BF40", "3.3-V LVCMOS"),
    "interrupt_n_o": ("GPIO_D[1]", "BE43", "3.3-V LVCMOS"),
    "fan_i2c_scl": ("FPGA_I2C_SCLK", "BF120", "3.3-V LVCMOS"),
    "fan_i2c_sda": ("FPGA_I2C_SDAT", "BH118", "3.3-V LVCMOS"),
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build-root", type=Path, required=True)
    parser.add_argument("--core-root", type=Path)
    parser.add_argument("--firmware", type=Path)
    parser.add_argument("--variant", choices=("all", "rtl_generic", "rtl_altera", "softcore_generic", "softcore_altera"), default="all")
    parser.add_argument("--compile", action="store_true")
    parser.add_argument("--processors",type=int,choices=range(1,17),default=2,help="limit Quartus worker pressure")
    parser.add_argument("--quartus", default="C:/altera_pro/26.1/quartus/bin64/quartus_sh.exe")
    args = parser.parse_args()
    here = Path(__file__).resolve().parent
    core = (args.core_root or here.parents[1]).resolve()
    firmware = (args.firmware or core / "build/full/rsa_control.hex").resolve()
    if not (core / "rtl/common/keygen_core.v").exists():
        raise FileNotFoundError("canonical keygen_core.v missing; pass --core-root")
    if not firmware.exists():
        raise FileNotFoundError("built firmware missing; pass --firmware; no placeholder ROM is permitted")
    variants = [f"{control}_{backend}" for control in ("rtl", "softcore")
                for backend in ("generic", "altera")
                if args.variant in ("all", f"{control}_{backend}")]
    for variant in variants:
        if (args.build_root / variant).exists():
            raise FileExistsError(f"build already exists: {args.build_root / variant}; use a new build root")
    version = subprocess.run([args.quartus, "--version"], check=True, capture_output=True,
                             text=True, timeout=60)
    tool_version = (version.stdout + version.stderr).strip()
    if not tool_version:
        raise RuntimeError("Quartus returned no tool version")
    pin_path = here / "vendor/pin_reference.qsf"
    pin_bytes = pin_path.read_bytes()
    pin_reference = pin_bytes.decode()
    base = []
    for line in pin_reference.splitlines():
        if not line.startswith("set_global_assignment"):
            continue
        if any(x in line for x in ("SIGNALTAP", "TOP_LEVEL_ENTITY", "VERILOG_FILE", "SDC_FILE", "QUARTUS_VERSION", "PROJECT_CREATION", "IP_REGENERATION", "PROJECT_OUTPUT_DIRECTORY")):
            continue
        base.append(line)
    rtl = sorted((core / "rtl").rglob("*.v"))
    ip = sorted(p for p in (core / "IP").rglob("*.v") if "tests" not in p.parts)
    sources = rtl + ip + sorted(here.glob("*.v")) + sorted((here / "vendor").glob("*.v")) + [here.parent / "test_rng/keygen_test_source.v"]
    inputs = {source: source.read_bytes() for source in sources}
    inputs[firmware] = firmware.read_bytes()
    inputs[pin_path] = pin_bytes
    verify_inputs(inputs)
    sdc = """create_clock -name board_clock -period 20.000 [get_ports clock_i]
create_generated_clock -name fan_clock -divide_by 128 -source [get_ports clock_i] [get_registers {*fan_control*CLOCKMEM_inst2*CK_1HZ}]
derive_clock_uncertainty
# External asynchronous inputs only feed explicit first-stage synchronizers.
set_false_path -from [get_ports {spi_clock_i spi_cs_n_i spi_mosi_i}]
# Asynchronous assertion; board/SPI reset release has two clocked stages.
set_false_path -from [get_ports {board_reset_n_i spi_reset_n_i}]
# At <=1MHz, mode-0 MISO changes after a falling edge and settles before the next rise.
set_max_delay 20.000 -to [get_ports {spi_miso_o interrupt_n_o}]
# Vendor slow open-drain management bus; not a core datapath timing exception.
set_false_path -from [get_ports {fan_i2c_scl fan_i2c_sda}]
set_false_path -to [get_ports {fan_i2c_scl fan_i2c_sda}]
"""
    for control in ("rtl", "softcore"):
        for backend in ("generic", "altera"):
            variant = f"{control}_{backend}"
            if args.variant not in ("all", variant):
                continue
            build = (args.build_root / variant).resolve()
            build.mkdir(parents=True, exist_ok=False)
            settings = base + [
                "set_global_assignment -name TOP_LEVEL_ENTITY keygen_de25_top",
                "set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files",
                f"set_global_assignment -name NUM_PARALLEL_PROCESSORS {args.processors}",
                'set_global_assignment -name RESERVE_ALL_UNUSED_PINS "AS INPUT TRI-STATED"',
                "set_global_assignment -name SDC_FILE keygen_de25.sdc",
                f"set_parameter -name RSA_SOFTCORE {int(control=='softcore')}",
            ]
            if backend == "altera":
                settings.append('set_global_assignment -name VERILOG_MACRO "KEYGEN_ALTERA=1"')
            snapshot = build / "sources"
            snapshot.mkdir(exist_ok=True)
            snapshot_paths = []
            for index, source in enumerate(sources):
                copied = snapshot / (str(index).zfill(3)+"_"+source.name)
                copied.write_bytes(inputs[source])
                if copied.read_bytes() != inputs[source]:
                    raise RuntimeError(f"snapshot copy mismatch: {copied}")
                snapshot_paths.append(copied)
            for source in snapshot_paths:
                settings.append(f'set_global_assignment -name VERILOG_FILE "{source.as_posix()}"')
            for port, (vendor, pin, standard) in PINS.items():
                if not re.search(r"set_location_assignment\s+PIN_"+pin+r"\s+-to\s+"+re.escape(vendor)+r"\s*$", pin_reference, re.M):
                    raise ValueError(f"pin reference mismatch: {port}")
                settings += [f"set_location_assignment PIN_{pin} -to {port}",
                             f'set_instance_assignment -name IO_STANDARD "{standard}" -to {port}']
            (build / "keygen_de25.qsf").write_text("\n".join(settings)+"\n")
            (build / "keygen_de25.qpf").write_text('PROJECT_REVISION = "keygen_de25"\n')
            (build / "keygen_de25.sdc").write_text(sdc)
            (build / "rsa_control.hex").write_bytes(inputs[firmware])
            verify_inputs(inputs)
            config_files = [build / name for name in ("keygen_de25.qsf", "keygen_de25.qpf", "keygen_de25.sdc", "rsa_control.hex")]
            manifest = {"variant": variant, "device": "A5ED013BB32AE4SCS", "clock_hz": 50000000,
                        "test_mode": True, "firmware_sha256": digest(inputs[firmware]),
                        "quartus_executable": str(Path(args.quartus).resolve()), "quartus_version": tool_version,
                        "pin_reference_sha256": digest(pin_bytes),
                        "config_sha256": {p.name: digest(p.read_bytes()) for p in config_files},
                        "source_sha256": {str(p): digest(inputs[p]) for p in sources},
                        "snapshot_sha256": {str(p): digest(p.read_bytes()) for p in snapshot_paths},
                        "status": "prepared", "timing_accepted": False}
            (build / "build_manifest.json").write_text(json.dumps(manifest, indent=2)+"\n")
            print(f"PREPARED {variant}: {build}", flush=True)
            if args.compile:
                with (build / "compile.log").open("w") as log:
                    result = subprocess.run([args.quartus, "--flow", "compile", "keygen_de25"], cwd=build, stdout=log, stderr=subprocess.STDOUT)
                manifest["status"] = "compiled" if result.returncode == 0 else "failed"
                (build / "build_manifest.json").write_text(json.dumps(manifest, indent=2)+"\n")
                if result.returncode:
                    raise RuntimeError(f"{variant}: Quartus failed; inspect {build/'compile.log'}")
                print(f"COMPILED {variant}; timing/resource reports still require acceptance review", flush=True)


if __name__ == "__main__":
    main()
