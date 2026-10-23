"""Select/check a board project; compile only when --compile is supplied.

AI disclosure: Codex assisted with this board-selection utility.
"""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
TARGETS = {
    "DE1": ("de1_soc_top", "5CSEMA5F31C6", "Lite or Standard"),
    "DE25": ("de25_soc_top", "A5ED013BB32AE4SCS", "Pro"),
}


def select(board):
    if board not in TARGETS:
        raise ValueError("board must be DE1 or DE25")
    top, device, edition = TARGETS[board]
    folder = ROOT / "Boards" / board
    project = folder / (top + ".qpf")
    settings = folder / (top + ".qsf")
    if not project.is_file():
        raise ValueError(f"Missing project: {project}")
    qsf = settings.read_text()
    for key, expected in (("TOP_LEVEL_ENTITY", top), ("DEVICE", device)):
        values = re.findall(r"^set_global_assignment -name " + key + r'\s+"?([^"\s]+)"?\s*$', qsf, re.M)
        if values != [expected]:
            raise ValueError(f"{settings}: {key} must be {expected}")
    if not re.search(r'PROJECT_REVISION\s*=\s*"' + re.escape(top) + r'"', project.read_text()):
        raise ValueError("Project revision does not match the selected top")
    sources = re.findall(r'^set_global_assignment -name (?:VERILOG_FILE|SDC_FILE)\s+"?([^"\n]+?)"?\s*$', qsf, re.M)
    if not sources:
        raise ValueError("Project has no source files")
    for source in sources:
        if not (folder / source).is_file():
            raise ValueError(f"Missing project input: {folder / source}")
    return folder, top, device, edition


def validate_fit(folder, top):
    output = folder / "output_files"
    summary = (output / (top + ".fit.summary")).read_text()
    match = re.search(r"Total PLLs\s*:\s*(\d+)", summary)
    if "Fitter Status : Successful" not in summary or not match or int(match[1]) < 1:
        raise ValueError("Fit did not retain the required hardware PLL")
    for suffix in (".fit.rpt", ".map.rpt", ".syn.rpt"):
        report = output / (top + suffix)
        if report.exists():
            text = report.read_text()
            if "Ignored assignment LOCATION" in text or "No exact pin location assignment" in text:
                raise ValueError("Quartus ignored or omitted board pin assignments; inspect its report")
    settings = (folder / (top + ".qsf")).read_text()
    pins = (output / (top + ".pin")).read_text()
    assignments = re.findall(r'^set_location_assignment PIN_(\S+) -to "?([^"\s]+)"?\s*$', settings, re.M)
    if not assignments:
        raise ValueError("No board pin assignments found")
    for pin, port in assignments:
        if not re.search(r"^" + re.escape(port) + r"\s*:\s*" + re.escape(pin) + r"\s*:", pins, re.M):
            raise ValueError(f"Physical pin does not match the board project: {port} / {pin}")
    if not (output / (top + ".sof")).is_file():
        raise ValueError("Compilation did not produce a bitstream")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=ROOT / "board_config.json")
    parser.add_argument("--board", choices=TARGETS, help="Override config for this run without editing it")
    parser.add_argument("--compile", action="store_true", help="Run Quartus; never program hardware")
    parser.add_argument("--quartus", default="quartus_sh", help="Path to the correct edition's quartus_sh")
    args = parser.parse_args(argv)
    try:
        board = args.board or json.loads(args.config.read_text())["board"]
        folder, top, device, edition = select(board)
        print(f"Board: {board}\nTop: {top}\nDevice: {device}\nProject: {folder / (top + '.qpf')}\nQuartus: {edition}", flush=True)
        if not args.compile:
            print("Project inputs verified. Add --compile to build.")
            return 0
        tool = str(Path(args.quartus).resolve()) if Path(args.quartus).is_file() else args.quartus
        version = subprocess.run([tool, "--version"], capture_output=True, text=True, check=True)
        text = version.stdout + version.stderr
        supported = ("Pro Edition" in text) if board == "DE25" else ("Lite Edition" in text or "Standard Edition" in text)
        if not supported:
            raise ValueError(f"{board} requires Quartus {edition}; selected tool reports: {text.strip()}")
        result = subprocess.run([tool, "--flow", "compile", top], cwd=folder)
        if result.returncode:
            return result.returncode
        validate_fit(folder, top)
        print("Compile complete; required PLL and pin assignments verified. Timing/hardware acceptance remains separate.")
        return 0
    except (OSError, ValueError, KeyError, TypeError, subprocess.CalledProcessError) as error:
        print(f"Build selection failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
