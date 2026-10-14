"""Snapshot the existing Phase 1 TPM for a DE25 RevD build; never programs USB."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import subprocess


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build', type=Path, required=True)
    parser.add_argument('--quartus', type=Path, default=Path('C:/altera_pro/26.1/quartus/bin64/quartus_sh.exe'))
    parser.add_argument('--compile', action='store_true')
    args = parser.parse_args()
    here = Path(__file__).resolve().parent
    repo = here.parents[1]
    demo = repo / 'Key Generation/demo/de25_revd'
    # Reuse the verified board pin table, never keygen RTL or its transport.
    spec = importlib.util.spec_from_file_location('keygen_board_pins', demo / 'prepare_build.py')
    pin_module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(pin_module)
    reference = (demo / 'vendor/pin_reference.qsf').read_text()
    sources = [repo / 'de25_soc_top.v', repo / 'TPM_TOP.v',
               repo / 'Management Module/management_module.v', repo / 'Execution Engine/execution_engine.v']
    sources += sorted((repo / 'IO Interface').glob('*.v'))
    sources += sorted((demo / 'vendor').glob('*.v'))
    sources += [demo / 'keygen_fan_guard.v']
    captured = {p: p.read_bytes() for p in sources}
    header = repo / 'IO Interface/tpm_types.vh'
    captured[header] = header.read_bytes()
    build = args.build.resolve()
    build.mkdir(parents=True, exist_ok=False)
    snapshot = build / 'sources'
    snapshot.mkdir()
    settings = []
    for line in reference.splitlines():
        if line.startswith('set_global_assignment') and not any(s in line for s in
            ('SIGNALTAP', 'TOP_LEVEL_ENTITY', 'VERILOG_FILE', 'SDC_FILE', 'QUARTUS_VERSION',
             'PROJECT_CREATION', 'IP_REGENERATION', 'PROJECT_OUTPUT_DIRECTORY')):
            settings.append(line)
    settings += [
        'set_global_assignment -name TOP_LEVEL_ENTITY de25_soc_top',
        'set_global_assignment -name VERILOG_INPUT_VERSION VERILOG_2001',
        'set_global_assignment -name VERILOG_MACRO "DE25_PHASE1_DIAGNOSTICS=1"',
        'set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files',
        'set_global_assignment -name NUM_PARALLEL_PROCESSORS 2',
        'set_global_assignment -name RESERVE_ALL_UNUSED_PINS "AS INPUT TRI-STATED"',
        'set_global_assignment -name SDC_FILE de25_soc_top.sdc',
        'set_global_assignment -name SEARCH_PATH sources',
    ]
    for index, path in enumerate(sources):
        dest = snapshot / f'{index:03d}_{path.name}'
        dest.write_bytes(captured[path])
        settings.append(f'set_global_assignment -name VERILOG_FILE "sources/{dest.name}"')
    (snapshot / 'TPM_TYPES.vh').write_bytes(captured[header])
    for port, (vendor, pin, standard) in pin_module.PINS.items():
        if not re.search(r'set_location_assignment\s+PIN_'+pin+r'\s+-to\s+'+re.escape(vendor)+r'\s*$', reference, re.M):
            raise RuntimeError('unverified pin '+port)
        settings += [f'set_location_assignment PIN_{pin} -to {port}',
                     f'set_instance_assignment -name IO_STANDARD "{standard}" -to {port}']
    for name in ('board_release_reg[*]', 'tpm_release_reg[*]',
                 'tpm|io|de25_serializer|spi_serializer|spi_clock_meta_reg',
                 'tpm|io|de25_serializer|spi_serializer|spi_clock_sync_reg',
                 'tpm|io|de25_serializer|spi_serializer|spi_mosi_meta_reg',
                 'tpm|io|de25_serializer|spi_serializer|spi_mosi_sync_reg',
                 'tpm|io|de25_serializer|spi_serializer|chip_select_meta_reg',
                 'tpm|io|de25_serializer|spi_serializer|chip_select_sync_reg'):
        settings.append('set_instance_assignment -name SYNCHRONIZER_IDENTIFICATION "FORCED IF ASYNCHRONOUS" -to {'+name+'}')
    sdc = (here / 'de25_soc_top.sdc').read_bytes()
    (build / 'de25_soc_top.sdc').write_bytes(sdc)
    (build / 'de25_soc_top.qsf').write_text('\n'.join(settings)+'\n')
    (build / 'de25_soc_top.qpf').write_text('PROJECT_REVISION = "de25_soc_top"\n')
    version = subprocess.run([str(args.quartus), '--version'], check=True, capture_output=True, text=True, timeout=60)
    manifest = {'status': 'prepared', 'top': 'de25_soc_top', 'device': 'A5ED013BB32AE4SCS',
        'timing_accepted': False, 'hardware_tested': False,
        'scope': 'Phase 1 TPM baseline, no keygen',
        'clocking': 'All Phase 1 DE25 logic runs at 50 MHz; no PLL required',
        'tool_version': version.stdout + version.stderr,
        'source_sha256': {str(p.relative_to(repo)): sha(data) for p, data in captured.items()},
        'snapshot_sha256': {str(p.relative_to(build)): sha(p.read_bytes()) for p in snapshot.iterdir()},
        'config_sha256': {p.name: sha(p.read_bytes()) for p in build.glob('de25_soc_top.*')}}
    for path, data in captured.items():
        if path.read_bytes() != data:
            raise RuntimeError('source changed during snapshot: '+str(path))
    manifest_path = build / 'build_manifest.json'
    manifest_path.write_text(json.dumps(manifest, indent=2)+'\n')
    if args.compile:
        from compile_phase1 import compile_snapshot
        compile_snapshot(build, args.quartus)
    print(str(build))


if __name__ == '__main__':
    main()
